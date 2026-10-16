"""Regenera exclusivamente los apoyos visibles del riel y de las góndolas centrales."""

import json
import math
import re
import struct
from collections import Counter, defaultdict

from lib.gondola import nombre_en_godot
from lib.integracion_modelo import bloques, nodo, recurso, ruta


def prismas_verticales(caras):
    """La triangulación superior conserva los brazos, huecos y encuentros oblicuos del riel."""
    vertices = [tuple(p) for cara in caras for p in cara]
    if not vertices:
        raise ValueError('La malla no tiene caras')
    abajo, arriba = min(p[1] for p in vertices), max(p[1] for p in vertices)
    if arriba <= abajo:
        raise ValueError('La pieza no tiene espesor vertical')
    if any(abs(p[1] - abajo) > 1e-6 and abs(p[1] - arriba) > 1e-6 for p in vertices):
        raise ValueError('La pieza no es una extrusión entre dos niveles')
    superiores = {(p[0], p[2]) for p in vertices if abs(p[1] - arriba) <= 1e-6}
    inferiores = {(p[0], p[2]) for p in vertices if abs(p[1] - abajo) <= 1e-6}
    if superiores != inferiores:
        raise ValueError('Las bases no conservan el mismo contorno')
    salida = []
    for cara in caras:
        if not all(abs(p[1] - arriba) <= 1e-6 for p in cara):
            continue
        a, b, c = cara
        area2 = (b[0] - a[0]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[0] - a[0])
        if abs(area2) <= 1e-10:
            raise ValueError('Triángulo superior sin área')
        salida.append([tuple(p) for p in cara] + [(p[0], abajo, p[2]) for p in cara])
    if not salida:
        raise ValueError('Falta la superficie superior')
    return salida


def mallas_del_glb(datos, nombres):
    """Lee sólo las mallas solicitadas: los puntos ya están en ejes locales de Godot.

    La transformación del nodo pertenece a la escena importada. Aplicarla aquí de nuevo
    desplazaría o giraría los soportes una segunda vez.
    """
    if len(datos) < 12:
        raise ValueError('GLB incompleto')
    magic, version, largo = struct.unpack_from('<4sII', datos)
    if magic != b'glTF' or version != 2 or largo != len(datos):
        raise ValueError('Cabecera GLB inválida')
    chunks = {}
    offset = 12
    while offset < len(datos):
        if offset + 8 > len(datos):
            raise ValueError('Chunk GLB incompleto')
        largo, tipo = struct.unpack_from('<I4s', datos, offset)
        offset += 8
        if offset + largo > len(datos) or tipo in chunks:
            raise ValueError('Chunk GLB inválido o duplicado')
        chunks[tipo] = datos[offset:offset + largo]
        offset += largo
    try:
        modelo = json.loads(chunks[b'JSON'])
        binario = chunks.get(b'BIN\0', b'')
    except (KeyError, ValueError) as error:
        raise ValueError('GLB sin documento JSON válido') from error

    def accessor(indice):
        dato = modelo['accessors'][indice]
        vista = modelo['bufferViews'][dato['bufferView']]
        if dato.get('sparse') or vista.get('buffer', 0) != 0:
            raise ValueError('El apoyo requiere accessors completos del buffer local')
        formatos = {5121: 'B', 5123: 'H', 5125: 'I', 5126: 'f'}
        cantidades = {'SCALAR': 1, 'VEC3': 3}
        formato = '<' + formatos[dato['componentType']] * cantidades[dato['type']]
        paso = vista.get('byteStride', struct.calcsize(formato))
        comienzo = vista.get('byteOffset', 0) + dato.get('byteOffset', 0)
        fin = comienzo + paso * max(0, dato['count'] - 1) + struct.calcsize(formato)
        limite = vista.get('byteOffset', 0) + vista['byteLength']
        if fin > limite or fin > len(binario) or paso < struct.calcsize(formato):
            raise ValueError('Accessor fuera de su buffer')
        return [struct.unpack_from(formato, binario, comienzo + i * paso)
                for i in range(dato['count'])]

    salida = {}
    try:
        for anclaje in modelo.get('nodes', []):
            nombre = nombre_en_godot(anclaje.get('name', ''))
            if nombre not in nombres or 'mesh' not in anclaje:
                continue
            if nombre in salida:
                raise ValueError(f'Malla duplicada: {nombre}')
            caras = []
            for primitiva in modelo['meshes'][anclaje['mesh']]['primitives']:
                if primitiva.get('mode', 4) != 4:
                    raise ValueError(f'{nombre} no conserva sus triángulos')
                puntos = accessor(primitiva['attributes']['POSITION'])
                indices = [p[0] for p in accessor(primitiva['indices'])]
                if len(indices) % 3:
                    raise ValueError(f'{nombre} tiene una cara incompleta')
                caras.extend([[puntos[i] for i in indices[j:j + 3]]
                              for j in range(0, len(indices), 3)])
            if not caras:
                raise ValueError(f'Malla vacía: {nombre}')
            salida[nombre] = caras
    except (KeyError, IndexError, struct.error) as error:
        raise ValueError('Geometría GLB inválida') from error
    faltan = set(nombres) - salida.keys()
    if faltan:
        raise ValueError('Faltan mallas: ' + ', '.join(sorted(faltan)))
    return salida


def _con_volumen(puntos):
    if len(puntos) < 4 or not all(math.isfinite(c) for p in puntos for c in p):
        return False
    origen = puntos[0]
    direccion = next((tuple(b - a for a, b in zip(origen, p)) for p in puntos[1:]
                      if p != origen), None)
    if direccion is None:
        return False
    for punto in puntos[1:]:
        otro = tuple(b - a for a, b in zip(origen, punto))
        normal = (direccion[1] * otro[2] - direccion[2] * otro[1],
                  direccion[2] * otro[0] - direccion[0] * otro[2],
                  direccion[0] * otro[1] - direccion[1] * otro[0])
        if any(abs(sum(n * (b - a) for n, a, b in zip(normal, origen, p))) > 1e-12
               for p in puntos[1:]):
            return True
    return False


def poner_compuesto(texto, padre, cuerpo, piezas, capa):
    """Reemplaza sólo las formas del cuerpo indicado, sin tocar otros nodos o recursos."""
    # Blender y GLB triangulan algunas caras por diagonales distintas. El sólido es el
    # mismo: ordenar su nube local y normalizar -0 evita reescribir un apoyo equivalente.
    piezas = sorted([sorted({tuple(round(float(c), 9) or 0.0 for c in p) for p in puntos})
                     for puntos in piezas])
    if not piezas or any(not _con_volumen(puntos) for puntos in piezas):
        raise ValueError('Cada apoyo debe conservar un volumen no vacío')
    path = padre + '/' + cuerpo
    partes = bloques(texto)
    eliminadas = [b for b in partes if (ruta(b) or '').startswith(path + '/')]
    if any('type="CollisionShape3D"' not in b.split('\n', 1)[0] for b in eliminadas):
        raise ValueError('El cuerpo contiene nodos ajenos a sus formas de colisión')
    viejos = {match for b in eliminadas for match in re.findall(r'SubResource\("([^"]+)"\)', b)}
    partes = [b for b in partes if b not in eliminadas]
    restantes = {match for b in partes if ruta(b) is not None
                 for match in re.findall(r'SubResource\("([^"]+)"\)', b)}
    sin_uso = viejos - restantes
    partes = [b for b in partes if not any(
        b.startswith('[sub_resource ') and f'id="{identificador}"]' in b.split('\n', 1)[0]
        for identificador in sin_uso)]
    nodo(partes, cuerpo, padre, 'StaticBody3D', {
        'collision_layer': str(capa), 'collision_mask': '0' if capa == 8 else '1',
        'transform': None, 'position': None, 'rotation': None, 'scale': None,
        'editor_description': json.dumps(
            'Volúmenes convexos del soporte visible. La unión conserva el contacto y los huecos '
            'del modelo; no es su caja envolvente.', ensure_ascii=False),
    })
    prefijo = 'apoyo_' + re.sub(r'[^a-z0-9_]', '_', padre.lower()) + '_' + cuerpo.lower()
    for indice, puntos in enumerate(piezas):
        identificador = f'{prefijo}_{indice:03d}'
        recurso(partes, identificador, 'ConvexPolygonShape3D', {
            'margin': '0.002',
            'points': ('PackedVector3Array('
                       + ', '.join(f'{c:.9f}' for p in puntos for c in p) + ')'),
        })
        nodo(partes, f'Apoyo{indice:03d}', path, 'CollisionShape3D', {
            'shape': f'SubResource("{identificador}")',
        })
    nuevo = ''.join(partes)
    cantidad = len(re.findall(r'^\[(?:ext|sub)_resource\b', nuevo, re.M)) + 1
    return re.sub(r'(?<=load_steps=)\d+', str(cantidad), nuevo, count=1)


EPS = 1e-8


def resta(a, b):
    return tuple(x - y for x, y in zip(a, b))


def producto(a, b):
    return sum(x * y for x, y in zip(a, b))


def cruz(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def norma(a):
    return math.sqrt(producto(a, a))


def recortar(poligono, normal, constante, mayor=False):
    salida = []
    for i, p in enumerate(poligono):
        q = poligono[(i + 1) % len(poligono)]
        dp, dq = producto(normal, p) + constante, producto(normal, q) + constante
        pin, qin = (dp >= 0, dq >= 0) if mayor else (dp <= 0, dq <= 0)
        if pin:
            salida.append(p)
        if pin != qin:
            t = dp / (dp - dq)
            salida.append(tuple(p[d] + (q[d] - p[d]) * t for d in range(3)))
    return salida


def componentes(triangulos):
    aristas = defaultdict(list)
    for i, tri in enumerate(triangulos):
        for j in range(3):
            aristas[tuple(sorted((tri[j], tri[(j + 1) % 3])))].append(i)
    vecindad = [set() for _ in triangulos]
    for caras in aristas.values():
        for cara in caras:
            vecindad[cara].update(caras)
    pendientes = set(range(len(triangulos)))
    grupos = []
    while pendientes:
        semilla = min(pendientes)
        pila, grupo = [semilla], set()
        while pila:
            actual = pila.pop()
            if actual in grupo:
                continue
            grupo.add(actual)
            pila.extend(vecindad[actual] - grupo)
        pendientes.difference_update(grupo)
        grupos.append(sorted(grupo))
    return sorted(grupos, key=len, reverse=True)


def puntos_unicos(poligonos):
    return sorted({tuple(p) for poligono in poligonos for p in poligono})


def _plana(puntos, normal, origen):
    largo = norma(normal)
    return all(abs(producto(normal, resta(p, origen))) <= EPS * largo for p in puntos)


def _area2(poligono):
    return sum(norma(cruz(resta(poligono[i], poligono[0]),
                          resta(poligono[i + 1], poligono[0])))
               for i in range(1, len(poligono) - 1))


def _region(poligonos, cortes):
    salida = []
    for poligono in poligonos:
        for eje, valor, mayor in cortes:
            normal = tuple(1 if d == eje else 0 for d in range(3))
            poligono = recortar(poligono, normal, -valor, mayor)
        if len(poligono) < 3:
            continue
        if any(max(abs(p[eje] - valor) for p in poligono) < EPS for eje, valor, _ in cortes):
            continue
        if _area2(poligono) > 1e-12:
            salida.append(poligono)
    return salida


def _pata(poligonos, hacia_norte):
    pisos = []
    for poligono in poligonos:
        n = cruz(resta(poligono[1], poligono[0]), resta(poligono[2], poligono[0]))
        if norma(n) > EPS and n[1] / norma(n) < -.999999:
            pisos.append(poligono)
    if not pisos:
        raise ValueError("La pata no conserva su piso plano original.")
    piso = max(pisos, key=_area2)
    altura = sum(p[1] for p in piso) / len(piso)
    inferiores = []
    for poligono in poligonos:
        if min(p[1] for p in poligono) < altura - 1e-6:
            inferiores.extend(recortar(poligono, (0, 1, 0), -altura))
    if not inferiores:
        raise ValueError("La pata no conserva el cambio de piso junto al panel.")
    limite = max(p[2] for p in inferiores) if hacia_norte else min(p[2] for p in inferiores)
    return [puntos_unicos(_region(poligonos, [(2, limite, mayor)])) for mayor in (False, True)]


def _armazon(tris):
    planos = defaultdict(list)
    for tri in tris:
        if max(p[2] for p in tri) - min(p[2] for p in tri) < 1e-6:
            planos[round(sum(p[2] for p in tri) / 3, 6)].append(tri)
    if len(planos) != 4:
        raise ValueError("El armazón no conserva sus cuatro planos transversales.")
    cortes = sorted(sum(p[2] for tri in caras for p in tri) / (3 * len(caras))
                    for caras in planos.values())
    z0, z1, z2, z3 = cortes
    puntos = puntos_unicos(tris)
    xcentro = (min(p[0] for p in puntos) + max(p[0] for p in puntos)) / 2
    regiones = [
        [(2, z1, True), (2, z2, False)],
        [(2, z0, True), (2, z1, False)],
        [(2, z2, True), (2, z3, False)],
        [(2, z0, False), (0, xcentro, False)],
        [(2, z0, False), (0, xcentro, True)],
        [(2, z3, True), (0, xcentro, False)],
        [(2, z3, True), (0, xcentro, True)],
    ]
    salida = []
    for i, region in enumerate(regiones):
        # Sólo tocar el corte no da volumen: incluir esas caras extendería el panel
        # por la espina o haría una cuña entre las patas.
        poligonos = _region(tris, region)
        if i < 3:
            salida.append(puntos_unicos(poligonos))
        else:
            salida.extend(_pata(poligonos, i >= 5))
    return salida


def _chapa(tris, eje_fondo):
    # Mayor área proyectada horizontal orientada hacia arriba: ignora caras laterales
    # verticales y conserva exactamente la inclinación de la chapa original.
    cara = max(tris, key=lambda tri: cruz(resta(tri[1], tri[0]), resta(tri[2], tri[0]))[1])
    normal = cruz(resta(cara[1], cara[0]), resta(cara[2], cara[0]))
    largo = norma(normal)
    if normal[1] <= 0 or largo <= 0:
        raise ValueError("La chapa no conserva una superficie de apoyo orientada hacia arriba.")
    normal = tuple(v / largo for v in normal)
    constante = -producto(normal, cara[0])
    centro = sum(p[eje_fondo] for p in cara) / 3
    chapa, sobresalen = [], {-1: [], 1: []}
    for tri in tris:
        chapa.append(recortar(tri, normal, constante))
        if max(producto(normal, p) + constante for p in tri) <= 1e-6:
            continue
        poligono = recortar(tri, normal, constante, True)
        lado = -1 if sum(p[eje_fondo] for p in poligono) / len(poligono) < centro else 1
        sobresalen[lado].extend(poligono)
    puntos = puntos_unicos(tris)
    alto = max(p[1] for p in puntos) - min(p[1] for p in puntos)
    fondo = max(p[2] for p in puntos) - min(p[2] for p in puntos)
    if eje_fondo == 2 and alto < fondo * .5:
        # Las seis cabeceras delgadas doblan atrás hacia un tramo horizontal.
        # Unir ese tramo con la rampa en un casco rellenaba hasta 11,75 mm de aire.
        horizontales = defaultdict(list)
        for tri in tris:
            n = cruz(resta(tri[1], tri[0]), resta(tri[2], tri[0]))
            if n[1] / norma(n) > .999999:
                horizontales[round(sum(p[1] for p in tri) / 3, 6)].append(tri)
        if not horizontales:
            raise ValueError("La cabecera perdió su pestaña posterior horizontal.")
        secundaria = max(horizontales.values(), key=lambda caras: sum(_area2(t) for t in caras))
        altura = sum(p[1] for tri in secundaria for p in tri) / (3 * len(secundaria))
        if abs(normal[2]) < EPS:
            raise ValueError("La rampa de cabecera no conserva inclinación longitudinal.")
        corte_z = -(normal[1] * altura + constante) / normal[2]
        salida = [puntos_unicos([recortar(poligono, (0, 0, 1), -corte_z, mayor)
                                for poligono in chapa]) for mayor in (False, True)]
    else:
        salida = [puntos_unicos(chapa)]
    for lado, vertices in sobresalen.items():
        if not vertices:
            continue
        limite = (min(p[eje_fondo] for p in vertices) if lado > 0
                  else max(p[eje_fondo] for p in vertices))
        n = tuple(1 if d == eje_fondo else 0 for d in range(3))
        salida.append(puntos_unicos([recortar(tri, n, -limite, lado > 0) for tri in tris]))
    return salida


def grupos_convexos(triangulos):
    """Divide las 33 islas de metal en 65 nubes locales con volumen.

    Los cortes siguen los planos originales, incluidos los quiebres de rampas y patas.
    Las 48 etiquetas planas quedan fuera de la colisión; una topología desconocida falla
    en lugar de fabricar un casco general que rellene aire.
    """
    triangulos = [tuple(tuple(float(v) for v in p) for p in tri) for tri in triangulos]
    if not triangulos or any(len(tri) != 3 or any(len(p) != 3 for p in tri) for tri in triangulos):
        raise ValueError("Se necesitan triángulos de tres puntos 3D.")
    cerrados, etiquetas = [], 0
    for indices in componentes(triangulos):
        tris = [triangulos[i] for i in indices]
        puntos = puntos_unicos(tris)
        normal = cruz(resta(tris[0][1], tris[0][0]), resta(tris[0][2], tris[0][0]))
        if norma(normal) <= 1e-12:
            raise ValueError("Triángulo degenerado en la fuente.")
        incidencias = Counter(tuple(sorted((tri[i], tri[(i + 1) % 3])))
                              for tri in tris for i in range(3))
        if _plana(puntos, normal, tris[0][0]):
            if len(tris) != 2 or len(puntos) != 4:
                raise ValueError("Superficie abierta no reconocida: no se omite.")
            etiquetas += 1
            continue
        if set(incidencias.values()) != {2}:
            raise ValueError("Componente no cerrada: no se fabrica volumen.")
        cerrados.append(tris)
    if len(cerrados) != 33 or etiquetas != 48:
        raise ValueError(
            f"Topología fuente inesperada: {len(cerrados)} sólidos y {etiquetas} etiquetas.")
    armazon = cerrados[0]
    limites = [max(p[d] for tri in armazon for p in tri)
               - min(p[d] for tri in armazon for p in tri) for d in range(3)]
    salida = _armazon(armazon)
    for tris in cerrados[1:]:
        puntos = puntos_unicos(tris)
        ancho = max(p[0] for p in puntos) - min(p[0] for p in puntos)
        largo = max(p[2] for p in puntos) - min(p[2] for p in puntos)
        if largo > limites[2] * .6:
            salida.extend(_chapa(tris, 0))
        elif ancho > limites[0] * .8:
            salida.extend(_chapa(tris, 2))
        else:
            salida.append(puntos)
    if len(salida) != 65 or any(len(puntos) < 4 for puntos in salida):
        raise ValueError("La partición no conserva sus 65 volúmenes.")
    return salida


def actualizar_contorno_preciso(texto, padre, caras):
    return poner_compuesto(texto, padre, 'Contorno', grupos_convexos(caras), 8)


def actualizar_apoyos(texto, mallas):
    texto = poner_compuesto(texto, 'bano_riel_frontal', 'ApoyoDelRiel',
                            prismas_verticales(mallas['bano_riel_frontal']), 1)
    for padre in ('gondolanueva', 'gondolanueva2'):
        texto = actualizar_contorno_preciso(texto, padre, mallas[padre])
    return texto
