"""Le da a las paredes pintadas del salón y del baño los desperfectos de una pared real.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/paredes_pintadas.py -- [--aplicar]

Sin `--aplicar` pinta en una carpeta temporal y no guarda nada. Con `--aplicar` escribe las
texturas en `assets/source/textures/store/` y guarda la fuente canónica. Después van
`armar_atlas.py`, `exportar_modelo.py` y `assets/models/extraer_mallas.gd`. Cambia la UV de las
paredes: Godot rehace la UV del mapa de luz, así que también piden `hornear.py` y
`hornear.py --sin-luz`.

## Por qué

La pared del salón (`local_pared_pintada`) y la del baño (`bano_pared_clara`) eran un color liso.
Una pared pintada de blanco nunca es lisa: el revoque se asoma bajo la pintura, el rodillo deja
sus pasadas, la mugre se junta donde la gente roza y toca, y cada tanto hay un raspón. La luz del
local está horneada, así que el detalle va en el color y no en la rugosidad: la pared sigue siendo
pintura mate.

## Qué cambia

- **Cada pared del recinto tiene su rectángulo en una textura de color de 1024 px.** La UV es
  planar y mide lo mismo en los dos sentidos: los texeles del salón son de 1,4 cm, los del baño
  de 1,1 cm. Un raspón de 3 cm ocupa dos o tres. Las caras que no son pared del recinto
  (el frente de afuera, las jambas, el techo, los cantos) van a un parche liso del color de
  siempre: **su aspecto no cambia**.
- **Cada material gana una textura de color y nada más.** El brillo, la rugosidad y el resto del
  material no se tocan. No hay materiales ni superficies nuevas.
- **La geometría no se toca.** Ningún triángulo se suma.

## Qué lleva la pintura

La pintura sale de la geometría y de los objetos del local, nunca de un número escrito a mano
por pared:

- el revoque: la luz de una foto de revoque real (ambientCG «Plaster 002», CC0, en
  `assets/source/textures/third-party/`), a su tamaño real. El grano que se inventaba texel por
  texel y las pasadas del rodillo se leían como tela pixelada y se sacaron. De la foto sólo se
  toma la luminancia: el tono lo sigue poniendo el color del material;
- variación de tono a 2 o 3 metros, apenas más amarillenta o más gris;
- mugre abajo, cerca del zócalo, y polvo cerca del techo y en las esquinas;
- mugre alrededor de cada vano (puerta, ventanal), más fuerte a la altura de la mano;
- detrás del mostrador: la altura de la cadera y las patadas de abajo;
- junto a las mesas: el roce de los respaldos de las sillas, a unos 85 cm;
- raspones, golpecitos y marcas de zapato, de 1 a 4 cm, más seguidos cerca del piso;
- en el baño: humedad al pie (menos de 50 cm), churretes bajo las piletas y salpicaduras sobre
  ellas, y el pie de los inodoros.

**Que sea sutil es parte del contrato.** La media de cada pared vuelve al tono liso de antes
(así de lejos no cambia ni el tono ni el brillo) y el desvío de la pintura ronda el 12 %: con 4 % el usuario no vio ningún cambio.
El 1 % más oscuro, al pie, pierde entre un 7 y un 14 %. A 2 m la pared se lee blanca y limpia.

## Lo que cuesta

Una textura de 1024 px más por recinto, que hasta ahora no tenían ninguna. Sin materiales ni
dibujos nuevos. El `.glb` pesa lo que pesan dos PNG de 1024.

La foto no viaja al juego: sólo su luz, ya pintada en los PNG de arriba.

Es idempotente: la UV y los PNG salen sólo de la geometría, de la foto y de las constantes, con
una semilla fija por pared.
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
import metal_detalle as metal  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

configurar()

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
CARPETA = RAIZ / "assets/source/textures/store"
EDIFICIO = "almacen-col"
#: La foto del revoque: ambientCG «Plaster 002», CC0. Su licencia viaja con ella.
REVOQUE = (
    RAIZ / "assets/source/textures/third-party/ambientcg-plaster-002/Plaster002_1K-JPG_Color.jpg"
)
#: Su pirámide de niveles, que arma `main`. Se declara acá para que `_revoque` la vea.
_REVOQUE: list[np.ndarray] = []

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
REVOQUE_DESVIO = 0.14
#: Cuánto de la mancha grande de la foto se conserva: 1 menos esto, y a cuántos niveles de la
#: pirámide (un nivel es el doble de ancho) empieza a contar como mancha grande.
NUBE = 0.3
NIVELES_DE_NUBE = 3
#: Niveles de la pirámide de más sobre el texel de la pared. Con un filtro pixelado, el detalle
#: que mide un texel o dos se ve como tablero de ajedrez; así el menor rasgo mide tres o cuatro.
NIVELES_MAS_SUAVES = 0
TONO_GRIS = 0.03
TONO_CALIDO = 0.02
PIE = 0.10
TECHO_POLVO = 0.05
ESQUINA = 0.035
VANO = 0.08
CADERA = 0.05
RESPALDO = 0.06
HUMEDAD_DEL_BANO = 0.08
CHURRETE = 0.07
SALPICADURA = 0.10


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
    tipo: str  # mostrador, silla, pileta o inodoro
    alcance: float  # hasta dónde, en metros, deja su marca en la pared


@dataclass(frozen=True)
class Recinto:
    nombre: str
    material: str
    planos: tuple[Plano, ...]
    techo: float
    archivo: str
    humedad: bool
    muebles: tuple[Mueble, ...] = field(default=())


SALON = Recinto(
    nombre="salon",
    material="local_pared_pintada",
    planos=(Plano(0, -2.48, +1), Plano(0, 7.87, -1), Plano(1, -6.28, +1), Plano(1, 7.87, -1)),
    techo=3.5,
    archivo="pared_del_salon_color.png",
    humedad=False,
    muebles=(
        Mueble("EscritorioComputadora-col", "mostrador", 0.8),
        Mueble("salon_silla", "silla", 1.8),
    ),
)
BANO = Recinto(
    nombre="bano",
    material="bano_pared_clara",
    planos=(Plano(0, 8.29, +1), Plano(0, 13.43, -1), Plano(1, -6.28, +1), Plano(1, 0.33, -1)),
    techo=3.47,
    archivo="pared_del_bano_color.png",
    humedad=True,
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
    """La luz y el tinte que le toca a cada texel de una pared, antes de teñir el color base."""

    def __init__(self, s: np.ndarray, t: np.ndarray):
        self.s, self.t = s, t
        self.luz = np.ones(s.shape, dtype=np.float32)
        self.tinte = np.ones(s.shape + (3,), dtype=np.float32)

    def aclarar_u_oscurecer(self, cantidad: np.ndarray | float) -> None:
        self.luz += cantidad

    def ensuciar(self, cantidad: np.ndarray, color: np.ndarray = MUGRE) -> None:
        """`cantidad` es la fracción de luz que pierde; `color` es el tono de lo que se acumula."""
        cantidad = np.clip(cantidad, 0.0, 0.5)[..., None]
        self.tinte *= 1.0 - cantidad * _reparto(color)


def _luminancia_del_revoque() -> np.ndarray:
    """La luz relativa de la foto del revoque: media 1, desvío 1 menos uno. Lado `LADO_REVOQUE`.

    Sólo se usa la luminancia: el tono de la pared lo sigue poniendo el color del material.
    """
    imagen = bpy.data.images.load(str(REVOQUE), check_existing=False)
    imagen.colorspace_settings.name = "Non-Color"
    ancho, alto = imagen.size
    crudo = np.empty(ancho * alto * 4, dtype=np.float32)
    imagen.pixels.foreach_get(crudo)
    bpy.data.images.remove(imagen)
    rgb = crudo.reshape(alto, ancho, 4)[..., :3]
    lineal = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    luz = lineal @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    return luz / luz.mean() - 1.0


def _piramide(luz: np.ndarray) -> list[np.ndarray]:
    """La foto y sus mitades, promediadas de a 2x2: cada nivel mide la mitad del anterior."""
    niveles = [luz]
    while niveles[-1].shape[0] > 16:
        a = niveles[-1]
        niveles.append(0.25 * (a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2]))
    return niveles


def _leer_bilineal(imagen: np.ndarray, u: np.ndarray, v: np.ndarray) -> np.ndarray:
    """La imagen en `(u, v)` con `u` y `v` en vueltas de la imagen. Se repite en los bordes."""
    alto, ancho = imagen.shape
    x, y = u * ancho - 0.5, v * alto - 0.5
    x0, y0 = np.floor(x), np.floor(y)
    fx, fy = x - x0, y - y0
    x0, y0 = x0.astype(np.int64) % ancho, y0.astype(np.int64) % alto
    x1, y1 = (x0 + 1) % ancho, (y0 + 1) % alto
    arriba = imagen[y0, x0] * (1 - fx) + imagen[y0, x1] * fx
    abajo = imagen[y1, x0] * (1 - fx) + imagen[y1, x1] * fx
    return arriba * (1 - fy) + abajo * fy


def _revoque(lienzo: Lienzo, densidad: int, semilla: int) -> None:
    """La luz del revoque pintado: la foto de un revoque real, a su tamaño real.

    Tres copias de la misma foto con tamaños que no se dividen entre sí (1,4, 2,0 y 2,9 m),
    giradas o espejadas y corridas al azar. Con un período solo, la trama se repetiría cada
    metro y medio. Con tres, la distancia hasta que dos copias vuelvan a coincidir pasa de
    cualquier pared. Cada copia se toma del nivel de la pirámide cuyo texel no es menor que el
    de la pared: así no hay grano más fino que el texel, que es lo que daba la tela.
    """
    azar = np.random.default_rng(semilla)
    capas = (
        (1.4, lambda u, v: (u, v)),
        (2.0, lambda u, v: (v, 1.0 - u)),
        (2.9, lambda u, v: (1.0 - u, v)),
    )
    suma = np.zeros(lienzo.s.shape, dtype=np.float32)
    for lado, orientar in capas:
        texeles = _REVOQUE[0].shape[0] / (lado * densidad)
        nivel = int(np.floor(np.log2(texeles))) + NIVELES_MAS_SUAVES
        nivel = min(max(nivel, 0), len(_REVOQUE) - 1)
        corrimiento = azar.random(2)
        u, v = orientar(lienzo.s / lado + corrimiento[0], lienzo.t / lado + corrimiento[1])
        # Las manchas grandes de la foto se atenúan: una pared pintada se lee por las
        # marcas de la llana, no por nubes de medio metro.
        grueso = _REVOQUE[min(nivel + NIVELES_DE_NUBE, len(_REVOQUE) - 1)]
        suma += _leer_bilineal(_REVOQUE[nivel], u, v) - NUBE * _leer_bilineal(grueso, u, v)
    suma /= np.sqrt(3.0)
    lienzo.aclarar_u_oscurecer(REVOQUE_DESVIO * suma / max(float(suma.std()), 1e-6))


def _tono(lienzo: Lienzo, semilla: int, capa: int) -> None:
    """Variación de tono a 2 o 3 m: zonas apenas más amarillentas o más grises."""
    s, t = lienzo.s, lienzo.t
    lienzo.aclarar_u_oscurecer(TONO_GRIS * ruido(s, t, 2.6, 2.0, 3, semilla + 6, capa))
    calido = TONO_CALIDO * ruido(s, t, 3.2, 2.4, 2, semilla + 7, capa)
    lienzo.tinte[..., 0] *= 1.0 + 0.6 * calido
    lienzo.tinte[..., 1] *= 1.0 + 0.5 * calido
    lienzo.tinte[..., 2] *= 1.0 - 1.0 * calido


def _suciedad_general(lienzo, pared, recinto, semilla, capa, densidad, distancia_a_vano):
    s, t = lienzo.s, lienzo.t
    altura = t - PISO
    # Abajo: lo que se junta al pie de la pared. Las patadas y la fregona dejan franjas bajas.
    franjas = ruido(s, t, 0.9, 0.06, 2, semilla + 8, capa)
    borde = _suave(0.0, 1.0, 1.0 - altura / 0.55)
    manchas = ruido(s, t, 0.5, 0.5, 2, semilla + 9, capa)
    pie = PIE * borde**1.5 * (0.65 + 0.2 * franjas + 0.15 * manchas)
    lienzo.ensuciar(pie)
    # Arriba: polvo y un tono más oscuro cerca del techo.
    bajo_techo = recinto.techo - t
    polvo = TECHO_POLVO * _suave(0.0, 1.0, 1.0 - bajo_techo / 0.40)
    polvo *= 0.55 + 0.45 * ruido(s, t, 0.7, 0.3, 2, semilla + 10, capa)
    lienzo.ensuciar(polvo)
    # Las esquinas verticales también juntan polvo.
    a_la_esquina = np.minimum(s - pared.s0, pared.s1 - s)
    esquina = ESQUINA * np.exp(-np.clip(a_la_esquina, 0, None) / 0.10)
    esquina *= 0.6 + 0.4 * ruido(s, t, 0.4, 0.5, 2, semilla + 11, capa)
    lienzo.ensuciar(esquina)
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
    altura = t - PISO
    for n, (tipo, s0, s1, z0, z1, distancia) in enumerate(pared.fijos):
        centro = 0.5 * (s0 + s1)
        irregular = 0.65 + 0.35 * ruido(s, t, 0.25, 0.25, 2, semilla + 20 + n, capa)
        if tipo == "mostrador":
            # Detrás del mostrador la gente se apoya y se mueve: cadera y patadas.
            a_lo_largo = _suave(0.0, 1.0, 1.0 - np.maximum(0, np.maximum(s0 - s, s - s1)) / 0.35)
            cadera = np.exp(-(((t - 1.0) / 0.22) ** 2))
            patada = _suave(0.0, 1.0, 1.0 - altura / 0.7)
            lienzo.ensuciar(a_lo_largo * (CADERA * cadera + 0.5 * PIE * patada) * irregular)
        elif tipo == "silla":
            # Un respaldo que se apoya o se arrastra contra la pared, a unos 85 cm.
            fuerza = RESPALDO * (1.0 - 0.3 * min(distancia / 1.9, 1.0))
            marca = _aureola(s, t, centro, 0.85, 0.30, 0.10)
            lienzo.ensuciar(fuerza * marca * irregular)
        elif tipo == "pileta":
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
    clases = (("zapato", 1.3, 0.55), ("raspon", 2.2, 2.2), ("golpe", 0.9, 2.4))
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


def pintar(recinto: Recinto, pared: Pared, indice: int, densidad: int, base: np.ndarray):
    """La pintura de una pared: un arreglo (alto, ancho, 3) de luz lineal relativa a la base."""
    semilla = _semilla(f"{recinto.nombre}-{pared.plano.eje}-{pared.plano.coord}")
    azar = np.random.default_rng(semilla)
    alto = pared.alto + 2 * COLCHON
    ancho = pared.ancho + 2 * COLCHON
    columnas = (np.arange(ancho, dtype=np.float64) + 0.5 - COLCHON) / densidad
    filas = (np.arange(alto, dtype=np.float64) + 0.5 - COLCHON) / densidad
    s = np.broadcast_to(pared.s0 + columnas[None, :], (alto, ancho)).astype(np.float32).copy()
    t = np.broadcast_to(PISO + filas[:, None], (alto, ancho)).astype(np.float32).copy()
    lienzo = Lienzo(s, t)

    # Qué texeles son pared y cuáles vano, dentro del rectángulo; el colchón repite el borde.
    cubierto = np.zeros((pared.alto, pared.ancho), dtype=bool)
    adentro = (slice(COLCHON, -COLCHON), slice(COLCHON, -COLCHON))
    interior_s, interior_t = s[adentro], t[adentro]
    for triangulo in pared.triangulos:
        _cubrir(cubierto, triangulo, interior_s, interior_t)
    vano = np.pad(~cubierto, COLCHON, mode="edge")
    distancia = distancia_en_texeles(vano)

    _revoque(lienzo, densidad, semilla)
    _tono(lienzo, semilla, indice)
    _suciedad_general(lienzo, pared, recinto, semilla, indice, densidad, distancia)
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


def pintar_recinto(recinto: Recinto) -> tuple[np.ndarray, dict]:
    """La textura del recinto y lo que hace falta para escribir su UV."""
    material = bpy.data.materials[recinto.material]
    entrada = material.node_tree.nodes["Principled BSDF"].inputs["Base Color"]
    base = np.array(entrada.default_value[:3], dtype=np.float32)
    paredes = paredes_de(recinto)
    densidad = acomodar(paredes, recinto.techo - PISO)
    de_pared, otras = recoger_caras(recinto, paredes)
    notas = anotar_muebles(recinto, paredes)

    textura = np.ones((LADO, LADO, 3), dtype=np.float32) * base
    resumen = []
    marcas = 0
    for indice, pared in enumerate(paredes):
        pintura, hechas, desvio, oscuro = pintar(recinto, pared, indice, densidad, base)
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
    nodo.interpolation = "Closest"
    nodo.location = (-700, 300)
    arbol.links.new(nodo.outputs["Color"], principal.inputs["Base Color"])


def aplicar(recinto: Recinto, destino: Path) -> str:
    pixeles, info = pintar_recinto(recinto)
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
    destino = CARPETA if guardar else Path(tempfile.mkdtemp(prefix="paredes_pintadas_"))
    _REVOQUE[:] = _piramide(_luminancia_del_revoque())
    for recinto in RECINTOS:
        print(aplicar(recinto, destino))
    if guardar:
        bpy.ops.wm.save_mainfile()
        print(f"guardado: {FUENTE}")
    else:
        print(f"sin --aplicar: texturas en {destino}")


if __name__ == "__main__":
    main()
