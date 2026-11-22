"""Limpia la porcelana pixelada del baño y coloca portarrollos con papel higiénico en ambas cabinas.

    blender --factory-startup --background --python-exit-code 1 \
        --python .claude/scripts/blender/detalles_del_bano.py -- [--aplicar]

Sin `--aplicar`, guarda una copia de prueba en `reports/detalles-del-bano.blend`.
Con `--aplicar`, actualiza `assets/models/SEPT_JUEGOS_PROTOTIPO.blend` en su lugar.

## Por qué

1. `bano_porcelana` y `bano_asiento_marfil` muestreaban un recorte de 6x8 píxeles de
   `porcelana_atlas.png` (comprimido en bloques BC1 de 4x4) con filtro cercano en el asiento y
   la tapa: se leían cuadrados grandes sobre la porcelana. Al desconectar ese atlas y dejar el
   color sólido satinado de cerámica, la superficie queda lisa sin agregar variantes de shader.
2. Ninguna de las dos cabinas tenía portarrollos ni papel higiénico. Se modela un portarrollos
   mural de acero inoxidable (`bano_acero`) con tapa curva, eje, tubo de cartón
   (`bano_carton_rollo`), rollo y hoja colgante (`bano_papel_higienico`) montado sobre la
   mampara izquierda de cada cabina, fuera del barrido de la puerta y al alcance del inodoro.

Es idempotente: correrlo dos veces deja la misma geometría, materiales y transformadas.
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
sys.path.insert(0, str(RAIZ / ".claude/scripts"))

from lib.consola import configurar  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
DESTINO_PRUEBA = RAIZ / "reports/detalles-del-bano.blend"

# Porcelana y asiento: color sólido satinado (sin recorte de `porcelana_atlas.png`).
COLOR_PORCELANA = (0.86, 0.87, 0.85, 1.0)
RUGOSIDAD_PORCELANA = 0.30
COLOR_ASIENTO = (0.80, 0.80, 0.76, 1.0)
RUGOSIDAD_ASIENTO = 0.32

# Materiales nuevos para el rollo (PBR sólido sin textura: comparten shader con paneles del baño).
MAT_PAPEL = "bano_papel_higienico"
COLOR_PAPEL = (0.93, 0.92, 0.89, 1.0)
RUGOSIDAD_PAPEL = 0.92

MAT_CARTON = "bano_carton_rollo"
COLOR_CARTON = (0.42, 0.30, 0.19, 1.0)
RUGOSIDAD_CARTON = 0.90

MAT_ACERO = "bano_acero"

# Caras internas (+X) de las mamparas izquierdas de cada cabina:
# - Cabina 1: `bano_mampara_lateral-convcol` X=[10.172, 10.227]
# - Cabina 2: `bano_mampara_lateral-convcol.001` X=[11.783, 11.838]
# Las puertas abren hacia adentro sobre el lado derecho (+X) con bisagra en X=11.455 y X=13.065.
# Montados en la mampara izquierda a Y=-5.50, Z=0.72 quedan despejados del barrido y visibles.
PORTARROLLOS = (
    ("bano_portarrollo_1", 10.227, -5.50, 0.72),
    ("bano_portarrollo_2", 11.838, -5.50, 0.72),
)


def _asegurar_material_solido(
    nombre: str, color: tuple[float, float, float, float], rugosidad: float, metal: float = 0.0
):
    mat = bpy.data.materials.get(nombre) or bpy.data.materials.new(nombre)
    mat.use_nodes = True
    arbol = mat.node_tree
    bsdf = next((n for n in arbol.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = arbol.nodes.new("ShaderNodeBsdfPrincipled")
    for enlace in list(bsdf.inputs["Base Color"].links):
        arbol.links.remove(enlace)
    for nodo in list(arbol.nodes):
        if nodo.type == "TEX_IMAGE":
            arbol.nodes.remove(nodo)
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rugosidad
    bsdf.inputs["Metallic"].default_value = metal
    return mat


def _limpiar_porcelana() -> dict[str, dict[str, object]]:
    """Desconecta `porcelana_atlas.png` de porcelana y asiento para eliminar el pixelado."""
    informe: dict[str, dict[str, object]] = {}
    especificaciones = (
        ("bano_porcelana", COLOR_PORCELANA, RUGOSIDAD_PORCELANA),
        ("bano_asiento_marfil", COLOR_ASIENTO, RUGOSIDAD_ASIENTO),
    )
    for nombre, color, rugosidad in especificaciones:
        mat = _asegurar_material_solido(nombre, color, rugosidad, 0.0)
        informe[nombre] = {
            "color": list(color[:3]),
            "rugosidad": rugosidad,
            "texturas": sum(1 for n in mat.node_tree.nodes if n.type == "TEX_IMAGE"),
        }
    return informe


def _agregar_caja(
    bm: bmesh.types.BMesh,
    centro: tuple[float, float, float],
    tamano: tuple[float, float, float],
    mat_idx: int,
    bisel: float = 0.0,
) -> None:
    cx, cy, cz = centro
    sx, sy, sz = tamano
    hx, hy, hz = sx / 2.0, sy / 2.0, sz / 2.0
    if bisel <= 0.0:
        verts = [
            bm.verts.new((cx + dx, cy + dy, cz + dz))
            for dz in (-hz, hz)
            for dy in (-hy, hy)
            for dx in (-hx, hx)
        ]
        # 0:(-,-,-) 1:(+,-,-) 2:(-,+,-) 3:(+,+,-) 4:(-,-,+) 5:(+,-,+) 6:(-,+,+) 7:(+,+,+)
        caras = (
            (0, 2, 3, 1),
            (4, 5, 7, 6),
            (0, 1, 5, 4),
            (2, 6, 7, 3),
            (0, 4, 6, 2),
            (1, 3, 7, 5),
        )
        for indices in caras:
            f = bm.faces.new([verts[i] for i in indices])
            f.material_index = mat_idx
            f.smooth = False
        return
    # Perfil octogonal redondeado en YZ extruido en X.
    b = min(bisel, hy * 0.4, hz * 0.4)
    perfil = [
        (-hy + b, -hz),
        (hy - b, -hz),
        (hy, -hz + b),
        (hy, hz - b),
        (hy - b, hz),
        (-hy + b, hz),
        (-hy, hz - b),
        (-hy, -hz + b),
    ]
    tras = [bm.verts.new((cx - hx, cy + py, cz + pz)) for py, pz in perfil]
    fren = [bm.verts.new((cx + hx, cy + py, cz + pz)) for py, pz in perfil]
    n = len(perfil)
    for i in range(n):
        j = (i + 1) % n
        f = bm.faces.new((tras[i], tras[j], fren[j], fren[i]))
        f.material_index = mat_idx
        f.smooth = True
    f_tras = bm.faces.new(list(reversed(tras)))
    f_tras.material_index = mat_idx
    f_tras.smooth = False
    f_fren = bm.faces.new(fren)
    f_fren.material_index = mat_idx
    f_fren.smooth = False


def _agregar_cilindro_y(
    bm: bmesh.types.BMesh,
    cx: float,
    cz: float,
    y0: float,
    y1: float,
    radio: float,
    lados: int,
    mat_idx: int,
) -> None:
    anillo0 = [
        bm.verts.new((cx + radio * math.cos(i * math.tau / lados), y0, cz + radio * math.sin(i * math.tau / lados)))
        for i in range(lados)
    ]
    anillo1 = [
        bm.verts.new((cx + radio * math.cos(i * math.tau / lados), y1, cz + radio * math.sin(i * math.tau / lados)))
        for i in range(lados)
    ]
    for i in range(lados):
        j = (i + 1) % lados
        f = bm.faces.new((anillo0[i], anillo0[j], anillo1[j], anillo1[i]))
        f.material_index = mat_idx
        f.smooth = True
    f0 = bm.faces.new(list(reversed(anillo0)))
    f0.material_index = mat_idx
    f0.smooth = False
    f1 = bm.faces.new(anillo1)
    f1.material_index = mat_idx
    f1.smooth = False


def _agregar_tubo_hueco_y(
    bm: bmesh.types.BMesh,
    cx: float,
    cz: float,
    estaciones: list[tuple[float, float]],
    lados: int,
    mat_idx: int,
) -> None:
    """Construye un cuerpo cerrado de revolución alrededor del eje Y desde un lazo `(y, r)` cerrado."""
    anillos = [
        [
            bm.verts.new(
                (cx + r * math.cos(i * math.tau / lados), y, cz + r * math.sin(i * math.tau / lados))
            )
            for i in range(lados)
        ]
        for y, r in estaciones
    ]
    m = len(anillos)
    for k in range(m):
        a = anillos[k]
        b = anillos[(k + 1) % m]
        # Suave a lo largo de superficies cilíndricas y biseles; plano en tapas si radio cambia mucho.
        for i in range(lados):
            j = (i + 1) % lados
            f = bm.faces.new((a[i], a[j], b[j], b[i]))
            f.material_index = mat_idx
            f.smooth = True


def _agregar_cinta_xz(
    bm: bmesh.types.BMesh,
    puntos_xz: list[tuple[float, float]],
    espesor: float,
    y0: float,
    y1: float,
    mat_idx: int,
) -> None:
    """Extruir a lo largo de Y una lámina cerrada con espesor `espesor` a partir de una curva en XZ."""
    n = len(puntos_xz)
    izq: list[tuple[float, float]] = []
    der: list[tuple[float, float]] = []
    mitad = espesor / 2.0
    for i, (px, pz) in enumerate(puntos_xz):
        ax, az = puntos_xz[max(0, i - 1)]
        bx, bz = puntos_xz[min(n - 1, i + 1)]
        tx, tz = bx - ax, bz - az
        largo = math.hypot(tx, tz) or 1.0
        nx, nz = -tz / largo, tx / largo
        izq.append((px + nx * mitad, pz + nz * mitad))
        der.append((px - nx * mitad, pz - nz * mitad))
    contorno = izq + list(reversed(der))
    anillo0 = [bm.verts.new((px, y0, pz)) for px, pz in contorno]
    anillo1 = [bm.verts.new((px, y1, pz)) for px, pz in contorno]
    total = len(contorno)
    for i in range(total):
        j = (i + 1) % total
        f = bm.faces.new((anillo0[i], anillo0[j], anillo1[j], anillo1[i]))
        f.material_index = mat_idx
        f.smooth = True
    f0 = bm.faces.new(list(reversed(anillo0)))
    f0.material_index = mat_idx
    f0.smooth = False
    f1 = bm.faces.new(anillo1)
    f1.material_index = mat_idx
    f1.smooth = False


def _construir_malla_portarrollo(nombre_malla: str, materiales: list) -> bpy.types.Mesh:
    """Construye la malla local del portarrollos con origen en la pared (`x=0`), mirando a `+X`."""
    bm = bmesh.new()
    try:
        # Índices de material: 0 = acero, 1 = papel, 2 = cartón.
        x_eje = 0.072

        # 1. Placa mural con esquinas suavizadas (1 mm embebida en la mampara para cero luz).
        _agregar_caja(bm, (0.0025, 0.0, 0.012), (0.007, 0.142, 0.072), 0, bisel=0.008)

        # 2. Dos brazos laterales de acero que sostienen el eje del rollo.
        for signo in (-1.0, 1.0):
            y_brazo = signo * 0.062
            _agregar_caja(bm, (0.041, y_brazo, 0.0), (0.076, 0.007, 0.018), 0)
            _agregar_cilindro_y(bm, x_eje, 0.0, y_brazo - 0.005, y_brazo + 0.005, 0.011, 16, 0)

        # 3. Eje cilíndrico central de acero.
        _agregar_cilindro_y(bm, x_eje, 0.0, -0.064, 0.064, 0.0085, 16, 0)

        # 4. Tapa/visera curva de acero inoxidable por encima del rollo.
        visera_xz = [
            (0.005, 0.044),
            (0.024, 0.059),
            (0.052, 0.065),
            (0.082, 0.064),
            (0.110, 0.056),
            (0.128, 0.044),
            (0.133, 0.036),
        ]
        _agregar_cinta_xz(bm, visera_xz, 0.0028, -0.064, 0.064, 0)

        # 5. Tubo interior de cartón (asoma 1.5 mm a cada lado del papel para leerse bien).
        estaciones_carton = [
            (-0.0515, 0.019),
            (0.0515, 0.019),
            (0.0515, 0.022),
            (-0.0515, 0.022),
        ]
        _agregar_tubo_hueco_y(bm, x_eje, 0.0, estaciones_carton, 24, 2)

        # 6. Rollo de papel higiénico (diámetro 10.6 cm, ancho 10.0 cm, cantos biselados 2.5 mm).
        r_int = 0.0222
        r_ext = 0.053
        bisel = 0.0028
        estaciones_papel = [
            (-0.050, r_int),
            (0.050, r_int),
            (0.050, r_ext - bisel),
            (0.050 - bisel, r_ext),
            (-0.050 + bisel, r_ext),
            (-0.050, r_ext - bisel),
        ]
        _agregar_tubo_hueco_y(bm, x_eje, 0.0, estaciones_papel, 28, 1)

        # 7. Hoja de papel colgando por el frente del rollo con caída natural suave.
        hoja_xz = [
            (x_eje + r_ext - 0.003, 0.016),
            (x_eje + r_ext - 0.001, 0.000),
            (x_eje + r_ext - 0.002, -0.024),
            (x_eje + r_ext - 0.005, -0.052),
            (x_eje + r_ext - 0.004, -0.082),
            (x_eje + r_ext - 0.001, -0.108),
            (x_eje + r_ext + 0.003, -0.126),
        ]
        _agregar_cinta_xz(bm, hoja_xz, 0.0020, -0.0495, 0.0495, 1)

        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.normal_update()

        # Verificar integridad topológica antes de volcar a malla.
        assert all(len(e.link_faces) == 2 for e in bm.edges), f"Aristas no-manifold en {nombre_malla}"
        assert all(f.calc_area() > 1e-8 for f in bm.faces), f"Caras degeneradas en {nombre_malla}"

        # UV cúbica en metros para mantener escala uniforme en acero cepillado y papel.
        uv = bm.loops.layers.uv.verify()
        escala_uv = 3.0
        for cara in bm.faces:
            n = cara.normal
            ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
            for loop in cara.loops:
                co = loop.vert.co
                if ax >= ay and ax >= az:
                    u, v = co.y, co.z
                elif ay >= ax and ay >= az:
                    u, v = co.x, co.z
                else:
                    u, v = co.x, co.y
                loop[uv].uv = (u * escala_uv + 0.5, v * escala_uv + 0.5)

        malla = bpy.data.meshes.new(nombre_malla)
        bm.to_mesh(malla)
    finally:
        bm.free()

    for mat in materiales:
        malla.materials.append(mat)

    # Marcar aristas de quiebre duro (>35°) como sharp para conservar tapas planas y cilindros suaves.
    bm = bmesh.new()
    try:
        bm.from_mesh(malla)
        limite = math.radians(35.0)
        for arista in bm.edges:
            if len(arista.link_faces) == 2 and arista.calc_face_angle(0.0) > limite:
                arista.smooth = False
            else:
                arista.smooth = True
        bm.to_mesh(malla)
    finally:
        bm.free()

    malla.update()
    return malla


def _coleccion_del_bano():
    referencia = bpy.data.objects.get("inodoro-convcol")
    if referencia is not None and referencia.users_collection:
        return referencia.users_collection[0]
    return bpy.context.scene.collection


def _colocar_portarrollos() -> list[dict[str, object]]:
    acero = bpy.data.materials.get(MAT_ACERO)
    if acero is None:
        raise ValueError(f"Falta el material `{MAT_ACERO}` en el .blend")
    papel = _asegurar_material_solido(MAT_PAPEL, COLOR_PAPEL, RUGOSIDAD_PAPEL, 0.0)
    carton = _asegurar_material_solido(MAT_CARTON, COLOR_CARTON, RUGOSIDAD_CARTON, 0.0)
    materiales = [acero, papel, carton]
    coleccion = _coleccion_del_bano()

    resumen: list[dict[str, object]] = []
    for nombre, x_pared, y_centro, z_centro in PORTARROLLOS:
        existente = bpy.data.objects.get(nombre)
        if existente is not None:
            vieja_malla = existente.data
            bpy.data.objects.remove(existente, do_unlink=True)
            if vieja_malla is not None and vieja_malla.users == 0:
                bpy.data.meshes.remove(vieja_malla)

        malla_huerfana = bpy.data.meshes.get(nombre)
        if malla_huerfana is not None and malla_huerfana.users == 0:
            bpy.data.meshes.remove(malla_huerfana)

        malla = _construir_malla_portarrollo(nombre, materiales)
        objeto = bpy.data.objects.new(nombre, malla)
        objeto.location = Vector((x_pared, y_centro, z_centro))
        coleccion.objects.link(objeto)

        # Triangulación + normales pesadas por ángulo para exportación limpia a glTF.
        tri = objeto.modifiers.new("Triángulos para exportación", "TRIANGULATE")
        tri.quad_method = "SHORTEST_DIAGONAL"
        tri.keep_custom_normals = True
        tri.show_in_editmode = False

        bpy.context.view_layer.update()
        deps = bpy.context.evaluated_depsgraph_get()
        ev = objeto.evaluated_get(deps)
        em = ev.to_mesh()
        tris = len(em.polygons)
        verts = len(em.vertices)
        ev.to_mesh_clear()

        esquinas = [objeto.matrix_world @ Vector(c) for c in objeto.bound_box]
        resumen.append(
            {
                "nombre": nombre,
                "vertices_eval": verts,
                "triangulos_eval": tris,
                "bbox_x": [round(min(p.x for p in esquinas), 4), round(max(p.x for p in esquinas), 4)],
                "bbox_y": [round(min(p.y for p in esquinas), 4), round(max(p.y for p in esquinas), 4)],
                "bbox_z": [round(min(p.z for p in esquinas), 4), round(max(p.z for p in esquinas), 4)],
            }
        )
    return resumen


def _huellas_ajenas(excluir: set[str]) -> dict[str, str]:
    huellas: dict[str, str] = {}
    for o in bpy.data.objects:
        if o.type != "MESH" or o.name in excluir:
            continue
        datos = {
            "v": len(o.data.vertices),
            "p": len(o.data.polygons),
            "m": [round(f, 5) for fila in o.matrix_world for f in fila],
        }
        huellas[o.name] = hashlib.sha256(json.dumps(datos).encode()).hexdigest()
    return huellas


def aplicar() -> dict[str, object]:
    propios = {nombre for nombre, *_ in PORTARROLLOS}
    antes = _huellas_ajenas(propios)
    porcelana = _limpiar_porcelana()
    portarrollos = _colocar_portarrollos()
    despues = _huellas_ajenas(propios)
    assert antes == despues, "Se modificó un objeto ajeno al baño"
    return {"porcelana": porcelana, "portarrollos": portarrollos}


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
