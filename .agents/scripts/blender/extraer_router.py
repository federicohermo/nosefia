"""Deja en un .blend sólo el router que armó el artista.

blender SEPT_JUEGOS_PROTOTIPO.blend --background --python extraer_router.py -- router.blend

La fuente es `assets/source/SEPT_JUEGOS_PROTOTIPO.blend` de la rama `modelossupermercado`. Se
retiran los objetos ajenos y se empaqueta la imagen que la malla enlaza, para que el .blend no
dependa de la carpeta del artista. Las mallas, las UV, los materiales y las transformaciones no
se tocan.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]

OBJETOS = ("router-col", "antenas-col", "luces_botones-col", "patasrouter-col", "powerrouter_col")
destino = Path(sys.argv[sys.argv.index("--") + 1]).resolve()

for objeto in list(bpy.data.objects):
    if objeto.name not in OBJETOS:
        bpy.data.objects.remove(objeto, do_unlink=True)
# Un pase por cada tipo de dato que quedó sin dueño: mallas, materiales e imágenes ajenas.
bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
for coleccion in list(bpy.data.collections):
    if not coleccion.objects and not coleccion.children:
        bpy.data.collections.remove(coleccion)
for imagen in list(bpy.data.images):
    if imagen.source == "FILE":
        imagen.pack()
    else:
        bpy.data.images.remove(imagen)
bpy.ops.wm.save_as_mainfile(filepath=str(destino), compress=True)
print("objetos:", sorted(objeto.name for objeto in bpy.data.objects))
print("imagenes:", sorted(imagen.name for imagen in bpy.data.images))
