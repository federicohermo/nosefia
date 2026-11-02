"""Le devuelve a una caja regenerada el color de su original, sin perder el desgaste nuevo.

    python .claude/scripts/igualar_color_de_caja.py NUEVA ORIGINAL SALIDA

El método y por qué es así están en `lib/color_de_caja.py`.

## Por qué la salida es otro archivo

**La caja nueva tiene que quedar recuperable.** Igual que `aplicar_desgaste.py`, el script se
niega a escribir sobre la caja que lee, y sobre el original: el resultado va a otra ruta, y quien
lo quiere en el lugar de la fuente lo mueve a mano.

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

configurar()

SCRIPT = Path(__file__).resolve().parent / "blender" / "igualar_color_de_caja.py"


def argumentos(entrada: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("nueva", type=Path)
    parser.add_argument("original", type=Path)
    parser.add_argument("salida", type=Path)
    return parser.parse_args(entrada)


def main() -> int:
    elegidos = argumentos(sys.argv[1:])
    for archivo in (elegidos.nueva, elegidos.original):
        if not archivo.is_file():
            print(f"no existe: {archivo}", file=sys.stderr)
            return 1
    for protegido in (elegidos.nueva, elegidos.original):
        if elegidos.salida.resolve() == protegido.resolve():
            print(f"la salida no puede ser {protegido.name}: tiene que quedar", file=sys.stderr)
            return 1
    blender, _ = resolver(dict(os.environ))
    if blender is None:
        print(como_declararlo(dict(os.environ)), file=sys.stderr)
        return 1
    elegidos.salida.parent.mkdir(parents=True, exist_ok=True)
    orden = [
        blender, "--factory-startup", "--background", "--python-exit-code", "1",
        "--python", str(SCRIPT), "--",
        str(elegidos.nueva.resolve()), str(elegidos.original.resolve()),
        str(elegidos.salida.resolve()),
    ]
    proceso = subprocess.run(
        orden, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    if proceso.returncode != 0:
        print(proceso.stdout + proceso.stderr, file=sys.stderr)
        return proceso.returncode
    for linea in proceso.stdout.splitlines():
        if linea.startswith("color:"):
            print(linea)
    return 0


if __name__ == "__main__":
    sys.exit(main())
