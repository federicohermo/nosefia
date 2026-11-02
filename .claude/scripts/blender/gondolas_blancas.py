"""Devuelve las góndolas al blanco. Se aplica una sola vez.

    blender --background --python-exit-code 1 --python \
        .claude/scripts/blender/gondolas_blancas.py -- --aplicar

Sin `--aplicar` sólo informa, y el `.blend` del repo queda como estaba.

La chapa y el panel perforado vuelven a sus texturas blancas, que viven en
`assets/source/textures/shelf/`. Las ménsulas y los parantes lisos, que se habían oscurecido con
ellas, vuelven a blanco y a gris claro. Los zócalos, los portaprecios y el metal negro del freezer
no se tocan.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
TEXTURAS = RAIZ / "assets/source/textures/shelf"
IMAGENES = {
    "gondola_chapa_blanca_512_basecolor_negra": "gondola_chapa_blanca_512_basecolor.png",
    "gondola_panel_blanca_1024_basecolor_negra": "gondola_panel_blanca_1024_basecolor.png",
}
COLORES = {
    "GONDOLA | Mensula blanca": (0.8, 0.8, 0.8, 1.0),
    "GONDOLA | Parante gris claro": (0.55, 0.56, 0.58, 1.0),
}


def principal():
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE))
    if not any(nombre in bpy.data.images for nombre in IMAGENES):
        raise SystemExit("Las góndolas ya son blancas; no se tocó nada.")
    for nombre, archivo in IMAGENES.items():
        imagen = bpy.data.images[nombre]
        imagen.unpack(method="REMOVE")
        imagen.filepath = str(TEXTURAS / archivo)
        imagen.reload()
        imagen.pack()
        imagen.name = archivo.removesuffix(".png")
        print(f"{imagen.name}: {tuple(imagen.size)}")
    for nombre, color in COLORES.items():
        nodos = bpy.data.materials[nombre].node_tree.nodes
        base = next(n for n in nodos if n.type == "BSDF_PRINCIPLED")
        base.inputs["Base Color"].default_value = color
        print(f"{nombre}: {color}")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_as_mainfile(filepath=str(FUENTE), check_existing=False)


principal()
