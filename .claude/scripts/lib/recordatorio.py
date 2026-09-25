"""Decide si una llamada explora `src/` o `test/`. Puro."""

import re
from pathlib import Path

CARPETAS_INDEXADAS = ("src", "test")

PREFIJO_DEL_INDICE = "mcp__nosefia-index__"

# Un `git add src/` no explora.
_EXPLORA_POR_SHELL = re.compile(r"(?<![\w-])(grep|rg|find|cat|head|tail|sed|awk|ls|less)(?![\w-])")

_RUTA_INDEXADA = re.compile(
    r"(?:^|[\s\"'=/])(?:" + "|".join(CARPETAS_INDEXADAS) + r")(?:/|[\s\"']|$)"
)

_COMO_CARGARLO = (
    "Si sus herramientas aparecen sólo por nombre, cargalas con `ToolSearch` y "
    f"`select:{PREFIJO_DEL_INDICE}mapa_del_sistema`."
)

AL_ARRANCAR = (
    "Este repo tiene un índice del código: `nosefia-index`. Consultá `mapa_del_sistema` antes "
    f"de buscar en `src/`. {_COMO_CARGARLO}"
)


def es_del_indice(herramienta: str) -> bool:
    return herramienta.startswith(PREFIJO_DEL_INDICE)


def _ruta_indexada(ruta: str, raiz: Path) -> bool:
    # Vacía o `.` es la raíz, que contiene las carpetas indexadas.
    if ruta in ("", "."):
        return True
    candidata = Path(ruta)
    if candidata.is_absolute():
        try:
            candidata = candidata.resolve().relative_to(raiz.resolve())
        except ValueError:
            return False
    return bool(candidata.parts) and candidata.parts[0] in CARPETAS_INDEXADAS


def explora_el_codigo(herramienta: str, entrada: dict, raiz: Path) -> bool:
    if herramienta == "Grep":
        return _ruta_indexada(entrada.get("path") or "", raiz)
    if herramienta == "Glob":
        ruta = entrada.get("path") or ""
        patron = entrada.get("pattern") or ""
        if ruta in ("", "."):
            return patron.startswith("**") or _ruta_indexada(patron, raiz)
        return _ruta_indexada(ruta, raiz)
    if herramienta == "Read":
        ruta = entrada.get("file_path") or ""
        return bool(ruta) and _ruta_indexada(ruta, raiz)
    if herramienta in ("Bash", "PowerShell"):
        comando = entrada.get("command") or ""
        return bool(_EXPLORA_POR_SHELL.search(comando) and _RUTA_INDEXADA.search(comando))
    return False


def recordatorio(herramienta: str) -> str:
    return (
        f"Este `{herramienta}` explora `src/` o `test/`, y la sesión no consultó "
        f"`nosefia-index`. Consultá `mapa_del_sistema` primero. {_COMO_CARGARLO}"
    )
