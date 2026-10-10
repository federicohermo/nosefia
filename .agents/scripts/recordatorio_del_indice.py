"""Hook: recuerda consultar `nosefia-index` antes de explorar `src/`.

La regla del CLAUDE.md era prosa. Una sesión exploró `src/` con `grep` porque las herramientas
del índice llegaban diferidas.

Avisa y no bloquea. Nunca contesta `permissionDecision`: un `allow` saltearía el permiso del
usuario. Si falla, deja pasar y escribe el error en stderr: un aviso que muere callado vuelve a
ser prosa.
"""

import json
import os
import re
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.recordatorio import (  # noqa: E402
    AL_ARRANCAR,
    es_del_indice,
    explora_el_codigo,
    recordatorio,
)
from lib.repo import RAIZ  # noqa: E402

# Un hook no guarda estado entre llamadas.
DIR_DE_MARCAS = Path(tempfile.gettempdir()) / "nosefia-indice"


def contexto(payload: dict, directorio: Path = DIR_DE_MARCAS, raiz: Path = RAIZ) -> str | None:
    evento = payload.get("hook_event_name")
    if evento == "SessionStart":
        return AL_ARRANCAR
    if evento != "PreToolUse":
        return None
    herramienta = payload.get("tool_name") or ""
    marca = directorio / re.sub(r"[^\w-]", "_", payload.get("session_id") or "sin-sesion")
    if es_del_indice(herramienta):
        directorio.mkdir(parents=True, exist_ok=True)
        marca.touch()
        return None
    if not marca.exists() and explora_el_codigo(herramienta, payload.get("tool_input") or {}, raiz):
        return recordatorio(herramienta)
    return None


def main() -> None:
    try:
        payload = json.loads(sys.stdin.read())
        texto = contexto(payload)
    except Exception as error:  # noqa: BLE001 — falla abierto, y lo dice
        print(f"recordatorio_del_indice no pudo correr: {error}", file=sys.stderr)
        sys.exit(0)
    if texto:
        salida = {
            "hookSpecificOutput": {
                "hookEventName": payload["hook_event_name"],
                "additionalContext": texto,
            }
        }
        print(json.dumps(salida, ensure_ascii=False))
    sys.exit(0)


if __name__ == "__main__":
    main()
