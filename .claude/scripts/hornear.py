"""Hornear la luz del local: apretar «Bake Lightmaps» sin abrir el editor a mano.

    python .claude/scripts/hornear.py

## Por qué existe

Godot no expone el horneado a ningún script: es un botón del editor, y sin editor no hay
horneador. Este script abre el editor con el plugin `addons/hornear` prendido; el plugin aprieta
el botón, guarda y cierra; acá se lee el veredicto. Se corre cada vez que cambia el modelo o una
luz, y lo que deja —el `.lmbake`, el `.exr` y su `.import`, al lado de `almacen.tscn`— se
commitea.

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

- `GODOT_BIN`, la misma que usa `verificar.py`.
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

from lib.godot import como_declararlo, resolver  # noqa: E402
from lib.horneado import (  # noqa: E402
    SALIDAS,
    project_con_el_plugin,
    reescritos_de_mas,
    sesion_bloqueada,
    tope_en_segundos,
    veredicto,
)
from lib.repo import RAIZ  # noqa: E402

PROJECT = Path(RAIZ) / "project.godot"


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


def main() -> int:
    godot, _ = resolver(dict(os.environ))
    if godot is None:
        print(como_declararlo(dict(os.environ)))
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

    tope = tope_en_segundos(dict(os.environ))
    previos = sucios(Path(RAIZ))
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
        )
    except subprocess.TimeoutExpired:
        print(f"el editor no cerró en {tope // 60} minutos")
        return 1
    finally:
        PROJECT.write_bytes(original)
        devolver_lo_reescrito(Path(RAIZ), desde, previos)

    for linea in (corrida.stdout + corrida.stderr).splitlines():
        if "[hornear]" in linea:
            print(linea.strip())
    actualizados = {
        salida: (Path(RAIZ) / salida).exists() and (Path(RAIZ) / salida).stat().st_mtime >= desde
        for salida in SALIDAS
    }
    ok, motivo = veredicto(corrida.returncode, actualizados)
    print(motivo)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
