"""Vuelca el almacén para los visores web de prueba: escena, geometría, luces, lightmap y texturas.

    python .claude/scripts/volcar_almacen.py                    # a build/motor-web/datos/
    python .claude/scripts/volcar_almacen.py --salida DIR       # a otra carpeta
    python .claude/scripts/volcar_almacen.py --proyecto DIR     # desde una copia importada

## Qué hace, en orden

1. Corre `web/volcar_almacen.gd` adentro de Godot, sin ventana. Lee las escenas del almacén y
   escribe `escena.json`, `geometria.bin` y la página 0 del lightmap.
2. Lee `src/escenas/almacen.lmbake` y deja el rectángulo de cada nodo en el atlas
   (`lightmap.json`), el atlas recortado a las filas usadas (`lightmap.bin`) y las sondas
   (`sondas.bin`).
3. Empaqueta las texturas que Godot ya importó, en BC, y las cuatro capas del lightmap
   (`texturas.bin` y `texturas.json`). El visor sube a la GPU los mismos bytes que viajan en
   el `.pck` de la web de hoy.
4. Copia las poses de cámara de `web/vistas.json`.

## Qué pide

El proyecto tiene que estar importado: `.godot/imported/` con los `.ctex`. Un editor abierto
una vez alcanza, o `godot --headless --import`. Sin eso el paso 3 no tiene qué empaquetar, y el
script lo dice antes de arrancar en vez de dejar una carpeta a medias.

No toca `src/`: sólo lee. Escribe únicamente en la carpeta de salida.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib import godot, volcado_almacen as volcado  # noqa: E402
from lib.repo import RAIZ  # noqa: E402

SCRIPT_DE_GODOT = Path(__file__).resolve().parent / "web" / "volcar_almacen.gd"
VISTAS = Path(__file__).resolve().parent / "web" / "vistas.json"
HORNEADO = Path("src") / "escenas" / "almacen.lmbake"
SALIDA_POR_DEFECTO = RAIZ / "build" / "motor-web" / "datos"
MINUTOS_PARA_GODOT = 15


def volcar_con_godot(binario: str, proyecto: Path, salida: Path) -> int:
    """El paso que sólo Godot puede dar: leer las escenas. La salida viaja como argumento."""
    comando = [
        binario, "--headless", "--path", str(proyecto),
        "--script", str(SCRIPT_DE_GODOT), "--", str(salida) + os.sep,
    ]  # fmt: skip
    with open(salida / "volcado_godot.log", "wb") as registro:
        return subprocess.run(
            comando, stdout=registro, stderr=subprocess.STDOUT, timeout=MINUTOS_PARA_GODOT * 60
        ).returncode


def lightmap_y_sondas(proyecto: Path, salida: Path) -> None:
    b = (proyecto / HORNEADO).read_bytes()
    nombres, _ = volcado.leer_nombres(b)
    rects = volcado.rectangulos(b, nombres)
    manifiesto = volcado.manifiesto_del_lightmap(rects)
    crudo = (salida / "lightmap.bin").read_bytes()
    alto = manifiesto["alto"]
    (salida / "atlas_previa.png").write_bytes(volcado.previa_del_atlas(crudo, alto))
    (salida / "lightmap.bin").write_bytes(volcado.recortar_lightmap(crudo, alto))
    (salida / "lightmap.json").write_text(json.dumps(manifiesto), encoding="utf-8")
    s = volcado.sondas(b, nombres)
    if s:
        cuerpo, resumen = volcado.sondas_a_bytes(s)
        (salida / "sondas.bin").write_bytes(cuerpo)
        (salida / "sondas.json").write_text(json.dumps(resumen), encoding="utf-8")
    print(f"lightmap: {len(rects)} rectángulos, {alto} filas; sondas: {bool(s)}")


def texturas(proyecto: Path, salida: Path) -> list[str]:
    escena = json.loads((salida / "escena.json").read_text(encoding="utf-8"))
    importado = proyecto / ".godot" / "imported"
    paquete = volcado.Paquete()
    faltan = []
    for ruta, info in escena["texturas"].items():
        patron = volcado.glob_escapado(info["archivo"])
        candidatos = sorted(importado.glob(patron + "-*.s3tc.ctex")) or sorted(
            importado.glob(patron + "-*.bptc.ctex")
        )
        if not candidatos:
            faltan.append(info["archivo"])
            continue
        paquete.agregar_textura(ruta, candidatos[0].read_bytes(), candidatos[0].name)
    alto = json.loads((salida / "lightmap.json").read_text(encoding="utf-8"))["alto"]
    mapa = next(importado.glob("almacen.exr-*.bptc.ctexarray"))
    filas = (alto + 3) // 4
    paquete.agregar_lightmap(volcado.capas_del_lightmap(mapa.read_bytes(), filas), filas)
    (salida / "texturas.bin").write_bytes(paquete.binario())
    (salida / "texturas.json").write_text(paquete.manifiesto(), encoding="utf-8")
    print(f"texturas: {len(paquete.indice) - volcado.CAPAS_DEL_LIGHTMAP}, {paquete.cursor} bytes")
    return faltan


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--proyecto", type=Path, default=RAIZ)
    ap.add_argument("--salida", type=Path, default=SALIDA_POR_DEFECTO)
    opciones = ap.parse_args()
    proyecto, salida = opciones.proyecto.resolve(), opciones.salida.resolve()

    if not (proyecto / ".godot" / "imported").is_dir():
        print(f"{proyecto} no está importado: falta .godot/imported.")
        print("Corré `godot --headless --import` en ese proyecto.")
        return 1
    binario, origen = godot.resolver(dict(os.environ))
    if binario is None:
        print(godot.como_declararlo(dict(os.environ)))
        return 1
    salida.mkdir(parents=True, exist_ok=True)
    print(f"Godot: {binario} ({origen})")

    codigo = volcar_con_godot(binario, proyecto, salida)
    if codigo != 0 or not (salida / "escena.json").is_file():
        print(f"el volcado de Godot salió con {codigo} y no dejó escena.json")
        print(f"mirá {salida / 'volcado_godot.log'}")
        return 1
    lightmap_y_sondas(proyecto, salida)
    faltan = texturas(proyecto, salida)
    shutil.copyfile(VISTAS, salida / "vistas.json")
    if faltan:
        print(f"aviso: {len(faltan)} texturas sin importar en BC, el visor las dibuja lisas: {faltan}")
    print(f"listo en {salida}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
