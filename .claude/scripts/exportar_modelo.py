"""Exporta el modelo del almacén y deja a Godot con la malla nueva.

    python .claude/scripts/exportar_modelo.py            # exportar y reimportar
    python .claude/scripts/exportar_modelo.py --solo-importar

## Por qué existe

La receta de exportación vivía en el docstring de un test, y las dos trampas que la rodean ya
costaron tiempo: los modificadores `Array` se apagan **por nombre** —apagar por tipo no apaga
ninguno—, y **la caché de `.godot/imported/` declara verde un modelo que ya cambió**, porque un
`.glb` reexportado no se reimporta solo en una corrida headless. Costó dos diagnósticos
equivocados el 2026-09-15.

Una receta escrita es una receta que alguien va a seguir de memoria. Acá es un comando.

## Qué hace, en orden

1. Resuelve Blender. La serie está pinneada: **dos versiones del exportador devuelven datos de
   vértice distintos para la misma malla**, así que exportar con otra deja un diff binario que no
   corresponde a ningún cambio del modelo.
2. Corre `blender/exportar.py` adentro de Blender, que apaga los `Array` y exporta.
3. Escribe al lado del `.glb` la huella del `.blend` del que salió. Va en el mismo commit que el
   `.glb`. `test_modelo_actualizado.py` la compara con el `.blend` del árbol. Es del `.blend` y
   no del `.glb`: dos exportaciones del mismo `.blend` no dan los mismos bytes.
4. **Borra la caché del `.glb` y reimporta con Godot.** Sin esto, los tests comparan contra la
   malla anterior y pasan.

## Lo que NO hace

No commitea, y no decide si el resultado está bien. Después de correrlo va
`python .claude/scripts/verificar.py`: el par `.blend` ↔ `.glb` y los apoyos del modelo los
verifican sus tests, y un diff binario que nadie mira es exactamente lo que ellos existen para
no dejar pasar.
"""

import hashlib
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.blender import como_declararlo, resolver  # noqa: E402
from lib.godot import como_declararlo as como_declarar_godot  # noqa: E402
from lib.godot import resolver as resolver_godot  # noqa: E402
from lib.repo import RAIZ  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
DESTINO = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.glb"
HUELLA = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.glb.fuente"
EXPORTADOR = Path(__file__).resolve().parent / "blender" / "exportar.py"

#: La caché que Godot escribe por cada recurso importado. Se borra la del modelo y nada más:
#: borrar `.godot/` entero obliga a reimportar el proyecto completo, que son minutos.
CACHE = RAIZ / ".godot" / "imported"


def cache_del_modelo() -> list[Path]:
    if not CACHE.is_dir():
        return []
    return sorted(CACHE.glob(f"{DESTINO.name}-*"))


def _huella_de(fuente: Path) -> str:
    # El formato de `sha256sum`: la huella también se comprueba a mano, con `sha256sum -c`.
    return f"{hashlib.sha256(fuente.read_bytes()).hexdigest()}  {fuente.name}\n"


def escribir_huella(fuente: Path, huella: Path) -> None:
    huella.write_text(_huella_de(fuente), encoding="utf-8", newline="\n")


def desfasaje(fuente: Path, huella: Path) -> str | None:
    """Por qué el `.glb` no salió de `fuente`, o `None` si salió de ella."""
    if not huella.is_file():
        motivo = f"falta {huella.name}"
    elif huella.read_text(encoding="utf-8") != _huella_de(fuente):
        motivo = f"{fuente.name} cambió desde la última exportación"
    else:
        return None
    return f"{motivo}: corré python .claude/scripts/exportar_modelo.py"


def exportar() -> int:
    blender, origen = resolver(dict(os.environ))
    if blender is None:
        print(como_declararlo(dict(os.environ)), file=sys.stderr)
        return 1
    if not FUENTE.is_file():
        print(f"no está la fuente: {FUENTE}", file=sys.stderr)
        return 1

    print(f"Blender ({origen}): {blender}")
    proceso = subprocess.run(
        [blender, str(FUENTE), "--background", "--python", str(EXPORTADOR), "--", str(DESTINO)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    # El veredicto sale del código de salida. Blender escribe avisos en stderr con la
    # exportación bien hecha, así que buscar «error» en la salida daría rojos inventados.
    if proceso.returncode != 0:
        print(proceso.stdout + proceso.stderr, file=sys.stderr)
        return proceso.returncode
    for linea in proceso.stdout.splitlines():
        if linea.startswith(("modificadores", "exportado")):
            print(f"  {linea}")
    escribir_huella(FUENTE, HUELLA)
    print(f"  huella: {HUELLA}")
    return 0


def reimportar() -> int:
    godot, _ = resolver_godot(dict(os.environ))
    if godot is None:
        print(como_declarar_godot(dict(os.environ)), file=sys.stderr)
        return 1

    borrados = cache_del_modelo()
    for archivo in borrados:
        archivo.unlink()
    print(f"caché borrada: {len(borrados)} archivos")

    proceso = subprocess.run(
        [godot, "--headless", "--path", str(RAIZ), "--import", "--quit"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if proceso.returncode != 0:
        print(proceso.stdout + proceso.stderr, file=sys.stderr)
        return proceso.returncode
    print("reimportado")
    return 0


def main() -> int:
    if "--solo-importar" not in sys.argv:
        codigo = exportar()
        if codigo != 0:
            return codigo
    codigo = reimportar()
    if codigo != 0:
        return codigo
    print("\nListo. Ahora: python .claude/scripts/verificar.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
