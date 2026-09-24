"""Decidir si una llamada explora el código sin haber pasado por `nosefia-index`. Puro.

Lo usa `recordatorio_del_indice.py`. No es un parser de shell ni de globs: mira las formas en
que un agente busca en `src/` y `test/` —la herramienta `Grep`, `Glob`, `Read`, o un `grep` por
`Bash`—, que son las que el índice contesta en una consulta.
"""

import re
from pathlib import Path, PurePosixPath

#: Las carpetas que el índice cubre. `specs/` queda afuera: un spec se lee entero, y el índice
#: sólo cita sus criterios.
CARPETAS_INDEXADAS = ("src", "test")

#: El prefijo de toda herramienta del índice. Cualquiera cuenta como consultarlo: la regla pide
#: pasar por el índice, y exigir `mapa_del_sistema` puntual volvería ruido un aviso útil.
PREFIJO_DEL_INDICE = "mcp__nosefia-index__"

#: Los comandos de shell que buscan o leen. Un `git` o un `python` que nombra `src/` no explora.
_EXPLORA_POR_SHELL = re.compile(r"(?<![\w-])(grep|rg|find|cat|head|tail|sed|awk|ls|less)(?![\w-])")

#: Una carpeta indexada como componente de una ruta, relativa o absoluta.
_RUTA_INDEXADA = re.compile(r"(?:^|[\s\"'=/])(?:" + "|".join(CARPETAS_INDEXADAS) + r")(?:/|[\s\"']|$)")

AL_ARRANCAR = (
    "Este repo tiene un índice del código: `nosefia-index`. La primera consulta de cualquier "
    "tarea es `mapa_del_sistema`, antes de un `Grep`, un `Read` o un `grep` por `Bash` sobre "
    "`src/`. Si sus herramientas aparecen sólo por nombre, se cargan con `ToolSearch` y "
    "`select:mcp__nosefia-index__mapa_del_sistema`."
)


def es_del_indice(herramienta: str) -> bool:
    return herramienta.startswith(PREFIJO_DEL_INDICE)


def _ruta_indexada(ruta: str, raiz: Path) -> bool:
    """Si `ruta` cae en una carpeta indexada. Vacía o `.` es la raíz, que las contiene."""
    if ruta in ("", "."):
        return True
    candidata = Path(ruta)
    if candidata.is_absolute():
        try:
            candidata = candidata.resolve().relative_to(raiz.resolve())
        except ValueError:
            return False
    partes = PurePosixPath(candidata.as_posix()).parts
    return bool(partes) and partes[0] in CARPETAS_INDEXADAS


def explora_el_codigo(herramienta: str, entrada: dict, raiz: Path) -> bool:
    """Si la llamada busca o lee en `src/` o `test/` lo que el índice contesta."""
    if herramienta == "Grep":
        return _ruta_indexada(entrada.get("path") or "", raiz)
    if herramienta == "Glob":
        # El patrón puede traer la carpeta adentro: `src/**/*.gd` sobre la raíz.
        ruta = entrada.get("path") or ""
        patron = entrada.get("pattern") or ""
        if ruta in ("", "."):
            return _ruta_indexada(patron, raiz) or patron.startswith("**")
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
        f"Todavía no se consultó `nosefia-index` en esta sesión, y este `{herramienta}` explora "
        "`src/` o `test/`. La primera consulta es `mapa_del_sistema`; `buscar_simbolo`, "
        "`quien_usa` y `contexto_de_archivo` contestan lo que suele buscarse con un grep. Si sus "
        "herramientas aparecen sólo por nombre, se cargan con `ToolSearch` y "
        "`select:mcp__nosefia-index__mapa_del_sistema`. El aviso se apaga con la primera consulta "
        "al índice."
    )
