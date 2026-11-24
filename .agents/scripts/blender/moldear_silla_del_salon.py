"""Modela la silla de madera maciza y tapizado crema del salón sobre la malla existente.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/moldear_silla_del_salon.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.
Después van `texturizar_silla_del_salon.py`, `texturizar_patas_de_silla.py` y
`exportar_modelo.py`.

## Por qué

La referencia del salón (`build/referencias/sillas_referencia.png`) muestra sillas modernas de
madera maciza clara en tono miel con asiento redondo tapizado en cuero sintético crema. La malla
anterior era una carcasa entera de plástico blanco con respaldo alto, que tapaba las mesas y no
respondía al mobiliario de madera del local.

Las mesas del salón miden 0,90 m de alto en la escena, que representan una mesa real de 0,75 m
(`ESCALA_DE_LA_MESA = 1,20`). Modelar la silla en metros reales (asiento a 45,8 cm y respaldo a
80,2 cm) y escalarla por ese mismo factor mantiene la proporción exacta frente a la mesa sin que
la silla quede chica ni invada la tapa.

## Qué cambia

- **El respaldo** (`MADERA`): una sola tabla ancha de madera curvada en planta que envuelve la
  espalda, con esquinas redondeadas y canto boleado continuo.
- **El asiento** (`TAPIZADO`): almohadón redondo de 4,6 cm de espesor con coronamiento suave y
  canto redondeado, apoyado sobre un **aro de madera** (`MADERA`) cerrado por debajo.
- **Las patas y los travesaños** (`MADERA`): cuatro patas torneadas más finas hacia el piso y
  abiertas hacia afuera. Las dos traseras suben desde el piso, abrazan el aro por detrás del
  asiento y se curvan hacia atrás hasta tomar el dorso de la tabla del respaldo. Tres travesaños
  torneados bajos unen los laterales sin cerrar el frente.
- **Las UV y los materiales**: conserva las dos ranuras de `salon_silla` y las rutas de textura ya
  importadas (`silla_plastico_blanco.png` para el tapizado crema y `silla_patas_madera.png` para
  toda la madera), con cada pieza desplegada en su banda sin superposiciones.

## Lo que cuesta

2.280 triángulos por silla (4 más que la silla anterior, dentro del tope de 2.500) y ningún
material ni dibujo más. Es idempotente: reconstruye la malla entera desde sus medidas.
"""

import math
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

MALLA = "salon_silla"
TAPIZADO, MADERA = 0, 1

#: Las mesas del salón miden 0,90 m en la escena para representar 0,75 m reales.
ESCALA_DE_LA_MESA = 0.90 / 0.75

MATERIAL_TAPIZADO = "SILLA | Tapizado crema"
MATERIAL_MADERA = "SILLA | Patas de madera"
TEXTURA_TAPIZADO = "//../source/textures/store/silla_plastico_blanco.png"
TEXTURA_MADERA = "//../source/textures/store/silla_patas_madera.png"
COLOR_TAPIZADO = (0.91, 0.80, 0.62, 1.0)
COLOR_MADERA = (0.48, 0.24, 0.08, 1.0)
RUGOSIDAD_TAPIZADO = 0.48
RUGOSIDAD_MADERA = 0.34
LADO_TAPIZADO = 512

# --- Medidas reales en metros (el frente mira a +y y el respaldo queda en -y) ----------------
Y_CENTRO_ASIENTO = 0.012
RADIO_ASIENTO = 0.210
Z_TOPE_ASIENTO = 0.458
LADOS_RADIALES = 32

RADIO_EXT_ARO = 0.208
RADIO_INT_ARO = 0.174
Z_BASE_ARO = 0.376
Z_TOPE_ARO = 0.414

Z_BASE_RESPALDO = 0.606
ALTO_RESPALDO = 0.196
MEDIO_ANCHO_RESPALDO = 0.246
RADIO_ESQUINA_SUP = 0.048
RADIO_ESQUINA_INF = 0.068
RADIO_CURVA_RESPALDO = 0.355
Y_BASE_RESPALDO = -0.228
INCLINACION_RESPALDO = -0.175
GROSOR_RESPALDO = 0.018
COLUMNAS_RESPALDO = 19

X_MONTANTE_RESPALDO = 0.148
Z_TOPE_MONTANTE = 0.774
LADOS_PATA_TRASERA = 10
LADOS_PATA_DELANTERA = 12
LADOS_TRAVESANO = 10
Z_TRAVESANO = 0.162

# --- Bandas de UV en `silla_patas_madera.png` (1024x1024) ------------------------------------
UV_RESPALDO_FRENTE = (0.020, 0.980, 0.016, 0.282)
UV_RESPALDO_DORSO = (0.020, 0.980, 0.324, 0.590)
UV_ARO = (0.000, 1.000, 0.640, 0.708)
UV_FONDO_ARO = (0.100, 0.900, 0.626, 0.640)
UV_TIRAS_V = (0.748, 0.952)
UV_TESTERO = (0.500, 0.986)
ARCO_MAXIMO_RESPALDO = 2.0 * RADIO_CURVA_RESPALDO * math.asin(
    MEDIO_ANCHO_RESPALDO / RADIO_CURVA_RESPALDO
)


def catmull_rom(puntos: list[Vector], muestras: int) -> list[Vector]:
    extremos = [puntos[0] * 2 - puntos[1], *puntos, puntos[-1] * 2 - puntos[-2]]
    salida = []
    for i in range(1, len(extremos) - 2):
        p0, p1, p2, p3 = extremos[i - 1 : i + 3]
        for k in range(muestras):
            t = k / muestras
            salida.append(
                0.5
                * (
                    2 * p1
                    + (p2 - p0) * t
                    + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                    + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t
                )
            )
    salida.append(puntos[-1].copy())
    return salida


class Armado:
    def __init__(self) -> None:
        self.vertices: list[Vector] = []
        self.uvs: list[tuple[float, float]] = []
        self.caras: list[tuple[list[int], list[Vector] | None, int]] = []

    def vertice(self, punto: Vector, uv: tuple[float, float]) -> int:
        self.vertices.append(punto.copy())
        self.uvs.append(uv)
        return len(self.vertices) - 1

    def cara(self, indices: list[int], normales: list[Vector] | None, material: int) -> None:
        """Orienta el polígono hacia la suma de sus normales explícitas."""
        puntos = [self.vertices[i] for i in indices]
        newell = Vector((0.0, 0.0, 0.0))
        for a, b in zip(puntos, puntos[1:] + puntos[:1]):
            newell += Vector(
                ((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
            )
        deseada = sum(normales, Vector()) if normales else None
        if deseada is not None and newell.dot(deseada) < 0:
            indices, normales = indices[::-1], normales[::-1]
        self.caras.append((indices, normales, material))


def _anillo_uv(
    armado: Armado,
    anillo_a: list[tuple[int, Vector]],
    anillo_b: list[tuple[int, Vector]],
    material: int,
) -> None:
    """Cose dos anillos cerrados con costura de UV duplicada (largo N + 1)."""
    for k in range(len(anillo_a) - 1):
        ia0, na0 = anillo_a[k]
        ia1, na1 = anillo_a[k + 1]
        ib0, nb0 = anillo_b[k]
        ib1, nb1 = anillo_b[k + 1]
        armado.cara([ia0, ia1, ib1, ib0], [na0, na1, nb1, nb0], material)


def asiento_tapizado(armado: Armado) -> None:
    """Almohadón redondo con coronamiento suave y canto boleado hacia el aro de madera."""
    # (radio, altura z, inclinación radial de la normal, inclinación vertical de la normal)
    perfil = [
        (0.115, 0.4568, 0.03, 1.00),
        (0.184, 0.4530, 0.14, 0.99),
        (0.203, 0.4460, 0.62, 0.78),
        (RADIO_ASIENTO, 0.4335, 1.00, 0.04),
        (0.205, 0.4195, 0.72, -0.69),
        (0.193, 0.4115, 0.25, -0.97),
    ]
    recorridos = [0.0]
    prev = (0.0, Z_TOPE_ASIENTO)
    for r, z, _, _ in perfil:
        recorridos.append(recorridos[-1] + math.hypot(r - prev[0], z - prev[1]))
        prev = (r, z)
    total = recorridos[-1]

    centro = armado.vertice(Vector((0.0, Y_CENTRO_ASIENTO, Z_TOPE_ASIENTO)), (0.5, 0.5))
    anillos: list[list[tuple[int, Vector]]] = []
    for (r, z, nr, nz), s in zip(perfil, recorridos[1:]):
        rho = 0.45 * (s / total)
        fila = []
        for k in range(LADOS_RADIALES):
            ang = 2.0 * math.pi * k / LADOS_RADIALES
            ca, sa = math.cos(ang), math.sin(ang)
            punto = Vector((r * ca, Y_CENTRO_ASIENTO + r * sa, z))
            normal = Vector((nr * ca, nr * sa, nz)).normalized()
            uv = (0.5 + rho * ca, 0.5 + rho * sa)
            fila.append((armado.vertice(punto, uv), normal))
        anillos.append(fila)

    primero = anillos[0]
    for k in range(LADOS_RADIALES):
        m = (k + 1) % LADOS_RADIALES
        armado.cara(
            [centro, primero[k][0], primero[m][0]],
            [Vector((0.0, 0.0, 1.0)), primero[k][1], primero[m][1]],
            TAPIZADO,
        )
    for a, b in zip(anillos, anillos[1:]):
        for k in range(LADOS_RADIALES):
            m = (k + 1) % LADOS_RADIALES
            armado.cara(
                [a[k][0], a[m][0], b[m][0], b[k][0]],
                [a[k][1], a[m][1], b[m][1], b[k][1]],
                TAPIZADO,
            )


def aro_de_madera(armado: Armado) -> None:
    """Bastidor circular bajo el asiento, cerrado por debajo para las vistas bajas."""
    u0, u1, v0, v1 = UV_ARO
    seccion = [
        (0.203, Z_TOPE_ARO, 0.45, 0.89, v1),
        (RADIO_EXT_ARO, Z_TOPE_ARO - 0.004, 0.98, 0.20, v0 + 0.86 * (v1 - v0)),
        (RADIO_EXT_ARO - 0.002, Z_BASE_ARO + 0.004, 0.98, -0.20, v0 + 0.24 * (v1 - v0)),
        (0.201, Z_BASE_ARO, 0.35, -0.94, v0 + 0.08 * (v1 - v0)),
        (RADIO_INT_ARO, Z_BASE_ARO, -0.35, -0.94, v0),
        (RADIO_INT_ARO, Z_BASE_ARO + 0.020, -1.00, 0.00, v0 + 0.16 * (v1 - v0)),
    ]
    anillos = []
    for r, z, nr, nz, v_uv in seccion:
        fila = []
        for k in range(LADOS_RADIALES + 1):
            frac = k / LADOS_RADIALES
            ang = 2.0 * math.pi * frac
            ca, sa = math.cos(ang), math.sin(ang)
            punto = Vector((r * ca, Y_CENTRO_ASIENTO + r * sa, z))
            normal = Vector((nr * ca, nr * sa, nz)).normalized()
            fila.append((armado.vertice(punto, (u0 + frac * (u1 - u0), v_uv)), normal))
        anillos.append(fila)
    for a, b in zip(anillos, anillos[1:]):
        _anillo_uv(armado, a, b, MADERA)

    # Tapa inferior interna para que no se vea hueco desde el piso.
    fu0, fu1, fv0, fv1 = UV_FONDO_ARO
    z_fondo = Z_BASE_ARO + 0.020
    abajo = Vector((0.0, 0.0, -1.0))
    centro = armado.vertice(
        Vector((0.0, Y_CENTRO_ASIENTO, z_fondo)), ((fu0 + fu1) * 0.5, (fv0 + fv1) * 0.5)
    )
    borde = []
    for k in range(LADOS_RADIALES):
        ang = 2.0 * math.pi * k / LADOS_RADIALES
        ca, sa = math.cos(ang), math.sin(ang)
        uv = ((fu0 + fu1) * 0.5 + 0.38 * ca, (fv0 + fv1) * 0.5 + 0.006 * sa)
        borde.append(
            armado.vertice(
                Vector((RADIO_INT_ARO * ca, Y_CENTRO_ASIENTO + RADIO_INT_ARO * sa, z_fondo)), uv
            )
        )
    for k in range(LADOS_RADIALES):
        m = (k + 1) % LADOS_RADIALES
        armado.cara([centro, borde[m], borde[k]], [abajo, abajo, abajo], MADERA)


def punto_y_normal_respaldo(x: float, dz: float) -> tuple[Vector, Vector, float]:
    """Punto en la cara delantera del respaldo, su normal hacia el asiento y el arco lateral."""
    seno = max(-0.98, min(0.98, x / RADIO_CURVA_RESPALDO))
    theta = math.asin(seno)
    envoltura = RADIO_CURVA_RESPALDO * (1.0 - math.cos(theta))
    punto = Vector(
        (x, Y_BASE_RESPALDO + INCLINACION_RESPALDO * dz + envoltura, Z_BASE_RESPALDO + dz)
    )
    tx = Vector((math.cos(theta), math.sin(theta), 0.0))
    tz = Vector((0.0, INCLINACION_RESPALDO, 1.0)).normalized()
    normal = tz.cross(tx).normalized()
    return punto, normal, RADIO_CURVA_RESPALDO * theta


def _medio_ancho_respaldo(dz: float) -> float:
    ancho = MEDIO_ANCHO_RESPALDO
    if dz < RADIO_ESQUINA_INF:
        cateto = RADIO_ESQUINA_INF - dz
        ancho = (MEDIO_ANCHO_RESPALDO - RADIO_ESQUINA_INF) + math.sqrt(
            max(0.0, RADIO_ESQUINA_INF**2 - cateto**2)
        )
    elif ALTO_RESPALDO - dz < RADIO_ESQUINA_SUP:
        cateto = RADIO_ESQUINA_SUP - (ALTO_RESPALDO - dz)
        ancho = (MEDIO_ANCHO_RESPALDO - RADIO_ESQUINA_SUP) + math.sqrt(
            max(0.0, RADIO_ESQUINA_SUP**2 - cateto**2)
        )
    return ancho


def _uv_respaldo(
    arco: float, dz: float, caja: tuple[float, float, float, float]
) -> tuple[float, float]:
    u0, u1, v0, v1 = caja
    tu = 0.5 + arco / ARCO_MAXIMO_RESPALDO
    tv = dz / ALTO_RESPALDO
    return (u0 + min(max(tu, 0.0), 1.0) * (u1 - u0), v0 + min(max(tv, 0.0), 1.0) * (v1 - v0))


def respaldo_curvo(armado: Armado) -> None:
    """Tabla única curvada en planta con esquinas redondeadas y canto boleado."""
    alturas = [
        *(RADIO_ESQUINA_INF * (1.0 - math.cos(0.5 * math.pi * k / 4)) for k in range(4)),
        RADIO_ESQUINA_INF,
        0.5 * (RADIO_ESQUINA_INF + ALTO_RESPALDO - RADIO_ESQUINA_SUP),
        ALTO_RESPALDO - RADIO_ESQUINA_SUP,
        *(
            ALTO_RESPALDO
            - RADIO_ESQUINA_SUP * (1.0 - math.sin(0.5 * math.pi * k / 4))
            for k in range(1, 5)
        ),
    ]
    filas = len(alturas)
    cols = COLUMNAS_RESPALDO

    frente_pts: list[list[Vector]] = []
    normales: list[list[Vector]] = []
    arcos: list[list[float]] = []
    for dz in alturas:
        medio = _medio_ancho_respaldo(dz)
        fp, fn, fa = [], [], []
        for j in range(cols):
            c = -1.0 + 2.0 * j / (cols - 1)
            p, n, arco = punto_y_normal_respaldo(medio * c, dz)
            fp.append(p)
            fn.append(n)
            fa.append(arco)
        frente_pts.append(fp)
        normales.append(fn)
        arcos.append(fa)

    sup, inf = [], []
    for i, dz in enumerate(alturas):
        sup.append(
            [
                armado.vertice(frente_pts[i][j], _uv_respaldo(arcos[i][j], dz, UV_RESPALDO_FRENTE))
                for j in range(cols)
            ]
        )
        inf.append(
            [
                armado.vertice(
                    frente_pts[i][j] - normales[i][j] * GROSOR_RESPALDO,
                    _uv_respaldo(arcos[i][j], dz, UV_RESPALDO_DORSO),
                )
                for j in range(cols)
            ]
        )

    for i in range(filas - 1):
        for j in range(cols - 1):
            q = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]
            armado.cara([sup[a][b] for a, b in q], [normales[a][b] for a, b in q], MADERA)
            armado.cara([inf[a][b] for a, b in q], [-normales[a][b] for a, b in q], MADERA)

    contorno = (
        [(0, j) for j in range(cols)]
        + [(i, cols - 1) for i in range(1, filas)]
        + [(filas - 1, j) for j in range(cols - 2, -1, -1)]
        + [(i, 0) for i in range(filas - 2, 0, -1)]
    )
    afuera = {}
    for k, (i, j) in enumerate(contorno):
        prev_i, prev_j = contorno[k - 1]
        sig_i, sig_j = contorno[(k + 1) % len(contorno)]
        tangente = (frente_pts[sig_i][sig_j] - frente_pts[prev_i][prev_j]).normalized()
        n = normales[i][j]
        # `contorno` recorre el borde en sentido antihorario visto desde la normal delantera.
        saliente = n.cross(tangente).normalized()
        afuera[(i, j)] = saliente

    canto_frente, canto_dorso = {}, {}
    for i, j in contorno:
        centro_canto = (
            frente_pts[i][j]
            - normales[i][j] * (GROSOR_RESPALDO * 0.5)
            + afuera[(i, j)] * (GROSOR_RESPALDO * 0.42)
        )
        canto_frente[(i, j)] = armado.vertice(
            centro_canto, _uv_respaldo(arcos[i][j], alturas[i], UV_RESPALDO_FRENTE)
        )
        canto_dorso[(i, j)] = armado.vertice(
            centro_canto, _uv_respaldo(arcos[i][j], alturas[i], UV_RESPALDO_DORSO)
        )

    for k, actual in enumerate(contorno):
        siguiente = contorno[(k + 1) % len(contorno)]
        par = [actual, siguiente]
        n = [normales[i][j] for i, j in par]
        o = [afuera[p] for p in par]
        armado.cara(
            [
                sup[par[0][0]][par[0][1]],
                sup[par[1][0]][par[1][1]],
                canto_frente[par[1]],
                canto_frente[par[0]],
            ],
            [(n[0] + o[0]).normalized(), (n[1] + o[1]).normalized(), o[1], o[0]],
            MADERA,
        )
        armado.cara(
            [
                canto_dorso[par[0]],
                canto_dorso[par[1]],
                inf[par[1][0]][par[1][1]],
                inf[par[0][0]][par[0][1]],
            ],
            [o[0], o[1], (o[1] - n[1]).normalized(), (o[0] - n[0]).normalized()],
            MADERA,
        )


def _tubo_en_tira(
    armado: Armado,
    secciones: list[tuple[Vector, Vector, Vector, float, float]],
    lados: int,
    tira: int,
    tapar_inicio: bool,
    domo_final: bool,
) -> None:
    """Barre secciones elípticas `(centro, eje_lat, eje_norm, rx, ry)` en una de las 8 tiras."""
    u0 = (tira + 0.10) / 8.0
    u1 = (tira + 0.90) / 8.0
    v0, v1 = UV_TIRAS_V
    largos = [0.0]
    for (pa, *_), (pb, *_) in zip(secciones, secciones[1:]):
        largos.append(largos[-1] + (pb - pa).length)
    total = max(largos[-1], 1e-6)

    anillos = []
    for (centro, ex, ey, rx, ry), s in zip(secciones, largos):
        v_uv = v0 + (s / total) * (v1 - v0)
        fila = []
        for k in range(lados + 1):
            frac = k / lados
            ang = 2.0 * math.pi * frac
            ca, sa = math.cos(ang), math.sin(ang)
            despl = ex * (rx * ca) + ey * (ry * sa)
            normal = (ex * (ca / rx) + ey * (sa / ry)).normalized()
            fila.append((armado.vertice(centro + despl, (u0 + frac * (u1 - u0), v_uv)), normal))
        anillos.append(fila)

    for a, b in zip(anillos, anillos[1:]):
        _anillo_uv(armado, a, b, MADERA)

    if tapar_inicio:
        c0, ex0, ey0, rx0, ry0 = secciones[0]
        eje0 = (secciones[1][0] - c0).normalized()
        pie = []
        for k in range(lados):
            ang = 2.0 * math.pi * k / lados
            pie.append(
                armado.vertice(
                    c0 + ex0 * (rx0 * math.cos(ang)) + ey0 * (ry0 * math.sin(ang)), UV_TESTERO
                )
            )
        armado.cara(pie, [-eje0] * lados, MADERA)

    if domo_final:
        cf, exf, eyf, rxf, ryf = secciones[-1]
        ejef = (cf - secciones[-2][0]).normalized()
        du0, du1 = (7 + 0.14) / 8.0, (7 + 0.86) / 8.0
        anillo_medio = []
        for k in range(lados + 1):
            frac = k / lados
            ang = 2.0 * math.pi * frac
            ca, sa = math.cos(ang), math.sin(ang)
            punto = cf + ejef * 0.006 + exf * (rxf * 0.62 * ca) + eyf * (ryf * 0.62 * sa)
            normal = (ejef * 0.65 + exf * ca + eyf * sa).normalized()
            anillo_medio.append(
                (armado.vertice(punto, (du0 + frac * (du1 - du0), v1 - 0.012)), normal)
            )
        _anillo_uv(armado, anillos[-1], anillo_medio, MADERA)
        punta = armado.vertice(cf + ejef * 0.010, ((du0 + du1) * 0.5, v1))
        for k in range(lados):
            armado.cara(
                [anillo_medio[k][0], anillo_medio[k + 1][0], punta],
                [anillo_medio[k][1], anillo_medio[k + 1][1], ejef],
                MADERA,
            )


def _montante_trasero(armado: Armado, sx: int, tira: int) -> tuple[Vector, Vector]:
    """Una pata trasera continua del piso al dorso del respaldo; devuelve el eje inferior."""
    x_m = sx * X_MONTANTE_RESPALDO

    def en_respaldo(dz: float) -> tuple[Vector, Vector, Vector]:
        p_frente, n_frente, _ = punto_y_normal_respaldo(x_m, dz)
        p_dorso = p_frente - n_frente * GROSOR_RESPALDO
        # El centro queda a 9 mm del dorso: con semiespesor 12 mm penetra 3 mm sin asomar adelante.
        centro = p_dorso - n_frente * 0.009
        eje_z = Vector((0.0, INCLINACION_RESPALDO, 1.0)).normalized()
        eje_lat = n_frente.cross(eje_z).normalized()
        return centro, eje_lat, n_frente

    c_bajo_resp, lat_resp, norm_resp = en_respaldo(0.016)
    c_medio_resp, _, _ = en_respaldo(0.092)
    c_alto_resp, _, _ = en_respaldo(Z_TOPE_MONTANTE - Z_BASE_RESPALDO)

    pie = Vector((sx * 0.180, -0.214, 0.000))
    en_aro = Vector((sx * 0.142, -0.156, 0.392))
    curva_baja = catmull_rom(
        [
            pie,
            Vector((sx * 0.165, -0.186, 0.165)),
            en_aro,
            Vector((sx * 0.147, -0.169, 0.475)),
            Vector((sx * 0.154, -0.195, 0.550)),
            c_bajo_resp,
        ],
        2,
    )
    # Índices pares + intermedios clave dan 8 cortes suaves hasta el respaldo, más 2 sobre la tabla.
    puntos = [
        curva_baja[0],
        curva_baja[2],
        curva_baja[4],
        curva_baja[5],
        curva_baja[7],
        curva_baja[9],
        curva_baja[10],
        c_medio_resp,
        c_alto_resp,
    ]
    radios = [
        (0.0125, 0.0125),
        (0.0148, 0.0148),
        (0.0182, 0.0182),
        (0.0176, 0.0170),
        (0.0172, 0.0150),
        (0.0170, 0.0130),
        (0.0168, 0.0120),
        (0.0166, 0.0120),
        (0.0158, 0.0115),
    ]
    secciones = []
    for idx, (centro, (rx, ry)) in enumerate(zip(puntos, radios)):
        if idx >= 6:
            _, ex, ey = en_respaldo(max(0.0, centro.z - Z_BASE_RESPALDO))
        else:
            tang = (puntos[min(idx + 1, len(puntos) - 1)] - puntos[max(idx - 1, 0)]).normalized()
            # `ey` mira hacia +y: `ang = pi/2` es el frente y `ang = 3*pi/2` es el dorso.
            ex = Vector((1.0, 0.0, 0.0))
            ex = (ex - tang * ex.dot(tang)).normalized()
            ey = tang.cross(ex).normalized()
            if ey.y < 0:
                ey = -ey
        secciones.append((centro, ex, ey, rx, ry))

    _tubo_en_tira(armado, secciones, LADOS_PATA_TRASERA, tira, tapar_inicio=True, domo_final=True)
    return pie, en_aro


def patas_y_travesanos(armado: Armado) -> None:
    """Las cuatro patas torneadas y los tres travesaños bajos en H desplazada."""
    ejes_traseros = {}
    for sx, tira in ((-1, 0), (1, 1)):
        ejes_traseros[sx] = _montante_trasero(armado, sx, tira)

    ejes_delanteros = {}
    for sx, tira in ((-1, 2), (1, 3)):
        pie = Vector((sx * 0.184, 0.172, 0.000))
        tope = Vector((sx * 0.142, 0.146, 0.394))
        medio = pie.lerp(tope, 0.48)
        tang = (tope - pie).normalized()
        ex = (Vector((1.0, 0.0, 0.0)) - tang * tang.x).normalized()
        ey = tang.cross(ex).normalized()
        secciones = [
            (pie, ex, ey, 0.0120, 0.0120),
            (medio, ex, ey, 0.0158, 0.0158),
            (tope, ex, ey, 0.0185, 0.0185),
        ]
        _tubo_en_tira(
            armado, secciones, LADOS_PATA_DELANTERA, tira, tapar_inicio=True, domo_final=False
        )
        ejes_delanteros[sx] = (pie, tope)

    def en_z(par: tuple[Vector, Vector], z: float) -> Vector:
        a, b = par
        return a.lerp(b, (z - a.z) / (b.z - a.z))

    def travesano(a: Vector, b: Vector, tira: int) -> None:
        eje = (b - a).normalized()
        # Penetra 5 mm en cada pata para cerrar el encuentro sin caras sueltas.
        pa, pb = a - eje * 0.005, b + eje * 0.005
        ref = Vector((0.0, 0.0, 1.0))
        ex = eje.cross(ref).normalized()
        ey = ex.cross(eje).normalized()
        secciones = [
            (pa, ex, ey, 0.0102, 0.0102),
            (pa.lerp(pb, 0.5), ex, ey, 0.0115, 0.0115),
            (pb, ex, ey, 0.0102, 0.0102),
        ]
        _tubo_en_tira(
            armado, secciones, LADOS_TRAVESANO, tira, tapar_inicio=False, domo_final=False
        )

    anclajes_centrales = []
    for sx, tira in ((-1, 4), (1, 5)):
        adelante = en_z(ejes_delanteros[sx], Z_TRAVESANO)
        atras = en_z(ejes_traseros[sx], Z_TRAVESANO)
        travesano(adelante, atras, tira)
        anclajes_centrales.append(adelante.lerp(atras, 0.54))
    travesano(anclajes_centrales[0], anclajes_centrales[1], 6)


def configurar_material(
    actual,
    nombre: str,
    textura_rel: str,
    color_base: tuple[float, float, float, float],
    rugosidad: float,
    lado_inicial: int,
):
    """Actualiza el material de la ranura en su lugar para no dejar huérfanos en el `.blend`."""
    material = actual or bpy.data.materials.get(nombre) or bpy.data.materials.new(nombre)
    material.name = nombre
    if material.node_tree is None:
        material.use_nodes = True
    nodos = material.node_tree.nodes
    principal = next(n for n in nodos if n.type == "BSDF_PRINCIPLED")
    imagen_nodo = next((n for n in nodos if n.type == "TEX_IMAGE"), None) or nodos.new(
        "ShaderNodeTexImage"
    )
    ruta = Path(bpy.path.abspath(textura_rel))
    if not ruta.exists():
        ruta.parent.mkdir(parents=True, exist_ok=True)
        lisa = bpy.data.images.new(ruta.stem, lado_inicial, lado_inicial)
        lisa.generated_color = color_base
        lisa.filepath_raw = str(ruta)
        lisa.file_format = "PNG"
        lisa.save()
        bpy.data.images.remove(lisa)
    imagen = bpy.data.images.load(str(ruta), check_existing=True)
    imagen.filepath = textura_rel
    imagen.colorspace_settings.name = "sRGB"
    imagen_nodo.image = imagen
    imagen_nodo.interpolation = "Linear"
    material.node_tree.links.new(imagen_nodo.outputs["Color"], principal.inputs["Base Color"])
    principal.inputs["Base Color"].default_value = color_base
    principal.inputs["Roughness"].default_value = rugosidad
    principal.inputs["Metallic"].default_value = 0.0
    material.diffuse_color = color_base
    return material


def volcar(armado: Armado, malla) -> None:
    malla.materials[TAPIZADO] = configurar_material(
        malla.materials[TAPIZADO],
        MATERIAL_TAPIZADO,
        TEXTURA_TAPIZADO,
        COLOR_TAPIZADO,
        RUGOSIDAD_TAPIZADO,
        LADO_TAPIZADO,
    )
    malla.materials[MADERA] = configurar_material(
        malla.materials[MADERA],
        MATERIAL_MADERA,
        TEXTURA_MADERA,
        COLOR_MADERA,
        RUGOSIDAD_MADERA,
        1024,
    )
    materiales = list(malla.materials)
    malla.clear_geometry()
    malla.from_pydata(
        [tuple(v * ESCALA_DE_LA_MESA) for v in armado.vertices],
        [],
        [c[0] for c in armado.caras],
    )
    malla.update()
    capa = malla.uv_layers.new(name="UVMap")
    normales = []
    for poligono, (indices, propias, material) in zip(malla.polygons, armado.caras):
        poligono.material_index = material
        poligono.use_smooth = True
        for lazo, indice in zip(poligono.loop_indices, indices):
            capa.data[lazo].uv = armado.uvs[indice]
        normales.extend(propias if propias else [poligono.normal.copy()] * len(indices))
    malla.normals_split_custom_set([tuple(n) for n in normales])
    if list(malla.materials) != materiales:
        raise ValueError("la silla perdió sus materiales")


def main() -> None:
    configurar()
    malla = bpy.data.meshes[MALLA]
    antes = sum(len(p.vertices) - 2 for p in malla.polygons)
    armado = Armado()
    asiento_tapizado(armado)
    aro_de_madera(armado)
    respaldo_curvo(armado)
    patas_y_travesanos(armado)
    volcar(armado, malla)
    despues = sum(len(p.vertices) - 2 for p in malla.polygons)
    print(f"{MALLA}: {antes} -> {despues} triángulos, en {malla.users} sillas")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
