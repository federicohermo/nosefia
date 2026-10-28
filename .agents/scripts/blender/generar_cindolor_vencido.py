"""Genera sólo la variante: fuente SVG -> textura -> malla con material independiente.

    python .claude/scripts/blender/generar_cindolor_vencido.py

Este paso del pipeline usa Godot para conservar el ArrayMesh ya extraído, sin reexportar
el almacén ni modificar el Cindolor normal. La marca editable vive en source/products-cam.
La importación intermedia permite que el material guarde la ruta de la textura importada.
"""

import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib.consola import configurar
from lib.godot import como_declararlo, resolver
from lib.repo import RAIZ


def main() -> int:
    configurar()
    motor, _ = resolver(dict(os.environ))
    if motor is None:
        print(como_declararlo(dict(os.environ)), file=sys.stderr)
        return 1
    base = [motor, "--headless", "--path", str(RAIZ)]
    script = ["--script", "assets/models/generar_cindolor_vencido.gd", "--"]
    for argumentos in (script + ["--textura"], ["--editor", "--import", "--quit"],
                       script + ["--malla"], script + ["--comprobar"]):
        resultado = subprocess.run(base + argumentos, cwd=RAIZ)
        if resultado.returncode:
            return resultado.returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())
