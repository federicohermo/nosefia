"""Agrega bisel no destructivo con normales pesadas a computadora, caja, lector y router.

    blender --factory-startup --background --python-exit-code 1 \
        --python .claude/scripts/blender/biselar_puesto.py -- [--objetivo local|router|todos] \
        [--aplicar]

Sin `--aplicar`, guarda copias de prueba en `reports/` sin tocar los `.blend` del repo.
Con `--aplicar`, guarda `assets/models/SEPT_JUEGOS_PROTOTIPO.blend` y
`assets/source/puestos/router.blend` en su lugar.

## Por qué

La computadora del mostrador, la caja registradora, el lector de productos y el router son objetos
de superficies duras que el jugador opera de frente. Sus aristas de 90 grados cortaban en filo vivo.

## Qué cambia

- En `SEPT_JUEGOS_PROTOTIPO.blend`: `base compu-col`, `monitor pantalla-col`,
  `monitor soporte-col`, `teclado-col`, `mouse-col`, `cajaregistradora-col` y
  `lector de productos-col`.
- En `assets/source/puestos/router.blend`: `router-col`, `luces_botones-col` y `powerrouter_col`.
  Se excluyen las antenas (aristas de 0,5 mm que colapsan) y las patas ocultas debajo del chasis.

En las dos hojas con escala no uniforme (`teclado-col` y `luces_botones-col`), la escala local se
hornea a los vértices para que el bisel conserve el mismo ancho en los tres ejes sin mover la
posición en el mundo. El resto conserva su escala intacta y compensa el ancho de bisel por la
escala de mundo. Es idempotente: una segunda corrida no reescribe nada.
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
from mathutils import Matrix  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))

from lib.bisel_de_puesto import (  # noqa: E402
    MODO_DE_NORMALES,
    NOMBRE_BISEL,
    NOMBRE_NORMALES,
    NOMBRE_TRIANGULOS,
    PESO_DE_NORMALES,
    PIEZAS_DEL_LOCAL,
    PIEZAS_DEL_ROUTER,
    PiezaDeBisel,
    ancho_local,
    peso_de_arista,
    pila_coincide,
    validar_pieza,
)
from lib.consola import configurar  # noqa: E402

FUENTE_LOCAL = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
FUENTE_ROUTER = RAIZ / "assets/source/puestos/router.blend"
DESTINO_LOCAL = RAIZ / "reports/bisel-puesto-local.blend"
DESTINO_ROUTER = RAIZ / "reports/bisel-puesto-router.blend"
CAPA_PESO_BISEL = "bevel_weight_edge"
TOLERANCIA_FLOTANTE = 1e-5
TOLERANCIA_ESCALA = 1e-4


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


def _escala_local_unitaria(objeto) -> bool:
    return all(math.isclose(c, 1.0, abs_tol=TOLERANCIA_ESCALA) for c in objeto.scale)


def _hornear_escala_local(objeto) -> None:
    if _escala_local_unitaria(objeto):
        return
    sx, sy, sz = objeto.scale
    matriz_escala = Matrix.Diagonal((sx, sy, sz, 1.0))
    bm = bmesh.new()
    try:
        bm.from_mesh(objeto.data)
        bmesh.ops.transform(bm, matrix=matriz_escala, verts=bm.verts)
        if sx * sy * sz < 0.0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.normal_update()
        bm.to_mesh(objeto.data)
    finally:
        bm.free()
    objeto.scale = (1.0, 1.0, 1.0)
    objeto.data.update()
    bpy.context.view_layer.update()


def _escala_mundo_uniforme(objeto) -> float:
    bpy.context.view_layer.update()
    sx, sy, sz = (abs(c) for c in objeto.matrix_world.to_scale())
    maximo = max(sx, sy, sz)
    minimo = min(sx, sy, sz)
    if maximo <= 1e-6 or (maximo - minimo) / maximo > 0.02:
        raise ValueError(
            f"{objeto.name} tiene escala de mundo no uniforme ({sx:.4f}, {sy:.4f}, {sz:.4f})"
        )
    return (sx + sy + sz) / 3.0


def _peso_esperado(arista, pieza: PiezaDeBisel) -> float:
    if len(arista.link_faces) != 2:
        return 0.0
    angulo = math.degrees(arista.calc_face_angle(0.0))
    return peso_de_arista(angulo, pieza.angulo_minimo_grados)


def _malla_coincide(objeto, pieza: PiezaDeBisel) -> tuple[bool, int]:
    if pieza.aplicar_escala and not _escala_local_unitaria(objeto):
        return False, 0
    bm = bmesh.new()
    try:
        bm.from_mesh(objeto.data)
        pesos = bm.edges.layers.float.get(CAPA_PESO_BISEL)
        aristas_biseladas = 0
        coincide = pesos is not None
        if coincide and not all(cara.smooth for cara in bm.faces):
            coincide = False
        for arista in bm.edges:
            esperado = _peso_esperado(arista, pieza)
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


def _modificadores_coinciden(objeto, pieza: PiezaDeBisel, ancho_en_local: float) -> bool:
    actual = [(m.name, m.type) for m in objeto.modifiers]
    if not pila_coincide(actual):
        return False
    bisel = objeto.modifiers[NOMBRE_BISEL]
    triangulos = objeto.modifiers[NOMBRE_TRIANGULOS]
    normales = objeto.modifiers[NOMBRE_NORMALES]
    return (
        math.isclose(bisel.width, ancho_en_local, rel_tol=1e-4, abs_tol=1e-6)
        and bisel.offset_type == "OFFSET"
        and bisel.segments == pieza.segmentos
        and math.isclose(bisel.profile, pieza.perfil, rel_tol=1e-5, abs_tol=1e-7)
        and bisel.limit_method == "WEIGHT"
        and bisel.use_clamp_overlap is True
        and bisel.harden_normals is False
        and triangulos.quad_method == "SHORTEST_DIAGONAL"
        and triangulos.keep_custom_normals is True
        and normales.mode == MODO_DE_NORMALES
        and normales.weight == PESO_DE_NORMALES
        and normales.keep_sharp is True
    )


def _escribir_malla(objeto, pieza: PiezaDeBisel) -> int:
    if pieza.aplicar_escala:
        _hornear_escala_local(objeto)
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
            peso = _peso_esperado(arista, pieza)
            arista[pesos] = peso
            if peso > 0.0:
                aristas_biseladas += 1
        bm.to_mesh(objeto.data)
        objeto.data.update()
        return aristas_biseladas
    finally:
        bm.free()


def _configurar_modificadores(objeto, pieza: PiezaDeBisel, ancho_en_local: float) -> None:
    objeto.modifiers.clear()
    bisel = objeto.modifiers.new(NOMBRE_BISEL, "BEVEL")
    bisel.width = ancho_en_local
    bisel.offset_type = "OFFSET"
    bisel.segments = pieza.segmentos
    bisel.profile = pieza.perfil
    bisel.limit_method = "WEIGHT"
    bisel.use_clamp_overlap = True
    bisel.harden_normals = False

    triangulos = objeto.modifiers.new(NOMBRE_TRIANGULOS, "TRIANGULATE")
    triangulos.quad_method = "SHORTEST_DIAGONAL"
    triangulos.keep_custom_normals = True
    triangulos.show_in_editmode = False

    normales = objeto.modifiers.new(NOMBRE_NORMALES, "WEIGHTED_NORMAL")
    normales.mode = MODO_DE_NORMALES
    normales.weight = PESO_DE_NORMALES
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


def aplicar_lote(piezas: tuple[PiezaDeBisel, ...]) -> dict:
    for pieza in piezas:
        validar_pieza(pieza)
    objetos = []
    for pieza in piezas:
        objeto = bpy.data.objects.get(pieza.nombre)
        if objeto is None or objeto.type != "MESH":
            raise SystemExit(f"falta el objeto de malla {pieza.nombre}")
        objetos.append((pieza, objeto))

    excluidos = {pieza.nombre for pieza in piezas}
    antes = _huellas_ajenas(excluidos)

    resumen: list[dict] = []
    for pieza, objeto in objetos:
        malla_ok, aristas_biseladas = _malla_coincide(objeto, pieza)
        if malla_ok:
            escala_mundo = _escala_mundo_uniforme(objeto)
            ancho_en_local = ancho_local(pieza.ancho_en_metros, escala_mundo)
            ya_biselado = _modificadores_coinciden(objeto, pieza, ancho_en_local)
        else:
            ya_biselado = False
        if not ya_biselado:
            aristas_biseladas = _escribir_malla(objeto, pieza)
            escala_mundo = _escala_mundo_uniforme(objeto)
            ancho_en_local = ancho_local(pieza.ancho_en_metros, escala_mundo)
            _configurar_modificadores(objeto, pieza, ancho_en_local)
        triangulos, caras_area_cero = _evaluar(objeto)
        assert (
            caras_area_cero == 0
        ), f"Quedaron {caras_area_cero} caras con área nula en {objeto.name}"
        resumen.append(
            {
                "objeto": objeto.name,
                "ya_biselado": ya_biselado,
                "escala_mundo": round(escala_mundo, 5),
                "ancho_mm": round(pieza.ancho_en_metros * 1000.0, 2),
                "aristas_biseladas": aristas_biseladas,
                "triangulos": triangulos,
                "caras_area_cero": caras_area_cero,
            }
        )

    despues = _huellas_ajenas(excluidos)
    assert antes == despues, "Se modificó otro objeto del .blend"
    return {"archivo": bpy.data.filepath, "objetos": resumen}


def procesar(fuente: Path, destino: Path, piezas: tuple[PiezaDeBisel, ...], aplicar: bool) -> dict:
    bpy.ops.wm.open_mainfile(filepath=str(fuente), load_ui=False)
    resultado = aplicar_lote(piezas)
    salida = fuente if aplicar else destino
    salida.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(salida), check_existing=False)
    return resultado


def main() -> None:
    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--objetivo", choices=("local", "router", "todos"), default="todos")
    parser.add_argument("--aplicar", action="store_true")
    opciones = parser.parse_args(argumentos)

    salidas = []
    if opciones.objetivo in ("local", "todos"):
        salidas.append(procesar(FUENTE_LOCAL, DESTINO_LOCAL, PIEZAS_DEL_LOCAL, opciones.aplicar))
    if opciones.objetivo in ("router", "todos"):
        salidas.append(procesar(FUENTE_ROUTER, DESTINO_ROUTER, PIEZAS_DEL_ROUTER, opciones.aplicar))
    print(json.dumps(salidas, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
