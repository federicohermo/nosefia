"""Soldar el cuerpo del salón y recortar sus vanos sin caras internas entre tramos.

Edición de un paso. Las caras del baño, depósito y cielorraso conservan sus UV.
La unión usa las coordenadas exactas de los bloques, sin voxelizar a una resolución.
"""

import itertools
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar

configurar()


def union(cajas, materiales):
    ejes = [sorted({p[k] for caja in cajas for p in caja}) for k in range(3)]
    ocupadas = set()
    for celda in itertools.product(*(range(len(eje) - 1) for eje in ejes)):
        centro = [(ejes[k][i] + ejes[k][i + 1]) / 2 for k, i in enumerate(celda)]
        if any(all(a[k] < centro[k] < b[k] for k in range(3)) for a, b in cajas):
            ocupadas.add(celda)
    bm = bmesh.new()
    vertices = {}
    for celda in ocupadas:
        for eje, signo in itertools.product(range(3), [-1, 1]):
            vecina = list(celda)
            vecina[eje] += signo
            if tuple(vecina) in ocupadas:
                continue
            # Orden cíclico de ejes, normal exterior para cada una de las seis caras.
            u, v = (eje + 1) % 3, (eje + 2) % 3
            claves = []
            for du, dv in [(0, 0), (1, 0), (1, 1), (0, 1)]:
                punto = list(celda)
                punto[eje] += int(signo > 0)
                punto[u] += du
                punto[v] += dv
                claves.append(tuple(punto))
            if signo < 0:
                claves.reverse()
            for clave in claves:
                if clave not in vertices:
                    vertices[clave] = bm.verts.new([ejes[k][i] for k, i in enumerate(clave)])
            cara = bm.faces.new([vertices[c] for c in claves])
            cara.material_index = materiales["local_pared_pintada"]
            puntos = [v.co for v in cara.verts]
            if eje == 2 and signo > 0 and abs(puntos[0].z - .10223747) < .00001:
                cara.material_index = materiales["local_ceramica"]
            elif eje == 1 and signo > 0 and abs(puntos[0].y - 8.25329) < .00001:
                cara.material_index = materiales["deposito_revestimiento_bloques"]
    bm.normal_update()
    bmesh.ops.dissolve_limit(bm, angle_limit=.01, verts=list(bm.verts),
                             edges=list(bm.edges), delimit={"MATERIAL"})
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    abiertos = sum(not e.is_manifold for e in bm.edges)
    if abiertos:
        raise RuntimeError(f"La unión dejó {abiertos} aristas sin cerrar.")
    bm.verts.index_update()
    return bm


def aplicar(escala_del_piso=2.0, limite_x_del_piso=7.99, limite_y_del_piso=7.89):
    objeto = bpy.data.objects["almacen-col"]
    anterior = objeto.data
    mats = {m.name: i for i, m in enumerate(anterior.materials)}
    cajas = [
        ((-2.60, -6.40, -.104), (limite_x_del_piso, limite_y_del_piso, .10223747)),
        ((-2.60, -6.40, .10223747), (-2.48, -1.5, 4.38)),
        ((-2.60, 6.1, .10223747), (-2.48, 7.87, 4.38)),
        ((-2.60, -1.5, .10223747), (-2.48, 6.1, .48)),
        ((-2.60, -1.5, 4.16), (-2.48, 6.1, 4.38)),
        ((-2.48, -6.40, .10223747), (-1.5, -6.28, 4.38)),
        ((-.1, -6.40, .10223747), (1.65, -6.28, 4.38)),
        ((-1.5, -6.40, .10223747), (-.1, -6.28, 1.04)),
        ((-1.5, -6.40, 2.44), (-.1, -6.28, 4.38)),
        ((1.65, -6.40, 4.16), (7.87, -6.28, 4.38)),
        ((7.87, -6.40, .10223747), (8.08, -1.576, 4.38)),
        ((7.87, .104, .10223747), (8.08, 7.87, 4.38)),
        ((7.87, -1.576, 2.85), (8.08, .104, 4.38)),
        ((-4.594, 7.87, .10223747), (5.882, 8.25329, 7.09332)),
        ((7.606, 7.87, .10223747), (8.08, 8.25329, 7.09332)),
        ((5.882, 7.87, 2.886), (7.606, 8.25329, 7.09332)),
        ((-2.48, -6.28, 4.37), (7.87, 7.87, 4.40)),
    ]
    bm = union(cajas, mats)
    inv = objeto.matrix_world.inverted()
    vertices = [inv @ v.co for v in bm.verts]
    caras, indices, datos_uv, smooth = [], [], [], []
    for cara in bm.faces:
        caras.append([v.index for v in cara.verts])
        indices.append(cara.material_index)
        smooth.append(False)
        puntos = [v.co for v in cara.verts]
        if cara.material_index == mats["local_ceramica"]:
            coords = [((v.x + v.y) / (escala_del_piso * math.sqrt(2)),
                       (v.y - v.x) / (escala_del_piso * math.sqrt(2))) for v in puntos]
        elif cara.material_index == mats["deposito_revestimiento_bloques"]:
            coords = [(v.x / 2, v.z / 2) for v in puntos]
        else:
            eje = max(range(3), key=lambda k: abs(cara.normal[k]))
            u, v = [(1, 2), (0, 2), (0, 1)][eje]
            coords = [(p[u] / 2, p[v] / 2) for p in puntos]
        datos_uv.append([coords for _ in anterior.uv_layers])
    informe = dict(vertices=len(bm.verts), caras=len(bm.faces),
                   aristas_abiertas=0, volumen=bm.calc_volume())
    bm.free()
    conservados = {}
    for cara in anterior.polygons:
        mat = anterior.materials[cara.material_index].name
        puntos = [objeto.matrix_world @ anterior.vertices[i].co for i in cara.vertices]
        if mat in ["local_pared_pintada", "local_ceramica"]:
            continue
        if mat == "deposito_revestimiento_bloques" and all(
                abs(v.y - 8.25329) < .001 for v in puntos):
            continue
        indices_de_cara = []
        for indice in cara.vertices:
            if indice not in conservados:
                conservados[indice] = len(vertices)
                vertices.append(anterior.vertices[indice].co.copy())
            indices_de_cara.append(conservados[indice])
        caras.append(indices_de_cara)
        indices.append(cara.material_index)
        smooth.append(cara.use_smooth)
        datos_uv.append([[tuple(c.data[i].uv) for i in cara.loop_indices]
                         for c in anterior.uv_layers])
    nuevo = bpy.data.meshes.new("almacen_estructura_continua")
    nuevo.from_pydata(vertices, [], caras)
    for mat in anterior.materials:
        nuevo.materials.append(mat)
    for k, capa in enumerate(anterior.uv_layers):
        uv = nuevo.uv_layers.new(name=capa.name)
        for cara, datos in zip(nuevo.polygons, datos_uv):
            for i, coordenada in zip(cara.loop_indices, datos[k]):
                uv.data[i].uv = coordenada
    for cara, mi, s in zip(nuevo.polygons, indices, smooth):
        cara.material_index, cara.use_smooth = mi, s
    objeto.data = nuevo
    for nombre in ["local_vereda_lateral", "local_vereda_frente"]:
        if nombre in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[nombre], do_unlink=True)
    (RAIZ / ".git/revision_almacen/union_paredes.json").write_text(
        json.dumps(informe, indent=2), encoding="utf-8")
    print(informe)


if __name__ == "__main__":
    if "--aplicar" not in sys.argv:
        raise SystemExit("Pasar --aplicar para guardar la fuente.")
    if bpy.context.scene.get("local_estructura_continua_v4"):
        raise SystemExit("La estructura continua ya está aplicada.")
    aplicar()
    bpy.context.scene["local_estructura_continua_v4"] = True
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
