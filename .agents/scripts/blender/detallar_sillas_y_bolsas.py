"""Bisela las sillas del salón y abomba las bolsas de snacks: papas, chizitos y Saladix.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/detallar_sillas_y_bolsas.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.
Después van `exportar_modelo.py` y `extraer_mallas.gd`.

## Por qué

La silla tenía todos los cantos vivos y se leía como cajas pegadas. Las bolsas de papas y de
chizitos eran una losa de caras planas, y la de Saladix un ladrillo.

## Qué cambia

- **La silla** gana un chaflán de `BISEL` metros en cada canto vivo. La UV se desliza con el canto.
- **Las bolsas** se subdividen y toman forma de almohada: gruesas al medio y cerradas en los
  bordes. El ancho, el alto y el grosor máximo no cambian, y por eso entran donde entraban. La
  UV sale de la subdivisión: la etiqueta queda donde estaba.

## Lo que cuesta

Triángulos, y ningún dibujo. La cuenta por malla la imprime el script. Cada malla se marca al
pasar, y una malla marcada no se toca de nuevo.
"""

import math
import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

SILLA = "salon_silla_1a-col"
BISEL = 0.005
CANTO_VIVO = math.radians(30)

#: La unidad de cada bolsa y cuántos cortes lleva. El grosor es el eje más corto de la malla.
BOLSAS = {"snackpapas1-convcol.002": 1, "chisitos2-convcol.001": 1, "saladix-2oeste2-col": 3}
#: Cuánto grosor le queda a la bolsa en el borde, donde va la costura.
COSTURA = 0.08
MARCA = "detalle_de_forma"


def triangulos(malla) -> int:
    return sum(len(cara.verts) - 2 for cara in malla.faces)


def biselar(objeto) -> tuple[int, int]:
    malla = bmesh.new()
    malla.from_mesh(objeto.data)
    antes = triangulos(malla)
    vivos = [
        arista
        for arista in malla.edges
        if len(arista.link_faces) == 2 and arista.calc_face_angle(0.0) > CANTO_VIVO
    ]
    bmesh.ops.bevel(
        malla,
        geom=vivos,
        offset=BISEL,
        offset_type="OFFSET",
        segments=1,
        profile=0.5,
        affect="EDGES",
        clamp_overlap=True,
        loop_slide=True,
    )
    despues = triangulos(malla)
    malla.to_mesh(objeto.data)
    malla.free()
    return antes, despues


def abombar(objeto, cortes: int) -> tuple[int, int]:
    malla = bmesh.new()
    malla.from_mesh(objeto.data)
    antes = triangulos(malla)
    bmesh.ops.triangulate(malla, faces=malla.faces[:])
    bmesh.ops.subdivide_edges(malla, edges=malla.edges[:], cuts=cortes, use_grid_fill=True)
    minimos = [min(v.co[eje] for v in malla.verts) for eje in range(3)]
    maximos = [max(v.co[eje] for v in malla.verts) for eje in range(3)]
    # La escala del objeto decide cuál es el grosor: la malla puede ser un cubo.
    lados = [(maximos[eje] - minimos[eje]) * abs(objeto.scale[eje]) for eje in range(3)]
    grosor = lados.index(min(lados))
    ancho, alto = [eje for eje in range(3) if eje != grosor]
    medio = (maximos[grosor] + minimos[grosor]) / 2
    radio = (maximos[grosor] - minimos[grosor]) / 2
    for vertice in malla.verts:
        lado = vertice.co[grosor] - medio
        if abs(lado) < 1e-5:
            continue
        u = 2 * (vertice.co[ancho] - minimos[ancho]) / (maximos[ancho] - minimos[ancho]) - 1
        w = 2 * (vertice.co[alto] - minimos[alto]) / (maximos[alto] - minimos[alto]) - 1
        panza = (1 - abs(u) ** 2.2) * (1 - abs(w) ** 3)
        vertice.co[grosor] = medio + math.copysign(radio * max(panza, COSTURA), lado)
    for cara in malla.faces:
        cara.smooth = True
    despues = triangulos(malla)
    malla.to_mesh(objeto.data)
    malla.free()
    return antes, despues


def main() -> None:
    configurar()
    trabajos = [(SILLA, biselar, ())] + [(nombre, abombar, (c,)) for nombre, c in BOLSAS.items()]
    for nombre, forma, extra in trabajos:
        objeto = bpy.data.objects[nombre]
        if objeto.data.get(MARCA):
            print(f"{nombre}: ya estaba")
            continue
        antes, despues = forma(objeto, *extra)
        objeto.data[MARCA] = True
        print(f"{nombre}: {antes} -> {despues} triángulos, en {objeto.data.users} unidades")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
