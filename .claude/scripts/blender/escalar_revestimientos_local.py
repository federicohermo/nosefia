"""Agrandar sólo el tendido del salón, con placas completas entre las paredes.

Edición de un paso sobre la estructura continua v4. Conserva el atlas original,
los vanos, el depósito, el baño y todas las mallas de muebles.
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar

configurar()

X0, X1 = -2.48, 7.87
Y0, Y1 = -6.28, 7.87
COLUMNAS, FILAS = 12, 16
ANCHO, LARGO = (X1 - X0) / COLUMNAS, (Y1 - Y0) / FILAS


def aplicar():
    objeto = bpy.data.objects["almacen-col"]
    anterior = objeto.data
    techo = next(i for i, m in enumerate(anterior.materials) if m.name == "local_cielorraso")
    vertices, caras, indices, datos_uv, smooth = [], [], [], [], []
    conservados = {}
    inv = objeto.matrix_world.inverted()
    for cara in anterior.polygons:
        if cara.material_index == techo:
            continue
        puntos = [objeto.matrix_world @ anterior.vertices[i].co for i in cara.vertices]
        datos = [[tuple(c.data[i].uv) for i in cara.loop_indices]
                 for c in anterior.uv_layers]
        if anterior.materials[cara.material_index].name == "local_ceramica":
            # Mantener los 45 grados que compensan el tendido del bitmap original.
            datos = [[((v.x + v.y) / (2.4 * math.sqrt(2)),
                       (v.y - v.x) / (2.4 * math.sqrt(2))) for v in puntos]
                     for _ in anterior.uv_layers]
        indices_de_cara = []
        for i in cara.vertices:
            if i not in conservados:
                conservados[i] = len(vertices)
                vertices.append(anterior.vertices[i].co.copy())
            indices_de_cara.append(conservados[i])
        caras.append(indices_de_cara)
        indices.append(cara.material_index)
        datos_uv.append(datos)
        smooth.append(cara.use_smooth)
    for fila in range(FILAS):
        for columna in range(COLUMNAS):
            x, y = X0 + columna * ANCHO, Y0 + fila * LARGO
            # Un número entero de módulos ocupa el recinto; nunca se corta una celda.
            puntos = [(x, y, 4.26), (x, y + LARGO, 4.26),
                      (x + ANCHO, y + LARGO, 4.26), (x + ANCHO, y, 4.26)]
            u, v = columna % 4, fila % 4
            if columna in [0, COLUMNAS - 1] or fila in [0, FILAS - 1]:
                u, v = 0, 0
            coords = [(u / 4, v / 4), (u / 4, (v + 1) / 4),
                      ((u + 1) / 4, (v + 1) / 4), ((u + 1) / 4, v / 4)]
            caras.append(list(range(len(vertices), len(vertices) + 4)))
            vertices.extend(inv @ Vector(p) for p in puntos)
            indices.append(techo)
            datos_uv.append([coords for _ in anterior.uv_layers])
            smooth.append(False)
    nuevo = bpy.data.meshes.new("almacen_placas_enteras")
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
    print(f"Cielorraso: {COLUMNAS} x {FILAS} placas completas de {ANCHO:.6f} x {LARGO:.6f} m")
    print("Piso: mapa a 2.4 m, 20 % mayor, orientación conservada")


if __name__ == "__main__":
    if "--aplicar" not in sys.argv:
        raise SystemExit("Pasar --aplicar para guardar la fuente.")
    if bpy.context.scene.get("local_revestimientos_v5"):
        raise SystemExit("Los revestimientos v5 ya están aplicados.")
    aplicar()
    bpy.context.scene["local_revestimientos_v5"] = True
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
