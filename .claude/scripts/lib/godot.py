"""Encontrar el ejecutable de Godot, o decir cómo se declara.

Godot no se instala: se baja un `.exe` y se lo deja en algún lado. O sea que **no hay ninguna
ruta que se pueda dar por cierta**, y cada máquina del equipo lo tiene en otro lugar. La
única fuente confiable es que alguien lo declare una vez, y eso es `GODOT_BIN`.

Igual que en `gh.py` y en `rutas_protegidas.py`, el entorno se inyecta: el modo de falla que
importa es «esta máquina no lo tiene declarado», y una máquina que sí lo tiene no puede
fabricarlo.
"""

import os
import shutil
from collections.abc import Callable

#: La variable donde vive la ruta. Es la misma que usa el propio runner de gdUnit4
#: (`runtest.cmd` / `runtest.sh`), así que declararla sirve para las dos cosas.
VARIABLE = "GODOT_BIN"


def resolver(
    entorno: dict[str, str],
    en_el_path: Callable[[str], str | None] = shutil.which,
    existe: Callable[[str], bool] = os.path.isfile,
) -> str | None:
    """El ejecutable de Godot, o `None`.

    `GODOT_BIN` gana sobre el PATH: en una máquina con varias versiones bajadas, la que vale
    es la que el repo declara y no la que quedó primera en el PATH. Un `GODOT_BIN` que apunta
    a un archivo que no existe cuenta como no declarado, y quien lo dice es el mensaje: es el
    caso de una ruta que se movió, y confundirlo con «no está declarado» manda a escribir de
    nuevo lo que ya estaba escrito.
    """
    declarado = entorno.get(VARIABLE, "").strip('"')
    if declarado and existe(declarado):
        return declarado
    if declarado:
        return None
    for nombre in ("godot", "godot.exe", "Godot_v4.4.1-stable_win64.exe"):
        encontrado = en_el_path(nombre)
        if encontrado:
            return encontrado
    return None


def como_declararlo(entorno: dict[str, str]) -> str:
    """El mensaje: qué falta y cómo se arregla, en esta máquina."""
    declarado = entorno.get(VARIABLE, "")
    if declarado:
        return (
            f"`{VARIABLE}` está declarada y apunta a un archivo que no existe:\n  {declarado}\n"
            "Se movió el ejecutable, o la ruta quedó vieja. Corregila y volvé a correr."
        )
    return (
        f"No se encontró Godot. Declaralo una vez en `{VARIABLE}`:\n\n"
        '  PowerShell:  [Environment]::SetEnvironmentVariable("GODOT_BIN", '
        '"C:\\ruta\\a\\Godot_v4.4.1-stable_win64.exe", "User")\n'
        '  bash:        export GODOT_BIN="/c/ruta/a/Godot_v4.4.1-stable_win64.exe"\n\n'
        "En Windows conviene el `_console.exe`: el otro no escribe en la consola, así que la "
        "salida de los tests se pierde entera.\n"
        "Y **no lo dejes adentro de OneDrive**: si el archivo está descargado sólo en la nube, "
        "Windows lo rechaza con «el proveedor de archivos de nube no se está ejecutando» y los "
        "tests no arrancan."
    )
