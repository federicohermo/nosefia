"""Agrega bisel no destructivo con normales pesadas a los tres bidones de limpieza.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/biselar_bidones.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/bisel-de-bidones.blend` y no modifica el `.blend` del repo.
Con `--aplicar`, guarda la fuente canónica en su lugar.

## Por qué

Los quiebres horizontales de los tres bidones de jabón cortaban en arista viva de una sola fila de
vértices. En la luz del depósito ese canto se leía plano y filoso.

## Qué cambia

Sobre `bidón jabon01-col`, `bidón jabon01-col.001` y `bidón jabon01-col.002`:

- Suaviza todas las caras y aristas y escribe la capa `bevel_weight_edge` a partir de 30°.
- Arma la pila `BEVEL` (2 segmentos, 6 mm, perfil 0.5, por peso), `TRIANGULATE` y
  `WEIGHTED_NORMAL` (`FACE_AREA`, peso 100).

No mueve vértices de la malla base ni toca otros objetos del `.blend`. Es idempotente: si la malla
y la pila ya coinciden, no reescribe nada.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import bpy  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))

from lib.bisel_de_bidones import (  # noqa: E402
    PERFIL_DE_BIDONES,
    PerfilDeBisel,
    peso_de_arista,
    pila_coincide,
    validar_perfil,
)
from lib.consola import configurar  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
DESTINO_POR_DEFECTO = RAIZ / "reports/bisel-de-bidones.blend"
CAPA_PESO_BISEL = "bevel_weight_edge"
TOLERANCIA_FLOTANTE = 1e-5


def _huellas_ajenas(excluir: set[str]) -> dict[str, str]:
    resultado: dict[str, str] = {}
    for o in bpy.data.objects:
        if o.type != "MESH" or o.name in excluir:
            continue
        datos = {
            "vertices": [tuple(v.co) for v in o.data.vertices],
            "caras": [tuple(p.vertices) for p in o.data.polygons],
            "matriz": [tuple(f) for f in o.matrix_world],
            "modificadores": [(m.name, m.type) for m in o.modifiers],
        }
        resultado[o.name] = hashlib.sha256(json.dumps(datos).encode()).hexdigest()
    return resultado


def _peso_esperado(arista, perfil: PerfilDeBisel) -> float:
    if len(arista.link_faces) != 2:
        return 0.0
    angulo = math.degrees(arista.calc_face_angle(0.0))
    return peso_de_arista(angulo, perfil.angulo_minimo_grados)


def _malla_coincide(objeto, perfil: PerfilDeBisel) -> tuple[bool, int]:
    bm = bmesh.new()
    try:
        bm.from_mesh(objeto.data)
        pesos = bm.edges.layers.float.get(CAPA_PESO_BISEL)
        aristas_biseladas = 0
        coincide = pesos is not None
        if coincide and not all(cara.smooth for cara in bm.faces):
            coincide = False
        for arista in bm.edges:
            esperado = _peso_esperado(arista, perfil)
            if esperado > 0.0:
                aristas_biseladas += 1
            if not coincide:
                continue
            if not arista.smooth or not math.isclose(
                arista[pesos], esperado, abs_tol=TOLERANCIA_FLOTANTE
            ):
                coincide = False
        return coincide, aristas_biseladas
    finally:
        bm.free()


def _modificadores_coinciden(objeto, perfil: PerfilDeBisel) -> bool:
    actual = [(m.name, m.type) for m in objeto.modifiers]
    if not pila_coincide(actual, perfil):
        return False
    bisel = objeto.modifiers[perfil.nombre_bisel]
    triangulos = objeto.modifiers[perfil.nombre_triangulos]
    normales = objeto.modifiers[perfil.nombre_normales]
    return (
        math.isclose(bisel.width, perfil.ancho_en_metros, rel_tol=1e-5, abs_tol=1e-7)
        and bisel.offset_type == "OFFSET"
        and bisel.segments == perfil.segmentos
        and math.isclose(bisel.profile, perfil.perfil, rel_tol=1e-5, abs_tol=1e-7)
        and bisel.limit_method == "WEIGHT"
        and bisel.use_clamp_overlap is True
        and bisel.harden_normals is False
        and triangulos.quad_method == "SHORTEST_DIAGONAL"
        and triangulos.keep_custom_normals is True
        and normales.mode == perfil.modo_de_normales
        and normales.weight == perfil.peso_de_normales
        and normales.keep_sharp is True
    )


def _escribir_malla(objeto, perfil: PerfilDeBisel) -> int:
    bm = bmesh.new()
    try:
        bm.from_mesh(objeto.data)
        pesos = bm.edges.layers.float.get(CAPA_PESO_BISEL)
        if pesos is None:
            pesos = bm.edges.layers.float.new(CAPA_PESO_BISEL)
        for cara in bm.faces:
            cara.smooth = True
        aristas_biseladas = 0
        for arista in bm.edges:
            arista.smooth = True
            peso = _peso_esperado(arista, perfil)
            arista[pesos] = peso
            if peso > 0.0:
                aristas_biseladas += 1
        bm.to_mesh(objeto.data)
        objeto.data.update()
        return aristas_biseladas
    finally:
        bm.free()


def _configurar_modificadores(objeto, perfil: PerfilDeBisel) -> None:
    objeto.modifiers.clear()
    bisel = objeto.modifiers.new(perfil.nombre_bisel, "BEVEL")
    bisel.width = perfil.ancho_en_metros
    bisel.offset_type = "OFFSET"
    bisel.segments = perfil.segmentos
    bisel.profile = perfil.perfil
    bisel.limit_method = "WEIGHT"
    bisel.use_clamp_overlap = True
    bisel.harden_normals = False

    triangulos = objeto.modifiers.new(perfil.nombre_triangulos, "TRIANGULATE")
    triangulos.quad_method = "SHORTEST_DIAGONAL"
    triangulos.keep_custom_normals = True
    triangulos.show_in_editmode = False

    normales = objeto.modifiers.new(perfil.nombre_normales, "WEIGHTED_NORMAL")
    normales.mode = perfil.modo_de_normales
    normales.weight = perfil.peso_de_normales
    normales.keep_sharp = True


def _evaluar(objeto) -> tuple[int, int]:
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluado = objeto.evaluated_get(depsgraph)
    malla = evaluado.to_mesh()
    try:
        malla.calc_loop_triangles()
        triangulos = len(malla.loop_triangles)
        caras_area_cero = sum(1 for cara in malla.polygons if cara.area <= 1e-9)
        return triangulos, caras_area_cero
    finally:
        evaluado.to_mesh_clear()


def aplicar(perfil: PerfilDeBisel = PERFIL_DE_BIDONES) -> dict:
    validar_perfil(perfil)
    objetos = []
    for nombre in perfil.objetos:
        objeto = bpy.data.objects.get(nombre)
        if objeto is None or objeto.type != "MESH":
            raise SystemExit(f"falta el objeto de malla {nombre}")
        objetos.append(objeto)

    excluidos = set(perfil.objetos)
    antes = _huellas_ajenas(excluidos)

    resumen: list[dict] = []
    for objeto in objetos:
        malla_ok, aristas_biseladas = _malla_coincide(objeto, perfil)
        ya_biselado = malla_ok and _modificadores_coinciden(objeto, perfil)
        if not ya_biselado:
            aristas_biseladas = _escribir_malla(objeto, perfil)
            _configurar_modificadores(objeto, perfil)
        triangulos, caras_area_cero = _evaluar(objeto)
        assert (
            caras_area_cero == 0
        ), f"Quedaron {caras_area_cero} caras con área nula en {objeto.name}"
        resumen.append(
            {
                "objeto": objeto.name,
                "ya_biselado": ya_biselado,
                "aristas_biseladas": aristas_biseladas,
                "triangulos": triangulos,
                "caras_area_cero": caras_area_cero,
            }
        )

    despues = _huellas_ajenas(excluidos)
    assert antes == despues, "Se modificó otro objeto del .blend"
    return {"objetos": resumen}


def main() -> None:
    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    parser.add_argument("--destino", type=Path, default=DESTINO_POR_DEFECTO)
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    resultado = aplicar()
    destino = FUENTE if opciones.aplicar else opciones.destino
    destino.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    print(json.dumps(resultado, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
