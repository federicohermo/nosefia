"""El recordatorio: explorar `src/` sin haber consultado `nosefia-index` recibe un aviso.

Corre como hook en dos eventos, y decide qué hacer por el `hook_event_name` del payload:

- **`SessionStart`**: pone en el contexto que el índice existe y cómo se carga.
- **`PreToolUse`**: si la herramienta es del índice, marca la sesión como consultada. Si no, y
  la llamada explora `src/` o `test/` en una sesión sin marca, agrega el recordatorio.

## Por qué existe

El CLAUDE.md pide consultar el índice antes de un `Grep` o un `Read`, y era prosa sin
verificador. El 2026-09-24 una sesión entera exploró `src/dominio/` con `grep` por `Bash`: las
herramientas del índice llegaban diferidas —sólo el nombre, sin la definición—, `Bash` estaba a
mano, y la regla no la recordaba nadie.

## Tres decisiones que no son obvias

1. **Avisa, no bloquea.** Un `Read` después de consultar el índice es lo correcto, y muchas
   veces antes también. Negarlo empujaría a dar la vuelta por otra herramienta, que es
   exactamente el modo de falla que esto cierra.

2. **Nunca contesta `permissionDecision`.** Un `allow` acá saltearía el permiso que el usuario
   configuró para esa herramienta. Lo único que sale es `additionalContext`.

3. **La marca vive en la carpeta temporal, por `session_id`.** Un hook no guarda estado entre
   llamadas, y sin la marca el aviso seguiría en cada búsqueda después de haber consultado el
   índice, que es ruido. Falla abierto como los gates del hook: ante cualquier error propio, no
   dice nada.
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

from lib.recordatorio import AL_ARRANCAR, es_del_indice, explora_el_codigo, recordatorio  # noqa: E402
from lib.repo import RAIZ  # noqa: E402

#: Dónde quedan las marcas de las sesiones que ya consultaron el índice.
DIR_DE_MARCAS = Path(tempfile.gettempdir()) / "nosefia-indice"


def _marca(session_id: str, directorio: Path) -> Path:
    # El id viene del payload: se limpia para que no pueda escribir fuera de la carpeta.
    return directorio / re.sub(r"[^\w-]", "_", session_id or "sin-sesion")


def contexto(payload: dict, directorio: Path = DIR_DE_MARCAS, raiz: Path = RAIZ) -> str | None:
    """El texto a agregar al contexto, o `None`. Marca la sesión si la llamada es del índice."""
    evento = payload.get("hook_event_name")
    if evento == "SessionStart":
        return AL_ARRANCAR
    if evento != "PreToolUse":
        return None
    herramienta = payload.get("tool_name") or ""
    marca = _marca(payload.get("session_id") or "", directorio)
    if es_del_indice(herramienta):
        directorio.mkdir(parents=True, exist_ok=True)
        marca.touch()
        return None
    if marca.exists():
        return None
    if explora_el_codigo(herramienta, payload.get("tool_input") or {}, raiz):
        return recordatorio(herramienta)
    return None


def main() -> None:
    try:
        payload = json.loads(sys.stdin.read())
        texto = contexto(payload)
    except Exception:  # noqa: BLE001 — un aviso que no puede correr no dice nada
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
