"""El detalle de los metales del almacén, pintado desde su geometría.

Un acero de color liso se lee como plástico gris. Uno real lleva manchas de agua, rayones,
suciedad en los encuentros y un satinado que se gasta donde se toca. Este módulo pinta eso en el
color de la textura y en un mapa de rugosidad y metal. **No toca la geometría**: sólo decide qué
UV lleva cada cara y qué pinta cada texel.

## Por qué sale de la malla y no de una textura que se repite

Una textura que se repite no sabe dónde está el piso, dónde se agarra una puerta ni dónde se
junta un plano con otro. La suciedad de abajo, las huellas a la altura de la mano y la línea
oscura de un encuentro dependen del lugar. Por eso cada cara tiene su lugar en un atlas y cada
texel sabe su posición en el mundo.

## Cómo se arma

1. `armar_islas` junta las caras vecinas que miran para el mismo lado. Cada grupo es una isla,
   proyectada sobre su plano. Una isla vertical lleva la altura en su eje `t`.
2. `elegir_densidad` baja los texeles por metro hasta que todas las islas entran en el atlas.
   Todas llevan la misma densidad: un rayón mide lo mismo en un pie de mesa y en un perfil.
3. `pintar_isla` pinta cada isla a partir de la posición de cada texel. Nada se repite.
4. `armar_atlas` conserva el tono medio de cada material y devuelve el color y el mapa ORM.

## Qué se pinta

- **Manchas de agua.** Aureolas claras y opacas y gotas secas, más densas abajo. Más rugosas que
  el acero que las rodea, y con menos metal.
- **Rayones.** Cortos y finos, en varias direcciones y más en las zonas de uso.
- **Huellas** a la altura de la mano.
- **Suciedad.** Oscura al pie, y en una línea al borde de cada isla, que es donde se juntan dos
  planos.
- **Satinado.** El cepillado corre a lo largo de cada isla. Se gasta y brilla donde se toca.
- **Tono.** Una variación de escala grande: nunca un gris parejo.

## Lo que cuesta

Ningún dibujo, ninguna malla. Cada material gana una textura de color y otra ORM (oclusión,
rugosidad y metal), que se suman a los de su conjunto. El mapa ORM sólo se ve donde hay una
sonda de reflejos. En cualquier otro lugar el detalle sale del color.
"""

import struct
import zlib
from dataclasses import dataclass, field

import numpy as np

#: El alto de la altura de la mano sobre el piso, en metros, y qué tan ancha es la zona de uso.
ALTURA_DE_USO = 1.05
ANCHO_DE_USO = 0.30


@dataclass(frozen=True)
class Receta:
    """Qué metal es y cuánto detalle lleva."""

    color: tuple[float, float, float]  #: sRGB 0..1. El tono medio que se conserva.
    rugosidad: float
    metal: float
    suelo: float  #: la altura del piso, en metros, en el sistema del modelo.
    manchas: float = 1.0
    rayones: float = 1.0
    huellas: float = 1.0
    mugre: float = 1.0
    semilla: int = 1


@dataclass
class Isla:
    """Un grupo de caras proyectado sobre un plano, con su lugar en el atlas."""

    caras: list[int]
    origen: np.ndarray  #: el punto del mundo donde `s` y `t` valen cero.
    eje_s: np.ndarray
    eje_t: np.ndarray
    normal: np.ndarray
    ancho: float  #: metros, a lo largo de `s`.
    alto: float  #: metros, a lo largo de `t`.
    bordes: list[tuple[float, float, float, float]] = field(default_factory=list)
    receta: Receta | None = None
    numero: int = 0
    # Dónde cae en el atlas, en texeles. `girada` intercambia `s` y `t`.
    x: int = 0
    y: int = 0
    girada: bool = False


# ── geometría ────────────────────────────────────────────────────────────────────────────────


def normal_y_area(posiciones: np.ndarray, poligono: list[int]) -> tuple[np.ndarray, float]:
    """La normal unitaria y el área de un polígono, por el método de Newell."""
    puntos = posiciones[poligono]
    siguiente = np.roll(puntos, -1, axis=0)
    vector = np.sum(np.cross(puntos, siguiente), axis=0)
    area = float(np.linalg.norm(vector)) / 2.0
    if area < 1e-12:
        return np.array([0.0, 0.0, 1.0]), 0.0
    return vector / (2.0 * area), area


def armar_islas(
    posiciones: np.ndarray, poligonos: list[list[int]], limite_grados: float = 38.0
) -> tuple[list[Isla], list[int]]:
    """Las islas de un conjunto de caras, y las caras sin área, que no llevan textura.

    Dos caras que comparten una arista van a la misma isla si la normal de la segunda queda a
    menos de `limite_grados` de la normal media del grupo. Un cilindro se parte en unos cuatro
    trozos, cada uno con menos de un cuarto de vuelta, y su proyección se estira poco.
    """
    normales, areas = [], []
    for poligono in poligonos:
        normal, area = normal_y_area(posiciones, poligono)
        normales.append(normal)
        areas.append(area)
    # Una arista de dos caras que no comparten vértices, pero sí lugar, también las une.
    _, soldado = np.unique(np.round(posiciones, 4), axis=0, return_inverse=True)
    de_cada_arista: dict[tuple[int, int], list[int]] = {}
    for cara, poligono in enumerate(poligonos):
        if areas[cara] <= 0.0:
            continue
        for i, a in enumerate(poligono):
            b = poligono[(i + 1) % len(poligono)]
            a, b = int(soldado[a]), int(soldado[b])
            de_cada_arista.setdefault((min(a, b), max(a, b)), []).append(cara)
    vecinas: dict[int, list[int]] = {}
    for caras in de_cada_arista.values():
        for cara in caras:
            vecinas.setdefault(cara, []).extend(c for c in caras if c != cara)
    coseno = np.cos(np.radians(limite_grados))
    asignada: dict[int, int] = {}
    grupos: list[list[int]] = []
    for semilla in range(len(poligonos)):
        if areas[semilla] <= 0.0 or semilla in asignada:
            continue
        grupo = [semilla]
        asignada[semilla] = len(grupos)
        suma = normales[semilla] * areas[semilla]
        pendientes = [semilla]
        while pendientes:
            actual = pendientes.pop()
            media = suma / np.linalg.norm(suma)
            for otra in vecinas.get(actual, []):
                if otra in asignada or float(np.dot(normales[otra], media)) < coseno:
                    continue
                asignada[otra] = len(grupos)
                grupo.append(otra)
                suma = suma + normales[otra] * areas[otra]
                pendientes.append(otra)
        grupos.append(sorted(grupo))
    grupos = _unir_los_chicos(grupos, vecinas, normales, areas)
    grupos = [
        parte
        for grupo in grupos
        for parte in _partir_los_vacios(posiciones, poligonos, grupo, normales, areas)
    ]
    islas = [_proyectar(posiciones, poligonos, grupo, suma_de(normales, areas, grupo), i,
                        soldado)
             for i, grupo in enumerate(grupos)]
    sin_area = [c for c in range(len(poligonos)) if areas[c] <= 0.0]
    return islas, sin_area


#: Una isla de menos área que esta, en m², se pega a su vecina: a ese tamaño la distorsión no se
#: ve y cada isla cuesta un margen de texeles.
AREA_MINIMA = 0.0012


def _unir_los_chicos(
    grupos: list[list[int]], vecinas: dict[int, list[int]], normales: list[np.ndarray],
    areas: list[float],
) -> list[list[int]]:
    """Pega cada grupo chico al vecino más grande que no mire para el lado contrario."""
    de_cada_cara = {c: i for i, g in enumerate(grupos) for c in g}
    grupos = [list(g) for g in grupos]
    cambio = True
    while cambio:
        cambio = False
        for indice in sorted(range(len(grupos)), key=lambda i: sum(areas[c] for c in grupos[i])):
            grupo = grupos[indice]
            if not grupo or sum(areas[c] for c in grupo) >= AREA_MINIMA:
                continue
            propia = suma_de(normales, areas, grupo)
            candidatos: dict[int, float] = {}
            for cara in grupo:
                for otra in vecinas.get(cara, []):
                    destino = de_cada_cara[otra]
                    if destino != indice and float(np.dot(propia, suma_de(
                            normales, areas, grupos[destino]))) > 0.0:
                        candidatos[destino] = sum(areas[c] for c in grupos[destino])
            if not candidatos:
                continue
            elegido = max(candidatos, key=lambda d: candidatos[d])
            for cara in grupo:
                de_cada_cara[cara] = elegido
            grupos[elegido] = sorted(grupos[elegido] + grupo)
            grupos[indice] = []
            cambio = True
    return [g for g in grupos if g]


def _partir_los_vacios(
    posiciones: np.ndarray, poligonos: list[list[int]], grupo: list[int],
    normales: list[np.ndarray], areas: list[float],
) -> list[list[int]]:
    """Parte por la mitad una isla cuya caja es mucho más grande que sus caras.

    Un riel que da la vuelta a un cubículo es una tira en forma de U: su caja abarca todo el
    cubículo y el atlas guardaría metros cuadrados de nada. Se corta por el lado largo, en la
    mediana de los centros, hasta que cada trozo llena su caja.
    """
    total = sum(areas[c] for c in grupo)
    eje_s, eje_t = _ejes(suma_de(normales, areas, grupo))
    puntos = posiciones[sorted({v for c in grupo for v in poligonos[c]})]
    extension_s = float(np.ptp(puntos @ eje_s))
    extension_t = float(np.ptp(puntos @ eje_t))
    if len(grupo) < 2 or extension_s * extension_t <= max(0.04, 2.5 * total):
        return [grupo]
    centros = np.array([posiciones[poligonos[c]].mean(axis=0) for c in grupo])
    ejes = (eje_s, eje_t) if extension_s >= extension_t else (eje_t, eje_s)
    for eje in ejes:
        valores = centros @ eje
        corte = float(np.median(valores))
        izquierda = [c for c, v in zip(grupo, valores) if v <= corte]
        derecha = [c for c, v in zip(grupo, valores) if v > corte]
        if not izquierda or not derecha:
            # Todos los centros quedan en el mismo valor: se prueba con el punto medio.
            corte = float((valores.min() + valores.max()) / 2)
            izquierda = [c for c, v in zip(grupo, valores) if v <= corte]
            derecha = [c for c, v in zip(grupo, valores) if v > corte]
        if izquierda and derecha:
            break
    else:
        return [grupo]
    return _partir_los_vacios(
        posiciones, poligonos, izquierda, normales, areas
    ) + _partir_los_vacios(posiciones, poligonos, derecha, normales, areas)


def suma_de(normales: list[np.ndarray], areas: list[float], grupo: list[int]) -> np.ndarray:
    total = sum(normales[c] * areas[c] for c in grupo)
    return total / np.linalg.norm(total)


def _ejes(normal: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """`s` y `t` de un plano. En una cara vertical, `t` es la altura."""
    if abs(normal[2]) < 0.5:
        arriba = np.array([0.0, 0.0, 1.0])
        eje_t = arriba - normal * float(np.dot(arriba, normal))
        eje_t = eje_t / np.linalg.norm(eje_t)
        eje_s = np.cross(eje_t, normal)
    else:
        este = np.array([1.0, 0.0, 0.0])
        eje_s = este - normal * float(np.dot(este, normal))
        eje_s = eje_s / np.linalg.norm(eje_s)
        eje_t = np.cross(normal, eje_s)
    return eje_s / np.linalg.norm(eje_s), eje_t / np.linalg.norm(eje_t)


def _proyectar(
    posiciones: np.ndarray, poligonos: list[list[int]], grupo: list[int], normal: np.ndarray,
    numero: int, soldado: np.ndarray,
) -> Isla:
    eje_s, eje_t = _ejes(normal)
    usados = sorted({v for c in grupo for v in poligonos[c]})
    puntos = posiciones[usados]
    s = puntos @ eje_s
    t = puntos @ eje_t
    minimo_s, minimo_t = float(s.min()), float(t.min())
    origen = eje_s * minimo_s + eje_t * minimo_t + normal * float(
        np.mean(puntos @ normal)
    )
    isla = Isla(
        caras=grupo,
        origen=origen,
        eje_s=eje_s,
        eje_t=eje_t,
        normal=normal,
        ancho=max(float(s.max() - minimo_s), 0.002),
        alto=max(float(t.max() - minimo_t), 0.002),
        numero=numero,
    )
    de_cada_arista: dict[tuple[int, int], list[int]] = {}
    for cara in grupo:
        poligono = poligonos[cara]
        for i, a in enumerate(poligono):
            b = poligono[(i + 1) % len(poligono)]
            clave = (int(min(soldado[a], soldado[b])), int(max(soldado[a], soldado[b])))
            de_cada_arista.setdefault(clave, []).append(a)
            de_cada_arista[clave].append(b)
    for caras in de_cada_arista.values():
        if len(caras) == 2:
            a, b = caras
            pa, pb = isla_st(isla, posiciones[a]), isla_st(isla, posiciones[b])
            isla.bordes.append((pa[0], pa[1], pb[0], pb[1]))
    return isla


def isla_st(isla: Isla, punto: np.ndarray) -> tuple[float, float]:
    """Las coordenadas de un punto del mundo en el plano de la isla, en metros."""
    relativo = np.asarray(punto) - isla.origen
    return float(relativo @ isla.eje_s), float(relativo @ isla.eje_t)


# ── el atlas ─────────────────────────────────────────────────────────────────────────────────

MARGEN = 3


def _medidas(isla: Isla, densidad: float) -> tuple[int, int]:
    return (
        int(np.ceil(isla.ancho * densidad)) + 2 * MARGEN,
        int(np.ceil(isla.alto * densidad)) + 2 * MARGEN,
    )


def acomodar(
    islas: list[Isla], lado: int, densidad: float, reservado: int = 0
) -> bool:
    """Reparte las islas en estantes de `lado` texeles. Devuelve `False` si no entran.

    Las filas de abajo hasta `reservado` quedan libres para los parches lisos. Cada isla se gira
    para que su lado largo corra a lo ancho del estante.
    """
    medidas = []
    for isla in islas:
        ancho, alto = _medidas(isla, densidad)
        girada = alto > ancho
        medidas.append((max(ancho, alto), min(ancho, alto), girada, isla))
    medidas.sort(key=lambda m: (-m[1], -m[0], m[3].numero))
    x, y, estante = 0, reservado, 0
    for ancho, alto, girada, isla in medidas:
        if ancho > lado:
            return False
        if x + ancho > lado:
            x, y = 0, y + estante
            estante = 0
        if y + alto > lado:
            return False
        isla.x, isla.y, isla.girada = x, y, girada
        x += ancho
        estante = max(estante, alto)
    return True


def elegir_densidad(
    islas: list[Isla], lado: int, maxima: float, minima: float = 120.0, reservado: int = 0
) -> float:
    """La mayor densidad, en texeles por metro, con la que entran todas las islas."""
    densidad = maxima
    while densidad >= minima:
        if acomodar(islas, lado, densidad, reservado):
            return densidad
        densidad *= 0.94
    raise ValueError(f"las islas no entran en {lado} px ni a {minima} texeles por metro")


def uv_de(isla: Isla, punto: np.ndarray, densidad: float, lado: int) -> tuple[float, float]:
    """La UV de un punto del mundo, con `v` hacia arriba."""
    s, t = isla_st(isla, punto)
    if isla.girada:
        columna, fila = t, s
    else:
        columna, fila = s, t
    x = isla.x + MARGEN + columna * densidad
    y = isla.y + MARGEN + fila * densidad
    return x / lado, y / lado


# ── el ruido ─────────────────────────────────────────────────────────────────────────────────


def _mezclar(h: np.ndarray) -> np.ndarray:
    h ^= h >> np.uint32(16)
    h *= np.uint32(0x7FEB352D)
    h ^= h >> np.uint32(15)
    h *= np.uint32(0x846CA68B)
    h ^= h >> np.uint32(16)
    return h


def _azar(ix: np.ndarray, iy: np.ndarray, iz: np.ndarray, semilla: int) -> np.ndarray:
    """Un valor en [0, 1) para cada celda entera. Es el mismo para la misma celda y semilla."""
    with np.errstate(over="ignore"):
        h = (
            (ix.astype(np.int64) & 0xFFFFFFFF).astype(np.uint32) * np.uint32(73856093)
            ^ (iy.astype(np.int64) & 0xFFFFFFFF).astype(np.uint32) * np.uint32(19349663)
            ^ (iz.astype(np.int64) & 0xFFFFFFFF).astype(np.uint32) * np.uint32(83492791)
            ^ np.uint32((semilla * 2654435761) & 0xFFFFFFFF)
        )
        h = _mezclar(h)
    return h.astype(np.float32) / np.float32(4294967296.0)


def _valor(x: np.ndarray, y: np.ndarray, z: np.ndarray, semilla: int) -> np.ndarray:
    """Ruido de valor, suave, en [0, 1]."""
    x0, y0, z0 = np.floor(x), np.floor(y), np.floor(z)
    fx, fy, fz = x - x0, y - y0, z - z0
    ux, uy, uz = (f * f * (3 - 2 * f) for f in (fx, fy, fz))
    ix, iy, iz = x0.astype(np.int64), y0.astype(np.int64), z0.astype(np.int64)
    salida = np.zeros(x.shape, dtype=np.float32)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                peso = (
                    (ux if dx else 1 - ux) * (uy if dy else 1 - uy) * (uz if dz else 1 - uz)
                )
                salida += peso * _azar(ix + dx, iy + dy, iz + dz, semilla)
    return salida


def _fbm(
    x: np.ndarray, y: np.ndarray, z: np.ndarray, frecuencia: float, octavas: int, semilla: int
) -> np.ndarray:
    total = np.zeros(x.shape, dtype=np.float32)
    amplitud, suma = 1.0, 0.0
    for octava in range(octavas):
        total += amplitud * _valor(
            x * frecuencia, y * frecuencia, z * frecuencia, semilla + 31 * octava
        )
        suma += amplitud
        amplitud *= 0.5
        frecuencia *= 2.0
    return total / np.float32(suma)


def _suave(borde0: float, borde1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - borde0) / (borde1 - borde0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ── la pintura de una isla ───────────────────────────────────────────────────────────────────


def _distancia_a_los_bordes(
    s: np.ndarray, t: np.ndarray, bordes: list[tuple[float, float, float, float]]
) -> np.ndarray:
    minima = np.full(s.shape, 1e3, dtype=np.float32)
    for s0, t0, s1, t1 in bordes:
        ds, dt = s1 - s0, t1 - t0
        largo2 = ds * ds + dt * dt
        if largo2 < 1e-12:
            continue
        parte = np.clip(((s - s0) * ds + (t - t0) * dt) / largo2, 0.0, 1.0)
        distancia = np.hypot(s - (s0 + parte * ds), t - (t0 + parte * dt))
        np.minimum(minima, distancia, out=minima)
    return minima


def _aureolas(
    s: np.ndarray, t: np.ndarray, z_de: tuple[float, float, float], densidad: float,
    receta: Receta, semilla: int,
) -> tuple[np.ndarray, np.ndarray]:
    """Gotas secas y aureolas. Devuelve el relleno y el aro, en [0, 1]."""
    celda = 0.085
    cx, cy = np.floor(s / celda), np.floor(t / celda)
    relleno = np.zeros(s.shape, dtype=np.float32)
    aro = np.zeros(s.shape, dtype=np.float32)
    ruido = _valor(s * 70.0, t * 70.0, np.zeros_like(s), semilla + 7) - 0.5
    fino = _valor(s * 420.0, t * 420.0, np.zeros_like(s), semilla + 9) - 0.5
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            ix, iy = cx + dx, cy + dy
            cero = np.zeros_like(ix)
            px = (ix + 0.12 + 0.76 * _azar(ix, iy, cero, semilla + 1)) * celda
            py = (iy + 0.12 + 0.76 * _azar(ix, iy, cero, semilla + 2)) * celda
            radio = 0.011 + 0.030 * _azar(ix, iy, cero, semilla + 3) ** 1.6
            altura = z_de[0] + z_de[1] * px + z_de[2] * py - receta.suelo
            probabilidad = receta.manchas * (0.10 + 0.55 * np.exp(-np.maximum(altura, 0) / 0.55))
            existe = _azar(ix, iy, cero, semilla + 4) < probabilidad
            lleno = _azar(ix, iy, cero, semilla + 5) < 0.45
            distancia = np.hypot(s - px, t - py) + ruido * radio * 0.5 + fino * 0.0009
            borde = 1.1 / densidad
            dentro = _suave(radio + borde, radio - borde, distancia) * existe
            franja = (
                _suave(radio - 2.4 / densidad, radio - 1.0 / densidad, distancia)
                * _suave(radio + borde, radio - borde * 0.4, distancia)
                * existe
            )
            velo = np.exp(-np.maximum(distancia - radio, 0.0) / 0.006) * existe * 0.5
            gota = dentro * np.where(lleno, 0.75, 0.22)
            relleno = np.maximum(relleno, np.maximum(gota, velo * 0.4))
            aro = np.maximum(aro, franja * np.where(lleno, 0.5, 1.0))
    return relleno, aro


def _marcas(
    ancho: int, alto: int, densidad: float, cantidad: int, azar: np.random.Generator,
    angulo_base: float, aceptar, largo: tuple[float, float],
) -> tuple[np.ndarray, np.ndarray]:
    """Rayones: segmentos finos y cortos. Devuelve los claros y los oscuros."""
    claros = np.zeros((alto, ancho), dtype=np.float32)
    oscuros = np.zeros((alto, ancho), dtype=np.float32)
    if cantidad <= 0:
        return claros, oscuros
    x0 = azar.uniform(0, ancho, cantidad)
    y0 = azar.uniform(0, alto, cantidad)
    queda = azar.uniform(0, 1, cantidad) < aceptar(x0, y0)
    x0, y0 = x0[queda], y0[queda]
    n = len(x0)
    if n == 0:
        return claros, oscuros
    metros = np.exp(azar.uniform(np.log(largo[0]), np.log(largo[1]), n))
    pixeles = metros * densidad
    seguido = azar.uniform(0, 1, n) < 0.6
    angulo = np.where(
        seguido, angulo_base + azar.normal(0, 0.14, n), azar.uniform(0, np.pi, n)
    )
    fuerza = azar.uniform(0.25, 0.8, n)
    claro = azar.uniform(0, 1, n) < 0.72
    pasos = int(np.ceil(pixeles.max())) + 1
    avance = np.linspace(0.0, 1.0, pasos)[None, :]
    xs = x0[:, None] + np.cos(angulo)[:, None] * pixeles[:, None] * avance
    ys = y0[:, None] + np.sin(angulo)[:, None] * pixeles[:, None] * avance
    xi, yi = np.floor(xs).astype(int), np.floor(ys).astype(int)
    dentro = (xi >= 0) & (xi < ancho) & (yi >= 0) & (yi < alto)
    peso = np.broadcast_to(fuerza[:, None], xs.shape)
    for capa, elegido in ((claros, claro), (oscuros, ~claro)):
        mascara = dentro & elegido[:, None]
        np.add.at(capa, (yi[mascara], xi[mascara]), peso[mascara].astype(np.float32))
    return np.minimum(claros, 1.0), np.minimum(oscuros, 1.0)


def _huellas(
    s: np.ndarray, t: np.ndarray, azar: np.random.Generator, cantidad: int, aceptar
) -> np.ndarray:
    """Óvalos suaves, como el rastro de un dedo."""
    marca = np.zeros(s.shape, dtype=np.float32)
    for _ in range(cantidad):
        cs = azar.uniform(0, float(s.max()))
        ct = azar.uniform(0, float(t.max()))
        if azar.uniform() >= aceptar(cs, ct):
            continue
        r1, r2 = azar.uniform(0.007, 0.012), azar.uniform(0.012, 0.022)
        angulo = azar.uniform(0, np.pi)
        ds, dt = s - cs, t - ct
        u = ds * np.cos(angulo) + dt * np.sin(angulo)
        v = -ds * np.sin(angulo) + dt * np.cos(angulo)
        forma = np.sqrt((u / r1) ** 2 + (v / r2) ** 2)
        estrias = 0.55 + 0.45 * np.sin(v * 520.0 + 3.0 * np.sin(u * 140.0))
        marca = np.maximum(marca, _suave(1.0, 0.45, forma) * estrias * azar.uniform(0.5, 1.0))
    return marca


def pintar_isla(
    isla: Isla, receta: Receta, densidad: float
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """El color (sRGB), la rugosidad y el metal de una isla, con la fila 0 en `t` mínimo."""
    ancho, alto = _medidas(isla, densidad)
    columnas = (np.arange(ancho, dtype=np.float32) + 0.5 - MARGEN) / np.float32(densidad)
    filas = (np.arange(alto, dtype=np.float32) + 0.5 - MARGEN) / np.float32(densidad)
    s, t = np.meshgrid(columnas, filas)
    punto = (
        isla.origen[None, None, :]
        + s[..., None] * isla.eje_s[None, None, :]
        + t[..., None] * isla.eje_t[None, None, :]
    ).astype(np.float32)
    x, y, z = punto[..., 0], punto[..., 1], punto[..., 2]
    altura = np.maximum(z - receta.suelo, 0.0)
    semilla = receta.semilla * 1009 + isla.numero * 7919
    azar = np.random.default_rng(semilla)
    area = isla.ancho * isla.alto
    vertical = abs(float(isla.normal[2])) < 0.5
    z_de = (
        float(isla.origen[2]),
        float(isla.eje_s[2]),
        float(isla.eje_t[2]),
    )

    def zona_de_uso(zs: np.ndarray) -> np.ndarray:
        return np.exp(-(((zs - ALTURA_DE_USO) / ANCHO_DE_USO) ** 2))

    # El tono de escala grande y el cepillado.
    tono = _fbm(x, y, z, 1.6, 3, semilla + 11) - 0.5
    manchon = _fbm(x, y, z, 5.5, 3, semilla + 13) - 0.5
    a_lo_largo_de_t = vertical or isla.alto >= isla.ancho
    if a_lo_largo_de_t:
        grano = _valor(s * densidad / 1.3, t * densidad / 26.0, np.zeros_like(s), semilla + 17)
        angulo_base = np.pi / 2
    else:
        grano = _valor(s * densidad / 26.0, t * densidad / 1.3, np.zeros_like(s), semilla + 17)
        angulo_base = 0.0
    grano = grano - 0.5

    # Manchas de agua y chorreaduras.
    relleno, aro = _aureolas(s, t, z_de, densidad, receta, semilla)
    cortina = _valor(
        (x + y) * 55.0, np.zeros_like(x), z * 2.6, semilla + 19
    ) * _valor((x - y) * 31.0, np.zeros_like(x), z * 4.0, semilla + 23)
    chorreado = (
        _suave(0.50, 0.78, cortina)
        * np.exp(-altura / 0.9)
        * (1.0 if vertical else 0.25)
        * receta.manchas
    )

    # Rayones y huellas.
    def zona_para_rayones(px: np.ndarray, py: np.ndarray) -> np.ndarray:
        zs = z_de[0] + z_de[1] * (px / densidad - MARGEN / densidad) + z_de[2] * (
            py / densidad - MARGEN / densidad
        )
        cerca_del_piso = np.exp(-np.maximum(zs - receta.suelo, 0) / 0.25)
        return np.minimum(1.0, 0.18 + 0.82 * np.maximum(zona_de_uso(zs), 0.6 * cerca_del_piso))

    cantidad = int(area * 650 * receta.rayones)
    claros, oscuros = _marcas(
        ancho, alto, densidad, cantidad, azar, angulo_base, zona_para_rayones, (0.010, 0.045)
    )
    huella = np.zeros_like(s)
    if vertical and receta.huellas > 0:
        huella = _huellas(
            s,
            t,
            azar,
            int(area * 70 * receta.huellas) + 1,
            lambda cs, ct: float(
                zona_de_uso(np.float32(z_de[0] + z_de[1] * cs + z_de[2] * ct))
            ),
        )

    # Suciedad al pie y en los encuentros.
    barro = np.exp(-altura / 0.07) * (0.55 + 0.45 * _fbm(x, y, z, 14.0, 2, semilla + 29))
    distancia = _distancia_a_los_bordes(s, t, isla.bordes)
    ruido_de_borde = _fbm(x, y, z, 22.0, 2, semilla + 31)
    linea = np.exp(-((distancia / 0.0042) ** 2)) * (0.45 + 0.9 * ruido_de_borde)
    rincon = np.exp(-distancia / 0.022) * (0.35 + 0.65 * ruido_de_borde)
    lustre = np.exp(-((distancia / 0.0012) ** 2)) * (0.4 + 0.6 * ruido_de_borde)

    # El uso gasta el satinado, y el resto se vuelve un poco más opaco.
    uso = zona_de_uso(z) * _suave(0.25, 0.7, _fbm(x, y, z, 4.0, 2, semilla + 37))
    uso = uso if vertical else uso * 0.5

    mugre = receta.mugre
    brillo = (
        1.0
        + 0.10 * tono
        + 0.07 * manchon
        + 0.07 * grano
        + 0.09 * uso
        + 0.22 * claros
        - 0.18 * oscuros
    )
    sucio = (
        1.0
        - 0.38 * mugre * barro
        - 0.26 * mugre * np.minimum(linea, 1.2)
        - 0.12 * mugre * rincon
        - 0.07 * mugre * (0.5 - manchon)
    )
    blanco = np.clip(
        0.16 * relleno + 0.24 * aro + 0.10 * chorreado + 0.10 * huella + 0.12 * lustre
        + 0.04 * uso,
        0.0,
        0.8,
    )
    base = np.array(receta.color, dtype=np.float32)[None, None, :]
    color = base * (brillo * sucio)[..., None]
    color = color + (1.0 - color) * blanco[..., None]
    color = np.clip(color, 0.0, 1.0)

    rugosidad = (
        receta.rugosidad
        + 0.20 * relleno
        + 0.10 * aro
        + 0.08 * chorreado
        + 0.12 * huella
        + 0.10 * np.minimum(barro + linea, 1.0) * mugre
        + 0.06 * np.minimum(claros, 1.0)
        + 0.05 * grano
        - 0.10 * uso
    )
    metal = receta.metal - 0.30 * relleno - 0.12 * aro - 0.10 * np.minimum(barro + linea, 1.0)
    return (
        color.astype(np.float32),
        np.clip(rugosidad, 0.06, 0.9).astype(np.float32),
        np.clip(metal, 0.2, 1.0).astype(np.float32),
    )


# ── el atlas completo ────────────────────────────────────────────────────────────────────────

#: Un parche liso por receta, en la esquina de abajo. Lo usan las caras que no llevan isla.
LADO_DEL_PARCHE = 8


def parche_liso(receta: Receta, lado: int, indice: int) -> tuple[float, float]:
    """La UV del centro del parche liso de la receta `indice`."""
    return (indice * LADO_DEL_PARCHE + LADO_DEL_PARCHE / 2) / lado, (LADO_DEL_PARCHE / 2) / lado


def armar_atlas(
    islas: list[Isla], recetas: list[Receta], lado: int, densidad: float
) -> tuple[np.ndarray, np.ndarray]:
    """El color (sRGB, 0..1) y el ORM (oclusión, rugosidad y metal) del atlas, `v` hacia arriba.

    Cada material conserva su tono medio: el detalle reparte la luz, no la cambia.
    """
    color = np.empty((lado, lado, 3), dtype=np.float32)
    color[...] = recetas[0].color
    orm = np.empty((lado, lado, 3), dtype=np.float32)
    orm[...] = (1.0, recetas[0].rugosidad, recetas[0].metal)
    for indice, receta in enumerate(recetas):
        x0 = indice * LADO_DEL_PARCHE
        color[:LADO_DEL_PARCHE, x0 : x0 + LADO_DEL_PARCHE] = receta.color
        orm[:LADO_DEL_PARCHE, x0 : x0 + LADO_DEL_PARCHE, 1] = receta.rugosidad
        orm[:LADO_DEL_PARCHE, x0 : x0 + LADO_DEL_PARCHE, 2] = receta.metal
    pintadas = [(isla, *pintar_isla(isla, isla.receta, densidad)) for isla in islas]
    for receta in recetas:
        propias = [p for p in pintadas if p[0].receta == receta]
        if not propias:
            continue
        total = sum(c.reshape(-1, 3).sum(axis=0) for _, c, _, _ in propias)
        cantidad = sum(c.shape[0] * c.shape[1] for _, c, _, _ in propias)
        media = total / cantidad
        factor = np.array(receta.color, dtype=np.float32) / np.maximum(media, 1e-4)
        for i, (isla, c, r, m) in enumerate(pintadas):
            if isla.receta == receta:
                pintadas[i] = (isla, np.clip(c * factor, 0.0, 1.0), r, m)
    for isla, c, r, m in pintadas:
        alto, ancho = c.shape[:2]
        if isla.girada:
            c, r, m = c.transpose(1, 0, 2), r.T, m.T
            alto, ancho = ancho, alto
        color[isla.y : isla.y + alto, isla.x : isla.x + ancho] = c
        orm[isla.y : isla.y + alto, isla.x : isla.x + ancho, 1] = r
        orm[isla.y : isla.y + alto, isla.x : isla.x + ancho, 2] = m
    return color, orm


# ── el PNG ───────────────────────────────────────────────────────────────────────────────────


def _bloque(nombre: bytes, datos: bytes) -> bytes:
    return (
        struct.pack(">I", len(datos))
        + nombre
        + datos
        + struct.pack(">I", zlib.crc32(nombre + datos))
    )


def png_de(pixeles: np.ndarray) -> bytes:
    """Un PNG RGB de 8 bits desde una matriz 0..1 con la fila 0 abajo. Siempre los mismos bytes."""
    arriba = np.flipud(pixeles)
    bytes8 = np.clip(np.rint(arriba * 255.0), 0, 255).astype(np.uint8)
    alto, ancho = bytes8.shape[:2]
    # Filtro «sub»: cada byte menos el de su pixel anterior.
    anterior = np.zeros_like(bytes8)
    anterior[:, 1:] = bytes8[:, :-1]
    filtrado = (bytes8.astype(np.int16) - anterior.astype(np.int16)).astype(np.uint8)
    filas = np.concatenate([np.ones((alto, 1), dtype=np.uint8), filtrado.reshape(alto, -1)], axis=1)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _bloque(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 2, 0, 0, 0))
        + _bloque(b"IDAT", zlib.compress(filas.tobytes(), 9))
        + _bloque(b"IEND", b"")
    )


def reducir_a_la_mitad(pixeles: np.ndarray) -> np.ndarray:
    """El promedio de cada bloque de 2×2."""
    alto, ancho = pixeles.shape[:2]
    return pixeles.reshape(alto // 2, 2, ancho // 2, 2, -1).mean(axis=(1, 3))
