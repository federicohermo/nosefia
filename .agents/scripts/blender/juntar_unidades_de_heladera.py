"""Junta las unidades de una heladera que quedaron demasiado separadas a lo largo del estante.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/juntar_unidades_de_heladera.py -- [--aplicar]

Sin `--aplicar` sólo informa. Con `--aplicar` guarda la fuente canónica. Después van
`exportar_modelo.py`, `blender/disponer.py`, `blender/disponer_prueba.py`, `integrar_modelo.py`,
`actualizar_apoyos.py` y `assets/models/extraer_mallas.gd`.

El acomodador reparte lo que sobra de un estante entre todos sus huecos. En una bandeja de heladera
con tres cajas anchas, eso deja 9 cm entre una y otra, y el mapa de prueba, que copia el producto
a otros estantes con un hueco de 5 cm como mucho, lo mostraba de dos maneras en el mismo mueble.
Acá el hueco entre dos unidades de una heladera no pasa de ese tope: lo que sobra va a los dos
costados, con la tanda centrada donde estaba. Sólo corre las unidades a lo largo del estante.
"""

from __future__ import annotations

import sys
from collections import defaultdict
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.gondola import AIRE  # noqa: E402
from lib.reparto import partes  # noqa: E402

#: Los muebles que son heladeras, por su letra en el reparto.
HELADERAS = ("H1", "H2")
#: El hueco más grande entre dos unidades: el mismo tope con que el mapa de prueba copia un molde.
HUECO_MAXIMO = AIRE + 0.03


def _extremos(objeto) -> tuple[float, float]:
    xs = [(objeto.matrix_world @ Vector(esquina)).x for esquina in objeto.bound_box]
    return min(xs), max(xs)


def juntar() -> int:
    tandas = defaultdict(list)
    for objeto in bpy.data.objects:
        tanda = objeto.get("tanda", "")
        if tanda and partes(tanda.split("/")[0])[0] in HELADERAS:
            tandas[tanda].append(objeto)
    corridas = 0
    for clave in sorted(tandas):
        # Las columnas, de izquierda a derecha: las dos filas comparten el centro.
        columnas: list[list] = []
        for objeto in sorted(tandas[clave], key=lambda o: sum(_extremos(o))):
            centro = sum(_extremos(objeto)) / 2
            if columnas and abs(centro - columnas[-1][0]) < 0.01:
                columnas[-1][1].append(objeto)
            else:
                columnas.append([centro, [objeto]])
        if len(columnas) < 2:
            continue
        ancho = max(b - a for a, b in map(_extremos, tandas[clave]))
        paso = (columnas[-1][0] - columnas[0][0]) / (len(columnas) - 1)
        if paso - ancho <= HUECO_MAXIMO + 1e-6:
            continue
        medio = (columnas[0][0] + columnas[-1][0]) / 2
        nuevo_paso = ancho + HUECO_MAXIMO
        for indice, (centro, objetos) in enumerate(columnas):
            destino = medio + (indice - (len(columnas) - 1) / 2) * nuevo_paso
            for objeto in objetos:
                matriz = objeto.matrix_world.copy()
                matriz.translation.x += destino - centro
                escala = objeto.scale.copy()
                objeto.matrix_world = matriz
                objeto.scale = escala
        corridas += 1
        print(
            f"{clave}: {len(columnas)} columnas, el hueco pasa de {(paso - ancho) * 100:.1f} "
            f"a {HUECO_MAXIMO * 100:.1f} cm"
        )
    return corridas


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    print(f"tandas corridas: {juntar()}")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
