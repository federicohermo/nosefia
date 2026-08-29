"""Encontrar el ejecutable de Godot, o decir cómo se declara.

Godot no se instala: se baja un `.exe` y se lo deja en algún lado. O sea que **no hay ninguna
ruta que se pueda dar por cierta**, y cada máquina del equipo lo tiene en otro lugar. La única
fuente confiable es que alguien lo declare una vez, y eso es `GODOT_BIN`.

## Por qué además se lee el registro de Windows

Porque declararla **no alcanza para que el proceso la vea**, y eso costó tres reinicios al
montar este harness.

En Windows, un proceso hereda el bloque de entorno **de su padre**; no lo lee del registro al
arrancar. `SetEnvironmentVariable(..., "User")` escribe en `HKCU\\Environment` y avisa por
broadcast, pero sólo lo recogen los procesos que manejan ese aviso —Explorer, y poco más—.
Una terminal abierta antes del cambio conserva el bloque viejo **y se lo pasa a todo lo que
lance**, para siempre. Medido acá: la variable se declaró a las 21:20, se abrió una terminal
nueva, y el `powershell.exe` que arrancó a las 21:51:57 seguía sin verla — porque su padre era
el mismo host de terminal de antes.

El síntoma es cruel: `[Environment]::GetEnvironmentVariable("GODOT_BIN","User")` contesta la
ruta correcta, así que quien lo revisa concluye que está bien declarada — y el script sigue
diciendo que no la encuentra. Las dos afirmaciones son ciertas a la vez.

Así que se lee el registro **como segunda fuente**, y esto no es adivinar: es leer *la misma
declaración que el usuario ya hizo*, en el lugar donde Windows la guarda. No se busca por el
disco ni se prueban rutas conocidas — eso sí sería adivinar, y está descartado a propósito.

**Y se declara de dónde salió.** Que el entorno esté viejo es información: `verificar.py` la
imprime, así que quien la vea sabe que su terminal quedó atrás — en vez de que la herramienta
lo tape y el mismo desfasaje aparezca en la próxima herramienta que no lo tape.

## Por qué el entorno se inyecta

Igual que en `gh.py` y en `rutas_protegidas.py`: el modo de falla que importa es «esta máquina
no lo tiene declarado», y una máquina que sí lo tiene no puede fabricarlo. El lector del
registro entra por parámetro por lo mismo, y además porque en Linux —donde corre la CI— no hay
registro que leer.
"""

import os
import shutil
from collections.abc import Callable

#: La variable donde vive la ruta. Es la misma que usa el propio runner de gdUnit4
#: (`runtest.cmd` / `runtest.sh`), así que declararla sirve para las dos cosas.
VARIABLE = "GODOT_BIN"

#: De dónde salió la ruta. `verificar.py` lo usa para avisar cuando el entorno está viejo.
ENTORNO = "entorno"
REGISTRO = "registro"
PATH = "PATH"


def leer_del_registro_de_windows() -> str | None:
    """El valor de `GODOT_BIN` en el registro de Windows, o `None`.

    Mira el del usuario y después el del sistema, que es el orden en que Windows los resuelve.
    Fuera de Windows no hay `winreg` y devuelve `None` sin quejarse: en Linux el entorno del
    proceso es la única fuente, y ahí funciona como se espera.
    """
    try:
        import winreg
    except ImportError:
        return None

    claves = (
        (winreg.HKEY_CURRENT_USER, "Environment"),
        (winreg.HKEY_LOCAL_MACHINE, r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment"),
    )
    for raiz, ruta in claves:
        try:
            with winreg.OpenKey(raiz, ruta) as clave:
                valor, _ = winreg.QueryValueEx(clave, VARIABLE)
        except OSError:
            # La clave no existe o la variable no está ahí. No es un error: es que no está
            # declarada por ese lado.
            continue
        if isinstance(valor, str) and valor.strip():
            # `expandvars` porque el registro guarda `REG_EXPAND_SZ` sin expandir: una ruta
            # declarada como `%USERPROFILE%\Godot\…` llega con el `%USERPROFILE%` literal, y sin
            # esto el archivo «no existe» por un motivo que no se ve.
            return os.path.expandvars(valor.strip()).strip('"')
    return None


def resolver(
    entorno: dict[str, str],
    en_el_path: Callable[[str], str | None] = shutil.which,
    existe: Callable[[str], bool] = os.path.isfile,
    del_registro: Callable[[], str | None] = leer_del_registro_de_windows,
) -> tuple[str | None, str | None]:
    """El ejecutable de Godot y de dónde salió: `(ruta, origen)`.

    El orden es entorno → registro → PATH, y cada paso tiene su motivo:

    - **El entorno gana** porque es lo que alguien puso *para esta corrida*: un
      `GODOT_BIN=… python verificar.py` para probar otra versión tiene que ganarle a lo que
      diga el registro.
    - **El registro va segundo** porque es la declaración persistente del usuario. Ver el
      encabezado: que el proceso no la tenga no quiere decir que no exista.
    - **El PATH va último** porque es el único que no fue una decisión sobre este repo: en una
      máquina con varias versiones bajadas, la que quedó primera en el PATH es un accidente.

    Un valor declarado que apunta a un archivo que **no existe** no cae al siguiente: devuelve
    `(None, None)`. Es el caso de una ruta que se movió, y confundirlo con «no está declarado»
    manda a escribir de nuevo lo que ya estaba escrito — el mensaje de `como_declararlo` los
    distingue.
    """
    declarado = entorno.get(VARIABLE, "").strip().strip('"')
    if declarado:
        return (declarado, ENTORNO) if existe(declarado) else (None, None)

    del_reg = del_registro()
    if del_reg:
        return (del_reg, REGISTRO) if existe(del_reg) else (None, None)

    for nombre in ("godot", "godot.exe"):
        encontrado = en_el_path(nombre)
        if encontrado:
            return encontrado, PATH
    return None, None


def como_declararlo(entorno: dict[str, str], del_registro: Callable[[], str | None] = leer_del_registro_de_windows) -> str:
    """El mensaje: qué falta y cómo se arregla, en esta máquina."""
    declarado = entorno.get(VARIABLE, "").strip().strip('"') or del_registro()
    if declarado:
        return (
            f"`{VARIABLE}` está declarada y apunta a un archivo que no existe:\n  {declarado}\n"
            "Se movió el ejecutable, o la ruta quedó vieja. Corregila y volvé a correr."
        )
    return (
        f"No se encontró Godot. Declaralo una vez en `{VARIABLE}`:\n\n"
        '  PowerShell:  [Environment]::SetEnvironmentVariable("GODOT_BIN", '
        '"C:\\ruta\\a\\Godot_v4.4.1-stable_win64_console.exe", "User")\n'
        '  bash:        export GODOT_BIN="/c/ruta/a/Godot_v4.4.1-stable_win64_console.exe"\n\n'
        "En Windows conviene el `_console.exe`: el otro no escribe en la consola, así que la "
        "salida de los tests se pierde entera.\n"
        "Y **no lo dejes adentro de OneDrive**: si el archivo está descargado sólo en la nube, "
        "Windows lo rechaza con «el proveedor de archivos de nube no se está ejecutando» y los "
        "tests no arrancan."
    )


def aviso_de_entorno_viejo(origen: str | None) -> str | None:
    """El aviso de que la terminal quedó atrás, o `None` si no hay nada que avisar.

    Se avisa aunque la corrida haya salido bien: el desfasaje es real y va a morder en la
    próxima herramienta que no tenga este rescate — empezando por el `runtest.cmd` del propio
    gdUnit4, que lee `GODOT_BIN` del entorno y nada más.
    """
    if origen != REGISTRO:
        return None
    return (
        f"aviso: `{VARIABLE}` no está en el entorno de esta terminal; se leyó del registro de\n"
        "       Windows. La terminal es anterior a la variable y le pasa el entorno viejo a todo\n"
        "       lo que lance. Se arregla cerrando el HOST de la terminal —no una pestaña— o\n"
        "       cerrando sesión; hasta entonces, otras herramientas van a seguir sin verla."
    )
