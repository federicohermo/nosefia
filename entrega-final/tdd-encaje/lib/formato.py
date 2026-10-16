"""Qué `.gd` formatea el hook de `PostToolUse`, y qué dice cuando `gdformat` no puede.

El nodo `formato` de `verificar.py` avisa recién al final, y un agente se entera ahí de un
formato que `gdformat` arreglaba solo al escribir.
"""

import ntpath
import os
import subprocess
from collections.abc import Callable
from pathlib import PureWindowsPath

HERRAMIENTAS_QUE_ESCRIBEN = ("Edit", "Write", "MultiEdit")


def ruta_a_formatear(payload: dict) -> str | None:
    """La ruta del `.gd` que acaba de escribirse, o `None` si el hook no tiene que tocar nada."""
    if payload.get("tool_name") not in HERRAMIENTAS_QUE_ESCRIBEN:
        return None
    ruta = (payload.get("tool_input") or {}).get("file_path")
    if not isinstance(ruta, str) or not ruta:
        return None
    # `PureWindowsPath` parte por las dos barras: el payload de Windows trae `\`, y la CI corre
    # en Linux con `/`.
    partes = PureWindowsPath(ruta)
    # `addons/` es código de terceros vendorizado: formatearlo ensucia el diff de una
    # actualización del addon con cambios que no son suyos.
    if partes.suffix != ".gd" or "addons" in partes.parts:
        return None
    cwd = payload.get("cwd")
    if not (os.path.isabs(ruta) or ntpath.isabs(ruta)) and isinstance(cwd, str) and cwd:
        return os.path.join(cwd, ruta)
    return ruta


def formatear(ruta: str, correr: Callable[..., subprocess.CompletedProcess]) -> str | None:
    """Corre `gdformat` sobre `ruta`. Devuelve el motivo si no pudo, o `None` si formateó.

    `correr` es `subprocess.run`, inyectado para poder fabricar el `gdformat` que falta.
    """
    try:
        proceso = correr(
            ["gdformat", ruta],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=20,
        )
    except FileNotFoundError:
        return (
            "gdformat no está instalado: el `.gd` quedó sin formatear. "
            "Se instala con `pip install gdtoolkit`."
        )
    except (OSError, subprocess.SubprocessError) as error:
        return f"gdformat no pudo correr sobre `{ruta}`: {error}"
    if proceso.returncode != 0:
        salida = (proceso.stderr or proceso.stdout).strip()
        return f"gdformat no pudo formatear `{ruta}`, que quedó como estaba:\n{salida}"
    return None
