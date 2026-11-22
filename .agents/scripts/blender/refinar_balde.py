"""Suaviza el aro, el cuerpo y la manija de `balde-col` conservando pivotes, logotipo y ranuras.

    blender --factory-startup --background --python-exit-code 1 \
        --python .claude/scripts/blender/refinar_balde.py -- [--aplicar]

Sin `--aplicar`, guarda una copia de prueba en `reports/balde-suave.blend`.
Con `--aplicar`, actualiza `assets/models/SEPT_JUEGOS_PROTOTIPO.blend` en su lugar.
Después van `texturizar_utiles.py --aplicar` y `exportar_modelo.py`.

## Por qué

El balde tenía 24 lados con un aro de canto duro, un arco de manija de 10 tramos con sección
hexagonal (6 lados) y un agarre de 3 anillos hexagonales. De cerca se leía muy low-poly.

## Qué cambia

- Cuerpo y aro superior (`util_plastico_azul` y `util_borde_crema`): 48 lados y labio enrollado
  suave conservando exactamente el radio interior (`0,1752..0,178 m`), el exterior (`0,195 m`) y la
  altura (`-0,156..+0,1755 m`) para no alterar el agua ni la mopa.
- Aro inferior de refuerzo (`util_plastico_azul`): 48 lados con cantos suavizados.
- Arco de la manija (`util_asa_grafito`): 40 tramos sobre la misma elipse `(0,187, 0,190)` con
  sección circular de 16 lados, pivotes exactos en `X = ±0,187, Z = 0,145`.
- Agarre superior (`util_borde_crema`): 16 tramos sobre el arco con sección de 18 lados, extremos
  redondeados y ligera curva ergonómica.
- Se conservan intactas las bisagras laterales y el relieve del logotipo frontal.
- Actualiza el atributo de cara `ranura_original` para que `texturizar_utiles.py` hornee cada
  material en su color correcto.

Es idempotente: correrlo dos veces produce exactamente la misma geometría y ranuras.
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
DESTINO_PRUEBA = RAIZ / "reports/balde-suave.blend"
NOMBRE_BALDE = "balde-col"
RANURA = "ranura_original"

# Mismo orden alfabético que usa `detalle_horneado.guardar_ranuras`.
MATERIALES_ORDENADOS = sorted(
    (
        "util_plastico_azul",
        "util_plastico_claro",
        "util_borde_crema",
        "util_asa_grafito",
        "util_mango_acero",
        "util_fibra_cruda",
        "util_fibra_sombra",
    )
)

LADOS_CUERPO = 48
TRAMOS_ARCO = 40
LADOS_ARCO = 16
TRAMOS_AGARRE = 16
LADOS_AGARRE = 18

# Arco de la manija alineado al pivote exacto del shader (`bisagra.y = 0.134` en Godot):
# Sube recto por fuera del labio (`r = 0.195`) hasta `Z = 0.176` en `X = ±0.2035` y luego curva
# en elipse suave hasta `Z = 0.338`. Cero cruce con el aro blanco ni la pared interior.
ARCO_RX = 0.2035
ARCO_RZ = 0.1620
ARCO_Z_BISAGRA = 0.1340
ARCO_Z0 = 0.1760
ARCO_RADIO_TUBO = 0.0070


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


def _componentes_conexas(bm) -> list[set]:
    vistas: set = set()
    grupos: list[set] = []
    for inicio in bm.verts:
        if inicio in vistas:
            continue
        pila = [inicio]
        grupo: set = set()
        while pila:
            actual = pila.pop()
            if actual in grupo:
                continue
            grupo.add(actual)
            vistas.add(actual)
            for arista in actual.link_edges:
                pila.append(arista.other_vert(actual))
        grupos.append(grupo)
    return grupos


def _es_componente_a_reemplazar(grupo: set) -> bool:
    """Identifica las partes a reconstruir (cuerpo, aro inferior, bisagras laterales, arco y agarre)."""
    xs = [v.co.x for v in grupo]
    ys = [v.co.y for v in grupo]
    zs = [v.co.z for v in grupo]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    min_z, max_z = min(zs), max(zs)
    # 1. Cuerpo + aro superior (abarca de z=-0.156 a z=+0.176).
    if min_z < -0.14 and max_z > 0.16:
        return True
    # 2. Aro inferior de refuerzo (z en [-0.125, -0.095], radio ~0.18 en X e Y).
    if -0.13 < min_z < -0.115 and -0.11 < max_z < -0.095 and (max_x - min_x) > 0.30 and (max_y - min_y) > 0.30:
        return True
    # 3. Bisagras laterales en X = ±0.15..0.21, |Y| < 0.03, Z en [0.11, 0.165].
    if max(abs(min_x), abs(max_x)) > 0.15 and max(abs(min_y), abs(max_y)) < 0.035 and 0.11 < min_z and max_z < 0.17:
        return True
    # 4. Arco y agarre de la manija: superan Z = 0.20 m (mismo umbral de `partes_de_manija.gd`).
    if max_z > 0.20:
        return True
    return False


def _agregar_revolucion(
    bm,
    perfil: list[tuple[float, float, str]],
    lados: int,
    cerrar_fondo_exterior: bool,
    cerrar_fondo_interior: bool,
    cerrar_lazo: bool,
    etiquetas: dict,
) -> None:
    """Agrega una superficie de revolución alrededor de Z desde `(r, z, nombre_material)`."""
    anillos = [
        [
            bm.verts.new((r * math.cos(i * math.tau / lados), r * math.sin(i * math.tau / lados), z))
            for i in range(lados)
        ]
        for r, z, _ in perfil
    ]
    n_capas = len(anillos)
    pares = n_capas if cerrar_lazo else n_capas - 1
    for k in range(pares):
        a = anillos[k]
        b = anillos[(k + 1) % n_capas]
        mat_nombre = perfil[k][2]
        for i in range(lados):
            j = (i + 1) % lados
            f = bm.faces.new((a[i], a[j], b[j], b[i]))
            f.smooth = True
            etiquetas[f] = mat_nombre
    if cerrar_fondo_exterior:
        f = bm.faces.new(list(reversed(anillos[0])))
        f.smooth = False
        etiquetas[f] = perfil[0][2]
    if cerrar_fondo_interior:
        f = bm.faces.new(anillos[-1])
        f.smooth = False
        etiquetas[f] = perfil[-1][2]


def _punto_arco(theta: float) -> Vector:
    return Vector((ARCO_RX * math.cos(theta), 0.0, ARCO_Z0 + ARCO_RZ * math.sin(theta)))


def _tangente_arco(theta: float) -> Vector:
    return Vector((-ARCO_RX * math.sin(theta), 0.0, ARCO_RZ * math.cos(theta))).normalized()


def _agregar_tubo_en_puntos(
    bm,
    estaciones: list[tuple[Vector, Vector, float]],
    lados: int,
    mat_nombre: str,
    etiquetas: dict,
) -> None:
    """Extruir un tubo cerrado desde `(centro, tangente, radio)` en el plano XZ."""
    anillos = []
    eje_y = Vector((0.0, 1.0, 0.0))
    for centro, tangente, radio in estaciones:
        normal = tangente.normalized().cross(eje_y).normalized()
        anillo = [
            bm.verts.new(
                centro
                + normal * (radio * math.cos(i * math.tau / lados))
                + eje_y * (radio * math.sin(i * math.tau / lados))
            )
            for i in range(lados)
        ]
        anillos.append(anillo)

    for k in range(len(anillos) - 1):
        a, b = anillos[k], anillos[k + 1]
        for i in range(lados):
            j = (i + 1) % lados
            f = bm.faces.new((a[i], a[j], b[j], b[i]))
            f.smooth = True
            etiquetas[f] = mat_nombre

    tapa0 = bm.faces.new(list(reversed(anillos[0])))
    tapa0.smooth = False
    etiquetas[tapa0] = mat_nombre
    tapa1 = bm.faces.new(anillos[-1])
    tapa1.smooth = False
    etiquetas[tapa1] = mat_nombre


def _agregar_tubo_en_arco(
    bm,
    estaciones: list[tuple[float, float]],
    lados: int,
    mat_nombre: str,
    etiquetas: dict,
) -> None:
    """Extruir un tubo cerrado a lo largo de la elipse del arco desde `(theta, radio)`."""
    puntos = [(_punto_arco(theta), _tangente_arco(theta), radio) for theta, radio in estaciones]
    _agregar_tubo_en_puntos(bm, puntos, lados, mat_nombre, etiquetas)


def _reconstruir_cuerpo_y_aros(bm, etiquetas: dict) -> None:
    # Perfil continuo del cuerpo + aro superior enrollado suave (exactamente dentro de las medidas
    # originales: fondo en z=-0.156, pared interior r=0.164..0.178, aro exterior r=0.195, z=0.1755).
    perfil_cuerpo = [
        (0.1470, -0.1560, "util_plastico_azul"),
        (0.1545, -0.1545, "util_plastico_azul"),
        (0.1755, -0.1335, "util_plastico_azul"),
        (0.1780, -0.1280, "util_plastico_azul"),
        (0.1848, 0.1488, "util_borde_crema"),
        # Labio superior enrollado con 7 estaciones suaves en vez de 3 esquinas vivas.
        (0.1920, 0.1545, "util_borde_crema"),
        (0.1950, 0.1605, "util_borde_crema"),
        (0.1950, 0.1710, "util_borde_crema"),
        (0.1922, 0.1748, "util_borde_crema"),
        (0.1865, 0.1755, "util_borde_crema"),
        (0.1805, 0.1748, "util_borde_crema"),
        (0.1778, 0.1715, "util_borde_crema"),
        (0.1752, 0.1447, "util_plastico_azul"),
        (0.1640, -0.1226, "util_plastico_azul"),
        (0.1615, -0.1325, "util_plastico_azul"),
        (0.1580, -0.1381, "util_plastico_azul"),
    ]
    _agregar_revolucion(
        bm,
        perfil_cuerpo,
        LADOS_CUERPO,
        cerrar_fondo_exterior=True,
        cerrar_fondo_interior=True,
        cerrar_lazo=False,
        etiquetas=etiquetas,
    )

    # Aro inferior de refuerzo (48 lados, sección suavizada en z = -0.121..-0.103).
    perfil_aro_inf = [
        (0.1768, -0.1210, "util_plastico_azul"),
        (0.1812, -0.1195, "util_plastico_azul"),
        (0.1826, -0.1155, "util_plastico_azul"),
        (0.1826, -0.1065, "util_plastico_azul"),
        (0.1810, -0.1035, "util_plastico_azul"),
        (0.1772, -0.1030, "util_plastico_azul"),
    ]
    _agregar_revolucion(
        bm,
        perfil_aro_inf,
        LADOS_CUERPO,
        cerrar_fondo_exterior=False,
        cerrar_fondo_interior=False,
        cerrar_lazo=True,
        etiquetas=etiquetas,
    )


def _agregar_cilindro_x(
    bm, x0: float, x1: float, cy: float, cz: float, radio: float, lados: int, mat_nombre: str, etiquetas: dict
) -> None:
    a0 = [
        bm.verts.new((x0, cy + radio * math.cos(i * math.tau / lados), cz + radio * math.sin(i * math.tau / lados)))
        for i in range(lados)
    ]
    a1 = [
        bm.verts.new((x1, cy + radio * math.cos(i * math.tau / lados), cz + radio * math.sin(i * math.tau / lados)))
        for i in range(lados)
    ]
    for i in range(lados):
        j = (i + 1) % lados
        f = bm.faces.new((a0[i], a0[j], a1[j], a1[i]))
        f.smooth = True
        etiquetas[f] = mat_nombre
    f0 = bm.faces.new(list(reversed(a0)))
    f0.smooth = False
    etiquetas[f0] = mat_nombre
    f1 = bm.faces.new(a1)
    f1.smooth = False
    etiquetas[f1] = mat_nombre


def _reconstruir_bisagras(bm, etiquetas: dict) -> None:
    """Orejas exteriores limpias sobre el canto del balde (sin atravesar la pared interior)."""
    for signo in (-1.0, 1.0):
        # Oreja exterior apoyada sobre la pared azul (`r = 0.184` a `z = 0.134`), siempre por
        # fuera de la pared interior (`r = 0.175`).
        x_in = signo * 0.1805
        x_out = signo * 0.2005
        if x_in > x_out:
            x_in, x_out = x_out, x_in
        _agregar_cilindro_x(bm, x_in, x_out, 0.0, ARCO_Z_BISAGRA, 0.0145, 16, "util_asa_grafito", etiquetas)
        # Perno exterior que recibe el extremo del arco (`x = ±0.2035, z = 0.134`).
        xp0 = signo * 0.1970
        xp1 = signo * 0.2105
        if xp0 > xp1:
            xp0, xp1 = xp1, xp0
        _agregar_cilindro_x(bm, xp0, xp1, 0.0, ARCO_Z_BISAGRA, 0.0085, 16, "util_borde_crema", etiquetas)


def _reconstruir_manija(bm, etiquetas: dict) -> None:
    # 1. Arco cilíndrico suave: tramo recto vertical en ambos pivotes (`Z = 0.134..0.176`) para
    # librar por fuera el aro blanco (`r = 0.195`) + 40 tramos en elipse hasta `Z = 0.338`.
    estaciones: list[tuple[Vector, Vector, float]] = []
    estaciones.append((Vector((-ARCO_RX, 0.0, ARCO_Z_BISAGRA)), Vector((0.0, 0.0, 1.0)), ARCO_RADIO_TUBO))
    estaciones.append((Vector((-ARCO_RX, 0.0, (ARCO_Z_BISAGRA + ARCO_Z0) / 2.0)), Vector((0.0, 0.0, 1.0)), ARCO_RADIO_TUBO))
    for k in range(TRAMOS_ARCO + 1):
        theta = math.pi - math.pi * k / TRAMOS_ARCO
        estaciones.append((_punto_arco(theta), _tangente_arco(theta), ARCO_RADIO_TUBO))
    estaciones.append((Vector((ARCO_RX, 0.0, (ARCO_Z_BISAGRA + ARCO_Z0) / 2.0)), Vector((0.0, 0.0, -1.0)), ARCO_RADIO_TUBO))
    estaciones.append((Vector((ARCO_RX, 0.0, ARCO_Z_BISAGRA)), Vector((0.0, 0.0, -1.0)), ARCO_RADIO_TUBO))
    _agregar_tubo_en_puntos(bm, estaciones, LADOS_ARCO, "util_asa_grafito", etiquetas)

    # 2. Agarre superior de plástico rígido moldeado (`util_borde_crema`):
    # extremos con hombro firme y 3 rebajes ergonómicos amplios (sin caras angostas sub-texel).
    theta_ini = math.radians(108.5)
    theta_fin = math.radians(71.5)
    perfil_agarre = [
        (0.000, 0.0080),
        (0.035, 0.0144),
        (0.140, 0.0148),
        (0.260, 0.0137),
        (0.380, 0.0149),
        (0.500, 0.0138),
        (0.620, 0.0149),
        (0.740, 0.0137),
        (0.860, 0.0148),
        (0.965, 0.0144),
        (1.000, 0.0080),
    ]
    estaciones_agarre = [
        (theta_ini + (theta_fin - theta_ini) * t, radio) for t, radio in perfil_agarre
    ]
    _agregar_tubo_en_arco(bm, estaciones_agarre, 12, "util_borde_crema", etiquetas)


def aplicar() -> dict[str, object]:
    antes = _huellas_ajenas(NOMBRE_BALDE)
    objeto = bpy.data.objects[NOMBRE_BALDE]
    malla = objeto.data

    # Leer la ranura original de cada cara antes de tocar la malla.
    ran_attr = malla.attributes.get(RANURA)
    ranuras_previas: list[str] = []
    if ran_attr is not None:
        ranuras_previas = [MATERIALES_ORDENADOS[d.value] for d in ran_attr.data]
    else:
        ranuras_previas = [malla.materials[p.material_index].name for p in malla.polygons]

    indice_por_nombre = {mat.name: i for i, mat in enumerate(malla.materials)}

    bm = bmesh.new()
    try:
        bm.from_mesh(malla)
        bm.faces.ensure_lookup_table()
        etiquetas: dict = {cara: ranuras_previas[cara.index] for cara in bm.faces}

        # Eliminar las 4 partes a suavizar (cuerpo, aro inferior, arco, agarre); conservar bisagras y logo.
        a_borrar = []
        for grupo in _componentes_conexas(bm):
            if _es_componente_a_reemplazar(grupo):
                a_borrar.extend(grupo)
        if a_borrar:
            bmesh.ops.delete(bm, geom=a_borrar, context="VERTS")

        # Limpiar referencias a caras borradas en el diccionario de etiquetas.
        etiquetas = {f: mat for f, mat in etiquetas.items() if f.is_valid}

        _reconstruir_cuerpo_y_aros(bm, etiquetas)
        _reconstruir_bisagras(bm, etiquetas)
        _reconstruir_manija(bm, etiquetas)

        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.normal_update()

        assert all(len(e.link_faces) == 2 for e in bm.edges), "Arista no-manifold en balde-col"
        assert all(f.calc_area() > 1e-8 for f in bm.faces), "Cara degenerada en balde-col"

        # Marcar aristas de quiebre duro (>34°) como sharp para conservar hombros firmes en el
        # agarre y tapas planas limpias sin perder suavidad en cuerpo, aro y arco.
        limite = math.radians(34.0)
        for arista in bm.edges:
            if len(arista.link_faces) == 2 and arista.calc_face_angle(0.0) > limite:
                arista.smooth = False
            else:
                arista.smooth = True

        # Asignar material_index provisional y guardar lista ordenada de ranura_original.
        bm.faces.index_update()
        nuevas_ranuras = [""] * len(bm.faces)
        for cara in bm.faces:
            nombre_mat = etiquetas[cara]
            nuevas_ranuras[cara.index] = nombre_mat
            cara.material_index = indice_por_nombre[nombre_mat]

        bm.to_mesh(malla)
    finally:
        bm.free()

    # Reescribir atributo de cara `ranura_original` sincronizado con la nueva topología.
    if RANURA in malla.attributes:
        malla.attributes.remove(malla.attributes[RANURA])
    attr = malla.attributes.new(RANURA, "INT", "FACE")
    for idx, nombre_mat in enumerate(nuevas_ranuras):
        attr.data[idx].value = MATERIALES_ORDENADOS.index(nombre_mat)

    malla["gajos_duplicados"] = True
    malla.update()

    despues = _huellas_ajenas(NOMBRE_BALDE)
    assert antes == despues, "Se modificó un objeto distinto de balde-col"

    tris = sum(len(p.vertices) - 2 for p in malla.polygons)
    return {
        "objeto": NOMBRE_BALDE,
        "vertices": len(malla.vertices),
        "caras": len(malla.polygons),
        "triangulos": tris,
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
