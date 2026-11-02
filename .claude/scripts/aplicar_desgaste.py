"""Aplica una capa de desgaste sobre una etiqueta y escribe el resultado en otro archivo.

    python .claude/scripts/aplicar_desgaste.py ETIQUETA CAPA SALIDA \
        [--fuerza 1.0] [--giro 0|90|180|270] [--espejo] [--dx 0.0] [--dy 0.0]

La fórmula y por qué es así están en `lib/desgaste.py`. Las capas viven en
`assets/source/desgaste/`.

## Por qué la salida es otro archivo

**El arte original tiene que quedar recuperable.** El script se niega a escribir sobre la
etiqueta que lee: el resultado va a otra ruta, y quien lo quiere en el lugar de la fuente lo
mueve a mano, sabiendo que la original queda en git.

## Una capa, varios productos

`--giro`, `--espejo`, `--dx` y `--dy` cambian cómo cae la capa. Dos productos vecinos no pueden
mostrar la misma marca: cada uno lleva una combinación distinta.

Necesita Blender, que es quien lee y escribe los PNG: este harness no tiene dependencias.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.blender import como_declararlo, resolver  # noqa: E402
from lib.consola import configurar  # noqa: E402
from lib.desgaste import GIROS  # noqa: E402

configurar()

SCRIPT = Path(__file__).resolve().parent / "blender" / "aplicar_desgaste.py"


def argumentos(entrada: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("etiqueta", type=Path)
    parser.add_argument("capa", type=Path)
    parser.add_argument("salida", type=Path)
    parser.add_argument("--fuerza", type=float, default=1.0)
    parser.add_argument("--giro", type=int, choices=GIROS, default=0)
    parser.add_argument("--espejo", action="store_true")
    parser.add_argument("--dx", type=float, default=0.0)
    parser.add_argument("--dy", type=float, default=0.0)
    return parser.parse_args(entrada)


def main() -> int:
    elegidos = argumentos(sys.argv[1:])
    for archivo in (elegidos.etiqueta, elegidos.capa):
        if not archivo.is_file():
            print(f"no existe: {archivo}", file=sys.stderr)
            return 1
    if elegidos.salida.resolve() == elegidos.etiqueta.resolve():
        print("la salida no puede ser la etiqueta: la original tiene que quedar", file=sys.stderr)
        return 1
    blender, origen = resolver(dict(os.environ))
    if blender is None:
        print(como_declararlo(dict(os.environ)), file=sys.stderr)
        return 1
    elegidos.salida.parent.mkdir(parents=True, exist_ok=True)
    orden = [
        blender, "--factory-startup", "--background", "--python-exit-code", "1",
        "--python", str(SCRIPT), "--",
        str(elegidos.etiqueta.resolve()), str(elegidos.capa.resolve()),
        str(elegidos.salida.resolve()), str(elegidos.fuerza), str(elegidos.giro),
        "1" if elegidos.espejo else "0", str(elegidos.dx), str(elegidos.dy),
    ]
    proceso = subprocess.run(
        orden, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    if proceso.returncode != 0:
        print(proceso.stdout + proceso.stderr, file=sys.stderr)
        return proceso.returncode
    for linea in proceso.stdout.splitlines():
        if linea.startswith("desgaste:"):
            print(linea)
    return 0


if __name__ == "__main__":
    sys.exit(main())
