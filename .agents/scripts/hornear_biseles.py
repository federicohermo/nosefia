"""Hornea la capa de biseles de las etiquetas de producto, desde las mallas del modelo.

    python .claude/scripts/hornear_biseles.py [--solo RUTA_DE_LA_ETIQUETA ...] [--destino CARPETA]

Escribe un PNG por etiqueta en `assets/source/biseles/`, o en `--destino`. Después hay que armar
el atlas de nuevo. El porqué y el formato de la capa están en `lib/biseles.py`.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.blender import como_declararlo, resolver  # noqa: E402
from lib.consola import configurar  # noqa: E402
from lib.repo import RAIZ  # noqa: E402

configurar()

SCRIPT = Path(__file__).resolve().parent / "blender" / "hornear_biseles.py"
MODELO = RAIZ / "assets" / "models" / "SEPT_JUEGOS_PROTOTIPO.blend"


def argumentos(entrada: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--solo", action="append", default=[], metavar="ETIQUETA")
    parser.add_argument("--destino", type=Path)
    return parser.parse_args(entrada)


def main() -> int:
    elegidos = argumentos(sys.argv[1:])
    blender, _ = resolver(dict(os.environ))
    if blender is None:
        print(como_declararlo(dict(os.environ)), file=sys.stderr)
        return 1
    orden = [
        blender, "--factory-startup", "--background", str(MODELO), "--python-exit-code", "1",
        "--python", str(SCRIPT), "--",
    ]
    for etiqueta in elegidos.solo:
        orden += ["--solo", etiqueta]
    if elegidos.destino is not None:
        orden += ["--destino", str(elegidos.destino.resolve())]
    proceso = subprocess.run(
        orden, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    if proceso.returncode != 0:
        print(proceso.stdout + proceso.stderr, file=sys.stderr)
        return proceso.returncode
    for linea in proceso.stdout.splitlines():
        if linea.startswith("bisel:"):
            print(linea)
    return 0


if __name__ == "__main__":
    sys.exit(main())
