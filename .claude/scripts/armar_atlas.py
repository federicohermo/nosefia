"""Arma los atlas de etiquetas de producto y de cajas, y deja su manifiesto.

    python .claude/scripts/armar_atlas.py                # armar y escribir en el árbol
    python .claude/scripts/armar_atlas.py --comprobar    # decir si está al día, sin escribir
    python .claude/scripts/armar_atlas.py --sellar       # sellar los PNG que ya están
    python .claude/scripts/armar_atlas.py --destino DIR  # armar en otra carpeta, sin tocar el árbol

## Cuándo se corre

Cada vez que cambia una textura de `lib.atlas.ETIQUETAS`, una caja de `assets/boxes/`, o el
tamaño con el que viaja alguna (`lib.blender.LADO_MAXIMO`). **Una textura nueva del mismo
tamaño o de otro se acomoda sola**: el reparto sale de los tamaños que lee, y el exportador
reescribe las UV de las que se movieron. Una etiqueta nueva es una línea en `ETIQUETAS`; una
caja nueva, un PNG en `assets/boxes/`.

Después de armar: `python .claude/scripts/exportar_modelo.py` y `python .claude/scripts/hornear.py`.
`test_atlas_al_dia.py` frena un atlas que ya no corresponde a sus fuentes.

## Qué hace

Corre `blender/armar_atlas.py` adentro de Blender: achica cada textura al lado con el que viaja,
la pone en su celda con un borde que repite su último píxel, y escribe un PNG por formato (BC1
para lo opaco, BC3 para lo que tiene alfa) y `atlas.json`, con la huella de cada fuente y de
cada PNG.

`--comprobar` no necesita Blender: compara el manifiesto con las fuentes y sale con 1 si no
corresponden.
"""

import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib import atlas  # noqa: E402
from lib.blender import como_declararlo, resolver  # noqa: E402

ARMADOR = Path(__file__).resolve().parent / "blender" / "armar_atlas.py"


def comprobar() -> int:
    if not atlas.MANIFIESTO.is_file():
        print(f"no hay atlas: falta {atlas.MANIFIESTO}")
        return 1
    motivos = atlas.desfasaje_con_el_disco(atlas.leer())
    for motivo in motivos:
        print(f"  {motivo}")
    print("el atlas está al día" if not motivos else "el atlas NO está al día")
    return 1 if motivos else 0


def armar(destino: Path | None, sellar: bool) -> int:
    blender, origen = resolver(dict(os.environ))
    if blender is None:
        print(como_declararlo(dict(os.environ)), file=sys.stderr)
        return 1
    print(f"Blender ({origen}): {blender}")
    orden = [
        blender, "--factory-startup", "--background", "--python-exit-code", "1",
        "--python", str(ARMADOR), "--", str(destino) if destino else "--en-el-arbol",
    ]
    if sellar:
        orden.append("--sellar")
    proceso = subprocess.run(
        orden, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    if proceso.returncode != 0:
        print(proceso.stdout + proceso.stderr, file=sys.stderr)
        return proceso.returncode
    for linea in proceso.stdout.splitlines():
        if linea.startswith(("atlas:", "manifiesto:", "reparto")):
            print(f"  {linea}")
    return 0


def main() -> int:
    argumentos = sys.argv[1:]
    if "--comprobar" in argumentos:
        return comprobar()
    destino = None
    if "--destino" in argumentos:
        destino = Path(argumentos[argumentos.index("--destino") + 1]).resolve()
    return armar(destino, "--sellar" in argumentos)


if __name__ == "__main__":
    sys.exit(main())
