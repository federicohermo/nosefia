"""Reconstruye apoyos desde las piezas vigentes, conservando las conexiones de los puestos."""

import re

from lib.integracion_modelo import bloques, casco, nodo, numeros, poner, recurso, ruta, vec


def reconstruir(modelo: dict, piezas: dict, descompuestos: dict, fuentes: dict) -> dict:
    resultado = dict(fuentes)
    lista = bloques(fuentes['estructura_del_almacen.tscn'])
    for path, datos in modelo.items():
        if not path.startswith(('local_vidrio_frente_', 'local_vidrio_ventanal_')):
            continue
        if datos['tipo'] != 'MeshInstance3D':
            continue
        nombre = 'vidrio_solido_' + path
        lista = [b for b in lista if not (
            b.startswith('[sub_resource ') and f'id="{nombre}"' in b.split('\n', 1)[0]
        )]
        # El artista dibujó planos sin espesor: una caja inventaría una pared invisible.
        recurso(lista, nombre, 'ConcavePolygonShape3D', {
            'backface_collision': 'true',
            'data': 'PackedVector3Array(' + ','.join(map(str, datos['caras'])) + ')',
        })
        nodo(lista, 'CuerpoDelVidrio', path, 'StaticBody3D', {
            'collision_layer': '8', 'collision_mask': '0',
        })
        nodo(lista, 'Volumen', path + '/CuerpoDelVidrio', 'CollisionShape3D', {
            'shape': f'SubResource("{nombre}")',
            'position': None,
        })
    hay_suelo = any(ruta(b) == "SueloSolido" for b in lista)
    partes = {**piezas, **descompuestos}
    techo = 'deposito_techo_industrial/deposito_techo_chapa'
    cuerpo_del_techo = techo + '/StaticBody3D'
    lista = [b for b in lista if not (ruta(b) or '').startswith(cuerpo_del_techo + '/')]
    nodo(lista, 'StaticBody3D', techo, 'StaticBody3D', {
        'collision_layer': '8', 'collision_mask': '0',
        'metadata/sin_volumen': '"Chapa delgada y corrugada: ningún agarrable cabe en su espesor."',
    })
    # La chapa está corrugada: una envolvente convexa rellena el aire bajo sus pendientes.
    recurso(lista, 'chapa_actual', 'ConcavePolygonShape3D', {
        'backface_collision': 'true',
        'data': 'PackedVector3Array(' + ','.join(map(str, modelo[techo]['caras'])) + ')',
    })
    nodo(lista, 'Volumen', cuerpo_del_techo, 'CollisionShape3D', {
        'shape': 'SubResource("chapa_actual")',
    })
    for nombre in ('heladeranueva', 'heladeranueva_001', 'heladera_fuera_de_servicio'):
        # El frente es una puerta móvil. El recinto fijo conserva sus cinco paredes y bandejas.
        caja = numeros(modelo[nombre]['aabb'])
        x, y, z, ancho, alto, fondo = caja
        e = 0.025
        cajas = [
            ((x, y, z), (e, alto, fondo)),
            ((x, y, z), (ancho, alto, e)),
            ((x, y, z + fondo - e), (ancho, alto, e)),
            ((x, y, z), (ancho, e, fondo)),
            ((x, y + alto - e, z), (ancho, e, fondo)),
        ]
        partes[nombre] = [esquinas(pos, tam) for pos, tam in cajas]
        partes[nombre].extend(piezas[nombre][3:])
    for path, volumenes in partes.items():
        cuerpo = path + '/StaticBody3D'
        if cuerpo not in modelo:
            nodo(lista, 'StaticBody3D', path, 'StaticBody3D', {
                'collision_layer': '8', 'collision_mask': '0',
            })
        lista = [b for b in lista if not (
            (ruta(b) or '').startswith(cuerpo + '/')
            and (' type="CollisionShape3D"' in b.split('\n', 1)[0]
                 or ruta(b) in modelo)
        )]
        if path == 'almacen':
            lista = [b for b in lista if not (ruta(b) or '').startswith('almacen/Volumen')]
        if cuerpo + '/CollisionShape3D' in modelo:
            poner(lista, cuerpo + '/CollisionShape3D', {'disabled': 'true'},
                  f'[node name="CollisionShape3D" parent="{cuerpo}"]')
        for indice, puntos in enumerate(volumenes):
            nombre = 'actual_' + path.replace('/', '_').replace(' ', '_') + '_' + str(indice)
            recurso(lista, nombre, 'ConvexPolygonShape3D', {
                'margin': '0.002',
                'points': 'PackedVector3Array(' + ','.join(
                    f'{c:.9f}' for p in puntos for c in p) + ')',
            })
            nombre_nodo = 'Volumen' if indice == 0 else f'Volumen{indice + 1}'
            props = {'shape': f'SubResource("{nombre}")'}
            if path == 'almacen' and hay_suelo and es_piso(puntos):
                props['disabled'] = 'true'
                props['editor_description'] = (
                    '"SueloSolido reemplaza este piso; duplicarlo hunde las unidades al asentarse."'
                )
            nodo(lista, nombre_nodo, cuerpo, 'CollisionShape3D', props)
    for path, datos in modelo.items():
        if datos['tipo'] != 'MeshInstance3D' or not path.rsplit('/', 1)[-1].startswith('deposito_pallet_'):
            continue
        cuerpo = path + '/StaticBody3D'
        nodo(lista, 'StaticBody3D', path, 'StaticBody3D', {'collision_layer': '8', 'collision_mask': '0'})
        caja = numeros(datos['aabb'])
        nombre = 'tabla_' + path.replace('/', '_')
        recurso(lista, nombre, 'BoxShape3D', {'size': vec(caja[3:])})
        centro = [caja[i] + caja[i + 3] / 2 for i in range(3)]
        nodo(lista, 'Volumen', cuerpo, 'CollisionShape3D', {
            'position': vec(centro), 'shape': f'SubResource("{nombre}")',
        })
    frame = 'puerta/marco_puerta_deposito'
    poner(lista, frame, {'top_level': 'true', 'transform': modelo[frame]['global_transform']})
    poner(lista, 'reloj/Hora', {'transform': modelo['reloj']['pose_hora']})
    poner(lista, 'HabitacionesDelAlmacen', {
        nombre: 'Array[AABB]([' + ', '.join(cajas) + '])'
        for nombre, cajas in modelo[':habitaciones']['valores'].items()
    })
    # La hoja móvil ocupa la geometría actual y conserva su eje y sus señales.
    puertas = [path for path, datos in modelo.items() if datos['tipo'] == 'MeshInstance3D'
               and path.rsplit('/', 1)[-1] in ('puerta', 'puerta2', 'puertajefe', 'puertaentrada',
                                             'porton', 'puerta_limpieza', 'puerta_heladera_0',
                                             'puerta_heladera_1', 'puerta_heladera_2')]
    for path in puertas:
        if path.rsplit('/', 1)[-1].startswith('puerta_heladera_'):
            caja = numeros(modelo[path]['aabb'])
            poner(lista, path + '/Bisagra', {
                'position': vec((caja[0] + caja[3], caja[1] + caja[4] / 2, caja[2])),
            })
        padre = path + '/CuerpoDeLaHoja'
        poner(lista, padre, {'transform': modelo[path]['cuerpo_transform']})
        cuerpo = {path: {**modelo[path], 'casco': modelo[path]['casco_del_cuerpo']}}
        props = casco(cuerpo, lista, path, 'hoja_' + path)
        poner(lista, padre + '/Volumen', {
            **props, 'transform': None, 'position': None, 'scale': None, 'rotation': None,
        })
    resultado['estructura_del_almacen.tscn'] = ''.join(lista)
    lista = bloques(fuentes['objetos_del_almacen.tscn'])
    for b in list(lista):
        path = ruta(b)
        if path is None:
            continue
        enlace = re.search(r'nodo_del_modelo = &"([^"]+)"', b)
        if enlace is None:
            continue
        nombre = enlace[1]
        medidas = numeros(modelo[nombre]['aabb'])
        pose = numeros(modelo[nombre]['global_transform'])
        mundial = numeros(modelo[nombre]['global_aabb'])
        pose[-2] -= mundial[1] - 0.102237
        desplazamiento = re.search(r'metadata/desplazamiento_funcional = (.*)', b)
        if desplazamiento is not None:
            offset = numeros(desplazamiento[1])
            for eje in range(3):
                pose[-3 + eje] += offset[eje]
        poner(lista, path, {'transform': 'Transform3D(' + ','.join(map(str, pose)) + ')'})
        if path.startswith('Jabon') or path == 'Balde':
            forma = 'actual_' + path
            recurso(lista, forma, 'CylinderShape3D', {
                'height': str(medidas[4]), 'radius': str(max(medidas[3], medidas[5]) / 2),
            })
            poner(lista, path + '/Forma', {
                'shape': f'SubResource("{forma}")',
                'position': vec([medidas[i] + medidas[i + 3] / 2 for i in range(3)]),
            })
    resultado['objetos_del_almacen.tscn'] = ''.join(lista)
    for b in list(lista):
        path = ruta(b)
        if path is None or not path.startswith('CajaDe') or '/' in path:
            continue
        anclaje = re.search(r'metadata/soporte_del_modelo = "([^"]+)"', b)
        if anclaje is None:
            continue
        offset = numeros(re.search(r'metadata/desplazamiento_sobre_tabla = (.*)', b)[1])
        caja = numeros(modelo[anclaje[1]]['global_aabb'])
        pose = numeros(re.search(r'^transform = (.*)', b, re.M)[1])
        pose[-3:] = [caja[0] + caja[3] / 2 + offset[0],
                     caja[1] + caja[4] + modelo[':' + path]['media'],
                     caja[2] + caja[5] / 2 + offset[2]]
        poner(lista, path, {'transform': 'Transform3D(' + ','.join(map(str, pose)) + ')'})
    resultado['objetos_del_almacen.tscn'] = ''.join(lista)
    lista = bloques(fuentes['limpieza_del_almacen.tscn'])
    primera = numeros(modelo['gondolanueva']['global_aabb'])
    segunda = numeros(modelo['gondolanueva2']['global_aabb'])
    centro = (primera[0] + primera[3] + segunda[0]) / 2
    mancha = next(b for b in lista if ruta(b) == 'ManchaEntreLasGondolas')
    pose = numeros(re.search(r'^transform = (.*)', mancha, re.M)[1])
    pose[-3] = centro
    poner(lista, 'ManchaEntreLasGondolas', {
        'transform': 'Transform3D(' + ','.join(map(str, pose)) + ')',
    })
    resultado['limpieza_del_almacen.tscn'] = ''.join(lista)
    return resultado


def esquinas(posicion, tamano):
    return [[posicion[0] + x * tamano[0], posicion[1] + y * tamano[1],
             posicion[2] + z * tamano[2]] for x in (0, 1) for y in (0, 1) for z in (0, 1)]


def es_piso(puntos):
    # El origen del edificio está en la cara superior del piso; sus losas quedan debajo.
    return max(p[1] for p in puntos) <= 0.00001
