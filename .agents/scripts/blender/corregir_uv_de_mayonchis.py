"""Mete hacia adentro las UV de las tres caras lisas de Mayonchis, lejos de las líneas divisorias.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/corregir_uv_de_mayonchis.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.

## Por qué

Tres caras del paquete muestran un color liso: la tapa, el fondo y un costado. Con el arte nuevo
de la etiqueta, las líneas divisorias de los paneles quedaron a entre 4 y 9 píxeles del borde de
esas caras, y se veían como una franja oscura. El arte viejo era liso hasta el borde.

## Qué cambia

Sólo la UV principal de esas tres caras, que se achica hacia su centro. El margen sale de medir la
textura nueva: la zona lisa de cada cara deja entre 0 y 9 píxeles de 1561 en horizontal y entre 0
y 5 de 1007 en vertical. Se usan 12 y 8, con holgura. UV2 y la geometría no se tocan.

Corre sobre los doce objetos `mayonchis-col*`, que tienen la misma disposición. Es idempotente: una
cara que ya está achicada se deja como está.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

PREFIJO = "mayonchis-col"
DIMENSIONES = (8, 6)

#: La textura nueva de Mayonchis, en píxeles.
ANCHO, ALTO = 1561, 1007
MARGEN_U = 12 / ANCHO
MARGEN_V = 8 / ALTO

#: Las caras lisas, por índice de polígono, con su rectángulo original en UV: (u0, u1, v0, v1).
CARAS_LISAS = {
    2: (0.1447, 0.2828, 0.1685, 0.8312),
    4: (0.1482, 0.2748, 0.8399, 0.9950),
    5: (0.1520, 0.2829, 0.1523, 0.8718),
}
TOLERANCIA = 0.0006


def _rectangulo(capa, cara) -> tuple[float, float, float, float]:
    us = [capa[i].uv.x for i in cara.loop_indices]
    vs = [capa[i].uv.y for i in cara.loop_indices]
    return min(us), max(us), min(vs), max(vs)


def _cerca(a, b) -> bool:
    return all(abs(x - y) <= TOLERANCIA for x, y in zip(a, b))


def _achicar(valor: float, minimo: float, maximo: float, margen: float) -> float:
    fraccion = (valor - minimo) / (maximo - minimo)
    return (minimo + margen) + fraccion * (maximo - minimo - 2 * margen)


def corregir() -> tuple[int, int]:
    movidas = ya_estaban = 0
    vistas = set()
    for objeto in bpy.data.objects:
        if objeto.type != "MESH" or not objeto.name.startswith(PREFIJO):
            continue
        malla = objeto.data
        if malla.name in vistas:
            continue
        vistas.add(malla.name)
        if (len(malla.vertices), len(malla.polygons)) != DIMENSIONES:
            raise ValueError(f"Cambió la geometría de {objeto.name}; revisar sus UV antes de aplicar")
        capa = malla.uv_layers[0].data
        for indice, (u0, u1, v0, v1) in CARAS_LISAS.items():
            cara = malla.polygons[indice]
            actual = _rectangulo(capa, cara)
            achicado = (u0 + MARGEN_U, u1 - MARGEN_U, v0 + MARGEN_V, v1 - MARGEN_V)
            if _cerca(actual, achicado):
                ya_estaban += 1
                continue
            if not _cerca(actual, (u0, u1, v0, v1)):
                raise ValueError(f"{objeto.name}, cara {indice}: sus UV no son las esperadas: {actual}")
            for lazo in cara.loop_indices:
                capa[lazo].uv.x = _achicar(capa[lazo].uv.x, u0, u1, MARGEN_U)
                capa[lazo].uv.y = _achicar(capa[lazo].uv.y, v0, v1, MARGEN_V)
            movidas += 1
    if not vistas:
        raise ValueError(f"no hay ningún objeto «{PREFIJO}*» en la fuente")
    return movidas, ya_estaban


def main() -> None:
    configurar()
    movidas, ya_estaban = corregir()
    print(f"caras corregidas: {movidas}, ya estaban: {ya_estaban}")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
