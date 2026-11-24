"""Quita el pallet suelto del piso del depósito (`deposito_pallet_piso`).

    blender --factory-startup --background --python-exit-code 1 \
        --python .claude/scripts/blender/quitar_pallet_piso.py -- [--aplicar]

Sin `--aplicar`, guarda una copia de prueba en `reports/sin-pallet-piso.blend`.
Con `--aplicar`, actualiza `assets/models/SEPT_JUEGOS_PROTOTIPO.blend` en su lugar.

## Por qué

`deposito_pallet_piso` quedaba vacío en el paso del depósito entre las estanterías y el portón.
Los pallets temporales de entrega (`pallets_de_entrega.gd`) toman su malla desde
`deposito_pallet_fondo_0_0` escalada al mismo tamaño (`1,38 × 0,92 m`), por lo que el pallet suelto
del piso ya no se necesita ni como geometría ni como plantilla.

Es idempotente: si el objeto ya no está, no modifica nada.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))

from lib.consola import configurar  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
DESTINO_PRUEBA = RAIZ / "reports/sin-pallet-piso.blend"
NOMBRE_PALLET = "deposito_pallet_piso"


def _huellas_ajenas(excluir: str) -> dict[str, str]:
    huellas: dict[str, str] = {}
    for o in bpy.data.objects:
        if o.type != "MESH" or o.name == excluir:
            continue
        datos = {
            "v": len(o.data.vertices),
            "p": len(o.data.polygons),
            "m": [round(f, 5) for fila in o.matrix_world for f in fila],
        }
        huellas[o.name] = hashlib.sha256(json.dumps(datos).encode()).hexdigest()
    return huellas


def aplicar() -> dict[str, object]:
    antes = _huellas_ajenas(NOMBRE_PALLET)
    objeto = bpy.data.objects.get(NOMBRE_PALLET)
    eliminado = False
    malla_eliminada = None
    if objeto is not None:
        malla = objeto.data
        bpy.data.objects.remove(objeto, do_unlink=True)
        eliminado = True
        if malla is not None and malla.users == 0:
            malla_eliminada = malla.name
            bpy.data.meshes.remove(malla)
    despues = _huellas_ajenas(NOMBRE_PALLET)
    assert antes == despues, "Se modificó un objeto ajeno al quitar deposito_pallet_piso"
    return {
        "objeto": NOMBRE_PALLET,
        "eliminado": eliminado,
        "malla_eliminada": malla_eliminada,
    }


def main() -> None:
    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    parser.add_argument("--destino", type=Path, default=DESTINO_PRUEBA)
    opciones = parser.parse_args(argumentos)

    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    resultado = aplicar()
    destino = FUENTE if opciones.aplicar else opciones.destino
    destino.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    print(json.dumps(resultado, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
