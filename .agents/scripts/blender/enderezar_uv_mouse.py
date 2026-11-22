"""Endereza las UV de la isla superior de `mouse-col` para alinear rueda y costura de botones.

    blender --factory-startup --background --python-exit-code 1 \
        --python .claude/scripts/blender/enderezar_uv_mouse.py -- [--aplicar]

## Por qué

`Mouse_Normal.png` fue horneada con la isla superior inclinada: la costura horizontal de los
botones sube ~5° hacia la derecha (`V = 0,231` en `U = 0,36` hasta `V = 0,254` en `U = 0,63`), y
la costura vertical se desplaza hacia la derecha al subir (`U = 0,487` bajo la rueda, `0,493` en la
rueda y `0,496` en la punta). Sobre una malla simétrica en X con proyección vertical recta, esa
inclinación hacía ver la rueda y las costuras torcidas respecto del contorno del mouse.

Este paso parte de la simetría exacta en X de la malla (`(x, y, z) <-> (-x, y, z)`) para que el
resultado sea 100% idempotente y alinea la costura vertical en `X = 0` y la horizontal a nivel.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))

from lib.consola import configurar  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
DESTINO_PRUEBA = RAIZ / "reports/mouse-uv-recto.blend"
NOMBRE_MOUSE = "mouse-col"

# Recta medida sobre `Mouse_Normal.png`:
# - Costura horizontal: V(U) = V_0 + PENDIENTE_H * (U - U_CENTRO_REF)
# - Costura vertical y rueda: U_centro(V) interpolado entre base (0.252 -> 0.4875),
#   rueda (0.328 -> 0.4926) y punta (0.486 -> 0.4958).
U_CENTRO_REF = 0.4948
PENDIENTE_H = 0.088
PUNTOS_U_CENTRO = (
    (0.000, 0.4875),
    (0.252, 0.4875),
    (0.328, 0.4926),
    (0.486, 0.4958),
    (1.000, 0.4958),
)


def _u_centro(v: float) -> float:
    for i in range(len(PUNTOS_U_CENTRO) - 1):
        v0, u0 = PUNTOS_U_CENTRO[i]
        v1, u1 = PUNTOS_U_CENTRO[i + 1]
        if v0 <= v <= v1:
            t = 0.0 if v1 == v0 else (v - v0) / (v1 - v0)
            return u0 + (u1 - u0) * t
    return PUNTOS_U_CENTRO[-1][1]


def _es_isla_superior(u: float, v: float) -> bool:
    return 0.335 <= u <= 0.665 and 0.0 <= v <= 0.505


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


def _clave_vertice(co) -> tuple[int, int, int]:
    return (round(co.x * 10000), round(co.y * 10000), round(co.z * 10000))


def _clave_espejo(co) -> tuple[int, int, int]:
    return (round(-co.x * 10000), round(co.y * 10000), round(co.z * 10000))


def aplicar() -> dict[str, object]:
    antes = _huellas_ajenas(NOMBRE_MOUSE)
    objeto = bpy.data.objects[NOMBRE_MOUSE]
    bm = bmesh.new()
    try:
        bm.from_mesh(objeto.data)
        uv = bm.loops.layers.uv.active
        assert uv is not None, f"{NOMBRE_MOUSE} no tiene capa UV"

        # Primero reconstruir una base 100% simétrica en la isla superior promediando cada vértice
        # con su espejo en X. Esto vuelve la transformación completamente idempotente.
        uvs_por_vert: dict[tuple[int, int, int], tuple[float, float]] = {}
        loops_superiores = []
        for cara in bm.faces:
            us = [l[uv].uv.x for l in cara.loops]
            vs = [l[uv].uv.y for l in cara.loops]
            if _es_isla_superior(sum(us) / len(us), sum(vs) / len(vs)):
                for loop in cara.loops:
                    loops_superiores.append(loop)
                    uvs_por_vert[_clave_vertice(loop.vert.co)] = (loop[uv].uv.x, loop[uv].uv.y)

        # Calcular (du_sim, v_sim) simétricos alrededor del eje X = 0 y acotar simétricamente
        # antes del cizallamiento para garantizar idempotencia exacta en corridas sucesivas.
        simetricas: dict[tuple[int, int, int], tuple[float, float]] = {}
        for clave, (u, v) in uvs_por_vert.items():
            espejo = (-clave[0], clave[1], clave[2])
            if espejo in uvs_por_vert:
                u_m, v_m = uvs_por_vert[espejo]
                du = (u - u_m) / 2.0
                v_sim = (v + v_m) / 2.0
            else:
                du = 0.0
                v_sim = v
            margen_v = abs(PENDIENTE_H * du)
            v_sim = max(0.004 + margen_v, min(0.495 - margen_v, v_sim))
            margen_u = abs(_u_centro(v_sim) - 0.5)
            du = max(-(0.155 - margen_u), min(0.155 - margen_u, du))
            simetricas[clave] = (du, v_sim)

        # Aplicar la alineación exacta a la costura vertical y horizontal de `Mouse_Normal.png`.
        ajustados = 0
        for loop in loops_superiores:
            du, v_sim = simetricas[_clave_vertice(loop.vert.co)]
            v_alineado = v_sim + PENDIENTE_H * du
            u_alineado = _u_centro(v_sim) + du
            loop[uv].uv = (u_alineado, v_alineado)
            ajustados += 1

        # Verificar que ningún polígono invirtió su orientación UV.
        invertidos = 0
        for cara in bm.faces:
            pts = [l[uv].uv for l in cara.loops]
            area = sum(
                pts[i].x * pts[(i + 1) % len(pts)].y - pts[(i + 1) % len(pts)].x * pts[i].y
                for i in range(len(pts))
            )
            if area < 0.0:
                invertidos += 1
        assert invertidos == 0, f"Quedaron {invertidos} caras con UV invertida"

        bm.to_mesh(objeto.data)
    finally:
        bm.free()

    objeto.data.update()
    despues = _huellas_ajenas(NOMBRE_MOUSE)
    assert antes == despues, "Se modificó un objeto distinto de mouse-col"

    # Huella de las UV resultantes para confirmar idempotencia.
    uv_layer = objeto.data.uv_layers.active.data
    huella_uv = hashlib.sha256(
        json.dumps([(round(d.uv.x, 5), round(d.uv.y, 5)) for d in uv_layer]).encode()
    ).hexdigest()
    return {
        "objeto": NOMBRE_MOUSE,
        "loops_alineados": ajustados,
        "huella_uv": huella_uv,
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
