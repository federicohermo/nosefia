"""Lleva el hombro de los tres bidones de jabón al trapecio que su textura pinta para él.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/uv_del_hombro_de_los_bidones.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.
Después va `exportar_modelo.py`.

## Por qué

El hombro, el cono entre el cuerpo y el pico, usaba la franja de la base del cuerpo. Donde el
hombro toca la franja de arriba del cuerpo se juntaban dos tiras que no son vecinas en la
textura, y en el juego se veía una línea clara alrededor del bidón. El trapecio que la textura
pinta para el hombro no lo usaba ninguna cara.

## Qué cambia

Sólo la UV de las caras del hombro: el anillo de abajo va al borde ancho del trapecio y el de
arriba al angosto. Cada gajo conserva su lugar alrededor del bidón, y así sigue la misma columna
que la franja del cuerpo. La malla y las texturas no cambian. Es idempotente.
"""

import math
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

BIDONES = ("bidón jabon01-col", "bidón jabon01-col.001", "bidón jabon01-col.002")
CUERPO = 0
#: El trapecio del hombro en la textura, medido en la imagen y con un margen hacia adentro.
V_ABAJO, V_ARRIBA = 0.534, 0.696
ABAJO = (0.018, 0.818)
ARRIBA = (0.128, 0.705)
#: Las columnas de las franjas del cuerpo, que el hombro usaba y que dicen su lugar alrededor.
COLUMNAS = (0.013, 0.987)
#: Una cara es del hombro si su radio cambia más que esto de un vértice a otro.
CONO = 0.05


def radio(punto, centro) -> float:
    return math.hypot(punto.x - centro[0], punto.y - centro[1])


def llevar(objeto) -> int:
    malla = objeto.data
    centro = (
        sum(v.co.x for v in malla.vertices) / len(malla.vertices),
        sum(v.co.y for v in malla.vertices) / len(malla.vertices),
    )
    hombro = []
    for cara in malla.polygons:
        puntos = [malla.vertices[i].co for i in cara.vertices]
        radios = [radio(p, centro) for p in puntos]
        if cara.material_index == CUERPO and max(radios) - min(radios) > CONO:
            hombro.append(cara)
    if not hombro:
        raise ValueError(f"{objeto.name} no tiene hombro")
    alturas = [malla.vertices[i].co.z for cara in hombro for i in cara.vertices]
    pie, tope = min(alturas), max(alturas)
    capa = malla.uv_layers[0].data
    for cara in hombro:
        for lazo, indice in zip(cara.loop_indices, cara.vertices):
            alto = (malla.vertices[indice].co.z - pie) / (tope - pie)
            vuelta = (capa[lazo].uv.x - COLUMNAS[0]) / (COLUMNAS[1] - COLUMNAS[0])
            izquierda = ABAJO[0] + (ARRIBA[0] - ABAJO[0]) * alto
            derecha = ABAJO[1] + (ARRIBA[1] - ABAJO[1]) * alto
            capa[lazo].uv = (
                izquierda + (derecha - izquierda) * vuelta,
                V_ABAJO + (V_ARRIBA - V_ABAJO) * alto,
            )
    return len(hombro)


def main() -> None:
    configurar()
    for nombre in BIDONES:
        objeto = bpy.data.objects[nombre]
        if objeto.data.get("hombro_en_su_trapecio"):
            print(f"{nombre}: ya estaba")
            continue
        caras = llevar(objeto)
        objeto.data["hombro_en_su_trapecio"] = True
        print(f"{nombre}: {caras} caras del hombro en su trapecio")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
