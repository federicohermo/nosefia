"""Cerrar el encuentro de la hoja con el vano sin desplazar su bisagra ni cambiar cabinas.

Un marco sin tope deja ver el baño por la holgura lateral aunque cubra la pared correctamente.
El perfil continuo integra un rebaje delante de la hoja, que abre hacia el lado contrario.
La copia de trabajo permite verificar cobertura y barrido antes de guardar la fuente canónica.
"""
import bpy
import bmesh
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / '.claude/scripts'))
from lib.consola import configurar

configurar()


def huella(obj):
    data = {
        'matrix': [list(row) for row in obj.matrix_world],
        'vertices': [tuple(v.co) for v in obj.data.vertices],
        'faces': [(tuple(p.vertices), p.material_index, p.use_smooth) for p in obj.data.polygons],
        'materials': [m.name for m in obj.data.materials],
        'uv': [[tuple(v.uv) for v in layer.data] for layer in obj.data.uv_layers],
    }
    return hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()


def rayo(obj, y, z):
    verts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    tree = BVHTree.FromPolygons(verts, [tuple(p.vertices) for p in obj.data.polygons])
    hit, _, _, distance = tree.ray_cast(Vector((7.70, y, z)), Vector((1, 0, 0)), 1)
    return {'hit': tuple(hit) if hit else None, 'distance': distance}


def agregar_uv_planar_si_faltan(obj):
    if obj.data.uv_layers.active is not None:
        return
    uv = obj.data.uv_layers.get('UVMap')
    if uv is None:
        uv = obj.data.uv_layers.new(name='UVMap')
    obj.data.uv_layers.active_index = list(obj.data.uv_layers).index(uv)
    uv.active_render = True
    normales = obj.matrix_world.to_3x3().inverted().transposed()
    for face in obj.data.polygons:
        normal = (normales @ face.normal).normalized()
        eje = max(range(3), key=lambda i: abs(normal[i]))
        ejes = [i for i in range(3) if i != eje]
        for loop in face.loop_indices:
            punto = obj.matrix_world @ obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (punto[ejes[0]], punto[ejes[1]])


def rayos_de_cierre(hoja, marco, edificio):
    arboles = {}
    for objeto in (hoja, marco, edificio):
        vertices = [objeto.matrix_world @ v.co for v in objeto.data.vertices]
        caras = [tuple(p.vertices) for p in objeto.data.polygons]
        arboles[objeto.name] = BVHTree.FromPolygons(vertices, caras)
    puntos = [(7.6532, z, 'bisagra') for z in (.35, 1.4, 2.6)]
    puntos += [(5.9867, 1.4, 'cierre')]
    puntos += [(y, .115, 'inferior') for y in (6.2, 6.82, 7.4)]
    resultados = []
    for y, z, banda in puntos:
        for pendiente in (-.15, 0, .15):
            direccion = Vector((1, -pendiente, 0))
            for sentido in (-1, 1):
                origen = Vector((7.974, y, z)) - sentido * direccion * .5
                avance = sentido * direccion.normalized()
                golpes = []
                for nombre, arbol in arboles.items():
                    golpe, _, _, distancia = arbol.ray_cast(origen, avance, direccion.length)
                    if golpe is not None:
                        golpes.append((distancia, nombre, tuple(golpe)))
                resultados.append({'band': banda, 'y': y, 'z': z,
                                   'slope': pendiente, 'side': sentido,
                                   'hit': min(golpes) if golpes else None})
    return resultados


def construir_rebaje(marco, hoja, vano, piso, margen, solape, holgura):
    puntos = [marco.matrix_world @ v.co for v in marco.data.vertices]
    cuerpo = {i for p in hoja.data.polygons if p.material_index == 0 for i in p.vertices}
    ps = [hoja.matrix_world @ hoja.data.vertices[i].co for i in cuerpo]
    x_frente = min(p.x for p in puntos)
    x_escalon = marco.get('bano_x_escalon', max(p.x for p in puntos))
    marco['bano_x_escalon'] = x_escalon
    x_fondo = min(p.x for p in ps) - holgura
    y_exterior_izq = min(p.y for p in puntos)
    y_exterior_der = max(p.y for p in puntos)
    z_exterior = max(p.z for p in puntos)
    y_izq, y_der, z_dintel = vano
    y_interior_izq = y_izq + margen
    y_interior_der = y_der - margen
    z_interior = z_dintel - margen
    y_tope_izq = min(p.y for p in ps) + solape
    y_tope_der = max(p.y for p in ps) - solape
    z_tope = max(p.z for p in ps) - solape
    assert x_frente < x_escalon < x_fondo
    assert y_interior_izq < y_tope_izq < y_tope_der < y_interior_der
    assert z_tope < z_interior < z_exterior
    exterior = [(y_exterior_izq, piso), (y_exterior_izq, z_exterior),
                (y_exterior_der, z_exterior), (y_exterior_der, piso)]
    interior = [(y_interior_der, piso), (y_interior_der, z_interior),
                (y_interior_izq, z_interior), (y_interior_izq, piso)]
    tope = [(y_tope_der, piso), (y_tope_der, z_tope),
            (y_tope_izq, z_tope), (y_tope_izq, piso)]
    vertices = []

    def anillo(x, perfil):
        ids = list(range(len(vertices), len(vertices) + len(perfil)))
        vertices.extend((x, y, z) for y, z in perfil)
        return ids

    a = anillo(x_frente, exterior + interior)
    b = anillo(x_escalon, exterior + interior)
    c = anillo(x_fondo, exterior)
    d = anillo(x_escalon, tope)
    e = anillo(x_fondo, tope)
    f = anillo(x_fondo, [(y_interior_izq, piso), (y_interior_der, piso)])
    proporcion_izq = (y_interior_izq-y_exterior_izq) / (y_tope_izq-y_exterior_izq)
    proporcion_der = (y_exterior_der-y_interior_der) / (y_exterior_der-y_tope_der)
    g = anillo(x_fondo, [
        (y_interior_izq, z_exterior + proporcion_izq * (z_tope-z_exterior)),
        (y_interior_der, z_exterior + proporcion_der * (z_tope-z_exterior)),
    ])
    caras = [(a[0], a[1], a[6], a[7]), (a[1], a[2], a[5], a[6]),
             (a[2], a[3], a[4], a[5])]
    for inicio, fin in ((a, b), (b[:4], c)):
        for i in range(3):
            caras.append((inicio[i], inicio[i+1], fin[i+1], fin[i]))
    for i in range(4, 7):
        caras.append((a[i], a[i+1], b[i+1], b[i]))
    for i in range(3):
        caras.append((b[4+i], b[5+i], d[i+1], d[i]))
        caras.append((d[i], d[i+1], e[i+1], e[i]))
    caras += [
        (c[0], c[1], g[0], f[0]), (f[0], g[0], e[2], e[3]),
        (c[1], c[2], g[1], g[0]), (g[0], g[1], e[1], e[2]),
        (c[2], c[3], f[1], g[1]), (g[1], f[1], e[0], e[1]),
        (a[0], b[0], b[7], a[7]), (b[0], c[0], f[0], b[7]),
        (b[7], f[0], e[3], d[3]),
        (a[3], a[4], b[4], b[3]), (b[3], b[4], f[1], c[3]),
        (b[4], d[0], e[0], f[1]),
    ]
    anterior = marco.data
    nombre = anterior.name
    malla = bpy.data.meshes.new(nombre + ' temporal')
    inversa = marco.matrix_world.inverted()
    malla.from_pydata([inversa @ Vector(v) for v in vertices], [], caras)
    malla.materials.append(anterior.materials[0])
    bm = bmesh.new()
    bm.from_mesh(malla)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(malla)
    bm.free()
    marco.data = malla
    if anterior.users == 0:
        bpy.data.meshes.remove(anterior)
    malla.name = nombre
    agregar_uv_planar_si_faltan(marco)
    return {'step_x': x_escalon, 'rear_x': x_fondo,
            'stop_aperture': [y_tope_izq, y_tope_der, z_tope],
            'front_aperture': [y_interior_izq, y_interior_der, z_interior],
            'overlap_mm': solape * 1000, 'leaf_clearance_mm': holgura * 1000}


def aplicar(margen=0.005, solape=0.012, holgura=0.002):
    hoja = bpy.data.objects['puerta2-col']
    marco = bpy.data.objects['bano_marco_entrada']
    edificio = bpy.data.objects['almacen-col']
    vecinos = {o.name: huella(o) for o in bpy.data.objects if o.type == 'MESH'
               and o.name not in {hoja.name, marco.name}}
    geometria_hoja = [tuple(v.co) for v in hoja.data.vertices]
    matriz_hoja = [list(row) for row in hoja.matrix_world]
    candidatos = []
    for face in edificio.data.polygons:
        puntos = [edificio.matrix_world @ edificio.data.vertices[i].co for i in face.vertices]
        if (all(7.75 < p.x < 8.4 and 5.8 < p.y < 7.85 and 2.7 < p.z < 3 for p in puntos)
                and max(p.z for p in puntos) - min(p.z for p in puntos) < 0.00001):
            candidatos.append(puntos)
    assert len(candidatos) == 1, 'Need one existing lintel underside in the doorway'
    dintel = candidatos[0]
    izquierda = min(p.y for p in dintel)
    derecha = max(p.y for p in dintel)
    alto = min(p.z for p in dintel)
    antes = rayos_de_cierre(hoja, marco, edificio)
    piso = min((marco.matrix_world @ v.co).z for v in marco.data.vertices)
    cuerpo = {i for p in hoja.data.polygons if p.material_index == 0 for i in p.vertices}
    base_anterior = min((hoja.matrix_world @ hoja.data.vertices[i].co).z for i in cuerpo)
    inversa = hoja.matrix_world.inverted()
    modificados = []
    for i in sorted(cuerpo):
        vertice = hoja.data.vertices[i]
        punto = hoja.matrix_world @ vertice.co
        if abs(punto.z - base_anterior) < .00001:
            punto.z = piso + .001
            vertice.co = inversa @ punto
            modificados.append(i)
    hoja.data.update()
    blanco = bpy.data.materials.get('bano_entrada_blanca')
    if blanco is None:
        blanco = hoja.data.materials[0].copy()
        blanco.name = 'bano_entrada_blanca'
    blanco.diffuse_color = (0.86, 0.86, 0.82, 1)
    if not blanco.use_nodes:
        blanco.use_nodes = True
    principled = blanco.node_tree.nodes.get('Principled BSDF')
    assert principled is not None
    principled.inputs['Base Color'].default_value = blanco.diffuse_color
    principled.inputs['Roughness'].default_value = 0.78
    hoja.data.materials[0] = blanco
    marco.data.materials[0] = blanco
    rebaje = construir_rebaje(marco, hoja, (izquierda, derecha, alto), piso,
                             margen, solape, holgura)
    agregar_uv_planar_si_faltan(hoja)
    agregar_uv_planar_si_faltan(marco)
    bpy.context.view_layer.update()
    despues = rayos_de_cierre(hoja, marco, edificio)
    assert all(v['hit'] is not None for v in despues), 'Closed entrance must block every ray'
    assert all(tuple(v.co) == geometria_hoja[v.index] for v in hoja.data.vertices
               if v.index not in modificados)
    assert [list(row) for row in hoja.matrix_world] == matriz_hoja
    x_local = min(v.co.x for v in hoja.data.vertices)
    bisagra = hoja.matrix_world @ Vector((x_local, 0, 0))
    ps = [hoja.matrix_world @ hoja.data.vertices[i].co for i in cuerpo]
    assert max(p.y for p in ps) <= bisagra.y + .000001
    arbol_marco = BVHTree.FromPolygons(
        [marco.matrix_world @ v.co for v in marco.data.vertices],
        [tuple(p.vertices) for p in marco.data.polygons],
    )
    barrido = []
    for grados in range(0, 91, 5):
        giro = Matrix.Rotation(math.radians(grados), 4, 'Z')
        minimo = min((bisagra + giro @ (p-bisagra)).x for p in ps)
        assert minimo > rebaje['rear_x'] + holgura - .000001
        puntos_girados = [bisagra + giro @ (hoja.matrix_world @ v.co - bisagra)
                         for v in hoja.data.vertices]
        arbol_hoja = BVHTree.FromPolygons(
            puntos_girados, [tuple(p.vertices) for p in hoja.data.polygons]
        )
        cruces = arbol_marco.overlap(arbol_hoja)
        assert not cruces, ('Frame intersects moving leaf', grados, cruces)
        barrido.append({'degrees': grados, 'body_min_x': minimo,
                        'frame_triangle_intersections': len(cruces)})
    cambiados = [o.name for o in bpy.data.objects if o.name in vecinos
                 and huella(o) != vecinos[o.name]]
    assert not cambiados, cambiados
    return {
        'lintel_z': alto,
        'opening_y': [izquierda, derecha],
        'new_frame_inner': rebaje['front_aperture'],
        'coverage_margin_mm': margen * 1000,
        'rebate': rebaje,
        'bottom_before': base_anterior,
        'bottom_after': piso + .001,
        'leaf_changed_vertices': modificados,
        'hinge_world': tuple(bisagra),
        'sweep_clearance': barrido,
        'rays_before': antes,
        'rays_after': despues,
        'rays_unblocked_before': sum(r['hit'] is None for r in antes),
        'rays_unblocked_after': sum(r['hit'] is None for r in despues),
        'unchanged_neighbor_meshes': len(vecinos),
        'unchanged_leaf_upper_geometry_and_transform': True,
        'collider_size_y': max(p.z for p in ps) - min(p.z for p in ps),
        'collider_center_y': (max(p.z for p in ps) + min(p.z for p in ps)) / 2
                             - hoja.matrix_world.translation.z,
        'leaf_materials': [m.name for m in hoja.data.materials],
    }


if __name__ == '__main__':
    fuente = RAIZ / 'assets/models/SEPT_JUEGOS_PROTOTIPO.blend'
    bpy.ops.wm.open_mainfile(filepath=str(fuente),
                            load_ui=False)
    informe = aplicar()
    (RAIZ / 'reports/puerta-cierre-correccion.json').write_text(
        json.dumps(informe, indent=2), encoding='utf-8')
    destino = fuente if '--aplicar' in sys.argv else RAIZ / 'reports/puerta-cierre-opaco.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    print(json.dumps(informe, indent=2), flush=True)
