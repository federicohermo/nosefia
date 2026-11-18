"""Hornear la luz del local: apretar «Bake Lightmaps» sin abrir el editor a mano.

    python .claude/scripts/hornear.py             # el local con todas sus luces
    python .claude/scripts/hornear.py --sin-luz   # el mismo local en la noche del corte de luz
    python .claude/scripts/hornear.py --oclusion  # sólo la oclusión, sobre el atlas de la rama

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

## La oclusión de los rincones

Después de la sombra de apoyo, y como último paso del horneado con luz,
`addons/hornear/aplicar_oclusion.gd` multiplica la luz de cada texel del atlas por cuánto lo tapan
las mallas fijas a menos de `RADIO_DE_OCLUSION` (`addons/hornear/oclusion.gd`). Con
`NIVEL_DE_OCLUSION` en 0 el paso no corre. No hay nada que hornear de nuevo: `--oclusion` lo aplica
sobre el atlas que ya está en la rama, y `--nivel`, `--radio`, `--rayos` y `--salida` cambian lo
que usa y adónde escribe. Con `--salida` el atlas de la rama no se toca. **Sin `--salida` se
multiplica el atlas de la rama en su lugar: correrlo dos veces lo oscurece dos veces.** Un horneado
entero parte de un atlas nuevo y no tiene ese problema.

## El horneado sin luz

`--sin-luz` hornea el mismo local con todas sus luces apagadas salvo la de emergencia del panel,
y deja `almacen_sin_luz.lmbake` y `almacen_sin_luz.exr`. Los apaga en la copia del editor y no
guarda la escena: `almacen.tscn` queda como estaba. El juego cambia los datos del `LightmapGI`
por éstos al cortarse la luz de la séptima noche. Qué se apaga lo dice `corte_de_luz.gd`, y es lo
mismo que el juego apaga al cortar.

El horneador deja ese atlas en 2048 px de lado por capa. Después de reparar sus líneas, el script
lo reduce a `LADO_DEL_ATLAS_SIN_LUZ` (`blender/reducir_mapa_de_luz.py`): es una imagen casi negra y
pesa un cuarto. El horneado con luz no se reduce. Si algo falla, el `.lmbake`, el `.exr` y su
`.import` quedan como estaban.

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

- `GODOT_BIN`, la misma que usa `verificar.py`, y `BLENDER_BIN` o Blender en su lugar de siempre:
  los dos horneados reparan sus atlas con él, y el de sin luz también los reduce.
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

import argparse
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
    LADO_DEL_ATLAS_SIN_LUZ,
    NIVEL_DE_APOYO,
    NIVEL_DE_OCLUSION,
    RADIO_DE_OCLUSION,
    RAYOS_DE_OCLUSION,
    SALIDAS,
    SALIDAS_QUE_SE_DEVUELVEN,
    SALIDAS_SIN_LUZ,
    VARIANTE_CON_APOYO,
    VARIANTE_SIN_LUZ,
    comando_de_la_mezcla,
    comando_de_la_oclusion,
    comando_de_la_reduccion,
    comando_de_la_reparacion,
    con_apoyo,
    con_oclusion,
    entorno_de,
    project_con_el_plugin,
    reescritos_de_mas,
    ruta_para_godot,
    sesion_bloqueada,
    tope_en_segundos,
    veredicto,
)
from lib.repo import RAIZ  # noqa: E402

PROJECT = Path(RAIZ) / "project.godot"
REPARADOR = Path(RAIZ) / ".claude/scripts/blender/reparar_lineas_del_mapa_de_luz.py"
REDUCTOR = Path(RAIZ) / ".claude/scripts/blender/reducir_mapa_de_luz.py"


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


def reducir_atlas(blender: str, atlas: list[str], lado: int) -> None:
    """Lleva cada atlas a `lado` px por capa, en su lugar. Ver el reductor."""
    corrida = subprocess.run(
        comando_de_la_reduccion(blender, str(REDUCTOR), [str(Path(RAIZ) / a) for a in atlas], lado),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    print(corrida.stdout.strip())
    if corrida.returncode != 0:
        raise Fallo("no pude reducir " + ", ".join(atlas) + "\n" + corrida.stderr)


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


def oclusionar_atlas(
    godot: str,
    entrada: str,
    salida: str,
    nivel: float,
    radio: float = RADIO_DE_OCLUSION,
    rayos: int = RAYOS_DE_OCLUSION,
) -> None:
    """Multiplica la luz del atlas `entrada` por la oclusión de los rincones y escribe `salida`.

    Las rutas son relativas a la raíz, o enteras. Pueden ser el mismo atlas: se reescribe en su
    lugar. Ver `addons/hornear/oclusion.gd`.
    """

    def para_godot(ruta: str) -> str:
        return ruta_para_godot(str(Path(RAIZ) / ruta), RAIZ)

    corrida = subprocess.run(
        comando_de_la_oclusion(
            godot, RAIZ, para_godot(entrada), para_godot(salida), radio, nivel, rayos
        ),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    for linea in (corrida.stdout + corrida.stderr).splitlines():
        if "[oclusion]" in linea:
            print(linea.strip())
    if corrida.returncode != 0:
        raise Fallo("la oclusión salió con código %d" % corrida.returncode)


def hornear_con_luz(godot: str, blender: str) -> None:
    """El horneado que el juego carga: el local con luz y, encima, la sombra de apoyo.

    Hornea el local de siempre, y la mezcla le suma la sombra de un segundo horneado con
    obstáculos (`addons/hornear/apoyo.gd`): sólo el atlas, con el nivel de `NIVEL_DE_APOYO`. Las
    sondas son las del primero. Las rayas de un texel se reparan en cada atlas antes de
    mezclarlos, porque una raya mezclada deja de ser de media luz y el reparador no la ve. La
    oclusión va al final: si fuera antes, la mezcla la diluiría.
    """
    atlas = SALIDAS[1]
    sesion_del_editor(godot, "", SALIDAS)
    reparar_lineas(blender, [atlas])
    if con_apoyo(NIVEL_DE_APOYO):
        sesion_del_editor(godot, VARIANTE_CON_APOYO, INTERMEDIOS_DEL_APOYO[:2])
        reparar_lineas(blender, [INTERMEDIOS_DEL_APOYO[1]])
        mezclar_atlas(godot, NIVEL_DE_APOYO)
        reparar_lineas(blender, [atlas])
    if con_oclusion(NIVEL_DE_OCLUSION):
        oclusionar_atlas(godot, atlas, atlas, NIVEL_DE_OCLUSION)


def hornear_sin_luz(godot: str, blender: str) -> None:
    """El horneado de la noche del corte: el local sin luz, con sus líneas reparadas y reducido.

    Se reduce después de reparar, nunca antes: el reparador reconoce una línea por su huella de un
    texel, y al promediar bloques de 2 por 2 esa huella se reparte entre dos texeles.
    """
    atlas = SALIDAS_SIN_LUZ[1]
    sesion_del_editor(godot, VARIANTE_SIN_LUZ, SALIDAS_SIN_LUZ)
    reparar_lineas(blender, [atlas])
    reducir_atlas(blender, [atlas], LADO_DEL_ATLAS_SIN_LUZ)


def _argumentos(argumentos: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Hornear la luz del local.")
    parser.add_argument("--sin-luz", action="store_true", help="el horneado de la noche del corte")
    parser.add_argument(
        "--oclusion", action="store_true", help="sólo la oclusión, sobre el atlas de la rama"
    )
    parser.add_argument("--nivel", type=float, default=NIVEL_DE_OCLUSION)
    parser.add_argument("--radio", type=float, default=RADIO_DE_OCLUSION)
    parser.add_argument("--rayos", type=int, default=RAYOS_DE_OCLUSION)
    parser.add_argument("--salida", default=SALIDAS[1], help="adónde escribe la oclusión")
    return parser.parse_args(sys.argv[1:] if argumentos is None else argumentos)


def solo_la_oclusion(godot: str, opciones: argparse.Namespace) -> int:
    """Aplica la oclusión al atlas de la rama, sin hornear. Si falla, el atlas queda igual."""
    if not con_oclusion(opciones.nivel):
        print("el nivel es 0: no hay nada que aplicar")
        return 0
    raiz = Path(RAIZ)
    respaldo = guardar_salidas(raiz, (SALIDAS[1],))
    try:
        oclusionar_atlas(
            godot, SALIDAS[1], opciones.salida, opciones.nivel, opciones.radio, opciones.rayos
        )
    except Fallo as fallo:
        devolver_salidas(raiz, respaldo)
        print(fallo)
        return 1
    return 0


def main(argumentos: list[str] | None = None) -> int:
    opciones = _argumentos(argumentos)
    sin_luz = opciones.sin_luz
    godot, _ = resolver(dict(os.environ))
    if godot is None:
        print(como_declararlo(dict(os.environ)))
        return 2
    if opciones.oclusion:
        return solo_la_oclusion(godot, opciones)
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
    respaldo = guardar_salidas(raiz, SALIDAS_QUE_SE_DEVUELVEN)
    try:
        if sin_luz:
            hornear_sin_luz(godot, blender)
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
