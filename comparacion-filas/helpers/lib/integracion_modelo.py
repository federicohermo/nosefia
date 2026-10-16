"""Traduce el modelo importado a los soportes físicos y enlaces de sus escenas."""

import re


def bloques(texto):
    return re.split(r'(?=^\[)', texto, flags=re.M)


def ruta(bloque):
    cabecera = bloque.split('\n', 1)[0]
    if not cabecera.startswith('[node '):
        return None
    nombre = re.search(r'name="([^"]+)"', cabecera)[1]
    padre = re.search(r'parent="([^"]+)"', cabecera)
    return (padre[1] + '/' if padre and padre[1] != '.' else '') + nombre


def propiedad(bloque, nombre, valor):
    bloque = re.sub(r'^' + re.escape(nombre) + r' = .*\n', '', bloque, flags=re.M)
    if valor is not None:
        bloque = bloque.rstrip() + '\n' + nombre + ' = ' + valor + '\n\n'
    return bloque


def poner(lista, path, props, cabecera=None):
    for i, b in enumerate(lista):
        if ruta(b) == path:
            for k, v in props.items():
                b = propiedad(b, k, v)
            lista[i] = b
            return
    if not cabecera:
        padre, _, nombre = path.rpartition('/')
        cabecera = f'[node name="{nombre}" parent="{padre or "."}"]'
    assert cabecera, path
    b = cabecera + '\n\n'
    for k, v in props.items():
        b = propiedad(b, k, v)
    lista.append(b)


def nodo(lista, nombre, padre, tipo, props, extra=''):
    path = (padre + '/' if padre != '.' else '') + nombre
    poner(lista, path, props, f'[node name="{nombre}" type="{tipo}" parent="{padre}"{extra}]')


def recurso(lista, nombre, tipo, props):
    tag = f'[sub_resource type="{tipo}" id="{nombre}"]'
    b = tag + '\n\n'
    for k, v in props.items():
        b = propiedad(b, k, v)
    for i, anterior in enumerate(lista):
        if anterior.startswith(tag):
            lista[i] = b
            return
    indice = next(i for i, anterior in enumerate(lista) if anterior.startswith('[node '))
    lista.insert(indice, b)


def numeros(valor):
    return [float(n) for n in re.findall(r'[-+]?(?:\d*\.\d+|\d+)(?:e[-+]?\d+)?', valor.split('(', 1)[1], re.I)]


def vec(valores):
    return 'Vector3(' + ', '.join(f'{n:.9f}' for n in valores) + ')'


def casco(modelo, lista, path, nombre, transform=None):
    id_ = 'modelo_' + re.sub(r'[^a-z0-9_]', '_', nombre.lower())
    puntos = modelo[path]['casco']
    recurso(lista, id_, 'ConvexPolygonShape3D', {
        'margin': '0.002',
        'points': 'PackedVector3Array(' + ', '.join(f'{x:.9f}' for x in puntos) + ')',
    })
    props = {'shape': f'SubResource("{id_}")'}
    if transform:
        props['transform'] = transform
    return props


def integrar(modelo: dict, fuentes: dict[str, str]) -> dict[str, str]:
    resultados = dict(fuentes)
    archivo = 'estructura_del_almacen.tscn'
    lista = [b for b in bloques(fuentes[archivo]) if ruta(b) != 'AvisoDeHeladera']
    # Sólo se conservan overrides de nodos que existen en el modelo o en la composición.
    validos = set(modelo)
    for _ in range(8):
        for b in lista:
            path = ruta(b)
            if path is None or path == 'Estructura':
                continue
            parent = path.rpartition('/')[0]
            header = b.split('\n', 1)[0]
            if (' type=' in header or ' instance=' in header) and (not parent or parent in validos):
                validos.add(path)
    lista = [b for b in lista if ruta(b) is None or ruta(b) == 'Estructura' or ruta(b) in validos]
    for i, b in enumerate(lista):
        if ruta(b) in modelo and ' type=' not in b.split('\n', 1)[0]:
            lista[i] = propiedad(b, 'transform', None)

    poner(lista, 'cajaregistradora', {'mesh': None})
    poner(lista, 'cajaregistradora/StaticBody3D/Volumen', casco(modelo, lista, 'cajaregistradora', 'caja'))
    poner(lista, 'cajaregistradora/Ranura', {
        'position': None, 'transform': modelo['cajaregistradora']['pose_ticket'],
    })
    poner(lista, 'cajaregistradora/StaticBody3D', {
        'ancho_del_papel': str(modelo['cajaregistradora']['ancho_ticket']),
    })

    computadora = ['base compu', 'base compu/monitor pantalla', 'base compu/monitor soporte', 'teclado', 'mouse']
    lista = [b for b in lista if not ((ruta(b) or '').startswith('base compu/StaticBody3D/Volumen'))]
    poner(lista, 'base compu/StaticBody3D', {
        'mallas': '[NodePath(".."), NodePath("../monitor pantalla"), NodePath("../monitor soporte"), NodePath("../../teclado"), NodePath("../../mouse")]'
    })
    for i, path in enumerate(computadora):
        poner(lista, path + '/StaticBody3D', {'collision_layer': '0', 'collision_mask': '0'} if i else {'collision_layer': '1', 'collision_mask': '1'})
        if i == 0:
            poner(lista, path + '/StaticBody3D/CollisionShape3D', {'disabled': 'true'})
        nodo(lista, f'VolumenComputadora{i}', 'base compu/StaticBody3D', 'CollisionShape3D', casco(modelo, lista, path, f'computadora_{i}', modelo[path]['a_computadora']))

    for path in ['tachitobasura', 'tachitobasura_001', 'tachitobasura_002', 'reloj']:
        poner(lista, path + '/StaticBody3D/Volumen', casco(modelo, lista, path, path))
        poner(lista, path + '/StaticBody3D/CollisionShape3D', {'disabled': 'true'})

    base = 'deposito_contenedor_grande_soporte'
    cuerpo = base + '/deposito_contenedor_grande_cuerpo'
    izq = base + '/deposito_contenedor_bisagra_izquierda'
    der = base + '/deposito_contenedor_bisagra_derecha'
    tapa = izq + '/CuerpoDeLaTapa'
    extra = ' node_paths=PackedStringArray("tapa", "mallas") groups=["interactuable"]'
    poner(lista, cuerpo + '/StaticBody3D', {
        'script': 'ExtResource("contenedor")',
        'tapa': 'NodePath("../../deposito_contenedor_bisagra_izquierda/CuerpoDeLaTapa")',
        'mallas': '[NodePath("..")]',
    }, f'[node name="StaticBody3D" parent="{cuerpo}"{extra}]')
    # El override heredado también declara la resolución de sus enlaces.
    for i, b in enumerate(lista):
        if ruta(b) == cuerpo + '/StaticBody3D' and 'node_paths=' not in b.split('\n', 1)[0]:
            lista[i] = b.replace('parent="' + cuerpo + '"', 'parent="' + cuerpo + '"' + extra)
    poner(lista, cuerpo + '/StaticBody3D/CollisionShape3D', {'disabled': 'true'}, f'[node name="CollisionShape3D" parent="{cuerpo}/StaticBody3D"]')
    bb = numeros(modelo[cuerpo]['aabb'])
    x, y, z, ancho, alto, fondo = bb
    espesor = 0.05
    paredes = [
        ((x + espesor/2, y + alto/2, z + fondo/2), (espesor, alto, fondo)),
        ((x + ancho - espesor/2, y + alto/2, z + fondo/2), (espesor, alto, fondo)),
        ((x + ancho/2, y + alto/2, z + espesor/2), (ancho, alto, espesor)),
        ((x + ancho/2, y + alto/2, z + fondo - espesor/2), (ancho, alto, espesor)),
        ((x + ancho/2, y + espesor/2, z + fondo/2), (ancho, espesor, fondo)),
    ]
    for i, (centro, tamano) in enumerate(paredes):
        recurso(lista, f'contenedor_nuevo_{i}', 'BoxShape3D', {'size': vec(tamano)})
        nodo(lista, f'Volumen{i}', cuerpo + '/StaticBody3D', 'CollisionShape3D', {'position': vec(centro), 'shape': f'SubResource("contenedor_nuevo_{i}")'})
    for hinge, leaf in [(izq, 'deposito_contenedor_tapa_izquierda'), (der, 'deposito_contenedor_tapa_derecha')]:
        path = hinge + '/' + leaf
        poner(lista, path, {'gi_mode': '2'}, f'[node name="{leaf}" parent="{hinge}"]')
        poner(lista, path + '/StaticBody3D', {'collision_layer': '0', 'collision_mask': '0'}, f'[node name="StaticBody3D" parent="{path}"]')
    extra = ' node_paths=PackedStringArray("bisagra", "bisagras_adicionales", "mallas", "forma", "formas_adicionales", "soporte") groups=["interactuable"]'
    nodo(lista, 'CuerpoDeLaTapa', izq, 'AnimatableBody3D', {
        'script': 'ExtResource("tapa_contenedor")', 'bisagra': 'NodePath("..")',
        'bisagras_adicionales': '[NodePath("../../deposito_contenedor_bisagra_derecha")]',
        'angulo_en_modelo': '0.383972435',
        'mallas': '[NodePath("../deposito_contenedor_tapa_izquierda"), NodePath("../../deposito_contenedor_bisagra_derecha/deposito_contenedor_tapa_derecha")]',
        'forma': 'NodePath("Volumen")', 'formas_adicionales': '[NodePath("VolumenDerecho")]',
        'soporte': 'NodePath("../../deposito_contenedor_grande_cuerpo/StaticBody3D")',
    }, extra)
    leaf = izq + '/deposito_contenedor_tapa_izquierda'
    nodo(lista, 'Volumen', tapa, 'CollisionShape3D', casco(modelo, lista, leaf, 'tapa_izquierda'))
    leaf = der + '/deposito_contenedor_tapa_derecha'
    nodo(lista, 'VolumenDerecho', tapa, 'CollisionShape3D', casco(modelo, lista, leaf, 'tapa_derecha', 'Transform3D(1,0,0,0,1,0,0,0,1,1.012,0,0)'))

    lector = 'EscritorioComputadora/lector de productos'
    poner(lista, lector, {'visible': 'false'}, '[node name="lector de productos" parent="EscritorioComputadora" groups=["geometria_de_referencia"]]')
    for i, b in enumerate(lista):
        if ruta(b) == lector:
            lista[i] = b.replace('parent="EscritorioComputadora"]', 'parent="EscritorioComputadora" groups=["geometria_de_referencia"]]')
    poner(lista, lector + '/StaticBody3D', {'collision_layer': '0', 'collision_mask': '0'}, f'[node name="StaticBody3D" parent="{lector}"]')
    posicion = numeros(modelo[lector]['global_transform'])[-3:]
    poner(lista, 'Lector', {'transform': 'Transform3D(1,0,0,0,1,0,0,0,1,' + ','.join(map(str,posicion)) + ')'})

    # La estantería agregada reutiliza las piezas de colisión de su modelo gemelo.
    origen = 'gondola_deposito03'
    destino = 'gondola_deposito_central_izquierda'
    if not any((ruta(b) or '').startswith(destino + '/StaticBody3D/Volumen') for b in lista):
        for b in list(lista):
            if (ruta(b) or '').startswith(origen + '/StaticBody3D'):
                lista.append(b.replace(origen + '/', destino + '/'))
    unicos = set()
    limpios = []
    for b in lista:
        path = ruta(b)
        if path is not None and path in unicos:
            continue
        if path is not None:
            unicos.add(path)
        limpios.append(b)
    for numero, tacho in enumerate(['tachitobasura', 'tachitobasura_001', 'tachitobasura_002']):
        hojas = [p for p, dato in modelo.items() if p.startswith(tacho + '/')
                 and 'tapa' in p and dato['tipo'] == 'MeshInstance3D']
        for hoja in hojas:
            poner(limpios, hoja + '/StaticBody3D', {
                'script': 'ExtResource("tacho")', 'tacho': str(numero),
                'mallas': '[NodePath("..")]',
            }, f'[node name="StaticBody3D" parent="{hoja}" '
               'node_paths=PackedStringArray("mallas") groups=["interactuable"]]')
    resultados[archivo] = ''.join(limpios)

    raiz = 'almacen.tscn'
    texto = fuentes[raiz].replace('deposito_contenedor_soporte/deposito_contenedor_cuerpo', cuerpo).replace('deposito_contenedor_soporte/deposito_contenedor_bisagra_tapa', izq)
    texto = texto.replace(', NodePath("Estructura/gondolanueva_002/StaticBody3D")', '')
    lista = bloques(texto)
    lista = [b for b in lista if not (ruta(b) or '').startswith('Estructura/SueloSolido')]
    resultados[raiz] = re.sub(r'(\[ext_resource type="LightmapGIData") uid="[^"]+"', r'\1', ''.join(lista))

    archivo = 'lector.tscn'
    texto = fuentes[archivo].replace('lector_de_productos.res', 'lector_del_almacen.res').replace('lector_de_productos_colision.res', 'lector_del_almacen_colision.res')
    lista = bloques(texto)
    bb = numeros(modelo[lector]['global_aabb'])
    centro = [bb[0] + bb[3]/2-posicion[0], bb[1] + 0.0125-posicion[1], bb[2] + bb[5]/2-posicion[2]]
    recurso(lista, 'hueco', 'BoxMesh', {'material': 'SubResource("oscuro")', 'size': vec((bb[3],0.025,bb[5]))})
    recurso(lista, 'hueco_actual', 'BoxShape3D', {'size': vec((bb[3],0.025,bb[5]))})
    poner(lista, 'Lector', {'forma_del_hueco': 'SubResource("hueco_actual")', 'posicion_del_hueco': vec(centro), 'metadata/modelo_reemplazado': 'NodePath("Estructura/' + lector + '")'})
    resultados[archivo] = ''.join(lista)

    archivo = 'objetos_del_almacen.tscn'
    lista = bloques(fuentes[archivo])
    for b in list(lista):
        encontrado = re.search(r'^nodo_del_modelo = &"([^"]+)"', b, re.M)
        if encontrado:
            poner(lista, ruta(b), {'transform': modelo[encontrado[1]]['global_transform']})
    for numero, tacho in enumerate(['tachitobasura', 'tachitobasura_001', 'tachitobasura_002'], 1):
        hoja = next(d for p, d in modelo.items() if p.startswith(tacho + '/')
                    and 'tapa' in p and d['tipo'] == 'MeshInstance3D')
        caja = numeros(hoja['global_aabb'])
        pie = modelo[f':BolsaDeBasura{numero}']['pie']
        posicion = (caja[0] + caja[3] / 2, caja[1] + caja[4] + pie + 0.004,
                    caja[2] + caja[5] / 2)
        poner(lista, f'BolsaDeBasura{numero}', {
            'transform': 'Transform3D(1,0,0,0,1,0,0,0,1,'
                         + ','.join(f'{n:.9f}' for n in posicion) + ')',
        })
    resultados[archivo] = ''.join(lista)
    return resultados
