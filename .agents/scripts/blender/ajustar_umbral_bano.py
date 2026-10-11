"""Llevar la transición del suelo bajo la hoja y terminar el zócalo contra el rebaje.

El material del baño empezaba delante de la puerta cerrada. Dividir su cara real conserva
la superficie continua y permite prolongar las UV del artista, sin cubrirla con otra malla.
Los dos extremos del zócalo se recortan contra el marco sin rehacer el recorrido ni las juntas.
"""
import bpy
import bmesh
import itertools
import json
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / '.claude/scripts'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.consola import configurar
from ajustar_marco_bano import huella

configurar()


def estadisticas(bm):
    return {
        'vertices': len(bm.verts),
        'caras': len(bm.faces),
        'aristas_no_manifold': sum(not edge.is_manifold for edge in bm.edges),
        'caras_degeneradas': sum(face.calc_area() < 1e-12 for face in bm.faces),
    }


def firma_cara(face, layers):
    return {
        'vertices': {v.index: tuple(v.co) for v in face.verts},
        'uv': {loop.vert.index: [tuple(loop[layer].uv) for layer in layers]
               for loop in face.loops},
        'material': face.material_index,
        'smooth': face.smooth,
        'normal': tuple(face.normal),
    }


def continuar_uv(referencias):
    """Las tres referencias conservan la arista común y la inclinación del mapa del artista."""
    (a, ua), (b, ub), (c, uc) = referencias
    dx1, dy1 = b.x - a.x, b.y - a.y
    dx2, dy2 = c.x - a.x, c.y - a.y
    determinante = dx1 * dy2 - dx2 * dy1
    assert abs(determinante) > 1e-8
    gradientes = []
    for eje in range(2):
        du1, du2 = ub[eje] - ua[eje], uc[eje] - ua[eje]
        gradientes.append(((du1 * dy2 - du2 * dy1) / determinante,
                           (dx1 * du2 - dx2 * du1) / determinante))

    def uv(punto):
        return tuple(ua[i] + gx * (punto.x - a.x) + gy * (punto.y - a.y)
                     for i, (gx, gy) in enumerate(gradientes))

    return uv


def dividir_suelo(edificio, x_corte):
    malla = edificio.data
    bm = bmesh.new()
    bm.from_mesh(malla)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    bm.normal_update()
    layers = list(bm.loops.layers.uv.values())
    assert layers, 'La malla debe conservar las UV del artista'
    antes = estadisticas(bm)
    matriz = edificio.matrix_world

    def mundo(vert):
        return matriz @ vert.co

    materiales = [mat.name for mat in malla.materials]
    mat_bano = materiales.index('bano_piso_gris')
    mat_almacen = materiales.index('piso')
    candidatos = [face for face in bm.faces if face.material_index == mat_bano
                  and all(abs(mundo(v).z - .102237) < .00001 for v in face.verts)
                  and min(mundo(v).y for v in face.verts) < 2
                  and max(mundo(v).y for v in face.verts) > 7.8]
    assert len(candidatos) == 1, 'Se necesita la cara continua del suelo del baño'
    suelo = candidatos[0]
    if min(mundo(v).x for v in suelo.verts) >= x_corte - 1e-6:
        bm.free()
        return {'ya_corregido': True, 'x_transicion': x_corte, 'antes': antes, 'despues': antes}
    originales = {face: firma_cara(face, layers) for face in bm.faces}
    cruces = [edge for edge in suelo.edges
              if min(mundo(v).x for v in edge.verts) < x_corte - 1e-6
              and max(mundo(v).x for v in edge.verts) > x_corte + 1e-6]
    assert len(cruces) == 2, 'El corte debe atravesar sólo las dos aristas de las jambas'
    extremos = sorted([v for v in suelo.verts if mundo(v).x < x_corte - 1e-6],
                      key=lambda v: mundo(v).y)
    assert len(extremos) == 2
    a, b = extremos
    almacen = [face for face in bm.faces if face.material_index == mat_almacen
               and a in face.verts and b in face.verts]
    assert len(almacen) == 1
    almacen = almacen[0]
    tercero = next(v for v in almacen.verts if v not in (a, b))
    mapas = []
    for layer in layers:
        refs = [(mundo(v), next(loop[layer].uv.copy() for loop in almacen.loops
                               if loop.vert == v)) for v in (a, b, tercero)]
        mapas.append(continuar_uv(refs))

    paredes = set()
    nuevos = []
    inserciones = []
    for edge in cruces:
        bajo, alto = sorted(edge.verts, key=lambda v: mundo(v).x)
        factor = (x_corte - mundo(bajo).x) / (mundo(alto).x - mundo(bajo).x)
        caras = list(edge.link_faces)
        assert len(caras) == 2
        paredes.update(face for face in caras if face != suelo)
        uv_interpoladas = {}
        for face in caras:
            loops = {loop.vert: loop for loop in face.loops}
            uv_interpoladas[face] = [loops[bajo][layer].uv.lerp(loops[alto][layer].uv,
                                                                            factor)
                                     for layer in layers]
        _, nuevo = bmesh.utils.edge_split(edge, bajo, factor)
        nuevos.append(nuevo)
        for face in caras:
            loop = next(loop for loop in face.loops if loop.vert == nuevo)
            for layer, uv in zip(layers, uv_interpoladas[face]):
                loop[layer].uv = uv
        inserciones.append({'arista_original': [bajo.index, alto.index],
                            'factor': factor, 'punto': tuple(mundo(nuevo)),
                            'caras_vecinas': [face.index for face in caras if face != suelo]})
    nuevos.sort(key=lambda v: mundo(v).y)
    pieza, _ = bmesh.utils.face_split(suelo, nuevos[0], nuevos[1])
    frente = next(face for face in (suelo, pieza)
                  if max(mundo(v).x for v in face.verts) <= x_corte + 1e-6)
    bano = pieza if frente == suelo else suelo
    frente.material_index = mat_almacen
    for loop in frente.loops:
        for layer, mapa in zip(layers, mapas):
            loop[layer].uv = mapa(mundo(loop.vert))

    # Las paredes sólo ganan puntos colineales: su superficie y sus UV originales no cambian.
    for face, original in originales.items():
        if face == suelo:
            continue
        assert face.material_index == original['material'] and face.smooth == original['smooth']
        actual = firma_cara(face, layers)
        for indice, co in original['vertices'].items():
            assert actual['vertices'][indice] == co
            assert actual['uv'][indice] == original['uv'][indice]
        if face not in paredes:
            assert actual == original, ('Cambió una cara fuera del acceso', face.index)
        else:
            assert (Vector(actual['normal']) - Vector(original['normal'])).length < 1e-6
    for loop in bano.loops:
        if loop.vert in nuevos:
            continue
        assert [tuple(loop[layer].uv) for layer in layers] == originales[suelo]['uv'][
            loop.vert.index]
    corte = bm.edges.get((nuevos[0], nuevos[1]))
    assert corte is not None and corte.is_manifold
    despues = estadisticas(bm)
    assert despues['aristas_no_manifold'] == antes['aristas_no_manifold']
    assert despues['caras_degeneradas'] == antes['caras_degeneradas']
    informe = {'ya_corregido': False, 'x_transicion': x_corte,
               'antes': antes, 'despues': despues, 'inserciones': inserciones,
               'paredes_con_punto_colineal': sorted(face.index for face in paredes),
               'uv_anteriores_restantes_identicas': True, 'arista_del_corte_manifold': True}
    bm.to_mesh(malla)
    bm.free()
    malla.update()
    return informe


def terminar_zocalo(zocalo, marco):
    plano = max((marco.matrix_world @ v.co).x for v in marco.data.vertices)
    malla = zocalo.data
    puntos = {v.index: zocalo.matrix_world @ v.co for v in malla.vertices}
    minimo = min(p.x for p in puntos.values())
    extremos = {indice for indice, punto in puntos.items() if abs(punto.x - minimo) < 1e-6}
    assert len(extremos) == 10, 'Sólo deben cambiar los dos anillos de extremo del zócalo'
    if abs(minimo - plano) < 1e-6:
        return {'ya_corregido': True, 'x_extremos': plano, 'vertices_modificados': []}
    assert plano > minimo and plano - minimo < .04
    uv_antes = [[tuple(loop.uv) for loop in layer.data] for layer in malla.uv_layers]
    matriz_normales = zocalo.matrix_world.to_3x3().inverted().transposed()
    loops_cambiados = set()
    for face in malla.polygons:
        normal = matriz_normales @ face.normal
        eje = max(range(3), key=lambda i: abs(normal[i]))
        afectados = [loop for loop in face.loop_indices
                     if malla.loops[loop].vertex_index in extremos]
        if not afectados or eje == 0:
            continue
        ejes = [i for i in range(3) if i != eje]

        def proyectar(punto):
            return Vector((punto[ejes[0]], punto[ejes[1]], 0))

        def area(indices):
            ps = [proyectar(puntos[malla.loops[i].vertex_index]) for i in indices]
            return (ps[1] - ps[0]).cross(ps[2] - ps[0]).length

        referencias = max(itertools.combinations(face.loop_indices, 3), key=area)
        assert area(referencias) > 1e-8
        mapas = [continuar_uv([(proyectar(puntos[malla.loops[i].vertex_index]),
                               layer.data[i].uv.copy()) for i in referencias])
                 for layer in malla.uv_layers]
        for loop in afectados:
            vertice = malla.loops[loop].vertex_index
            anterior = puntos[vertice]
            nuevo = anterior.copy()
            nuevo.x = plano
            for layer, mapa in zip(malla.uv_layers, mapas):
                uv_antes_punto = mapa(proyectar(anterior))
                uv_despues_punto = mapa(proyectar(nuevo))
                for i in range(2):
                    layer.data[loop].uv[i] += uv_despues_punto[i] - uv_antes_punto[i]
            loops_cambiados.add(loop)
    inversa = zocalo.matrix_world.inverted()
    for indice in extremos:
        punto = puntos[indice].copy()
        punto.x = plano
        malla.vertices[indice].co = inversa @ punto
    malla.update()
    for layer, datos in zip(malla.uv_layers, uv_antes):
        assert all(tuple(loop.uv) == datos[i] for i, loop in enumerate(layer.data)
                   if i not in loops_cambiados)
    assert min((zocalo.matrix_world @ v.co).x for v in malla.vertices) >= plano - 1e-6
    return {'ya_corregido': False, 'x_extremos': plano,
            'recorte_mm': (plano - minimo) * 1000, 'vertices_modificados': sorted(extremos),
            'loops_uv_modificados': sorted(loops_cambiados),
            'escala_uv_conservada': 'gradiente actual de cada cara'}


def material_en_suelo(edificio, x, y):
    arbol = BVHTree.FromPolygons([edificio.matrix_world @ v.co for v in edificio.data.vertices],
                                [tuple(face.vertices) for face in edificio.data.polygons])
    punto, _, indice, _ = arbol.ray_cast(Vector((x, y, .4)), Vector((0, 0, -1)), .5)
    assert punto is not None
    material = edificio.data.materials[edificio.data.polygons[indice].material_index].name
    return {'x': x, 'y': y, 'z': punto.z, 'material': material}


def aplicar():
    edificio = bpy.data.objects['almacen-col']
    hoja = bpy.data.objects['puerta2-col']
    marco = bpy.data.objects['bano_marco_entrada']
    zocalo = bpy.data.objects['bano_zocalo_perimetral']
    vecinos = {obj.name: huella(obj) for obj in bpy.data.objects if obj.type == 'MESH'
               and obj.name not in {edificio.name, zocalo.name}}
    x_corte = hoja.matrix_world.translation.x
    antes = [material_en_suelo(edificio, 7.918, y) for y in (6.2, 6.82, 7.4)]
    suelo = dividir_suelo(edificio, x_corte)
    borde = terminar_zocalo(zocalo, marco)
    despues = [material_en_suelo(edificio, x, y)
               for x in (7.70, 7.918, 8.08) for y in (6.2, 6.82, 7.4)]
    assert all(r['material'] == ('piso' if r['x'] < x_corte else 'bano_piso_gris')
               for r in despues)
    assert all(abs(r['z'] - .102237) < .00001 for r in despues)
    assert all(huella(bpy.data.objects[nombre]) == firma for nombre, firma in vecinos.items())
    return {'suelo': suelo, 'zocalo': borde, 'rayos_antes': antes,
            'rayos_despues': despues, 'mallas_vecinas_identicas': len(vecinos)}


if __name__ == '__main__':
    fuente = RAIZ / 'assets/models/SEPT_JUEGOS_PROTOTIPO.blend'
    bpy.ops.wm.open_mainfile(filepath=str(fuente), load_ui=False)
    informe = aplicar()
    (RAIZ / 'reports').mkdir(parents=True, exist_ok=True)
    (RAIZ / 'reports/umbral-correccion.json').write_text(
        json.dumps(informe, indent=2), encoding='utf-8')
    destino = fuente if '--aplicar' in sys.argv else RAIZ / 'reports/umbral-bano-corregido.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    print(json.dumps(informe, indent=2), flush=True)
