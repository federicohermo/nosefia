"""Abomba el frente y el dorso de las bolsas de papas y de chizitos.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/abombar_bolsas.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.
Después van `exportar_modelo.py` y `extraer_mallas.gd`.

## Por qué

El frente de la bolsa era un plano: la bolsa se leía como una tabla con la etiqueta pegada.

## Qué cambia

Sólo el panel del frente y el del dorso, que llevan la etiqueta: se subdividen y su interior se
infla hacia afuera, como una bolsa con aire. El borde del panel no se mueve. Los fuelles de los
costados y las costuras de arriba y de abajo quedan como los dibujó el artista, con su grosor y
sus caras planas. La UV del panel sale de la subdivisión y el desplazamiento es perpendicular a
la etiqueta: el dibujo no se estira.

## Lo que cuesta

Unos 200 triángulos más por bolsa, y ningún dibujo. Cada malla se marca al pasar, y una malla
marcada no se toca de nuevo.
"""

import math
import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

#: Una unidad de cada bolsa: todas las de su producto comparten la malla.
BOLSAS = ("snackpapas1-convcol.002", "chisitos2-convcol.001")
CORTES = 3
#: Cuánto sale el centro del panel, en fracción del medio grosor de la bolsa.
INFLADO = 0.32
MARCA = "frente_abombado"


def abombar(objeto) -> tuple[int, int]:
    malla = bmesh.new()
    malla.from_mesh(objeto.data)
    antes = sum(len(cara.verts) - 2 for cara in malla.faces)
    xs = [v.co.x for v in malla.verts]
    medio_grosor = (max(xs) - min(xs)) / 2
    paneles = [cara for cara in malla.faces if abs(cara.normal.x) > 0.9]
    aristas = list({e for cara in paneles for e in cara.edges})
    bmesh.ops.subdivide_edges(malla, edges=aristas, cuts=CORTES, use_grid_fill=True)
    malla.normal_update()
    for lado in (1, -1):
        caras = [c for c in malla.faces if c.normal.x * lado > 0.9]
        vertices = {v for c in caras for v in c.verts}
        # El borde del panel también es de un fuelle o de una costura: no se mueve.
        quietos = {v for v in vertices if any(abs(f.normal.x) <= 0.9 for f in v.link_faces)}
        ys = [v.co.y for v in vertices]
        zs = [v.co.z for v in vertices]
        for v in vertices - quietos:
            u = (v.co.y - min(ys)) / (max(ys) - min(ys))
            w = (v.co.z - min(zs)) / (max(zs) - min(zs))
            v.co.x += lado * medio_grosor * INFLADO * math.sin(math.pi * u) ** 0.7 * math.sin(
                math.pi * w) ** 0.7
        for c in caras:
            c.smooth = True
    despues = sum(len(cara.verts) - 2 for cara in malla.faces)
    malla.to_mesh(objeto.data)
    malla.free()
    return antes, despues


def main() -> None:
    configurar()
    for nombre in BOLSAS:
        objeto = bpy.data.objects[nombre]
        if objeto.data.get(MARCA):
            print(f"{nombre}: ya estaba")
            continue
        antes, despues = abombar(objeto)
        objeto.data[MARCA] = True
        print(f"{nombre}: {antes} -> {despues} triángulos, en {objeto.data.users} unidades")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
