"""Hornear la luz del local: apretar «Bake Lightmaps» sin abrir el editor a mano.

    python .claude/scripts/hornear.py

## Por qué existe

Godot no expone el horneado a ningún script: es un botón del editor, y sin editor no hay
horneador. Este script abre el editor con el plugin `addons/hornear` prendido; el plugin aprieta
el botón, guarda y cierra; acá se lee el veredicto. Se corre cada vez que cambia el modelo o una
luz, y lo que deja —el `.lmbake` y el `.exr` al lado de `almacen.tscn`— se commitea.

## Cómo se prende el plugin

Escribiendo `project.godot` con el plugin como único prendido, y devolviéndolo byte por byte al
terminar, pase lo que pase. No hay otra: el editor no lee la lista de plugins de `override.cfg`.
Dejar el plugin en `project.godot` haría que cada apertura del editor horneara y cerrara.

## Qué hace falta

- `GODOT_BIN`, la misma que usa `verificar.py`.
- **El editor del repo cerrado.** Dos editores sobre el mismo proyecto se pisan la caché.
- Una sesión con pantalla: el editor abre una ventana. El horneado no anda headless.
- Una GPU con Vulkan: el editor de horneado usa Mobile para evitar la textura nula del
  horneador OpenGL. El juego conserva el renderer definido en `project.godot`.
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
from lib.horneado import SALIDAS, project_con_el_plugin, veredicto  # noqa: E402
from lib.repo import RAIZ  # noqa: E402

PROJECT = Path(RAIZ) / "project.godot"
#: Un horneado del local tarda segundos. Si pasa de esto, el editor se quedó esperando algo.
TOPE_SEGUNDOS = 20 * 60


def main() -> int:
    godot, _ = resolver(dict(os.environ))
    if godot is None:
        print(como_declararlo(dict(os.environ)))
        return 2

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
            timeout=TOPE_SEGUNDOS,
        )
    except subprocess.TimeoutExpired:
        print(f"el editor no cerró en {TOPE_SEGUNDOS // 60} minutos")
        return 1
    finally:
        PROJECT.write_bytes(original)

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
