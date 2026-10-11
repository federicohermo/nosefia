"""Hook `PostToolUse`: deja cada `.gd` editado como lo deja `gdformat`.

«`gdformat` decide el formato» era prosa, y el nodo `formato` lo cobraba recién al final.

Nunca frena la edición: el archivo ya está escrito. Si `gdformat` falta o falla, lo dice por
`additionalContext` y sale con 0. Un aviso que muere callado vuelve a ser prosa.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.formato import formatear, ruta_a_formatear  # noqa: E402


def _avisar(texto: str) -> None:
    salida = {"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": texto}}
    print(json.dumps(salida, ensure_ascii=False))


def main() -> None:
    try:
        ruta = ruta_a_formatear(json.loads(sys.stdin.read()))
        motivo = formatear(ruta, subprocess.run) if ruta else None
        if ruta and motivo is None:
            # En Windows, `gdformat` reescribe con CRLF. El repo es `eol=lf`: el archivo tiene
            # que quedar como lo deja un checkout, no como lo deja la plataforma.
            archivo = Path(ruta)
            crudo = archivo.read_bytes()
            if b"\r\n" in crudo:
                archivo.write_bytes(crudo.replace(b"\r\n", b"\n"))
    except Exception as error:  # noqa: BLE001 — falla abierto, y lo dice
        motivo = f"formatear_al_editar no pudo correr: {error}"
    if motivo:
        _avisar(motivo)
    sys.exit(0)


if __name__ == "__main__":
    main()
