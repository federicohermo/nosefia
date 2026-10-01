"""Lo que decide `hornear.py`: cómo se prende el plugin y qué cuenta como horneado.

Acá no hay disco ni procesos: el script trae lo que pasó y esto contesta si alcanzó.
"""

import re

#: El plugin que aprieta el botón. Vive en `addons/hornear/`.
PLUGIN = "res://addons/hornear/plugin.cfg"

#: Lo que el horneado tiene que dejar escrito, relativo a la raíz del repo. El `.lmbake` es la
#: luz por sonda y el índice; el `.exr`, el atlas con la luz de cada malla.
SALIDAS = ("src/escenas/almacen.lmbake", "src/escenas/almacen.exr")

_LISTA = re.compile(r"^enabled=PackedStringArray\(.*\)$", re.MULTILINE)


def project_con_el_plugin(project: str) -> str:
    """El `project.godot` con el plugin como único plugin prendido.

    **El editor no lee la lista de plugins de `override.cfg`** —probado el 2026-09-21: con la
    lista ahí, arrancó con los plugins de `project.godot` y ninguno más—, así que no queda otra
    que tocar el archivo. Reemplaza la lista entera: mientras se hornea no hacen falta los
    otros plugins, y con menos editor corriendo hay menos que pueda interferir con el botón.
    """
    linea = 'enabled=PackedStringArray("%s")' % PLUGIN
    if _LISTA.search(project):
        return _LISTA.sub(linea, project, count=1)
    return project.rstrip("\n") + "\n\n[editor_plugins]\n\n" + linea + "\n"


def veredicto(codigo: int, actualizados: dict[str, bool]) -> tuple[bool, str]:
    """Si el horneado salió, y por qué no.

    El código de salida lo pone el plugin: cero sólo si llegó al final. Pero un editor que se
    cerró bien sin haber escrito nada también devuelve cero, así que además cada salida tiene
    que haber cambiado en el disco durante la corrida.
    """
    if codigo != 0:
        return False, "el editor terminó con código %d" % codigo
    faltan = [ruta for ruta, cambio in actualizados.items() if not cambio]
    if faltan:
        return False, "el editor cerró bien pero no escribió " + ", ".join(faltan)
    return True, "horneado: " + ", ".join(actualizados)


def reescritos_de_mas(escritos: list[str]) -> list[str]:
    """Lo que el editor reescribió durante el horneado sin que el horneado lo pidiera.

    **Para escribir el horneado, el editor guarda la escena, y al guardar re-serializa más de
    lo que cambió.** Medido el 2026-09-29 sobre `staging`: además de las dos salidas dejó
    `almacen.tscn` con 94 overrides de `transform` —los de los volúmenes de la estructura, con
    los mismos valores que ya tenían— y reescritos `tema.tres` y `caja_de_reposicion.tres`. El
    `LightmapGI` no había cambiado. Esos overrides no son inocentes: congelan en la escena de
    arriba la posición de hoy de cada volumen, y el día que la estructura mueva uno, la escena
    lo vuelve a poner donde estaba sin que nada lo diga.

    `project.godot` no va: lo devuelve `hornear.py` byte por byte con lo que tenía antes, que
    puede incluir cambios sin commitear.
    """
    return sorted(ruta for ruta in escritos if ruta not in SALIDAS and ruta != "project.godot")


#: Con GPU, el local se hornea en segundos: si el editor pasa de esto, se quedó esperando algo.
TOPE_CON_GPU = 20 * 60

#: Con el Vulkan por software de Mesa (lavapipe), el mismo horneado tarda minutos. Medido el
#: 2026-09-29: 9 con la máquina libre y 17,7 con otros procesos corriendo. El tope deja el
#: doble del peor, para no confundir una máquina ocupada con un editor colgado.
TOPE_POR_SOFTWARE = 45 * 60


def tope_en_segundos(entorno: dict[str, str]) -> int:
    """Cuánto se espera al editor antes de darlo por colgado.

    Lavapipe se reconoce por el ICD que declara `VK_ICD_FILENAMES`, que es como se lo elige: sin
    declararlo, el cargador de Vulkan prefiere una GPU si la hay.
    """
    if "lvp_icd" in entorno.get("VK_ICD_FILENAMES", ""):
        return TOPE_POR_SOFTWARE
    return TOPE_CON_GPU


def sesion_bloqueada(procesos: str) -> bool:
    """Si la lista de `tasklist` trae la pantalla de bloqueo de Windows.

    Con la sesión bloqueada el editor no dibuja y el plugin nunca aprieta el botón.
    """
    return "logonui.exe" in procesos.lower()
