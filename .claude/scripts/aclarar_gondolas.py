"""Lleva el cuerpo de las góndolas al tono de la puerta, y guarda el `.blend`.

    python .claude/scripts/aclarar_gondolas.py [--sin-guardar]

Escribe un PNG por textura en `assets/source/textures/gondola/`. Después hay que exportar el
modelo: `exportar_modelo.py`. Qué hace y por qué está en `lib/gondolas.py`.
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

SCRIPT = Path(__file__).resolve().parent / "blender" / "aclarar_gondolas.py"
MODELO = RAIZ / "assets" / "models" / "SEPT_JUEGOS_PROTOTIPO.blend"


def argumentos(entrada: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--sin-guardar", action="store_true")
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
    if elegidos.sin_guardar:
        orden.append("--sin-guardar")
    proceso = subprocess.run(
        orden, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    if proceso.returncode != 0:
        print(proceso.stdout + proceso.stderr, file=sys.stderr)
        return proceso.returncode
    for linea in proceso.stdout.splitlines():
        if linea.startswith(("gondola:", "guardado:")):
            print(linea)
    return 0


if __name__ == "__main__":
    sys.exit(main())
