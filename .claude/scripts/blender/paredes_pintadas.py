"""Pinta las paredes del salón y del baño con la foto de una pared pintada real.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/paredes_pintadas.py -- [--aplicar] \
        [--foto RUTA --metros LADO]

Sin `--aplicar` pinta en una carpeta temporal y no guarda nada. Con `--aplicar` escribe las
texturas en `assets/source/textures/store/` y guarda la fuente canónica. `--foto` prueba otra
foto en los dos recintos; `--metros` es el lado que cubre la foto en la pared. Después van
`armar_atlas.py`, `exportar_modelo.py` y `assets/models/extraer_mallas.gd`. La UV sale sólo de
la geometría: si el `.blend` ya la tenía, el horneado no cambia. Si no, piden `hornear.py` y
`hornear.py --sin-luz`.

## Por qué

La pared del salón (`local_pared_pintada`) y la del baño (`bano_pared_clara`) eran un color liso.
Después las pintó un ruido propio, y se veían como manchas de nube, sin el carácter de una pared
real. Ahora la base es la foto de una pared de revoque pintado (`painted_plaster_wall`, CC0, en
`assets/source/textures/third-party/painted_plaster_wall/`). La luz del local está horneada, así que el
detalle va en el color y no en la rugosidad: la pared sigue siendo pintura mate.

## Qué cambia

- **Cada pared del recinto tiene su rectángulo en una textura de color de 1024 px.** La UV es
  planar y mide lo mismo en los dos sentidos: los texeles del salón son de 1,4 cm, los del baño
  de 1,1 cm. Las caras que no son pared del recinto (el frente de afuera, las jambas, el techo,
  los cantos) van a un parche liso del color de siempre: **su aspecto no cambia**.
- **La foto entera es el color de la pared, a su escala real.** Se promedia por área a la
  densidad de la textura y se divide por su media en cada canal: queda la pintura de la foto,
  teñida al color de cada pared. La media de cada pared es el tono liso de antes.
- **La repetición se rompe con un segundo mosaico,** espejado a lo ancho y desfasado, que
  aparece en manchas de 1,6 m. Cada pared arranca en otro punto de la foto.
- **Encima, sutil, la mugre de uso:** al pie, alrededor de cada vano, raspones y marcas de
  zapato; en el baño, la humedad al pie y lo que dejan las piletas y los inodoros.
- **Cada material gana una textura de color y nada más.** El brillo, la rugosidad y el resto del
  material no se tocan. No hay materiales ni superficies nuevas. Ningún triángulo se suma.

**El juego la filtra lineal** (`assets/models/importar_modelo.gd`), como el concreto del
depósito. Con el filtro pixelado, la foto se leía como cuadraditos.

## Lo que cuesta

Una textura de 1024 px por recinto. Sin materiales ni dibujos nuevos. Es idempotente: la UV y
los PNG salen sólo de la geometría, de la foto y de las constantes, con una semilla fija por
pared.
"""

import sys
import tempfile
import zlib
from dataclasses import dataclass, field
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np
from mathutils import Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parent))
import listonar_frente_de_madera as madera  # noqa: E402
import metal_detalle as metal  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

configurar()

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
CARPETA = RAIZ / "assets/source/textures/store"
TERCEROS = RAIZ / "assets/source/textures/third-party"
EDIFICIO = "almacen-col"

#: El lado de la textura. Es el tope con el que viaja el color de un edificio.
LADO = 1024
#: Texeles de más que lleva cada pared alrededor, pintados con la misma receta: los mipmaps
#: promedian de a muchos texeles, y sin colchón una pared se tiñe con su vecina de la textura.
COLCHON = 8
PARCHE = 16

#: Cuánto puede sobresalir una cara de pared del rectángulo: el espesor del muro (12 cm).
ESPESOR = 0.15

#: El alto de las paredes, medido desde el piso.
PISO = 0.10

#: La mugre es un tono cálido y apagado: oscurece y entibia a la vez.
MUGRE = np.array([0.60, 0.57, 0.50], dtype=np.float32)
#: El churrete de agua enfría un poco.
HUMEDAD = np.array([0.80, 0.86, 0.86], dtype=np.float32)

#: Qué tanto cuenta cada desperfecto. Es la fracción de luz que le saca al color.
PIE = 0.05
VANO = 0.035
HUMEDAD_DEL_BANO = 0.04
CHURRETE = 0.04
SALPICADURA = 0.06


@dataclass(frozen=True)
class Plano:
    """Una pared del recinto: el eje de su normal, dónde está y hacia dónde mira."""

    eje: int  # 0: la pared está en x = coord; 1: está en y = coord
    coord: float
    signo: int  # +1 si la normal mira a +eje (el recinto queda del lado de +eje)


@dataclass(frozen=True)
class Mueble:
    """Un objeto del local que ensucia la pared que tiene cerca."""

    nombre: str  # el nombre del objeto o su prefijo
    tipo: str  # pileta o inodoro
    alcance: float  # hasta dónde, en metros, deja su marca en la pared


@dataclass(frozen=True)
class Foto:
    """La foto de una pared y el lado que cubre, en metros, como lo dice su página."""

    ruta: Path
    metros: float


@dataclass(frozen=True)
class Recinto:
    nombre: str
    material: str
    planos: tuple[Plano, ...]
    techo: float
    archivo: str
    humedad: bool
    foto: Foto
    muebles: tuple[Mueble, ...] = field(default=())


FOTO_DEL_SALON = Foto(TERCEROS / "painted_plaster_wall/painted_plaster_wall_diff_2k.jpg", 2.0)
FOTO_DEL_BANO = FOTO_DEL_SALON

SALON = Recinto(
    nombre="salon",
    material="local_pared_pintada",
    planos=(Plano(0, -2.48, +1), Plano(0, 7.87, -1), Plano(1, -6.28, +1), Plano(1, 7.87, -1)),
    techo=3.5,
    archivo="pared_del_salon_color.png",
    humedad=False,
    foto=FOTO_DEL_SALON,
)
BANO = Recinto(
    nombre="bano",
    material="bano_pared_clara",
    planos=(Plano(0, 8.29, +1), Plano(0, 13.43, -1), Plano(1, -6.28, +1), Plano(1, 0.33, -1)),
    techo=3.47,
    archivo="pared_del_bano_color.png",
    humedad=True,
    foto=FOTO_DEL_BANO,
    muebles=(
        Mueble("bano_lavatorio", "pileta", 0.5),
        Mueble("vanitory", "pileta", 0.5),
        Mueble("inodoro", "inodoro", 0.5),
        Mueble("bano_inodoro", "inodoro", 0.5),
    ),
)
RECINTOS = (SALON, BANO)


# ── la geometría ─────────────────────────────────────────────────────────────────────────────


@dataclass
class Pared:
    """El rectángulo de una pared en la textura, y la pintura que le toca."""

    plano: Plano
    s0: float  # dónde empieza, a lo largo de la pared, vista desde adentro
    s1: float
    px: int = 0  # su esquina de abajo a la izquierda, en texeles
    py: int = 0
    ancho: int = 0
    alto: int = 0
    triangulos: list = field(default_factory=list)  # (3 puntos (s, z)) de sus caras
    fijos: list = field(default_factory=list)  # (tipo, s0, s1, z0, z1, distancia)


def _derecha(plano: Plano) -> Vector:
    """El sentido en el que crece `s`: la derecha de quien mira la pared desde adentro."""
    normal = Vector((0.0, 0.0, 0.0))
    normal[plano.eje] = float(plano.signo)
    return (-normal).cross(Vector((0.0, 0.0, 1.0)))


def coordenada_s(plano: Plano, punto: Vector) -> float:
    return _derecha(plano).dot(punto)


def paredes_de(recinto: Recinto) -> list[Pared]:
    """Una pared por plano, con el largo del recinto en ese sentido."""
    rango = {
        eje: sorted(p.coord for p in recinto.planos if p.eje == eje) for eje in (0, 1)
    }
    paredes = []
    for plano in recinto.planos:
        a, b = rango[1 - plano.eje]  # la pared en x corre a lo largo de y, y al revés
        derecha = _derecha(plano)
        extremos = []
        for coord in (a, b):
            punto = Vector((0.0, 0.0, 0.0))
            punto[1 - plano.eje] = coord
            extremos.append(derecha.dot(punto))
        paredes.append(Pared(plano, min(extremos), max(extremos)))
    return paredes


def acomodar(paredes: list[Pared], alto_m: float) -> int:
    """Reparte los rectángulos en `LADO` x `LADO` con la mayor densidad entera que entre.

    Devuelve los texeles por metro. Una hilera de rectángulos del mismo alto, y otra cuando se
    acaba el ancho. Cada pared lleva `COLCHON` de cada lado, y queda reservado el parche.
    """
    for densidad in range(160, 39, -1):
        alto = int(np.ceil(alto_m * densidad))
        x, y, fila_alto, entra = 0, 0, 0, True
        for pared in paredes:
            ancho = int(np.ceil((pared.s1 - pared.s0) * densidad))
            if ancho + 2 * COLCHON > LADO:
                entra = False
                break
            if x + ancho + 2 * COLCHON > LADO:
                x, y = 0, y + fila_alto
                fila_alto = 0
            pared.px, pared.py = x + COLCHON, y + COLCHON
            pared.ancho, pared.alto = ancho, alto
            x += ancho + 2 * COLCHON
            fila_alto = max(fila_alto, alto + 2 * COLCHON)
        if entra and y + fila_alto + PARCHE <= LADO:
            return densidad
    raise ValueError("las paredes no entran en la textura ni a 40 texeles por metro")


def uv_de(pared: Pared, densidad: int, s: float, z: float) -> tuple[float, float]:
    u = (pared.px + (s - pared.s0) * densidad) / LADO
    v = (pared.py + (z - PISO) * densidad) / LADO
    return u, v


def _vertices_en_el_mundo(objeto, cara) -> list[Vector]:
    malla = objeto.data
    return [objeto.matrix_world @ malla.vertices[malla.loops[i].vertex_index].co
            for i in cara.loop_indices]


def pared_de_la_cara(paredes: list[Pared], recinto: Recinto, objeto, cara) -> Pared | None:
    """La pared del recinto a la que pertenece una cara, o `None` si no es de ninguna.

    Una cara es pared si es vertical, mira hacia adentro del recinto, está sobre su plano y no
    sale del rectángulo de la pared. Todo lo demás —el frente de afuera, las jambas, los
    cielorrasos, lo que sobresale por arriba— no cambia de aspecto.
    """
    normal = (objeto.matrix_world.to_3x3() @ cara.normal).normalized()
    puntos = _vertices_en_el_mundo(objeto, cara)
    for pared in paredes:
        plano = pared.plano
        if normal[plano.eje] * plano.signo < 0.99:
            continue
        if any(abs(p[plano.eje] - plano.coord) > 0.02 for p in puntos):
            continue
        ss = [coordenada_s(plano, p) for p in puntos]
        zs = [p.z for p in puntos]
        if min(ss) < pared.s0 - ESPESOR or max(ss) > pared.s1 + ESPESOR:
            continue
        if min(zs) < PISO - 0.05 or max(zs) > recinto.techo + 0.05:
            continue
        return pared
    return None


def recoger_caras(recinto: Recinto, paredes: list[Pared]) -> tuple[list, list]:
    """Las caras del material del recinto: las de pared, con su pared, y las demás.

    Anota en cada pared los triángulos que la cubren, para saber dónde hay vano.
    """
    objeto = bpy.data.objects[EDIFICIO]
    malla = objeto.data
    indices = {i for i, m in enumerate(malla.materials) if m and m.name == recinto.material}
    malla.calc_loop_triangles()
    por_cara: dict[int, list] = {}
    for triangulo in malla.loop_triangles:
        por_cara.setdefault(triangulo.polygon_index, []).append(triangulo)
    de_pared, otras = [], []
    for cara in malla.polygons:
        if cara.material_index not in indices:
            continue
        pared = pared_de_la_cara(paredes, recinto, objeto, cara)
        if pared is None:
            otras.append(cara)
            continue
        de_pared.append((cara, pared))
        for triangulo in por_cara.get(cara.index, []):
            puntos = [objeto.matrix_world @ malla.vertices[v].co for v in triangulo.vertices]
            pared.triangulos.append(
                [(coordenada_s(pared.plano, p), p.z) for p in puntos]
            )
    return de_pared, otras


def anotar_muebles(recinto: Recinto, paredes: list[Pared]) -> list[str]:
    """Qué objeto del local queda cerca de qué pared, con su lugar a lo largo de ella."""
    visto = []
    for objeto in bpy.data.objects:
        if objeto.type != "MESH":
            continue
        for mueble in recinto.muebles:
            if not objeto.name.startswith(mueble.nombre):
                continue
            esquinas = [objeto.matrix_world @ Vector(c) for c in objeto.bound_box]
            for pared in paredes:
                plano = pared.plano
                # Qué tan lejos queda de la pared el lado más cercano del objeto.
                if plano.signo > 0:
                    distancia = min(p[plano.eje] for p in esquinas) - plano.coord
                else:
                    distancia = plano.coord - max(p[plano.eje] for p in esquinas)
                if distancia > mueble.alcance or distancia < -0.3:
                    continue
                ss = [coordenada_s(plano, p) for p in esquinas]
                zs = [p.z for p in esquinas]
                pared.fijos.append(
                    (mueble.tipo, min(ss), max(ss), min(zs), max(zs), max(distancia, 0.0))
                )
                visto.append(f"{recinto.nombre}: {objeto.name} -> pared {plano.eje}/{plano.coord}")
    return visto


# ── el ruido y las distancias ────────────────────────────────────────────────────────────────


def _centrado(n: np.ndarray) -> np.ndarray:
    """Media cero y desvío 1, medidos sobre la propia pared."""
    return (n - n.mean()) / max(float(n.std()), 1e-6)


def ruido(s, t, escala_s, escala_t, octavas, semilla, capa) -> np.ndarray:
    """Ruido suave de media 0 y desvío 1. `escala_*` es el tamaño del rasgo, en metros."""
    return _centrado(
        metal._fbm(
            s / escala_s, t / escala_t, np.full_like(s, capa * 3.7), 1.0, octavas, semilla
        )
    )


def distancia_en_texeles(abierto: np.ndarray) -> np.ndarray:
    """La distancia a lo abierto (chamfer de dos pasadas), en texeles. 0 adentro de lo abierto."""
    grande = np.float32(1e6)
    d = np.where(abierto, np.float32(0), grande).astype(np.float32)
    filas, columnas = d.shape
    indice = np.arange(columnas, dtype=np.float32)
    diagonal = np.float32(np.sqrt(2.0))

    def barrer(fila: np.ndarray) -> np.ndarray:
        fila = np.minimum.accumulate(fila - indice) + indice
        return np.minimum.accumulate((fila + indice)[::-1])[::-1] - indice

    for rango in (range(filas), range(filas - 1, -1, -1)):
        anterior = None
        for i in rango:
            fila = d[i]
            if anterior is not None:
                fila = np.minimum(fila, anterior + 1)
                fila[1:] = np.minimum(fila[1:], anterior[:-1] + diagonal)
                fila[:-1] = np.minimum(fila[:-1], anterior[1:] + diagonal)
            d[i] = anterior = barrer(fila)
    return d


def _suave(a: float, b: float, x: np.ndarray) -> np.ndarray:
    return metal._suave(a, b, x)


def _cubrir(mascara: np.ndarray, triangulo, s: np.ndarray, t: np.ndarray) -> None:
    """Marca como cubiertos los puntos `(s, t)` que caen adentro de un triángulo."""
    (s0, t0), (s1, t1), (s2, t2) = triangulo
    area = (s1 - s0) * (t2 - t0) - (s2 - s0) * (t1 - t0)
    if abs(area) < 1e-9:
        return
    a = ((s1 - s) * (t2 - t) - (s2 - s) * (t1 - t)) / area
    b = ((s2 - s) * (t0 - t) - (s0 - s) * (t2 - t)) / area
    c = 1.0 - a - b
    margen = -1e-6
    mascara |= (a >= margen) & (b >= margen) & (c >= margen)


# ── la pintura ───────────────────────────────────────────────────────────────────────────────


def _semilla(texto: str) -> int:
    return zlib.crc32(texto.encode()) & 0x7FFFFFFF


def _reparto(color: np.ndarray) -> np.ndarray:
    """Cuánto pierde cada canal: la luz pierde `cantidad` en promedio y el resto se tiñe."""
    perdida = 1.0 - color
    return perdida / perdida.mean()


class Lienzo:
    """La luz y el tinte que le toca a cada texel de una pared, antes de teñir el color base.

    El tinte arranca en la foto: cada texel es la pintura de la foto relativa a su media.
    """

    def __init__(self, s: np.ndarray, t: np.ndarray, foto: np.ndarray):
        self.s, self.t = s, t
        self.luz = np.ones(s.shape, dtype=np.float32)
        self.tinte = foto.astype(np.float32)

    def ensuciar(self, cantidad: np.ndarray, color: np.ndarray = MUGRE) -> None:
        """`cantidad` es la fracción de luz que pierde; `color` es el tono de lo que se acumula."""
        cantidad = np.clip(cantidad, 0.0, 0.5)[..., None]
        self.tinte *= 1.0 - cantidad * _reparto(color)


def _suciedad_general(lienzo, semilla, capa, densidad, distancia_a_vano):
    s, t = lienzo.s, lienzo.t
    altura = t - PISO
    # Abajo: lo que se junta al pie de la pared. Las patadas y la fregona dejan franjas bajas.
    franjas = ruido(s, t, 0.9, 0.06, 2, semilla + 8, capa)
    borde = _suave(0.0, 1.0, 1.0 - altura / 0.55)
    manchas = ruido(s, t, 0.5, 0.5, 2, semilla + 9, capa)
    pie = PIE * borde**1.5 * (0.65 + 0.2 * franjas + 0.15 * manchas)
    lienzo.ensuciar(pie)
    # Alrededor de cada vano: la mano busca el borde, sobre todo a la altura del pecho.
    metros = distancia_a_vano / densidad
    mano = 0.55 + 0.9 * np.exp(-(((t - 1.05) / 0.40) ** 2))
    vano = VANO * np.exp(-metros / 0.11) * mano
    vano *= 0.6 + 0.4 * ruido(s, t, 0.3, 0.3, 2, semilla + 12, capa)
    lienzo.ensuciar(vano * (distancia_a_vano > 0))


def _aureola(s, t, centro_s, centro_t, radio_s, radio_t):
    """Una mancha elíptica y suave, de 1 en el centro a 0 en el borde."""
    r2 = ((s - centro_s) / radio_s) ** 2 + ((t - centro_t) / radio_t) ** 2
    return np.exp(-r2 * 1.6) * (r2 < 1.0)


def _muebles(lienzo, pared, semilla, capa) -> None:
    s, t = lienzo.s, lienzo.t
    for n, (tipo, s0, s1, z0, z1, _distancia) in enumerate(pared.fijos):
        centro = 0.5 * (s0 + s1)
        irregular = 0.65 + 0.35 * ruido(s, t, 0.25, 0.25, 2, semilla + 20 + n, capa)
        if tipo == "pileta":
            _pileta(lienzo, pared, s0, s1, z0, z1, semilla + 40 + n, capa)
        elif tipo == "inodoro":
            marca = _aureola(s, t, centro, PISO, 0.36, 0.55)
            lienzo.ensuciar(0.045 * marca * irregular, HUMEDAD)


def _pileta(lienzo, pared, s0, s1, z0, z1, semilla, capa) -> None:
    """Churretes bajo la pileta y salpicaduras sobre su borde."""
    s, t = lienzo.s, lienzo.t
    azar = np.random.default_rng(semilla)
    ancho = s1 - s0
    # Una sombra húmeda debajo, donde gotea.
    debajo = _aureola(s, t, 0.5 * (s0 + s1), z0 - 0.15, 0.55 * ancho + 0.1, 0.30)
    lienzo.ensuciar(0.35 * CHURRETE * debajo, HUMEDAD)
    # Los churretes: tiras finas que caen desde la pileta.
    for _ in range(9):
        x = azar.uniform(s0 + 0.05, s1 - 0.05)
        largo = azar.uniform(0.15, 0.50)
        grueso = azar.uniform(0.008, 0.02)
        arranque = _suave(0.0, 0.15, (z0 + 0.02 - t) / largo)
        a_lo_largo = arranque * _suave(0.0, 0.5, 1.0 - (z0 - t) / largo)
        tira = np.exp(-(((s - x - 0.01 * np.sin(t * 17.0 + x)) / grueso) ** 2))
        fuerza = CHURRETE * azar.uniform(0.5, 1.0)
        lienzo.ensuciar(fuerza * tira * a_lo_largo * (t < z0 + 0.02), HUMEDAD)
    # Las salpicaduras: gotitas sobre el borde y a los costados, más ralas cuanto más lejos.
    borde = z0 + 0.30
    cantidad = int(70 * (ancho + 0.3))
    for _ in range(cantidad):
        x = azar.normal(0.5 * (s0 + s1), 0.55 * ancho + 0.05)
        y = borde + abs(azar.normal(0.0, 0.16)) * (1.0 if azar.random() < 0.8 else -0.6)
        tamano = azar.uniform(0.005, 0.014)
        gota = np.exp(-((((s - x) / tamano) ** 2 + ((t - y) / tamano) ** 2)))
        lienzo.ensuciar(SALPICADURA * azar.uniform(0.4, 1.0) * gota, HUMEDAD)


def _humedad(lienzo, semilla, capa) -> None:
    """Humedad al pie del baño: nunca pasa de 50 cm y su borde es irregular."""
    s, t = lienzo.s, lienzo.t
    altura = t - PISO
    tope = 0.30 + 0.10 * ruido(s, t, 0.7, 0.7, 2, semilla + 30, capa)
    tope = np.clip(tope, 0.15, 0.48)
    mancha = _suave(0.0, 1.0, 1.0 - altura / tope)
    mancha *= 0.55 + 0.45 * _suave(-0.6, 0.6, ruido(s, t, 0.35, 0.35, 3, semilla + 31, capa))
    lienzo.ensuciar(HUMEDAD_DEL_BANO * mancha, HUMEDAD)


def _trazo(lienzo, desde, hasta, ancho, valor, color=MUGRE) -> None:
    """Una raya de `ancho` metros: oscurece si `valor` es positivo y aclara si es negativo."""
    s, t = lienzo.s, lienzo.t
    paso = abs(s[0, 1] - s[0, 0])
    (a_s, a_t), (b_s, b_t) = desde, hasta
    # Sólo se tocan los texeles cercanos a la raya.
    s_min, s_max = min(a_s, b_s) - 3 * paso, max(a_s, b_s) + 3 * paso
    t_min, t_max = min(a_t, b_t) - 3 * paso, max(a_t, b_t) + 3 * paso
    columnas = np.where((s[0] >= s_min) & (s[0] <= s_max))[0]
    filas = np.where((t[:, 0] >= t_min) & (t[:, 0] <= t_max))[0]
    if len(columnas) == 0 or len(filas) == 0:
        return
    ventana = np.ix_(filas, columnas)
    ps, pt = s[ventana], t[ventana]
    dx, dy = b_s - a_s, b_t - a_t
    largo2 = max(dx * dx + dy * dy, 1e-12)
    u = np.clip(((ps - a_s) * dx + (pt - a_t) * dy) / largo2, 0.0, 1.0)
    distancia = np.hypot(ps - (a_s + u * dx), pt - (a_t + u * dy))
    cobertura = np.clip(1.0 - (distancia - ancho * 0.5) / (0.7 * paso), 0.0, 1.0)
    if valor >= 0:
        lienzo.tinte[ventana] *= 1.0 - (cobertura * valor)[..., None] * _reparto(color)
    else:
        lienzo.luz[ventana] += cobertura * (-valor)


def _marcas(lienzo, pared, recinto, azar) -> int:
    """Raspones, golpecitos y marcas de zapato de 1 a 4 cm, más seguidos cerca del piso."""
    ancho_m = pared.s1 - pared.s0
    area = ancho_m * (recinto.techo - PISO)
    hechas = 0
    clases = (("zapato", 0.6, 0.55), ("raspon", 1.0, 2.2), ("golpe", 0.4, 2.4))
    for tipo, por_metro2, z_max in clases:
        cantidad = int(round(por_metro2 * area * (z_max - PISO) / (recinto.techo - PISO)))
        for _ in range(cantidad):
            s = azar.uniform(pared.s0 + 0.02, pared.s1 - 0.02)
            # Cuanto más abajo, más seguido: la altura sale de una cola corta.
            z = PISO + 0.05 + (z_max - PISO) * azar.random() ** 1.8
            if tipo == "zapato":
                largo = azar.uniform(0.025, 0.04)
                angulo = azar.normal(0.0, 0.25)
                destino = (s + largo * np.cos(angulo), z + largo * np.sin(angulo))
                _trazo(lienzo, (s, z), destino, 0.012, azar.uniform(0.11, 0.20))
            elif tipo == "raspon":
                largo = azar.uniform(0.012, 0.04)
                angulo = azar.uniform(0.0, np.pi)
                destino = (s + largo * np.cos(angulo), z + largo * np.sin(angulo))
                if azar.random() < 0.55:
                    # Quedó el revoque al aire: más claro que la pintura.
                    _trazo(lienzo, (s, z), destino, 0.007, -azar.uniform(0.06, 0.11))
                else:
                    _trazo(lienzo, (s, z), destino, 0.007, azar.uniform(0.11, 0.19))
            else:
                # Un golpecito: un punto claro con su sombra.
                radio = azar.uniform(0.006, 0.012)
                _trazo(lienzo, (s, z), (s, z), radio, -azar.uniform(0.05, 0.09))
                _trazo(lienzo, (s - 0.004, z - 0.006), (s - 0.004, z - 0.006), radio * 0.7,
                       azar.uniform(0.09, 0.15))
            hechas += 1
    return hechas


def leer_foto(foto: Foto) -> np.ndarray:
    """La foto en luz lineal, con la fila 0 abajo como la textura."""
    imagen = bpy.data.images.load(str(foto.ruta), check_existing=False)
    ancho, alto = imagen.size
    pixeles = np.empty(ancho * alto * 4, dtype=np.float32)
    imagen.pixels.foreach_get(pixeles)
    bpy.data.images.remove(imagen)
    srgb = pixeles.reshape(alto, ancho, 4)[..., :3]
    return np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)


def mosaico(foto: Foto, lineal: np.ndarray, densidad: int) -> np.ndarray:
    """La pintura de la foto a la densidad de la textura, relativa a su media por canal.

    Promediada por área: de 2 K a unos 140 texeles, un muestreo directo dejaría ruido. Se divide
    cada canal por su media (con piso de 0,35 del canal mayor por si se prueba una foto muy
    saturada): queda la foto entera —luz y matiz— teñida al color de cada pared.
    """
    lado = max(int(round(foto.metros * densidad)), 2)
    reducida = madera.remuestrear(lineal, lado, lado)
    media = reducida.mean(axis=(0, 1))
    divisor = np.maximum(media, 0.35 * float(media.max()))
    return reducida / divisor


def _muestrear(mosaico_: np.ndarray, x: np.ndarray, y: np.ndarray) -> np.ndarray:
    """Bilineal y repetida: `x`, `y` en texeles del mosaico, la columna y la fila."""
    alto, ancho = mosaico_.shape[:2]
    fx, fy = x - 0.5, y - 0.5
    x0, y0 = np.floor(fx), np.floor(fy)
    wx, wy = (fx - x0)[..., None], (fy - y0)[..., None]
    x0, y0 = x0.astype(int) % ancho, y0.astype(int) % alto
    x1, y1 = (x0 + 1) % ancho, (y0 + 1) % alto
    abajo = mosaico_[y0, x0] * (1 - wx) + mosaico_[y0, x1] * wx
    arriba = mosaico_[y1, x0] * (1 - wx) + mosaico_[y1, x1] * wx
    return abajo * (1 - wy) + arriba * wy


def _foto_en_la_pared(mosaico_, s, t, densidad, azar, semilla, capa) -> np.ndarray:
    """La foto a su escala, con un segundo mosaico espejado y desfasado en manchas de 1,6 m.

    Cada pared arranca en otro punto de la foto. El espejo es a lo ancho: lo vertical de la
    foto, como las pasadas del rodillo, sigue vertical. La mezcla conserva la varianza para no
    alisar la pintura en la transición entre los dos mosaicos.
    """
    lado = mosaico_.shape[0]
    x, y = s * densidad, t * densidad
    dx_a, dy_a = azar.uniform(0, lado), azar.uniform(0, lado)
    dx_b = azar.uniform(0, lado)
    dy_b = (dy_a + azar.uniform(0.35, 0.65) * lado) % lado
    a = _muestrear(mosaico_, x + dx_a, y + dy_a)
    b = _muestrear(mosaico_, -x + dx_b, y + dy_b)
    mezcla = _suave(-0.30, 0.30, ruido(s, t, 1.6, 1.6, 2, semilla + 70, capa))[..., None]
    media = mosaico_.mean(axis=(0, 1))
    escala = np.sqrt((1.0 - mezcla) ** 2 + mezcla**2)
    combinado = media + ((a - media) * (1.0 - mezcla) + (b - media) * mezcla) / escala
    return np.clip(combinado, 0.1, 2.5)


def pintar(recinto: Recinto, pared: Pared, indice: int, densidad: int, mosaico_: np.ndarray):
    """La pintura de una pared: un arreglo (alto, ancho, 3) de luz lineal relativa a la base."""
    semilla = _semilla(f"{recinto.nombre}-{pared.plano.eje}-{pared.plano.coord}")
    azar = np.random.default_rng(semilla)
    alto = pared.alto + 2 * COLCHON
    ancho = pared.ancho + 2 * COLCHON
    columnas = (np.arange(ancho, dtype=np.float64) + 0.5 - COLCHON) / densidad
    filas = (np.arange(alto, dtype=np.float64) + 0.5 - COLCHON) / densidad
    s = np.broadcast_to(pared.s0 + columnas[None, :], (alto, ancho)).astype(np.float32).copy()
    t = np.broadcast_to(PISO + filas[:, None], (alto, ancho)).astype(np.float32).copy()
    foto = _foto_en_la_pared(mosaico_, s, t, densidad, azar, semilla, indice)
    lienzo = Lienzo(s, t, foto)

    # Qué texeles son pared y cuáles vano, dentro del rectángulo; el colchón repite el borde.
    cubierto = np.zeros((pared.alto, pared.ancho), dtype=bool)
    adentro = (slice(COLCHON, -COLCHON), slice(COLCHON, -COLCHON))
    interior_s, interior_t = s[adentro], t[adentro]
    for triangulo in pared.triangulos:
        _cubrir(cubierto, triangulo, interior_s, interior_t)
    vano = np.pad(~cubierto, COLCHON, mode="edge")
    distancia = distancia_en_texeles(vano)

    _suciedad_general(lienzo, semilla, indice, densidad, distancia)
    _muebles(lienzo, pared, semilla, indice)
    if recinto.humedad:
        _humedad(lienzo, semilla, indice)
    hechas = _marcas(lienzo, pared, recinto, azar)

    color = lienzo.luz[..., None] * lienzo.tinte
    # Sobre el vano no hay pared: no cuenta para la media.
    pesos = np.pad(cubierto, COLCHON, mode="constant", constant_values=False)
    media = (color * pesos[..., None]).sum(axis=(0, 1)) / max(pesos.sum(), 1)
    relativo = (color / media)[..., 1][pesos]
    return color / media, hechas, float(relativo.std()), float(np.percentile(relativo, 1))


# ── el color y el PNG ────────────────────────────────────────────────────────────────────────


def _a_srgb(lineal: np.ndarray) -> np.ndarray:
    lineal = np.clip(lineal, 0.0, 1.0)
    return np.where(lineal <= 0.0031308, lineal * 12.92, 1.055 * lineal ** (1 / 2.4) - 0.055)


def pintar_recinto(recinto: Recinto, foto: Foto) -> tuple[np.ndarray, dict]:
    """La textura del recinto y lo que hace falta para escribir su UV."""
    material = bpy.data.materials[recinto.material]
    entrada = material.node_tree.nodes["Principled BSDF"].inputs["Base Color"]
    base = np.array(entrada.default_value[:3], dtype=np.float32)
    paredes = paredes_de(recinto)
    densidad = acomodar(paredes, recinto.techo - PISO)
    de_pared, otras = recoger_caras(recinto, paredes)
    notas = anotar_muebles(recinto, paredes)
    mosaico_ = mosaico(foto, leer_foto(foto), densidad)

    textura = np.ones((LADO, LADO, 3), dtype=np.float32) * base
    resumen = [f"    foto {foto.ruta.name}: {foto.metros} m en {mosaico_.shape[0]} texeles"]
    marcas = 0
    for indice, pared in enumerate(paredes):
        pintura, hechas, desvio, oscuro = pintar(recinto, pared, indice, densidad, mosaico_)
        marcas += hechas
        y0, x0 = pared.py - COLCHON, pared.px - COLCHON
        textura[y0 : y0 + pintura.shape[0], x0 : x0 + pintura.shape[1]] = base * pintura
        resumen.append(
            f"    pared {pared.plano.eje}/{pared.plano.coord}: {pared.ancho}x{pared.alto} px, "
            f"{len(pared.triangulos)} triángulos, {len(pared.fijos)} objetos cerca, "
            f"{hechas} marcas, desvío {desvio * 100:.1f} %, "
            f"el 1 % más oscuro pierde {(1 - oscuro) * 100:.0f} %"
        )
    # El parche liso, al fondo: lo que no es pared del recinto cae acá, del color de siempre.
    parche = (LADO - PARCHE, LADO - PARCHE)
    textura[parche[0] :, parche[1] :] = base
    pixeles = _a_srgb(textura)
    info = {
        "paredes": paredes,
        "densidad": densidad,
        "de_pared": de_pared,
        "otras": otras,
        "parche": ((parche[1] + PARCHE / 2) / LADO, (parche[0] + PARCHE / 2) / LADO),
        "resumen": resumen,
        "notas": notas,
        "marcas": marcas,
    }
    return np.clip(pixeles, 0.0, 1.0).astype(np.float32), info


# ── el modelo ────────────────────────────────────────────────────────────────────────────────


def escribir_uv(recinto: Recinto, info: dict) -> None:
    malla = bpy.data.objects[EDIFICIO].data
    capa = malla.uv_layers[0].data
    densidad = info["densidad"]
    mundo = bpy.data.objects[EDIFICIO].matrix_world
    for cara, pared in info["de_pared"]:
        for lazo in cara.loop_indices:
            punto = mundo @ malla.vertices[malla.loops[lazo].vertex_index].co
            capa[lazo].uv = uv_de(pared, densidad, coordenada_s(pared.plano, punto), punto.z)
    for cara in info["otras"]:
        for lazo in cara.loop_indices:
            capa[lazo].uv = info["parche"]
    malla.update()


def _imagen(ruta: Path) -> "bpy.types.Image":
    imagen = bpy.data.images.load(str(ruta), check_existing=True)
    imagen.reload()
    imagen.filepath = bpy.path.relpath(str(ruta))
    imagen.colorspace_settings.name = "sRGB"
    return imagen


def cablear(recinto: Recinto, ruta: Path) -> None:
    arbol = bpy.data.materials[recinto.material].node_tree
    principal = arbol.nodes["Principled BSDF"]
    nodo = arbol.nodes.get("Pared pintada") or arbol.nodes.new("ShaderNodeTexImage")
    nodo.name = nodo.label = "Pared pintada"
    nodo.image = _imagen(ruta)
    nodo.interpolation = "Linear"
    nodo.location = (-700, 300)
    arbol.links.new(nodo.outputs["Color"], principal.inputs["Base Color"])


def aplicar(recinto: Recinto, foto: Foto, destino: Path) -> str:
    pixeles, info = pintar_recinto(recinto, foto)
    destino.mkdir(parents=True, exist_ok=True)
    ruta = destino / recinto.archivo
    ruta.write_bytes(metal.png_de(pixeles))
    escribir_uv(recinto, info)
    cablear(recinto, ruta)
    for linea in info["resumen"] + info["notas"]:
        print(linea)
    return (
        f"{recinto.nombre}: {info['densidad']} texeles/m ({100 / info['densidad']:.2f} cm), "
        f"{len(info['de_pared'])} caras de pared, {len(info['otras'])} caras sin cambio, "
        f"{info['marcas']} marcas, {ruta.name} {ruta.stat().st_size:,} B"
    )


def main() -> None:
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    guardar = "--aplicar" in argumentos
    otra = None
    if "--foto" in argumentos:
        # Para probar otra foto en los dos recintos: `--foto RUTA --metros LADO`.
        ruta = Path(argumentos[argumentos.index("--foto") + 1]).resolve()
        otra = Foto(ruta, float(argumentos[argumentos.index("--metros") + 1]))
    destino = CARPETA if guardar else Path(tempfile.mkdtemp(prefix="paredes_pintadas_"))
    for recinto in RECINTOS:
        print(aplicar(recinto, otra or recinto.foto, destino))
    if guardar:
        bpy.ops.wm.save_mainfile()
        print(f"guardado: {FUENTE}")
    else:
        print(f"sin --aplicar: texturas en {destino}")


if __name__ == "__main__":
    main()
