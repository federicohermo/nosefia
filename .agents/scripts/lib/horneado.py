"""Lo que decide `hornear.py`: cómo se prende el plugin y qué cuenta como horneado.

Acá no hay disco ni procesos: el script trae lo que pasó y esto contesta si alcanzó.
"""

import re
from pathlib import Path

#: El plugin que aprieta el botón. Vive en `addons/hornear/`.
PLUGIN = "res://addons/hornear/plugin.cfg"

#: Lo que el horneado tiene que dejar escrito, relativo a la raíz del repo. El `.lmbake` es la
#: luz por sonda y el índice; el `.exr`, el atlas con la luz de cada malla.
SALIDAS = ("src/escenas/almacen.lmbake", "src/escenas/almacen.exr")

#: El segundo horneado, el de la noche del corte de luz: el mismo local con sólo la luz de
#: emergencia del panel. Se hornea aparte, con `--sin-luz`, y el juego lo cambia por el de arriba
#: al cortarse la luz.
SALIDAS_SIN_LUZ = ("src/escenas/almacen_sin_luz.lmbake", "src/escenas/almacen_sin_luz.exr")

#: El lado, en píxeles, de cada capa del atlas de la noche del corte. El horneador lo deja en el
#: doble, y `hornear.py` lo reduce después de reparar sus líneas. Es una imagen casi negra: con
#: este lado pesa un cuarto, y la luz que le queda a la vista no cambia. Medido el 2026-11-17: 16,8
#: MB contra 4,2 MB, y el export web bajó de 150,8 a 138,8 MiB. El horneado con luz no se reduce.
LADO_DEL_ATLAS_SIN_LUZ = 1024

#: Lo que el editor lee del entorno para saber qué horneado hace. Sin ella, el de siempre.
VARIABLE_DE_LA_VARIANTE = "HORNEAR_VARIANTE"
VARIANTE_SIN_LUZ = "sin_luz"

#: Cuánto pesa en el atlas final el horneado con obstáculos, de 0 a 1. Con 0 el atlas es el
#: horneado de siempre; con 1, el horneado con obstáculos entero. Lo eligió el usuario jugando una
#: build de prueba el 2026-11-16: con 1 el piso le pareció demasiado oscuro.
NIVEL_DE_APOYO = 0.75

#: Cuánto pesa en el atlas final la oclusión de los rincones, de 0 a 1. Con 0 el paso no corre y el
#: atlas queda como lo dejó el horneado. Lo elige el usuario jugando una build de prueba.
NIVEL_DE_OCLUSION = 0.5

#: A cuántos metros de un texel cuenta una malla como tapándolo. Una pared que pasa de este radio
#: no lo oscurece: entre el piso y el techo de un estante bajo hay menos.
RADIO_DE_OCLUSION = 0.8

#: Rayos por texel. Pocos se ven como grano; muchos alargan el paso, que tarda lo mismo que los
#: rayos: ~4 µs cada uno.
RAYOS_DE_OCLUSION = 64

#: El horneado con obstáculos: el mismo local con volúmenes que sólo existen mientras se hornea,
#: para que el piso se oscurezca bajo las góndolas. Su atlas se mezcla con el de siempre y no se
#: commitea: `hornear.py` lo borra al terminar.
VARIANTE_CON_APOYO = "con_apoyo"

#: Lo que deja el horneado con obstáculos, relativo a la raíz. Son archivos de paso: no entran a
#: `reescritos_de_mas` porque no están rastreados, y `hornear.py` los borra siempre.
INTERMEDIOS_DEL_APOYO = (
    "src/escenas/almacen_con_apoyo.lmbake",
    "src/escenas/almacen_con_apoyo.exr",
    "src/escenas/almacen_con_apoyo.exr.import",
)

# El atlas cambia de número de capas al variar la densidad o activar luz direccional.
# Restaurar su .import deja una caché válida acá, pero otra máquina corta mal el EXR.
METADATOS_DEL_ATLAS = tuple(
    ruta + ".import" for ruta in (*SALIDAS, *SALIDAS_SIN_LUZ) if ruta.endswith(".exr")
)


#: Lo que el horneado reescribe, y lo que `hornear.py` devuelve si falla a mitad de camino: las
#: salidas de los dos horneados y el `.import` de cada atlas, que dice en cuántas capas se corta.
SALIDAS_QUE_SE_DEVUELVEN = (
    *SALIDAS,
    SALIDAS[1] + ".import",
    *SALIDAS_SIN_LUZ,
    SALIDAS_SIN_LUZ[1] + ".import",
)


def salidas_de(sin_luz: bool) -> tuple[str, ...]:
    """Lo que deja el horneado pedido."""
    return SALIDAS_SIN_LUZ if sin_luz else SALIDAS


def _nivel_valido(nivel: float, de_que: str) -> float:
    if not 0.0 <= nivel <= 1.0:
        raise ValueError("el nivel %s va de 0 a 1, y llegó %r" % (de_que, nivel))
    return nivel


def con_apoyo(nivel: float) -> bool:
    """Si hace falta el horneado con obstáculos: con nivel 0 el atlas ya es el final."""
    return _nivel_valido(nivel, "del apoyo") > 0.0


def con_oclusion(nivel: float) -> bool:
    """Si corre el paso de la oclusión: con nivel 0 el atlas queda como lo dejó el horneado."""
    return _nivel_valido(nivel, "de la oclusión") > 0.0


def entorno_de(entorno: dict[str, str], variante: str) -> dict[str, str]:
    """El entorno con el que el editor hornea la variante pedida. Sin variante, el de siempre."""
    return {**entorno, VARIABLE_DE_LA_VARIANTE: variante} if variante else dict(entorno)


def comando_de_la_reparacion(blender: str, script: str, atlas: list[str]) -> list[str]:
    """Cómo se lanza Blender para reparar las líneas de media luz de unos atlas, en su lugar."""
    return [
        blender, "--background", "--python-exit-code", "1",
        "--python", script, "--", "--aplicar", *atlas,
    ]  # fmt: skip


def comando_de_la_reduccion(blender: str, script: str, atlas: list[str], lado: int) -> list[str]:
    """Cómo se lanza Blender para llevar cada atlas al lado pedido, en su lugar."""
    return [
        blender, "--background", "--python-exit-code", "1",
        "--python", script, "--", "--aplicar", "--lado", str(lado), *atlas,
    ]  # fmt: skip


def comando_de_la_mezcla(godot: str, raiz: str, nivel: float) -> list[str]:
    """Cómo se lanza Godot para mezclar el atlas del horneado con obstáculos en el de siempre."""
    return [
        godot, "--headless", "--path", raiz,
        "-s", "res://addons/hornear/mezclar_horneados.gd", "--", *argumentos_de_la_mezcla(nivel),
    ]  # fmt: skip


def argumentos_de_la_mezcla(nivel: float) -> list[str]:
    """Los argumentos de `addons/hornear/mezclar_horneados.gd`, que mezcla los dos atlas.

    El atlas de siempre es la base y el resultado: se reescribe en su lugar, con la disposición
    de piezas que ya tiene su `.lmbake`. Del horneado con obstáculos sólo salen las luces.
    """
    return [
        "res://" + SALIDAS[0],
        "res://" + SALIDAS[1],
        "res://" + INTERMEDIOS_DEL_APOYO[0],
        "res://" + INTERMEDIOS_DEL_APOYO[1],
        repr(float(nivel)),
    ]

def ruta_para_godot(ruta: str, raiz: str) -> str:
    """Una ruta como la entiende Godot: `res://` si está en el proyecto, y entera si está afuera."""
    try:
        return "res://" + Path(ruta).relative_to(raiz).as_posix()
    except ValueError:
        return Path(ruta).as_posix()


def argumentos_de_la_oclusion(
    entrada: str, salida: str, radio: float, nivel: float, rayos: int
) -> list[str]:
    """Los argumentos de `addons/hornear/aplicar_oclusion.gd`.

    Las piezas salen del `.lmbake` de la rama. Lee de `entrada` y escribe en `salida`, que pueden
    ser el mismo atlas.
    """
    return [
        "res://" + SALIDAS[0],
        entrada,
        salida,
        repr(float(radio)),
        repr(float(nivel)),
        str(int(rayos)),
    ]


def comando_de_la_oclusion(
    godot: str, raiz: str, entrada: str, salida: str, radio: float, nivel: float, rayos: int
) -> list[str]:
    """Cómo se lanza Godot para aplicar la oclusión de los rincones sobre un atlas."""
    return [
        godot, "--headless", "--path", raiz,
        "-s", "res://addons/hornear/aplicar_oclusion.gd", "--",
        *argumentos_de_la_oclusion(entrada, salida, radio, nivel, rayos),
    ]  # fmt: skip


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
    return sorted(
        ruta
        for ruta in escritos
        if ruta not in (*SALIDAS, *SALIDAS_SIN_LUZ, *METADATOS_DEL_ATLAS)
        and ruta != "project.godot"
    )


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
