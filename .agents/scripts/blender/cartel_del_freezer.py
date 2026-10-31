"""Deja un solo cartel sobre la tapa del freezer: el de fuera de servicio. Se aplica una sola vez.

    blender --background --python-exit-code 1 --python \
        .claude/scripts/blender/cartel_del_freezer.py -- --aplicar

Sin `--aplicar` sólo informa, y el `.blend` del repo queda como estaba.

El aviso de «Sin stock» toma el papel de fuera de servicio de la heladera, en su mismo lugar y con
su mismo tamaño. El de «Productos de muestra» se borra.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
QUE_SE_QUEDA = "freezer_aviso_sin_stock"
QUE_SE_VA = "freezer_aviso_productos_de_muestra"
NOMBRE_NUEVO = "freezer_aviso_fuera_de_servicio"
PAPEL = "AVISO | Fuera de servicio del juego"


def principal():
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE))
    if QUE_SE_QUEDA not in bpy.data.objects:
        raise SystemExit("El freezer ya tiene su cartel; no se tocó nada.")
    aviso = bpy.data.objects[QUE_SE_QUEDA]
    aviso.material_slots[1].material = bpy.data.materials[PAPEL]
    aviso.name = NOMBRE_NUEVO
    aviso.data.name = NOMBRE_NUEVO
    bpy.data.objects.remove(bpy.data.objects[QUE_SE_VA], do_unlink=True)
    print(f"{aviso.name} en {tuple(round(c, 3) for c in aviso.matrix_world.translation)}")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_as_mainfile(filepath=str(FUENTE), check_existing=False)


principal()
