"""Duplica los gajos de los modelos redondos que se veían poligonales: balde, mopa, Fernet y Poético.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/redondear_modelos.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.
Después van `texturizar_utiles.py`, `exportar_modelo.py` y `extraer_mallas.gd`.

## Por qué

La botella de Fernet y el bidón de Poético eran prismas de ocho caras, el balde tenía doce y el
mango de la mopa cinco. De cerca, el borde se leía como un polígono.

## Qué cambia

Cada anillo de hasta `LADOS_MAXIMOS` lados gana un vértice en el medio de cada lado, llevado al
radio del anillo: un anillo de ocho pasa a dieciséis. Los anillos se buscan en la malla, no se
listan: un lazo cerrado de aristas a la misma altura y a la misma distancia de su centro. La UV
del vértice nuevo es la del medio del lado, y las ranuras de material no cambian.

## Lo que cuesta

Triángulos, y ningún dibujo. La cuenta por modelo la imprime el script. Cada malla se marca al
pasar, y una malla marcada no se toca de nuevo.
"""

import sys
from collections import defaultdict
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

OBJETOS = ("balde-col", "mopa-col", "Fernetgod-col", "poetico-convcol")
LADOS_MAXIMOS = 12
LADOS_MINIMOS = 5
TOLERANCIA = 0.001
MARCA = "gajos_duplicados"


def anillos(malla) -> list[list]:
    """Los lazos cerrados de aristas horizontales cuyos vértices equidistan de su centro."""
    vecinas = defaultdict(list)
    for arista in malla.edges:
        a, b = arista.verts
        if abs(a.co.z - b.co.z) < TOLERANCIA:
            vecinas[a].append(arista)
            vecinas[b].append(arista)
    vistas, lazos = set(), []
    for inicio in list(vecinas):
        if inicio in vistas:
            continue
        grupo, aristas, pendientes = [], set(), [inicio]
        while pendientes:
            vertice = pendientes.pop()
            if vertice in vistas:
                continue
            vistas.add(vertice)
            grupo.append(vertice)
            for arista in vecinas[vertice]:
                aristas.add(arista)
                pendientes.append(arista.other_vert(vertice))
        cerrado = len(aristas) == len(grupo) and all(len(vecinas[v]) == 2 for v in grupo)
        if not cerrado or not LADOS_MINIMOS <= len(grupo) <= LADOS_MAXIMOS:
            continue
        centro = sum((v.co for v in grupo), start=grupo[0].co * 0) / len(grupo)
        radios = [(v.co - centro).length for v in grupo]
        if max(radios) - min(radios) < TOLERANCIA and min(radios) > TOLERANCIA:
            lazos.append(list(aristas))
    return lazos


def redondear(objeto) -> tuple[int, int]:
    malla = bmesh.new()
    malla.from_mesh(objeto.data)
    antes = sum(len(cara.verts) - 2 for cara in malla.faces)
    for lazo in anillos(malla):
        vertices = {v for arista in lazo for v in arista.verts}
        centro = sum((v.co for v in vertices), start=lazo[0].verts[0].co * 0) / len(vertices)
        radio = sum((v.co - centro).length for v in vertices) / len(vertices)
        resultado = bmesh.ops.subdivide_edges(malla, edges=lazo, cuts=1, use_grid_fill=True)
        for nuevo in resultado["geom_inner"]:
            if isinstance(nuevo, bmesh.types.BMVert):
                nuevo.co = centro + (nuevo.co - centro).normalized() * radio
    despues = sum(len(cara.verts) - 2 for cara in malla.faces)
    malla.to_mesh(objeto.data)
    malla.free()
    objeto.data[MARCA] = True
    return antes, despues


def main() -> None:
    configurar()
    for nombre in OBJETOS:
        objeto = bpy.data.objects[nombre]
        if objeto.data.get(MARCA):
            print(f"{nombre}: ya estaba redondeado")
            continue
        antes, despues = redondear(objeto)
        print(f"{nombre}: {antes} -> {despues} triángulos, en {objeto.data.users} unidades")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
