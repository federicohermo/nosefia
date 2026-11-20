"""Restaura el espesor del panel lateral izquierdo colapsado de `exhibidor_golosinas-col`.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/engrosar_lateral_exhibidor.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/engrosar-lateral-exhibidor.blend` y no modifica el
`.blend` del repo. Con `--aplicar`, guarda la fuente canónica en su lugar.

## Por qué

El lateral derecho (`-X`) del exhibidor tiene 20 mm de espesor (`x_local = -1.094 .. -1.074`).
El lateral izquierdo (`+X`, lado freezer) quedó colapsado a espesor 0 mm en `x_local = 0.432`,
con su cara exterior (`+X`), su cara interior (`-X`), cuatro caras de canto con área cero y las
cinco tapas de los escalones superpuestas en el mismo plano. Al hornear la luz, esa superposición
dejaba rayas negras a lo largo de los escalones del costado izquierdo.

## Qué cambia

Mueve los cuatro vértices de la cara exterior (`+X`) del panel izquierdo al espesor espejo del
panel derecho (`x_local = 0.452`, +20 mm). Las cuatro caras de canto recuperan su área y sus
normales hacia afuera. No toca escalones, zócalo, golosinas hijas ni ningún otro objeto del
`.blend`. Es idempotente: una segunda corrida no mueve vértices.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import bpy  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))

from lib.consola import configurar  # noqa: E402
from lib.exhibidor_de_golosinas import espesor_de_panel, x_exterior_objetivo  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
OBJETO = "exhibidor_golosinas-col"
TOLERANCIA_NORMAL = 0.99


def _huellas_ajenas(excluir: str) -> dict[str, str]:
    resultado: dict[str, str] = {}
    for o in bpy.data.objects:
        if o.type != "MESH" or o.name == excluir:
            continue
        datos = {
            "vertices": [tuple(v.co) for v in o.data.vertices],
            "caras": [tuple(p.vertices) for p in o.data.polygons],
            "matriz": [tuple(f) for f in o.matrix_world],
        }
        resultado[o.name] = hashlib.sha256(json.dumps(datos).encode()).hexdigest()
    return resultado


def _paneles_laterales(malla) -> tuple[list, list]:
    """Identifica las caras grandes verticales en X de los dos paneles laterales."""
    caras_x = [p for p in malla.polygons if abs(p.normal.x) >= TOLERANCIA_NORMAL]
    if not caras_x:
        raise ValueError(f"{OBJETO} no tiene caras laterales en X")
    area_max = max(p.area for p in caras_x)
    grandes = [p for p in caras_x if p.area >= area_max * 0.9]
    xs = [malla.vertices[p.vertices[0]].co.x for p in grandes]
    centro = (min(xs) + max(xs)) * 0.5
    derecho = [p for p in grandes if malla.vertices[p.vertices[0]].co.x < centro]
    izquierdo = [p for p in grandes if malla.vertices[p.vertices[0]].co.x > centro]
    if len(derecho) != 2 or len(izquierdo) != 2:
        raise ValueError(
            f"Se esperaban 2 caras por panel lateral; hay der={len(derecho)}, izq={len(izquierdo)}"
        )
    return derecho, izquierdo


def _x_de_cara(malla, cara) -> float:
    return sum(malla.vertices[i].co.x for i in cara.vertices) / len(cara.vertices)


def aplicar() -> dict:
    objeto = bpy.data.objects.get(OBJETO)
    if objeto is None:
        raise SystemExit(f"falta el objeto {OBJETO}")
    antes = _huellas_ajenas(OBJETO)
    malla = objeto.data
    derecho, izquierdo = _paneles_laterales(malla)

    der_ext = next(p for p in derecho if p.normal.x < 0.0)
    der_int = next(p for p in derecho if p.normal.x > 0.0)
    izq_ext = next(p for p in izquierdo if p.normal.x > 0.0)
    izq_int = next(p for p in izquierdo if p.normal.x < 0.0)

    espesor_der = espesor_de_panel(_x_de_cara(malla, der_ext), _x_de_cara(malla, der_int))
    x_ext_izq = _x_de_cara(malla, izq_ext)
    x_int_izq = _x_de_cara(malla, izq_int)
    espesor_izq_antes = espesor_de_panel(x_ext_izq, x_int_izq)
    objetivo = x_exterior_objetivo(x_ext_izq, x_int_izq, espesor_der, +1)

    vertices_movidos = 0
    if abs(objetivo - x_ext_izq) > 1e-6:
        # Confirmar que los vértices de la cara exterior no pertenecen a la cara interior ni a
        # los escalones.
        bloqueados = set(izq_int.vertices)
        for indice in izq_ext.vertices:
            if indice in bloqueados:
                raise ValueError(f"El vértice {indice} se comparte con la cara interior")
            malla.vertices[indice].co.x = objetivo
            vertices_movidos += 1
        bm = bmesh.new()
        bm.from_mesh(malla)
        bm.normal_update()
        bm.to_mesh(malla)
        bm.free()
        malla.update()

    despues = _huellas_ajenas(OBJETO)
    assert antes == despues, "Se modificó otro objeto del .blend"
    areas_cero = sum(1 for p in malla.polygons if p.area <= 1e-9)
    assert areas_cero == 0, f"Quedaron {areas_cero} caras con área nula en {OBJETO}"
    _, izquierdo_despues = _paneles_laterales(malla)
    izq_ext_d = next(p for p in izquierdo_despues if p.normal.x > 0.0)
    izq_int_d = next(p for p in izquierdo_despues if p.normal.x < 0.0)
    espesor_izq_despues = espesor_de_panel(_x_de_cara(malla, izq_ext_d), _x_de_cara(malla, izq_int_d))
    return {
        "objeto": OBJETO,
        "espesor_derecho_m": round(espesor_der, 6),
        "espesor_izquierdo_antes_m": round(espesor_izq_antes, 6),
        "espesor_izquierdo_despues_m": round(espesor_izq_despues, 6),
        "x_exterior_local": round(objetivo, 6),
        "vertices_movidos": vertices_movidos,
        "ya_engrosado": vertices_movidos == 0,
        "caras_area_cero": areas_cero,
    }


def main() -> None:
    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    parser.add_argument(
        "--destino", type=Path, default=RAIZ / "reports/engrosar-lateral-exhibidor.blend"
    )
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    resultado = aplicar()
    destino = FUENTE if opciones.aplicar else opciones.destino
    destino.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    print(json.dumps(resultado, indent=2))


if __name__ == "__main__":
    main()
