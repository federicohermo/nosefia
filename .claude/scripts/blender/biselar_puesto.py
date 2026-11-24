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
    ANCHO_BISEL_BASE_MOUSE,
    CORTE_CHAIKIN_MOUSE,
    CURVATURA_HOMBRO_MOUSE,
    LADOS_BASE_LECTOR,
    LADOS_CONTORNO_MOUSE,
    MODO_DE_NORMALES,
    NOMBRE_BISEL,
    NOMBRE_MOUSE,
    NOMBRE_NORMALES,
    NOMBRE_TRIANGULOS,
    PESO_DE_NORMALES,
    PIEZAS_DEL_LOCAL,
    PIEZAS_DEL_ROUTER,
    PIEZAS_SUAVIZADAS_DEL_ROUTER,
    PiezaDeBisel,
    PiezaSuavizada,
    SEGMENTOS_BISEL_BASE_MOUSE,
    ancho_local,
    anillos_circulares,
    peso_de_arista,
    pila_coincide,
    pila_suavizada_esperada,
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


def _peso_esperado(arista, pieza: PiezaDeBisel, escala_mundo: float) -> float:
    if len(arista.link_faces) != 2:
        return 0.0
    largo_mundo = arista.calc_length() * escala_mundo
    if pieza.longitud_minima_arista_metros > 0.0 and largo_mundo < pieza.longitud_minima_arista_metros:
        return 0.0
    if pieza.excluir_adyacentes_menores_metros > 0.0:
        for vertice in arista.verts:
            for vecina in vertice.link_edges:
                if (
                    vecina is not arista
                    and vecina.calc_length() * escala_mundo < pieza.excluir_adyacentes_menores_metros
                ):
                    return 0.0
    angulo = math.degrees(arista.calc_face_angle(0.0))
    return peso_de_arista(angulo, pieza.angulo_minimo_grados)


def _tiene_duplicados(bm, distancia_local: float) -> bool:
    if distancia_local <= 0.0 or len(bm.verts) < 2:
        return False
    copia = bm.copy()
    try:
        antes = len(copia.verts)
        bmesh.ops.remove_doubles(copia, verts=copia.verts, dist=distancia_local)
        return len(copia.verts) < antes
    finally:
        copia.free()


def _componentes_conexas(bm) -> list[set]:
    vistas: set = set()
    grupos: list[set] = []
    for inicio in bm.verts:
        if inicio in vistas:
            continue
        pendientes = [inicio]
        grupo: set = set()
        while pendientes:
            actual = pendientes.pop()
            if actual in grupo:
                continue
            grupo.add(actual)
            vistas.add(actual)
            for arista in actual.link_edges:
                pendientes.append(arista.other_vert(actual))
        grupos.append(grupo)
    return grupos


def _componente_base_lector(bm) -> tuple[set, list[tuple[float, float]], tuple[float, float]] | None:
    """Localiza el pedestal circular del lector y extrae sus estaciones `(z, radio)` y centro XY."""
    for grupo in _componentes_conexas(bm):
        por_z: dict[float, list] = {}
        for v in grupo:
            por_z.setdefault(round(v.co.z, 3), []).append(v)
        if len(por_z) != 4:
            continue
        cantidades = {len(vs) for vs in por_z.values()}
        if len(cantidades) != 1:
            continue
        cantidad = next(iter(cantidades))
        if cantidad < 8:
            continue
        cx = sum(v.co.x for v in grupo) / len(grupo)
        cy = sum(v.co.y for v in grupo) / len(grupo)
        estaciones: list[tuple[float, float]] = []
        es_circular = True
        for _, vs in sorted(por_z.items()):
            z_medio = sum(v.co.z for v in vs) / len(vs)
            radios = [math.hypot(v.co.x - cx, v.co.y - cy) for v in vs]
            if max(radios) - min(radios) > 0.01 or min(radios) <= 0.01:
                es_circular = False
                break
            estaciones.append((z_medio, sum(radios) / len(radios)))
        if es_circular:
            return grupo, estaciones, (cx, cy)
    return None


def _base_lector_pendiente(objeto) -> bool:
    if objeto.name != "lector de productos-col":
        return False
    bm = bmesh.new()
    try:
        bm.from_mesh(objeto.data)
        hallada = _componente_base_lector(bm)
        if hallada is None:
            return False
        grupo, estaciones, _ = hallada
        return len(grupo) // len(estaciones) < LADOS_BASE_LECTOR
    finally:
        bm.free()


def _redondear_base_lector(objeto) -> bool:
    """Reemplaza el pedestal de 12 lados del lector por uno circular de `LADOS_BASE_LECTOR`."""
    if objeto.name != "lector de productos-col":
        return False
    bm = bmesh.new()
    try:
        bm.from_mesh(objeto.data)
        hallada = _componente_base_lector(bm)
        if hallada is None:
            return False
        grupo, estaciones, centro_xy = hallada
        if len(grupo) // len(estaciones) >= LADOS_BASE_LECTOR:
            return False
        uv = bm.loops.layers.uv.verify()
        bmesh.ops.delete(bm, geom=list(grupo), context="VERTS")
        coordenadas = anillos_circulares(centro_xy, estaciones, LADOS_BASE_LECTOR)
        anillos = [[bm.verts.new(p) for p in anillo] for anillo in coordenadas]
        nuevas_caras = []
        # Acumular distancia sobre el perfil para UV cilíndrica uniforme sin estiramiento.
        distancias = [0.0]
        for i in range(1, len(estaciones)):
            dz = estaciones[i][0] - estaciones[i - 1][0]
            dr = estaciones[i][1] - estaciones[i - 1][1]
            distancias.append(distancias[-1] + math.hypot(dz, dr))
        perimetro_ref = math.tau * max(r for _, r in estaciones)
        escala_uv = 0.65
        for nivel in range(len(anillos) - 1):
            a0, a1 = anillos[nivel], anillos[nivel + 1]
            v0, v1 = distancias[nivel] * escala_uv, distancias[nivel + 1] * escala_uv
            for i in range(LADOS_BASE_LECTOR):
                j = (i + 1) % LADOS_BASE_LECTOR
                cara = bm.faces.new((a0[i], a0[j], a1[j], a1[i]))
                cara.material_index = 0
                cara.smooth = True
                u0 = (i / LADOS_BASE_LECTOR) * perimetro_ref * escala_uv
                u1 = ((i + 1) / LADOS_BASE_LECTOR) * perimetro_ref * escala_uv
                for lazo, coords in zip(cara.loops, ((u0, v0), (u1, v0), (u1, v1), (u0, v1))):
                    lazo[uv].uv = coords
                nuevas_caras.append(cara)
        cx, cy = centro_xy
        for anillo, invertir in ((anillos[0], True), (anillos[-1], False)):
            verts_tapa = list(reversed(anillo)) if invertir else anillo
            tapa = bm.faces.new(verts_tapa)
            tapa.material_index = 0
            tapa.smooth = True
            for lazo in tapa.loops:
                lazo[uv].uv = (
                    (lazo.vert.co.x - cx) * escala_uv,
                    (lazo.vert.co.y - cy) * escala_uv,
                )
            nuevas_caras.append(tapa)
        bmesh.ops.recalc_face_normals(bm, faces=nuevas_caras)
        bm.to_mesh(objeto.data)
        objeto.data.update()
        return True
    finally:
        bm.free()


def _malla_coincide(objeto, pieza: PiezaDeBisel) -> tuple[bool, int]:
    if pieza.aplicar_escala and not _escala_local_unitaria(objeto):
        return False, 0
    if _base_lector_pendiente(objeto):
        return False, 0
    escala_mundo = _escala_mundo_uniforme(objeto)
    bm = bmesh.new()
    try:
        bm.from_mesh(objeto.data)
        if pieza.soldar_vertices_metros > 0.0 and _tiene_duplicados(
            bm, pieza.soldar_vertices_metros / escala_mundo
        ):
            return False, 0
        pesos = bm.edges.layers.float.get(CAPA_PESO_BISEL)
        aristas_biseladas = 0
        coincide = pesos is not None
        if coincide and not all(cara.smooth for cara in bm.faces):
            coincide = False
        for arista in bm.edges:
            esperado = _peso_esperado(arista, pieza, escala_mundo)
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
    _redondear_base_lector(objeto)
    escala_mundo = _escala_mundo_uniforme(objeto)
    bm = bmesh.new()
    try:
        bm.from_mesh(objeto.data)
        if pieza.soldar_vertices_metros > 0.0:
            bmesh.ops.remove_doubles(
                bm, verts=bm.verts, dist=pieza.soldar_vertices_metros / escala_mundo
            )
            bm.normal_update()
        pesos = bm.edges.layers.float.get(CAPA_PESO_BISEL)
        if pesos is None:
            pesos = bm.edges.layers.float.new(CAPA_PESO_BISEL)
        for cara in bm.faces:
            cara.smooth = True
        aristas_biseladas = 0
        for arista in bm.edges:
            arista.smooth = True
            peso = _peso_esperado(arista, pieza, escala_mundo)
            arista[pesos] = peso
            if peso > 0.0:
                aristas_biseladas += 1
        bm.to_mesh(objeto.data)
        objeto.data.update()
        return aristas_biseladas
    finally:
        bm.free()


def _suavizado_coincide(objeto, pieza: PiezaSuavizada) -> bool:
    actual = [(m.name, m.type) for m in objeto.modifiers]
    if tuple(actual) != pila_suavizada_esperada():
        return False
    triangulos = objeto.modifiers[NOMBRE_TRIANGULOS]
    normales = objeto.modifiers[NOMBRE_NORMALES]
    if not (
        triangulos.quad_method == "SHORTEST_DIAGONAL"
        and triangulos.keep_custom_normals is True
        and normales.mode == MODO_DE_NORMALES
        and normales.weight == PESO_DE_NORMALES
        and normales.keep_sharp is True
    ):
        return False
    escala_mundo = _escala_mundo_uniforme(objeto)
    bm = bmesh.new()
    try:
        bm.from_mesh(objeto.data)
        if _tiene_duplicados(bm, pieza.soldar_vertices_metros / escala_mundo):
            return False
        if not all(cara.smooth for cara in bm.faces):
            return False
        for arista in bm.edges:
            if len(arista.link_faces) != 2:
                continue
            esperado_suave = math.degrees(arista.calc_face_angle(0.0)) < pieza.angulo_filo_grados
            if arista.smooth != esperado_suave:
                return False
        return True
    finally:
        bm.free()


def _aplicar_suavizado(objeto, pieza: PiezaSuavizada) -> None:
    escala_mundo = _escala_mundo_uniforme(objeto)
    bm = bmesh.new()
    try:
        bm.from_mesh(objeto.data)
        if pieza.soldar_vertices_metros > 0.0:
            bmesh.ops.remove_doubles(
                bm, verts=bm.verts, dist=pieza.soldar_vertices_metros / escala_mundo
            )
            bm.normal_update()
        for cara in bm.faces:
            cara.smooth = True
        for arista in bm.edges:
            if len(arista.link_faces) != 2:
                arista.smooth = False
            else:
                arista.smooth = (
                    math.degrees(arista.calc_face_angle(0.0)) < pieza.angulo_filo_grados
                )
        bm.to_mesh(objeto.data)
        objeto.data.update()
    finally:
        bm.free()
    objeto.modifiers.clear()
    triangulos = objeto.modifiers.new(NOMBRE_TRIANGULOS, "TRIANGULATE")
    triangulos.quad_method = "SHORTEST_DIAGONAL"
    triangulos.keep_custom_normals = True
    triangulos.show_in_editmode = False
    normales = objeto.modifiers.new(NOMBRE_NORMALES, "WEIGHTED_NORMAL")
    normales.mode = MODO_DE_NORMALES
    normales.weight = PESO_DE_NORMALES
    normales.keep_sharp = True


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


def _chaikin_anillo(puntos: list, t: float = CORTE_CHAIKIN_MOUSE) -> list:
    n = len(puntos)
    salida = []
    for i in range(n):
        a, b = puntos[i], puntos[(i + 1) % n]
        salida.append(a.lerp(b, t))
        salida.append(a.lerp(b, 1.0 - t))
    return salida


def _pieza_base_mouse() -> PiezaDeBisel:
    return PiezaDeBisel(
        NOMBRE_MOUSE,
        ANCHO_BISEL_BASE_MOUSE,
        segmentos=SEGMENTOS_BISEL_BASE_MOUSE,
    )


def _mouse_coincide(objeto) -> bool:
    escala_mundo = _escala_mundo_uniforme(objeto)
    pieza = _pieza_base_mouse()
    ancho_en_local = ancho_local(pieza.ancho_en_metros, escala_mundo)
    if not _modificadores_coinciden(objeto, pieza, ancho_en_local):
        return False
    bm = bmesh.new()
    try:
        bm.from_mesh(objeto.data)
        if len(bm.verts) < LADOS_CONTORNO_MOUSE * 5:
            return False
        pesos = bm.edges.layers.float.get(CAPA_PESO_BISEL)
        if pesos is None or not all(cara.smooth for cara in bm.faces):
            return False
        z0 = min(v.co.z for v in bm.verts)
        for arista in bm.edges:
            if not arista.smooth:
                return False
            es_base = all(abs(v.co.z - z0) < 1e-4 for v in arista.verts)
            esperado = 1.0 if es_base else 0.0
            if not math.isclose(arista[pesos], esperado, abs_tol=TOLERANCIA_FLOTANTE):
                return False
        return True
    finally:
        bm.free()


def _redondear_mouse(objeto) -> None:
    """Corta las 8 esquinas de `mouse-col` a 16 lados, curva el hombro y bisela el aro inferior."""
    bm = bmesh.new()
    necesita_reconstruir = False
    try:
        bm.from_mesh(objeto.data)
        necesita_reconstruir = len(bm.verts) < LADOS_CONTORNO_MOUSE * 5
        if necesita_reconstruir:
            bm.normal_update()
            uv_in = bm.loops.layers.uv.active
            tapa_inf = next(f for f in bm.faces if len(f.verts) == 8 and f.normal.z < -0.5)
            tapa_sup = next(f for f in bm.faces if len(f.verts) == 8 and f.normal.z > 0.5)

            anillos = [[lazo.vert for lazo in tapa_inf.loops]]
            vistos = set(anillos[0])
            for _ in range(3):
                siguiente = [
                    next(e.other_vert(v) for e in v.link_edges if e.other_vert(v) not in vistos)
                    for v in anillos[-1]
                ]
                anillos.append(siguiente)
                vistos.update(siguiente)

            coords8 = [[v.co.copy() for v in anillo] for anillo in anillos]
            uv_inf8 = [lazo[uv_in].uv.copy() for lazo in tapa_inf.loops]
            mapa_sup = {lazo.vert: lazo[uv_in].uv.copy() for lazo in tapa_sup.loops}
            uv_sup8 = [mapa_sup[v] for v in anillos[3]]

            uv_bandas = []
            for banda in range(3):
                a, b = anillos[banda], anillos[banda + 1]
                quads = []
                for i in range(8):
                    j = (i + 1) % 8
                    cara = next(
                        iter(
                            set(a[i].link_faces)
                            & set(a[j].link_faces)
                            & set(b[i].link_faces)
                            & set(b[j].link_faces)
                        )
                    )
                    mapa = {lazo.vert: lazo[uv_in].uv.copy() for lazo in cara.loops}
                    quads.append((mapa[a[i]], mapa[a[j]], mapa[b[j]], mapa[b[i]]))
                uv_bandas.append(quads)
    finally:
        bm.free()

    if necesita_reconstruir:
        t = CORTE_CHAIKIN_MOUSE
        coords16 = [_chaikin_anillo(anillo, t) for anillo in coords8]
        hombro = []
        for k in range(LADOS_CONTORNO_MOUSE):
            r1, r2, r3 = coords16[1][k], coords16[2][k], coords16[3][k]
            medio = r2.lerp(r3, 0.5)
            d_in = (r2 - r1).normalized()
            d_out = (r3 - r2).normalized()
            empuje = d_in - d_out
            if empuje.length > 1e-6:
                medio = medio + empuje.normalized() * ((r3 - r2).length * CURVATURA_HOMBRO_MOUSE)
            hombro.append(medio)
        todos_anillos = [coords16[0], coords16[1], coords16[2], hombro, coords16[3]]

        bm2 = bmesh.new()
        try:
            uv2 = bm2.loops.layers.uv.new("UVMap")
            v_anillos = [[bm2.verts.new(p) for p in anillo] for anillo in todos_anillos]

            def agregar_banda(va, vb, quads_uv, v0: float = 0.0, v1: float = 1.0) -> None:
                for i in range(8):
                    ua0, ua1, ub1, ub0 = quads_uv[i]
                    na0, na1, nb1, nb0 = quads_uv[(i + 1) % 8]
                    la0, la1 = ua0.lerp(ub0, v0), ua1.lerp(ub1, v0)
                    lb0, lb1 = ua0.lerp(ub0, v1), ua1.lerp(ub1, v1)
                    nla0, nla1 = na0.lerp(nb0, v0), na1.lerp(nb1, v0)
                    nlb0, nlb1 = na0.lerp(nb0, v1), na1.lerp(nb1, v1)
                    k0, k1, k2 = 2 * i, 2 * i + 1, (2 * i + 2) % LADOS_CONTORNO_MOUSE

                    cara_p = bm2.faces.new((va[k0], vb[k0], vb[k1], va[k1]))
                    for lazo, u in zip(
                        cara_p.loops,
                        (
                            la0.lerp(la1, t),
                            lb0.lerp(lb1, t),
                            lb0.lerp(lb1, 1.0 - t),
                            la0.lerp(la1, 1.0 - t),
                        ),
                    ):
                        lazo[uv2].uv = u

                    costura = (la1 - nla0).length > 1e-3 or (lb1 - nlb0).length > 1e-3
                    cara_e = bm2.faces.new((va[k1], vb[k1], vb[k2], va[k2]))
                    uvs_e = (
                        (la0.lerp(la1, 1.0 - t), lb0.lerp(lb1, 1.0 - t), lb1, la1)
                        if costura
                        else (
                            la0.lerp(la1, 1.0 - t),
                            lb0.lerp(lb1, 1.0 - t),
                            nlb0.lerp(nlb1, t),
                            nla0.lerp(nla1, t),
                        )
                    )
                    for lazo, u in zip(cara_e.loops, uvs_e):
                        lazo[uv2].uv = u

            agregar_banda(v_anillos[0], v_anillos[1], uv_bandas[0])
            agregar_banda(v_anillos[1], v_anillos[2], uv_bandas[1])
            agregar_banda(v_anillos[2], v_anillos[3], uv_bandas[2], 0.0, 0.5)
            agregar_banda(v_anillos[3], v_anillos[4], uv_bandas[2], 0.5, 1.0)

            fb = bm2.faces.new(v_anillos[0])
            for lazo, u in zip(fb.loops, _chaikin_anillo(uv_inf8, t)):
                lazo[uv2].uv = u
            ft = bm2.faces.new(list(reversed(v_anillos[-1])))
            for lazo, u in zip(ft.loops, reversed(_chaikin_anillo(uv_sup8, t))):
                lazo[uv2].uv = u

            bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces)
            bm2.to_mesh(objeto.data)
            objeto.data.update()
        finally:
            bm2.free()

    bm3 = bmesh.new()
    try:
        bm3.from_mesh(objeto.data)
        pesos = bm3.edges.layers.float.get(CAPA_PESO_BISEL)
        if pesos is None:
            pesos = bm3.edges.layers.float.new(CAPA_PESO_BISEL)
        z0 = min(v.co.z for v in bm3.verts)
        for cara in bm3.faces:
            cara.smooth = True
        for arista in bm3.edges:
            arista.smooth = True
            es_base = all(abs(v.co.z - z0) < 1e-4 for v in arista.verts)
            arista[pesos] = 1.0 if es_base else 0.0
        bm3.to_mesh(objeto.data)
        objeto.data.update()
    finally:
        bm3.free()

    pieza = _pieza_base_mouse()
    escala_mundo = _escala_mundo_uniforme(objeto)
    _configurar_modificadores(objeto, pieza, ancho_local(pieza.ancho_en_metros, escala_mundo))


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


def aplicar_lote(
    piezas: tuple[PiezaDeBisel, ...],
    suavizadas: tuple[PiezaSuavizada, ...] = (),
    redondear_mouse: bool = False,
) -> dict:
    for pieza in piezas:
        validar_pieza(pieza)
    objetos = []
    for pieza in piezas:
        objeto = bpy.data.objects.get(pieza.nombre)
        if objeto is None or objeto.type != "MESH":
            raise SystemExit(f"falta el objeto de malla {pieza.nombre}")
        objetos.append((pieza, objeto))
    objetos_suavizados = []
    for pieza_s in suavizadas:
        objeto = bpy.data.objects.get(pieza_s.nombre)
        if objeto is None or objeto.type != "MESH":
            raise SystemExit(f"falta el objeto de malla {pieza_s.nombre}")
        objetos_suavizados.append((pieza_s, objeto))
    objeto_mouse = None
    if redondear_mouse:
        objeto_mouse = bpy.data.objects.get(NOMBRE_MOUSE)
        if objeto_mouse is None or objeto_mouse.type != "MESH":
            raise SystemExit(f"falta el objeto de malla {NOMBRE_MOUSE}")

    excluidos = {pieza.nombre for pieza in piezas} | {p.nombre for p in suavizadas}
    if objeto_mouse is not None:
        excluidos.add(NOMBRE_MOUSE)
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

    for pieza_s, objeto in objetos_suavizados:
        ya_limpio = _suavizado_coincide(objeto, pieza_s)
        if not ya_limpio:
            _aplicar_suavizado(objeto, pieza_s)
        triangulos, caras_area_cero = _evaluar(objeto)
        assert (
            caras_area_cero == 0
        ), f"Quedaron {caras_area_cero} caras con área nula en {objeto.name}"
        resumen.append(
            {
                "objeto": objeto.name,
                "ya_biselado": ya_limpio,
                "triangulos": triangulos,
                "caras_area_cero": caras_area_cero,
            }
        )

    if objeto_mouse is not None:
        ya_mouse = _mouse_coincide(objeto_mouse)
        if not ya_mouse:
            _redondear_mouse(objeto_mouse)
        triangulos, caras_area_cero = _evaluar(objeto_mouse)
        assert (
            caras_area_cero == 0
        ), f"Quedaron {caras_area_cero} caras con área nula en {objeto_mouse.name}"
        resumen.append(
            {
                "objeto": objeto_mouse.name,
                "ya_biselado": ya_mouse,
                "triangulos": triangulos,
                "caras_area_cero": caras_area_cero,
            }
        )

    despues = _huellas_ajenas(excluidos)
    assert antes == despues, "Se modificó otro objeto del .blend"
    return {"archivo": bpy.data.filepath, "objetos": resumen}


def procesar(
    fuente: Path,
    destino: Path,
    piezas: tuple[PiezaDeBisel, ...],
    aplicar: bool,
    suavizadas: tuple[PiezaSuavizada, ...] = (),
    redondear_mouse: bool = False,
) -> dict:
    bpy.ops.wm.open_mainfile(filepath=str(fuente), load_ui=False)
    resultado = aplicar_lote(piezas, suavizadas, redondear_mouse)
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
        salidas.append(
            procesar(
                FUENTE_LOCAL,
                DESTINO_LOCAL,
                PIEZAS_DEL_LOCAL,
                opciones.aplicar,
                redondear_mouse=True,
            )
        )
    if opciones.objetivo in ("router", "todos"):
        salidas.append(
            procesar(
                FUENTE_ROUTER,
                DESTINO_ROUTER,
                PIEZAS_DEL_ROUTER,
                opciones.aplicar,
                PIEZAS_SUAVIZADAS_DEL_ROUTER,
            )
        )
    print(json.dumps(salidas, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
