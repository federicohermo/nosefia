"""Rehace la silla del salón como una silla de carcasa de plástico moldeado sobre patas torneadas.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/moldear_silla_del_salon.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.
Después va `exportar_modelo.py`.

## Por qué

La silla era una losa doblada en L sobre cuatro palitos cuadrados. Se leía como un mueble de
maqueta al lado de las mesas.

## Qué cambia

- **La carcasa** es una sola pieza de plástico inyectado de 12 mm: el asiento tiene un hueco suave,
  el borde de adelante cae redondeado, y el respaldo sube con una curva y envuelve la espalda. El
  contorno tiene las esquinas redondeadas y el canto es redondo. Es de plástico porque una carcasa
  con esa forma no es de madera: con la veta, la silla se leía rara.
- **Las patas** son cónicas, torneadas y abiertas hacia afuera. Un bastidor las une bajo el
  asiento, y un travesaño en H las une cerca del piso.

La silla mide `ESCALA` veces la anterior: el asiento queda a 62 cm de una mesa de 90, y entra
debajo de la mesa. Las seis sillas siguen en su lugar, y las patas siguen siendo de madera. Las normales van escritas a mano: el canto brilla como
un canto redondeado y la carcasa se ve lisa.

## Lo que cuesta

Unos dos mil triángulos por silla, y ningún dibujo más. Es idempotente: rehace la malla entera.
"""

import math
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

MALLA = "salon_silla"
CARCASA, PATAS = 0, 1
ESCALA = 1.12
#: El material de la carcasa reemplaza a la madera blanca en la misma ranura.
PLASTICO = "SILLA | Plástico blanco"
COLOR_DEL_PLASTICO = (0.78, 0.78, 0.75, 1.0)
RUGOSIDAD_DEL_PLASTICO = 0.5

#: La línea media de la carcasa en (y, z), desde la caída del borde de adelante hasta la punta
#: del respaldo. El respaldo queda del lado de -y, como en la silla anterior.
PERFIL = [
    (0.238, 0.505),
    (0.236, 0.530),
    (0.222, 0.548),
    (0.190, 0.553),
    (0.100, 0.547),
    (-0.030, 0.539),
    (-0.140, 0.545),
    (-0.205, 0.568),
    (-0.240, 0.620),
    (-0.258, 0.700),
    (-0.274, 0.800),
    (-0.290, 0.900),
    (-0.302, 0.985),
    (-0.306, 1.030),
]
FILAS = 30
COLUMNAS = 15
GROSOR = 0.012
#: El medio ancho de la carcasa según la fracción del recorrido: más angosta en la cintura.
MEDIO_ANCHO = [(0.0, 0.218), (0.45, 0.214), (0.62, 0.192), (0.78, 0.204), (1.0, 0.226)]
RADIO_DE_ESQUINA = 0.07
ENVOLTURA_DEL_RESPALDO = 0.04
HUECO_DEL_ASIENTO = 0.012

PATA_ARRIBA = (0.188, 0.172, -0.160)
PATA_ABAJO = (0.226, 0.214, -0.226)
RADIO_ARRIBA, RADIO_ABAJO = 0.017, 0.0115
LADOS_DE_PATA = 12
ALTO_DEL_TRAVESANO = 0.16
RADIO_DEL_TRAVESANO = 0.0085


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


def remuestrear(curva: list[Vector], cantidad: int) -> tuple[list[Vector], list[float]]:
    largos = [0.0]
    for a, b in zip(curva, curva[1:]):
        largos.append(largos[-1] + (b - a).length)
    total = largos[-1]
    puntos, recorridos, k = [], [], 0
    for i in range(cantidad):
        objetivo = total * i / (cantidad - 1)
        while k < len(largos) - 2 and largos[k + 1] < objetivo:
            k += 1
        tramo = largos[k + 1] - largos[k]
        t = 0.0 if tramo == 0 else (objetivo - largos[k]) / tramo
        puntos.append(curva[k].lerp(curva[k + 1], min(max(t, 0.0), 1.0)))
        recorridos.append(objetivo)
    return puntos, recorridos


def interpolar(tabla: list[tuple[float, float]], q: float) -> float:
    for (q0, v0), (q1, v1) in zip(tabla, tabla[1:]):
        if q <= q1:
            return v0 + (v1 - v0) * (q - q0) / (q1 - q0)
    return tabla[-1][1]


def suave(a: float, b: float, x: float) -> float:
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


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
        """Una cara con las normales que tiene que mostrar; se da vuelta si quedó al revés."""
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


def carcasa(armado: Armado) -> list[list[Vector]]:
    curva = catmull_rom([Vector((0.0, y, z)) for y, z in PERFIL], 40)
    medios, recorridos = remuestrear(curva, FILAS)
    largo = recorridos[-1]
    arriba: list[list[Vector]] = []
    for medio, s in zip(medios, recorridos):
        ancho = interpolar(MEDIO_ANCHO, s / largo)
        borde = min(s / RADIO_DE_ESQUINA, (largo - s) / RADIO_DE_ESQUINA, 1.0)
        ancho -= RADIO_DE_ESQUINA * (1 - math.sqrt(max(0.0, 1 - (1 - borde) ** 2)))
        respaldo = suave(0.58, 0.76, medio.z)
        fila = []
        for j in range(COLUMNAS):
            c = -1 + 2 * j / (COLUMNAS - 1)
            fila.append(
                Vector(
                    (
                        ancho * c,
                        medio.y + ENVOLTURA_DEL_RESPALDO * respaldo * c * c,
                        medio.z + HUECO_DEL_ASIENTO * (1 - respaldo) * c * c,
                    )
                )
            )
        arriba.append(fila)

    def derivadas(i: int, j: int) -> tuple[Vector, Vector]:
        a, b = arriba[max(i - 1, 0)][j], arriba[min(i + 1, FILAS - 1)][j]
        c, d = arriba[i][max(j - 1, 0)], arriba[i][min(j + 1, COLUMNAS - 1)]
        return (b - a).normalized(), (d - c).normalized()

    normales = [[Vector() for _ in range(COLUMNAS)] for _ in range(FILAS)]
    for i in range(FILAS):
        for j in range(COLUMNAS):
            a_lo_largo, a_lo_ancho = derivadas(i, j)
            normales[i][j] = a_lo_largo.cross(a_lo_ancho).normalized()
    if normales[FILAS // 3][COLUMNAS // 2].z < 0:
        normales = [[-n for n in fila] for fila in normales]

    sup, inf = [], []
    for i in range(FILAS):
        sup.append([armado.vertice(arriba[i][j], (arriba[i][j].x, recorridos[i])) for j in range(COLUMNAS)])
        inf.append(
            [
                armado.vertice(arriba[i][j] - normales[i][j] * GROSOR, (arriba[i][j].x, recorridos[i]))
                for j in range(COLUMNAS)
            ]
        )
    for i in range(FILAS - 1):
        for j in range(COLUMNAS - 1):
            esquina = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]
            armado.cara([sup[a][b] for a, b in esquina], [normales[a][b] for a, b in esquina], CARCASA)
            armado.cara([inf[a][b] for a, b in esquina], [-normales[a][b] for a, b in esquina], CARCASA)

    contorno = (
        [(0, j) for j in range(COLUMNAS)]
        + [(i, COLUMNAS - 1) for i in range(1, FILAS)]
        + [(FILAS - 1, j) for j in range(COLUMNAS - 2, -1, -1)]
        + [(i, 0) for i in range(FILAS - 2, 0, -1)]
    )
    afuera = {}
    for i, j in contorno:
        a_lo_largo, a_lo_ancho = derivadas(i, j)
        direccion = Vector()
        if j == 0:
            direccion -= a_lo_ancho
        if j == COLUMNAS - 1:
            direccion += a_lo_ancho
        if i == 0:
            direccion -= a_lo_largo
        if i == FILAS - 1:
            direccion += a_lo_largo
        n = normales[i][j]
        afuera[(i, j)] = (direccion - n * direccion.dot(n)).normalized()
    canto = {}
    for i, j in contorno:
        punto = arriba[i][j] - normales[i][j] * (GROSOR / 2) + afuera[(i, j)] * (GROSOR * 0.45)
        canto[(i, j)] = armado.vertice(punto, (punto.x + punto.y, punto.z))
    for k, actual in enumerate(contorno):
        siguiente = contorno[(k + 1) % len(contorno)]
        par = [actual, siguiente]
        n = [normales[i][j] for i, j in par]
        o = [afuera[p] for p in par]
        armado.cara(
            [sup[par[0][0]][par[0][1]], sup[par[1][0]][par[1][1]], canto[par[1]], canto[par[0]]],
            [(n[0] + o[0]).normalized(), (n[1] + o[1]).normalized(), o[1], o[0]],
            CARCASA,
        )
        armado.cara(
            [canto[par[0]], canto[par[1]], inf[par[1][0]][par[1][1]], inf[par[0][0]][par[0][1]]],
            [o[0], o[1], (o[1] - n[1]).normalized(), (o[0] - n[0]).normalized()],
            CARCASA,
        )
    return arriba


def fondo_de_la_carcasa(arriba: list[list[Vector]], y: float) -> float:
    """El alto de la cara de abajo del asiento en `y`, por la columna del medio."""
    medio = COLUMNAS // 2
    asiento = [fila[medio] for fila in arriba if fila[medio].z < 0.6]
    cercano = min(asiento, key=lambda p: abs(p.y - y))
    return cercano.z - GROSOR


def cono(armado: Armado, a: Vector, b: Vector, ra: float, rb: float, lados: int) -> None:
    eje = (b - a).normalized()
    u = eje.cross(Vector((0, 0, 1)) if abs(eje.z) < 0.9 else Vector((1, 0, 0))).normalized()
    v = eje.cross(u)
    anillos = []
    for centro, radio in ((a, ra), (b, rb)):
        anillo = []
        for k in range(lados):
            angulo = 2 * math.pi * k / lados
            radial = u * math.cos(angulo) + v * math.sin(angulo)
            anillo.append((armado.vertice(centro + radial * radio, (angulo * radio, centro.z)), radial))
        anillos.append(anillo)
    for k in range(lados):
        m = (k + 1) % lados
        armado.cara(
            [anillos[0][k][0], anillos[0][m][0], anillos[1][m][0], anillos[1][k][0]],
            [anillos[0][k][1], anillos[0][m][1], anillos[1][m][1], anillos[1][k][1]],
            PATAS,
        )
    armado.cara([v for v, _ in anillos[0]], [-eje] * lados, PATAS)
    armado.cara([v for v, _ in anillos[1]], [eje] * lados, PATAS)


def tabla(armado: Armado, a: Vector, b: Vector, ancho: float, alto: float) -> None:
    eje = (b - a).normalized()
    lado = eje.cross(Vector((0, 0, 1))).normalized()
    arriba = Vector((0, 0, 1))
    esquinas = []
    for punto in (a, b):
        for s, t in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            p = punto + lado * (s * ancho / 2) + arriba * (t * alto / 2)
            esquinas.append(armado.vertice(p, (p.x + p.y, p.z)))
    caras = [
        ([0, 1, 2, 3], -eje),
        ([4, 5, 6, 7], eje),
        ([0, 1, 5, 4], -arriba),
        ([3, 2, 6, 7], arriba),
        ([0, 3, 7, 4], -lado),
        ([1, 2, 6, 5], lado),
    ]
    for indices, normal in caras:
        armado.cara([esquinas[i] for i in indices], [normal] * 4, PATAS)


def patas(armado: Armado, arriba: list[list[Vector]]) -> None:
    x_arriba, y_adelante, y_atras = PATA_ARRIBA
    x_abajo, y_adelante_abajo, y_atras_abajo = PATA_ABAJO
    ejes = {}
    for sx in (-1, 1):
        for adelante, (y0, y1) in ((True, (y_adelante, y_adelante_abajo)), (False, (y_atras, y_atras_abajo))):
            tope = fondo_de_la_carcasa(arriba, y0) + 0.005
            a = Vector((sx * x_arriba, y0, tope))
            b = Vector((sx * x_abajo, y1, 0.0))
            ejes[(sx, adelante)] = (a, b)
            cono(armado, a, b, RADIO_ARRIBA, RADIO_ABAJO, LADOS_DE_PATA)

    def en_altura(eje: tuple[Vector, Vector], z: float) -> Vector:
        a, b = eje
        return a.lerp(b, (a.z - z) / (a.z - b.z))

    # El bastidor bajo el asiento: cuatro tablas que unen las patas por arriba.
    alto_del_bastidor = min(fondo_de_la_carcasa(arriba, y) for y in (y_adelante, y_atras)) - 0.017
    vueltas = [(-1, True), (1, True), (1, False), (-1, False)]
    for k, actual in enumerate(vueltas):
        siguiente = vueltas[(k + 1) % 4]
        tabla(
            armado,
            en_altura(ejes[actual], alto_del_bastidor),
            en_altura(ejes[siguiente], alto_del_bastidor),
            0.016,
            0.032,
        )
    # El travesaño en H: uno por lado y uno que los cruza.
    medios = []
    for sx in (-1, 1):
        a = en_altura(ejes[(sx, True)], ALTO_DEL_TRAVESANO)
        b = en_altura(ejes[(sx, False)], ALTO_DEL_TRAVESANO)
        cono(armado, a, b, RADIO_DEL_TRAVESANO, RADIO_DEL_TRAVESANO, 8)
        medios.append(a.lerp(b, 0.5))
    cono(armado, medios[0], medios[1], RADIO_DEL_TRAVESANO, RADIO_DEL_TRAVESANO, 8)


def plastico():
    material = bpy.data.materials.get(PLASTICO) or bpy.data.materials.new(PLASTICO)
    material.use_nodes = True
    nodos = material.node_tree.nodes
    for nodo in list(nodos):
        if nodo.type == "TEX_IMAGE":
            nodos.remove(nodo)
    principal = next(n for n in nodos if n.type == "BSDF_PRINCIPLED")
    principal.inputs["Base Color"].default_value = COLOR_DEL_PLASTICO
    principal.inputs["Roughness"].default_value = RUGOSIDAD_DEL_PLASTICO
    principal.inputs["Metallic"].default_value = 0.0
    material.diffuse_color = COLOR_DEL_PLASTICO
    return material


def volcar(armado: Armado, malla) -> None:
    malla.materials[CARCASA] = plastico()
    materiales = list(malla.materials)
    malla.clear_geometry()
    malla.from_pydata([tuple(v * ESCALA) for v in armado.vertices], [], [c[0] for c in armado.caras])
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
    arriba = carcasa(armado)
    patas(armado, arriba)
    volcar(armado, malla)
    despues = sum(len(p.vertices) - 2 for p in malla.polygons)
    print(f"{MALLA}: {antes} -> {despues} triángulos, en {malla.users} sillas")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
