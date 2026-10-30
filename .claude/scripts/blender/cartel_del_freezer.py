"""Deja un solo cartel sobre la tapa del freezer: el de fuera de servicio. Se aplica una sola vez.

    blender --background --python-exit-code 1 --python \
        .claude/scripts/blender/cartel_del_freezer.py -- --aplicar

Sin `--aplicar` sólo informa, y el `.blend` del repo queda como estaba.

El aviso de «Sin stock» toma el papel de fuera de servicio de la heladera y se centra en la parte
plana de la tapa. Es un papel cuadrado, así que el aviso deja de ser apaisado. El de «Productos de
muestra» se borra.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
from mathutils import Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
QUE_SE_QUEDA = "freezer_aviso_sin_stock"
QUE_SE_VA = "freezer_aviso_productos_de_muestra"
NOMBRE_NUEVO = "freezer_aviso_fuera_de_servicio"
PAPEL = "AVISO | Fuera de servicio del juego"
FREEZER = "freezer_helados-col"
#: Dónde cae el medio del aviso hacia el fondo: acá la tapa ya no se curva.
FONDO_DE_LA_TAPA = -2.47
#: Cuánto mide el aviso hacia el fondo: el ancho no cambia y el papel es cuadrado.
FONDO_DEL_AVISO = 0.29


def principal():
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE))
    if QUE_SE_QUEDA not in bpy.data.objects:
        raise SystemExit("El freezer ya tiene su cartel; no se tocó nada.")
    aviso = bpy.data.objects[QUE_SE_QUEDA]
    aviso.material_slots[1].material = bpy.data.materials[PAPEL]
    fondo = max(v.co.y for v in aviso.data.vertices) - min(v.co.y for v in aviso.data.vertices)
    for vertice in aviso.data.vertices:
        vertice.co.y *= FONDO_DEL_AVISO / fondo
    aviso.data.update()
    cajas = [bpy.data.objects[FREEZER].matrix_world @ Vector(v)
             for v in bpy.data.objects[FREEZER].bound_box]
    mundo = aviso.matrix_world.copy()
    mundo.translation.x = (min(p.x for p in cajas) + max(p.x for p in cajas)) / 2
    mundo.translation.y = FONDO_DE_LA_TAPA
    aviso.matrix_world = mundo
    aviso.name = NOMBRE_NUEVO
    aviso.data.name = NOMBRE_NUEVO
    bpy.data.objects.remove(bpy.data.objects[QUE_SE_VA], do_unlink=True)
    print(f"{aviso.name} en {tuple(round(c, 3) for c in aviso.matrix_world.translation)}")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_as_mainfile(filepath=str(FUENTE), check_existing=False)


principal()
