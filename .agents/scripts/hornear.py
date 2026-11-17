"""Hornear la luz del local: apretar «Bake Lightmaps» sin abrir el editor a mano.

    python .claude/scripts/hornear.py             # el local con todas sus luces
    python .claude/scripts/hornear.py --sin-luz   # el mismo local en la noche del corte de luz

## Por qué existe

Godot no expone el horneado a ningún script: es un botón del editor, y sin editor no hay
horneador. Este script abre el editor con el plugin `addons/hornear` prendido; el plugin aprieta
el botón, guarda y cierra; acá se lee el veredicto. Se corre cada vez que cambia el modelo o una
luz, y lo que deja —el `.lmbake`, el `.exr` y su `.import`, al lado de `almacen.tscn`— se
commitea.

## La sombra de apoyo

El horneado con luz hornea dos veces. El primero es el local de siempre, y de ahí salen el
`.lmbake` y las sondas. El segundo suma, sólo mientras se hornea, unos volúmenes bajo los
estantes de las góndolas (`addons/hornear/apoyo.gd`), y de ahí sale sólo el atlas: el piso se
oscurece al pie del mueble. `addons/hornear/mezclar_horneados.gd` mezcla los dos atlas con el
nivel `NIVEL_DE_APOYO` y deja el resultado en `almacen.exr`. El segundo horneado no se commitea:
el script lo borra, también si falla. Si algo falla a mitad de camino, `almacen.lmbake` y
`almacen.exr` quedan como estaban y el script sale con código 1.

Cada atlas se repara con Blender antes de mezclarlos
(`blender/reparar_lineas_del_mapa_de_luz.py`), y el resultado se repara otra vez. Hace falta
`BLENDER_BIN`, la misma que usan los otros scripts. Con el nivel en 0 no hay segundo horneado.

## El horneado sin luz

`--sin-luz` hornea el mismo local con todas sus luces apagadas salvo la de emergencia del panel,
y deja `almacen_sin_luz.lmbake` y `almacen_sin_luz.exr`. Los apaga en la copia del editor y no
guarda la escena: `almacen.tscn` queda como estaba. El juego cambia los datos del `LightmapGI`
por éstos al cortarse la luz de la séptima noche. Qué se apaga lo dice `corte_de_luz.gd`, y es lo
mismo que el juego apaga al cortar.

## Cómo se prende el plugin

Escribiendo `project.godot` con el plugin como único prendido, y devolviéndolo byte por byte al
terminar, pase lo que pase. No hay otra: el editor no lee la lista de plugins de `override.cfg`.
Dejar el plugin en `project.godot` haría que cada apertura del editor horneara y cerrara.

## Lo que el editor ensucia al guardar, se devuelve

El plugin guarda la escena para escribir el horneado, y el editor re-serializa de paso lo que
no le pidieron: `almacen.tscn` con overrides de los volúmenes de la estructura, y recursos que
cargó. Al terminar, todo archivo rastreado que se escribió durante la corrida vuelve a lo que
tenía antes, salvo las salidas y el `.import` del atlas. El detalle y la medición, en
`lib/horneado.reescritos_de_mas()`.

## Qué hace falta

- `GODOT_BIN`, la misma que usa `verificar.py`. Con `--sin-luz` no hace falta Blender.
- **El editor del repo cerrado.** Dos editores sobre el mismo proyecto se pisan la caché.
- Una sesión con pantalla: el editor abre una ventana. El horneado no anda headless.
- Una GPU con Vulkan: el editor de horneado usa Mobile para evitar la textura nula del
  horneador OpenGL. El juego conserva el renderer definido en `project.godot`.

En Linux sin pantalla ni GPU alcanza con Xvfb y el Vulkan por software de Mesa (lavapipe).
Medido el 2026-09-29: nueve minutos para el local entero, y 17,7 con otros procesos corriendo.
Con lavapipe declarado, el tope de espera se estira: ver `lib/horneado.tope_en_segundos()`.

    VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a \\
        -s "-screen 0 1600x900x24" python .claude/scripts/hornear.py
"""

import os
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib import blender as lib_blender  # noqa: E402
from lib.godot import como_declararlo, resolver  # noqa: E402
from lib.horneado import (  # noqa: E402
    INTERMEDIOS_DEL_APOYO,
    NIVEL_DE_APOYO,
    SALIDAS,
    SALIDAS_QUE_SE_DEVUELVEN,
    SALIDAS_SIN_LUZ,
    VARIANTE_CON_APOYO,
    VARIANTE_SIN_LUZ,
    comando_de_la_mezcla,
    comando_de_la_reparacion,
    con_apoyo,
    entorno_de,
    project_con_el_plugin,
    reescritos_de_mas,
    sesion_bloqueada,
    tope_en_segundos,
    veredicto,
)
from lib.repo import RAIZ  # noqa: E402

PROJECT = Path(RAIZ) / "project.godot"
REPARADOR = Path(RAIZ) / ".claude/scripts/blender/reparar_lineas_del_mapa_de_luz.py"


class Fallo(Exception):
    """Un paso del horneado no salió: el motivo es el mensaje."""


def _git(raiz: Path, *argumentos: str) -> str:
    return subprocess.run(
        ["git", "-C", str(raiz), *argumentos],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=True,
    ).stdout


def _rutas(raiz: Path, *argumentos: str) -> list[str]:
    """Las rutas que lista git, con `-z`.

    Sin él, una ruta con acento sale entre comillas y con escapes octales, no existe en el disco
    y se saltea sin decirlo. Las texturas del modelo tienen rutas así: `textura portón.png`.
    """
    return [r for r in _git(raiz, *argumentos, "-z").split("\0") if r]


def sucios(raiz: Path) -> dict[str, bytes]:
    """Lo rastreado que ya tenía cambios antes de hornear, con su contenido de ese momento."""
    rutas = _rutas(raiz, "diff", "--name-only", "HEAD")
    return {r: (raiz / r).read_bytes() for r in rutas if (raiz / r).is_file()}


def devolver_lo_reescrito(raiz: Path, desde: float, previos: dict[str, bytes]) -> list[str]:
    """Devuelve a su contenido de antes lo que el editor re-serializó sin que se lo pidieran.

    Lo que ya tenía cambios vuelve a esos cambios; lo que estaba limpio vuelve a lo de git.
    """
    escritos = [
        r
        for r in _rutas(raiz, "ls-files")
        if (raiz / r).is_file() and (raiz / r).stat().st_mtime >= desde
    ]
    devueltos = reescritos_de_mas(escritos)
    for ruta in devueltos:
        if ruta in previos:
            (raiz / ruta).write_bytes(previos[ruta])
        else:
            _git(raiz, "checkout", "--", ruta)
        print(f"devuelto (el editor lo re-serializó al guardar): {ruta}")
    return devueltos


def guardar_salidas(raiz: Path, rutas: tuple[str, ...]) -> dict[str, bytes | None]:
    """Lo que hay en cada ruta antes de hornear, o `None` si no existía."""
    return {r: (raiz / r).read_bytes() if (raiz / r).is_file() else None for r in rutas}


def devolver_salidas(raiz: Path, respaldo: dict[str, bytes | None]) -> None:
    """Deja cada ruta como estaba antes de hornear."""
    for ruta, contenido in respaldo.items():
        if contenido is None:
            (raiz / ruta).unlink(missing_ok=True)
        else:
            (raiz / ruta).write_bytes(contenido)


def borrar_intermedios(raiz: Path) -> None:
    """Los archivos de paso del horneado con obstáculos no se quedan en `src/`."""
    for ruta in INTERMEDIOS_DEL_APOYO:
        (raiz / ruta).unlink(missing_ok=True)


def _escribi(raiz: Path, rutas: tuple[str, ...], desde: float) -> dict[str, bool]:
    return {r: (raiz / r).exists() and (raiz / r).stat().st_mtime >= desde for r in rutas}


def sesion_del_editor(godot: str, variante: str, salidas: tuple[str, ...]) -> None:
    """Abre el editor con el plugin, que hornea la variante pedida y cierra.

    El `project.godot` vuelve a lo que tenía pase lo que pase. Falla si el editor no cerró bien o
    no escribió cada salida.
    """
    tope = tope_en_segundos(dict(os.environ))
    desde = time.time()
    original = PROJECT.read_bytes()
    PROJECT.write_text(project_con_el_plugin(original.decode("utf-8")), encoding="utf-8")
    try:
        # `-l en` porque el plugin busca el botón por su texto, y ese texto es el inglés.
        corrida = subprocess.run(
            [
                godot, "--editor", "--path", RAIZ, "-l", "en",
                "--rendering-method", "mobile", "--rendering-driver", "vulkan",
            ],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=tope,
            env=entorno_de(dict(os.environ), variante),
        )
    except subprocess.TimeoutExpired:
        raise Fallo(f"el editor no cerró en {tope // 60} minutos") from None
    finally:
        PROJECT.write_bytes(original)

    for linea in (corrida.stdout + corrida.stderr).splitlines():
        if "[hornear]" in linea:
            print(linea.strip())
    ok, motivo = veredicto(corrida.returncode, _escribi(Path(RAIZ), salidas, desde))
    print(motivo)
    if not ok:
        raise Fallo(motivo)


def reparar_lineas(blender: str, atlas: list[str]) -> None:
    """Repara las rayas de un texel de cada atlas, en su lugar. Ver el reparador."""
    corrida = subprocess.run(
        comando_de_la_reparacion(blender, str(REPARADOR), [str(Path(RAIZ) / a) for a in atlas]),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    print(corrida.stdout.strip())
    if corrida.returncode != 0:
        raise Fallo("no pude reparar las líneas de " + ", ".join(atlas) + "\n" + corrida.stderr)


def mezclar_atlas(godot: str, nivel: float) -> None:
    """Mezcla el atlas del horneado con obstáculos en el de siempre, que es el resultado."""
    corrida = subprocess.run(
        comando_de_la_mezcla(godot, RAIZ, nivel),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    for linea in (corrida.stdout + corrida.stderr).splitlines():
        if "[mezclar]" in linea:
            print(linea.strip())
    if corrida.returncode != 0:
        raise Fallo("la mezcla de los atlas salió con código %d" % corrida.returncode)


def hornear_con_luz(godot: str, blender: str) -> None:
    """El horneado que el juego carga: el local con luz y, encima, la sombra de apoyo.

    Hornea el local de siempre, y la mezcla le suma la sombra de un segundo horneado con
    obstáculos (`addons/hornear/apoyo.gd`): sólo el atlas, con el nivel de `NIVEL_DE_APOYO`. Las
    sondas son las del primero. Las rayas de un texel se reparan en cada atlas antes de
    mezclarlos, porque una raya mezclada deja de ser de media luz y el reparador no la ve.
    """
    atlas = SALIDAS[1]
    sesion_del_editor(godot, "", SALIDAS)
    reparar_lineas(blender, [atlas])
    if not con_apoyo(NIVEL_DE_APOYO):
        return
    sesion_del_editor(godot, VARIANTE_CON_APOYO, INTERMEDIOS_DEL_APOYO[:2])
    reparar_lineas(blender, [INTERMEDIOS_DEL_APOYO[1]])
    mezclar_atlas(godot, NIVEL_DE_APOYO)
    reparar_lineas(blender, [atlas])


def main(argumentos: list[str] | None = None) -> int:
    sin_luz = "--sin-luz" in (sys.argv[1:] if argumentos is None else argumentos)
    godot, _ = resolver(dict(os.environ))
    if godot is None:
        print(como_declararlo(dict(os.environ)))
        return 2
    blender = None
    if not sin_luz:
        blender, _ = lib_blender.resolver(dict(os.environ))
        if blender is None:
            print(lib_blender.como_declararlo(dict(os.environ)))
            return 2

    if os.name == "nt":
        procesos = subprocess.run(
            ["tasklist", "/fo", "csv"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        ).stdout
        if sesion_bloqueada(procesos):
            print("la sesión de Windows está bloqueada: el editor no hornea sin pantalla")
            return 2

    raiz = Path(RAIZ)
    previos = sucios(raiz)
    desde = time.time()
    respaldo = guardar_salidas(raiz, (*SALIDAS_QUE_SE_DEVUELVEN, *SALIDAS_SIN_LUZ))
    try:
        if sin_luz:
            sesion_del_editor(godot, VARIANTE_SIN_LUZ, SALIDAS_SIN_LUZ)
        else:
            hornear_con_luz(godot, blender)
    except Fallo as fallo:
        # Un horneado a medias no se queda: los archivos vuelven a como estaban.
        devolver_salidas(raiz, respaldo)
        print(fallo)
        return 1
    finally:
        borrar_intermedios(raiz)
        devolver_lo_reescrito(raiz, desde, previos)
    return 0


if __name__ == "__main__":
    sys.exit(main())
