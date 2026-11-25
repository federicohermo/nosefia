"""Mete en 0..1 las UV de las papas Lay's que se pasaban del cuadrado de la textura.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/corregir_uv_de_las_papas.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.

## Por qué

Cinco caras del costado de la bolsa llevaban la U entre 1,63 y 2,05: la textura se repetía y
mostraba, después de su borde derecho, su borde izquierdo. En un atlas la textura no se
repite: pasado el borde, el filtro muestrea la etiqueta de la vecina. Ninguna otra malla
de producto se pasa más de 0,015 del cuadrado.

## Qué cambia

Sólo la U de esas cinco caras, que se lleva de `[1,625, 2,054]` a `[0,625, 1,0]`. Es una
compresión de 12,6 % del ancho de ese tramo, en el costado de la bolsa, donde la textura
repetida mostraba el borde de la etiqueta. UV2 y la geometría no se tocan.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

OBJETO = "snackpapas1-convcol.002"
DIMENSIONES = (32, 34)
DESDE, HASTA = 1.625, 2.054
CAE_EN = (0.625, 1.0)
UMBRAL_DE_LA_CARA = 1.5


def corregir() -> int:
    malla = bpy.data.objects[OBJETO].data
    if (len(malla.vertices), len(malla.polygons)) != DIMENSIONES:
        raise ValueError(f"Cambió la geometría de {OBJETO}; revisar sus UV antes de aplicar")
    capa = malla.uv_layers[0].data
    movidas = 0
    for cara in malla.polygons:
        if min(capa[i].uv.x for i in cara.loop_indices) < UMBRAL_DE_LA_CARA:
            continue
        for lazo in cara.loop_indices:
            u = capa[lazo].uv.x
            fraccion = (u - DESDE) / (HASTA - DESDE)
            capa[lazo].uv.x = CAE_EN[0] + fraccion * (CAE_EN[1] - CAE_EN[0])
        movidas += 1
    fuera = [
        cara.index
        for cara in malla.polygons
        if max(capa[i].uv.x for i in cara.loop_indices) > 1.02
    ]
    if fuera:
        raise ValueError(f"siguen fuera de 0..1 las caras {fuera}")
    return movidas


def main() -> None:
    configurar()
    movidas = corregir()
    print(f"caras corregidas: {movidas}")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
