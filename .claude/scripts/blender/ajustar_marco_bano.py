"""Cubrir el vano real sin desplazar la hoja ni cambiar las cabinas.

El marco anterior usaba un dintel supuesto 25 mm más alto que el real y exponía la pared.
La copia de trabajo permite verificar ese encuentro antes de guardar la fuente canónica.
"""
import bpy
import hashlib
import json
import sys
from pathlib import Path
from mathutils import Vector
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


def aplicar(margen=0.005):
    hoja = bpy.data.objects['puerta2-col']
    marco = bpy.data.objects['bano_marco_entrada']
    edificio = bpy.data.objects['almacen-col']
    vecinos = {o.name: huella(o) for o in bpy.data.objects if o.type == 'MESH'
               and o.name not in {hoja.name, marco.name}}
    geometria_hoja = [(tuple(v.co)) for v in hoja.data.vertices]
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
    puntos = [marco.matrix_world @ v.co for v in marco.data.vertices]
    ys = sorted(set(round(p.y, 5) for p in puntos))
    zs = sorted(set(round(p.z, 5) for p in puntos))
    assert len(ys) == 4 and len(zs) == 3, 'Expected one editable U profile'
    interior_izq, interior_der, interior_alto = ys[1], ys[2], zs[1]
    muestras = [(6.82, (alto + interior_alto) / 2),
                ((izquierda + interior_izq) / 2, 1.70),
                ((derecha + interior_der) / 2, 1.70)]
    antes = [rayo(marco, y, z) for y, z in muestras]
    inversa = marco.matrix_world.inverted()
    for vertex in marco.data.vertices:
        p = marco.matrix_world @ vertex.co
        if abs(p.y - interior_izq) < 0.00002:
            p.y = izquierda + margen
        elif abs(p.y - interior_der) < 0.00002:
            p.y = derecha - margen
        if abs(p.z - interior_alto) < 0.00002:
            p.z = alto - margen
        vertex.co = inversa @ p
    marco.data.update()
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
    agregar_uv_planar_si_faltan(hoja)
    agregar_uv_planar_si_faltan(marco)
    bpy.context.view_layer.update()
    despues = [rayo(marco, y, z) for y, z in muestras]
    assert all(v['hit'] is not None for v in despues), 'New profile must cover each exposed band'
    assert [(tuple(v.co)) for v in hoja.data.vertices] == geometria_hoja
    assert [list(row) for row in hoja.matrix_world] == matriz_hoja
    cambiados = [o.name for o in bpy.data.objects if o.name in vecinos
                 and huella(o) != vecinos[o.name]]
    assert not cambiados, cambiados
    return {
        'lintel_z': alto,
        'opening_y': [izquierda, derecha],
        'previous_frame_inner': [interior_izq, interior_der, interior_alto],
        'new_frame_inner': [izquierda + margen, derecha - margen, alto - margen],
        'gap_mm': {'head': (interior_alto - alto) * 1000,
                   'left': (izquierda - interior_izq) * 1000,
                   'right': (interior_der - derecha) * 1000},
        'coverage_margin_mm': margen * 1000,
        'rays': [{'y':y, 'z':z, 'before':a, 'after':b}
                 for (y,z),a,b in zip(muestras,antes,despues)],
        'unchanged_neighbor_meshes': len(vecinos),
        'unchanged_leaf_geometry_and_transform': True,
        'leaf_materials': [m.name for m in hoja.data.materials],
    }


if __name__ == '__main__':
    fuente = RAIZ / 'assets/models/SEPT_JUEGOS_PROTOTIPO.blend'
    bpy.ops.wm.open_mainfile(filepath=str(fuente),
                            load_ui=False)
    informe = aplicar()
    (RAIZ / 'reports/marco-blanco-correccion.json').write_text(
        json.dumps(informe, indent=2), encoding='utf-8')
    destino = fuente if '--aplicar' in sys.argv else RAIZ / 'reports/puerta-marco-blancos.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    print(json.dumps(informe, indent=2), flush=True)
