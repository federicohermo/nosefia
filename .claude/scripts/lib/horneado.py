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
