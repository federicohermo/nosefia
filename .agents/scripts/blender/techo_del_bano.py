"""Integra el cielorraso del baño en `almacen-col` a Z = 3,14 m y quita `bano_cielorraso-convcol`.

    blender --factory-startup --background --python-exit-code 1 \
        --python .claude/scripts/blender/techo_del_bano.py -- [--aplicar]

Sin `--aplicar`, guarda una copia en `reports/techo-del-bano.blend`.
Con `--aplicar`, guarda `assets/models/SEPT_JUEGOS_PROTOTIPO.blend` en su lugar.

## Por qué

Antes el baño tenía un techo real en `almacen-col` a `Z = 3,472 m` y una caja separada
`bano_cielorraso-convcol` a `Z = 3,14..3,22 m` cuyas caras laterales quedaban coplanares con las
paredes del baño. Eso dejaba una cavidad oscura arriba y sangraba una banda de sombra/oclusión en
el encuentro de las cuatro paredes con el cielorraso.

## Qué cambia

- Baja los 6 vértices de la cara `bano_cielorraso_blanco` de `almacen-col` hasta `Z = 3,140 m` y
  ajusta proporcionalmente la coordenada V de las paredes del baño (`bano_pared_clara`) para que
  la escala de textura no se deforme.
- Elimina `bano_cielorraso-convcol` y su malla huérfana.
- Mantiene intactas las 9 luminarias (`Z = 3,101..3,139 m`) y el resto de los objetos del `.blend`.
- Es idempotente: una segunda corrida no cambia nada.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]
from mathutils import Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
DESTINO = RAIZ / "reports/techo-del-bano.blend"
EDIFICIO = "almacen-col"
PLACA_SEPARADA = "bano_cielorraso-convcol"
MATERIAL_TECHO = "bano_cielorraso_blanco"
ALTURA_OBJETIVO_MUNDO = 3.140
TOLERANCIA_Z = 5e-4


def _huellas_ajenas(excluir: set[str]) -> dict[str, str]:
    resultado: dict[str, str] = {}
    for o in bpy.data.objects:
        if o.type != "MESH" or o.name in excluir:
            continue
        datos = {
            "vertices": [tuple(round(c, 6) for c in v.co) for v in o.data.vertices],
            "caras": [tuple(p.vertices) for p in o.data.polygons],
            "matriz": [tuple(round(c, 6) for c in fila) for fila in o.matrix_world],
        }
        resultado[o.name] = hashlib.sha256(json.dumps(datos).encode()).hexdigest()
    return resultado


def _indice_material(objeto, nombre: str) -> int:
    for indice, ranura in enumerate(objeto.material_slots):
        if ranura.material and ranura.material.name == nombre:
            return indice
    raise SystemExit(f"falta el material {nombre} en {objeto.name}")


def aplicar_techo_del_bano() -> dict:
    almacen = bpy.data.objects.get(EDIFICIO)
    if almacen is None or almacen.type != "MESH":
        raise SystemExit(f"falta el objeto {EDIFICIO}")

    excluir = {EDIFICIO, PLACA_SEPARADA}
    antes = _huellas_ajenas(excluir)

    placa_eliminada = False
    placa = bpy.data.objects.get(PLACA_SEPARADA)
    if placa is not None:
        malla_placa = placa.data
        bpy.data.objects.remove(placa, do_unlink=True)
        if malla_placa is not None and malla_placa.users == 0:
            bpy.data.meshes.remove(malla_placa)
        placa_eliminada = True

    idx_techo = _indice_material(almacen, MATERIAL_TECHO)
    matriz = almacen.matrix_world.copy()
    inversa = matriz.inverted()
    z_local_objetivo = (inversa @ Vector((10.0, -3.0, ALTURA_OBJETIVO_MUNDO))).z

    bm = bmesh.new()
    vertices_movidos = 0
    z_anterior_mundo = ALTURA_OBJETIVO_MUNDO
    try:
        bm.from_mesh(almacen.data)
        bm.normal_update()
        capa_uv = bm.loops.layers.uv.active

        caras_techo = [
            cara
            for cara in bm.faces
            if cara.material_index == idx_techo and cara.normal.z < -0.9
        ]
        if not caras_techo:
            raise SystemExit(f"no se halló cara de {MATERIAL_TECHO} mirando hacia abajo")

        verts_techo = {v for cara in caras_techo for v in cara.verts}
        z_anterior_mundo = max((matriz @ v.co).z for v in verts_techo)

        # Verificar que todos los vértices sólo pertenezcan al techo y a las paredes del baño.
        for v in verts_techo:
            for cara in v.link_faces:
                mat = almacen.material_slots[cara.material_index].material
                if mat is None or mat.name not in (MATERIAL_TECHO, "bano_pared_clara"):
                    raise SystemExit(
                        f"vértice {v.index} compartido con material inesperado {mat.name if mat else None}"
                    )

        ya_en_altura = all(
            math.isclose((matriz @ v.co).z, ALTURA_OBJETIVO_MUNDO, abs_tol=TOLERANCIA_Z)
            for v in verts_techo
        )

        if not ya_en_altura:
            # Calcular dv/dz de cada pared del baño antes de mover los vértices.
            paredes = {
                cara
                for v in verts_techo
                for cara in v.link_faces
                if cara.material_index != idx_techo
            }
            escala_v_por_cara: dict = {}
            if capa_uv is not None:
                for cara in paredes:
                    lazos_bajos = [l for l in cara.loops if l.vert not in verts_techo]
                    lazos_altos = [l for l in cara.loops if l.vert in verts_techo]
                    if lazos_bajos and lazos_altos:
                        l_min = min(lazos_bajos, key=lambda l: (matriz @ l.vert.co).z)
                        l_max = lazos_altos[0]
                        dz = (matriz @ l_max.vert.co).z - (matriz @ l_min.vert.co).z
                        if abs(dz) > 1e-4:
                            escala_v_por_cara[cara] = (l_max[capa_uv].uv.y - l_min[capa_uv].uv.y) / dz

            for v in verts_techo:
                z_viejo_m = (matriz @ v.co).z
                delta_z_m = ALTURA_OBJETIVO_MUNDO - z_viejo_m
                v.co.z = z_local_objetivo
                vertices_movidos += 1
                if capa_uv is not None:
                    for lazo in v.link_loops:
                        dv_dz = escala_v_por_cara.get(lazo.face)
                        if dv_dz is not None:
                            lazo[capa_uv].uv.y += delta_z_m * dv_dz

            bm.normal_update()
            bm.to_mesh(almacen.data)
            almacen.data.update()

        caras_area_cero = sum(1 for cara in bm.faces if cara.calc_area() <= 1e-9)
        assert caras_area_cero == 0, f"quedaron {caras_area_cero} caras con área cero"
    finally:
        bm.free()

    despues = _huellas_ajenas(excluir)
    assert antes == despues, "se modificó otro objeto del .blend"
    return {
        "placa_eliminada": placa_eliminada,
        "vertices_movidos": vertices_movidos,
        "z_anterior": round(z_anterior_mundo, 4),
        "z_nueva": ALTURA_OBJETIVO_MUNDO,
    }


def main() -> None:
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    opciones = parser.parse_args(argumentos)

    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    resultado = aplicar_techo_del_bano()
    salida = FUENTE if opciones.aplicar else DESTINO
    salida.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(salida), check_existing=False)
    print(json.dumps({"archivo": str(salida), **resultado}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
