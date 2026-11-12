"""El detalle de los metales del almacén, pintado desde su geometría.

Un acero de color liso se lee como plástico gris. Uno real lleva grano satinado corto, huellas
sutiles de dedos, rayones finos a escala real y, cerca del piso del baño, pequeñas marcas de agua.
Este módulo pinta ese detalle en el color y, sobre todo, en el canal de rugosidad del mapa ORM.
**No toca la geometría**: sólo decide qué UV lleva cada cara y qué pinta cada texel.

## Por qué sale de la malla y no de una textura que se repite

Una textura repetida no sabe dónde está el piso, dónde apoya la mano una persona ni hacia qué lado
corre un perfil. Las marcas de agua bajas, las huellas en zonas de contacto y el sentido del
satinado dependen del lugar en el mundo. Por eso cada cara va a su isla en un atlas y cada texel
conoce su posición real.

## Cómo se arma

1. `armar_islas` agrupa las caras vecinas de orientación parecida. Descarta las caras sin área y las
   caras tapadas contra el piso, el techo o el frente exterior.
2. `elegir_densidad` busca la mayor densidad en texeles por metro con la que todas las islas entran
   en el atlas mediante rectángulos libres.
3. `pintar_isla` calcula color, rugosidad y metal desde la posición de cada texel, sin repetición.
4. `armar_atlas` conserva el tono medio de cada receta. Devuelve el color y el mapa ORM a igual
   resolución para conservar los rayones finos.

## Lo que cuesta

Ningún dibujo nuevo y ningún triángulo sumado. Cada conjunto escribe un PNG de color y un PNG ORM.
"""

import struct
import zlib
from dataclasses import dataclass, field

import numpy as np

#: Altura media de contacto de las manos sobre perfiles altos, en metros sobre el nivel del modelo.
ALTURA_DE_MANO = 1.05
ANCHO_DE_MANO = 0.30

#: Largo máximo de una isla de varias caras antes de partirla para ganar densidad en el atlas.
LARGO_MAXIMO_DE_ISLA = 1.80


@dataclass(frozen=True)
class Receta:
    """Qué metal es y cuánto detalle lleva en color y rugosidad."""

    color: tuple[float, float, float]  #: sRGB 0..1. El tono medio que se conserva.
    rugosidad: float
    metal: float
    suelo: float  #: altura del piso en metros, en el sistema del modelo.
    manchas: float = 0.0
    altura_agua: float = 0.26  #: altura máxima sobre `suelo` donde aparecen marcas de agua.
    rayones: float = 1.0
    huellas: float = 1.0
    mugre: float = 0.25
    variacion: float = 0.10
    satinado: float = 1.0
    escala_rugosidad: float = 1.0  #: compensa factores de post-importación como el del mostrador.
    semilla: int = 1


@dataclass
class Isla:
    """Un grupo de caras proyectado sobre un plano, con su lugar en el atlas."""

    caras: list[int]
    origen: np.ndarray  #: punto del mundo donde `s` y `t` valen cero.
    eje_s: np.ndarray
    eje_t: np.ndarray
    normal: np.ndarray
    ancho: float  #: metros, a lo largo de `s`.
    alto: float  #: metros, a lo largo de `t`.
    area_real: float = 0.0  #: metros cuadrados reales cubiertos por sus caras.
    bordes: list[tuple[float, float, float, float]] = field(default_factory=list)
    huecos: list[tuple[float, float, float, float]] = field(default_factory=list)
    receta: Receta | None = None
    numero: int = 0
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
    posiciones: np.ndarray,
    poligonos: list[list[int]],
    limite_grados: float = 38.0,
    suelo_oculto: float | None = None,
    planos_ocultos: tuple[tuple[tuple[float, float, float], float], ...] = (),
) -> tuple[list[Isla], list[int]]:
    """Las islas visibles de un conjunto de caras, y las caras que van al parche liso.

    `suelo_oculto` y `planos_ocultos` envían al parche liso las caras tapadas contra el suelo, el
    cielorraso o la calle para ganar densidad en las caras visibles.
    """
    cortes = list(planos_ocultos)
    if suelo_oculto is not None:
        cortes.append(((0.0, 0.0, -1.0), -(suelo_oculto + 0.015)))
    cortes_np = [(np.asarray(d, dtype=np.float64), float(u)) for d, u in cortes]
    normales, areas = [], []
    ocultas: set[int] = set()
    for indice, poligono in enumerate(poligonos):
        normal, area = normal_y_area(posiciones, poligono)
        normales.append(normal)
        areas.append(area)
        if area > 0.0 and cortes_np:
            pts = posiciones[poligono]
            for direccion, umbral in cortes_np:
                alineada = float(np.dot(normal, direccion)) > 0.95
                if alineada and float((pts @ direccion).min()) >= umbral:
                    ocultas.add(indice)
                    break
    _, soldado = np.unique(np.round(posiciones, 4), axis=0, return_inverse=True)
    de_cada_arista: dict[tuple[int, int], list[int]] = {}
    for cara, poligono in enumerate(poligonos):
        if areas[cara] <= 0.0 or cara in ocultas:
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
        if areas[semilla] <= 0.0 or semilla in ocultas or semilla in asignada:
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
    islas = [
        _proyectar(posiciones, poligonos, grupo, suma_de(normales, areas, grupo), i, soldado, areas)
        for i, grupo in enumerate(grupos)
    ]
    sin_area = [c for c in range(len(poligonos)) if areas[c] <= 0.0 or c in ocultas]
    return islas, sin_area


AREA_MINIMA = 0.0012


def _unir_los_chicos(
    grupos: list[list[int]],
    vecinas: dict[int, list[int]],
    normales: list[np.ndarray],
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
                    if destino != indice and float(
                        np.dot(propia, suma_de(normales, areas, grupos[destino]))
                    ) > 0.0:
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


def _caja_en_plano(
    posiciones: np.ndarray,
    poligonos: list[list[int]],
    grupo: list[int],
    eje_s: np.ndarray,
    eje_t: np.ndarray,
) -> tuple[float, float]:
    puntos = posiciones[sorted({v for c in grupo for v in poligonos[c]})]
    return float(np.ptp(puntos @ eje_s)), float(np.ptp(puntos @ eje_t))


def _partir_los_vacios(
    posiciones: np.ndarray,
    poligonos: list[list[int]],
    grupo: list[int],
    normales: list[np.ndarray],
    areas: list[float],
) -> list[list[int]]:
    """Parte una isla de varias caras si reduce su caja envolvente o acorta una tira larga."""
    total = sum(areas[c] for c in grupo)
    eje_s, eje_t = _ejes(suma_de(normales, areas, grupo))
    extension_s, extension_t = _caja_en_plano(posiciones, poligonos, grupo, eje_s, eje_t)
    area_caja = extension_s * extension_t
    largo_max = max(extension_s, extension_t)
    caja_vacia = area_caja > max(0.04, 2.5 * total)
    tira_larga = largo_max > LARGO_MAXIMO_DE_ISLA
    if len(grupo) < 2 or (not caja_vacia and not tira_larga):
        return [grupo]
    centros = np.array([posiciones[poligonos[c]].mean(axis=0) for c in grupo])
    ejes = (eje_s, eje_t) if extension_s >= extension_t else (eje_t, eje_s)
    for eje in ejes:
        valores = centros @ eje
        for corte in (float(np.median(valores)), float((valores.min() + valores.max()) / 2)):
            izquierda = [c for c, v in zip(grupo, valores) if v <= corte]
            derecha = [c for c, v in zip(grupo, valores) if v > corte]
            if not izquierda or not derecha:
                continue
            si, ti = _caja_en_plano(posiciones, poligonos, izquierda, eje_s, eje_t)
            sd, td = _caja_en_plano(posiciones, poligonos, derecha, eje_s, eje_t)
            suma_cajas = si * ti + sd * td
            achica_caja = suma_cajas < 0.85 * area_caja
            acorta_tira = (
                tira_larga
                and max(si, ti) < 0.98 * largo_max
                and max(sd, td) < 0.98 * largo_max
                and suma_cajas <= 1.15 * area_caja
            )
            if achica_caja or acorta_tira:
                return _partir_los_vacios(
                    posiciones, poligonos, izquierda, normales, areas
                ) + _partir_los_vacios(posiciones, poligonos, derecha, normales, areas)
    return [grupo]


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


def _rectangulo_libre_mayor(libre: np.ndarray) -> tuple[int, int, int, int] | None:
    """El mayor rectángulo de celdas `True` en `(c0, r0, c1, r1)`."""
    fils, cols = libre.shape
    alturas = np.zeros(cols + 1, dtype=int)
    mejor_area = 0
    mejor: tuple[int, int, int, int] | None = None
    for r in range(fils):
        alturas[:cols] = np.where(libre[r], alturas[:cols] + 1, 0)
        pila: list[int] = [-1]
        for c in range(cols + 1):
            while pila[-1] != -1 and alturas[c] < alturas[pila[-1]]:
                h = int(alturas[pila.pop()])
                c0 = pila[-1] + 1
                area = h * (c - c0)
                if area > mejor_area:
                    mejor_area = area
                    mejor = (c0, r + 1 - h, c, r + 1)
            pila.append(c)
    return mejor


def _huecos_de_isla(
    isla: Isla, posiciones: np.ndarray, poligonos: list[list[int]]
) -> list[tuple[float, float, float, float]]:
    """Rectángulos interiores vacíos `(s0, t0, s1, t1)` de un marco hueco, en metros."""
    if isla.ancho * isla.alto <= max(0.20, 2.4 * isla.area_real):
        return []
    paso = 0.02
    cols = int(np.floor(isla.ancho / paso))
    fils = int(np.floor(isla.alto / paso))
    if cols < 8 or fils < 8:
        return []
    gs, gt = np.meshgrid(
        (np.arange(cols, dtype=np.float32) + 0.5) * paso,
        (np.arange(fils, dtype=np.float32) + 0.5) * paso,
    )
    ocupado = np.zeros((fils, cols), dtype=bool)
    margen = 0.75 * paso + 0.04
    for cara in isla.caras:
        pts = np.array([isla_st(isla, posiciones[v]) for v in poligonos[cara]], dtype=np.float32)
        adentro = np.zeros((fils, cols), dtype=bool)
        n = len(pts)
        for i in range(n):
            s0, t0 = float(pts[i, 0]), float(pts[i, 1])
            s1, t1 = float(pts[(i + 1) % n, 0]), float(pts[(i + 1) % n, 1])
            cruza = (t0 > gt) != (t1 > gt)
            if cruza.any():
                s_cruce = s0 + (gt - t0) * (s1 - s0) / (t1 - t0)
                adentro ^= cruza & (gs < s_cruce)
            ds, dt = s1 - s0, t1 - t0
            largo2 = ds * ds + dt * dt
            if largo2 > 1e-12:
                parte = np.clip(((gs - s0) * ds + (gt - t0) * dt) / largo2, 0.0, 1.0)
                ocupado |= np.hypot(gs - (s0 + parte * ds), gt - (t0 + parte * dt)) < margen
            else:
                ocupado |= np.hypot(gs - s0, gt - t0) < margen
        ocupado |= adentro
    libre = ~ocupado
    huecos: list[tuple[float, float, float, float]] = []
    for _ in range(10):
        mejor = _rectangulo_libre_mayor(libre)
        if mejor is None:
            break
        c0, r0, c1, r1 = mejor
        ancho_h, alto_h = (c1 - c0) * paso, (r1 - r0) * paso
        if ancho_h * alto_h < 0.08 or min(ancho_h, alto_h) < 0.16:
            break
        huecos.append((c0 * paso, r0 * paso, c1 * paso, r1 * paso))
        libre[r0:r1, c0:c1] = False
    return huecos


def _proyectar(
    posiciones: np.ndarray,
    poligonos: list[list[int]],
    grupo: list[int],
    normal: np.ndarray,
    numero: int,
    soldado: np.ndarray,
    areas: list[float] | None = None,
) -> Isla:
    eje_s, eje_t = _ejes(normal)
    usados = sorted({v for c in grupo for v in poligonos[c]})
    puntos = posiciones[usados]
    s = puntos @ eje_s
    t = puntos @ eje_t
    minimo_s, minimo_t = float(s.min()), float(t.min())
    origen = (
        eje_s * minimo_s + eje_t * minimo_t + normal * float(np.mean(puntos @ normal))
    )
    area_real = (
        float(sum(areas[c] for c in grupo))
        if areas is not None
        else float(sum(normal_y_area(posiciones, poligonos[c])[1] for c in grupo))
    )
    isla = Isla(
        caras=grupo,
        origen=origen,
        eje_s=eje_s,
        eje_t=eje_t,
        normal=normal,
        ancho=max(float(s.max() - minimo_s), 0.002),
        alto=max(float(t.max() - minimo_t), 0.002),
        area_real=area_real,
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
    isla.huecos = _huecos_de_isla(isla, posiciones, poligonos)
    return isla


def isla_st(isla: Isla, punto: np.ndarray) -> tuple[float, float]:
    """Las coordenadas de un punto del mundo en el plano de la isla, en metros."""
    relativo = np.asarray(punto) - isla.origen
    return float(relativo @ isla.eje_s), float(relativo @ isla.eje_t)


# ── el atlas ─────────────────────────────────────────────────────────────────────────────────

MARGEN = 2


def _medidas(isla: Isla, densidad: float) -> tuple[int, int]:
    return (
        int(np.ceil(isla.ancho * densidad)) + 2 * MARGEN,
        int(np.ceil(isla.alto * densidad)) + 2 * MARGEN,
    )


def acomodar(
    islas: list[Isla], lado: int, densidad: float, reservado: int = 0
) -> bool:
    """Ubica las islas en `lado`×`lado` mediante rectángulos libres. Devuelve `False` si no entran.

    Las filas inferiores hasta `reservado` quedan libres para los parches lisos. Cada isla prueba
    su orientación normal y girada, y los huecos internos de los marcos huecos vuelven a `libres`
    para aprovechar el vidrio vacío sin tocar la geometría.
    """
    medidas = []
    for isla in islas:
        ancho, alto = _medidas(isla, densidad)
        medidas.append((ancho * alto, max(ancho, alto), ancho, alto, isla))
    medidas.sort(key=lambda m: (-m[0], -m[1], m[4].numero))
    libres = [(0, reservado, lado, lado - reservado)]
    for _, _, ancho, alto, isla in medidas:
        mejor = None
        for rx, ry, rw, rh in libres:
            for girada, iw, ih in ((False, ancho, alto), (True, alto, ancho)):
                if iw <= rw and ih <= rh:
                    sobra = (min(rw - iw, rh - ih), max(rw - iw, rh - ih), ry, rx, girada)
                    if mejor is None or sobra < mejor[0]:
                        mejor = (sobra, rx, ry, iw, ih, girada)
        if mejor is None:
            return False
        _, px, py, iw, ih, girada = mejor
        isla.x, isla.y, isla.girada = px, py, girada
        nuevos = []
        for rx, ry, rw, rh in libres:
            if px >= rx + rw or px + iw <= rx or py >= ry + rh or py + ih <= ry:
                nuevos.append((rx, ry, rw, rh))
                continue
            if px > rx:
                nuevos.append((rx, ry, px - rx, rh))
            if px + iw < rx + rw:
                nuevos.append((px + iw, ry, (rx + rw) - (px + iw), rh))
            if py > ry:
                nuevos.append((rx, ry, rw, py - ry))
            if py + ih < ry + rh:
                nuevos.append((rx, py + ih, rw, (ry + rh) - (py + ih)))
        for s0, t0, s1, t1 in isla.huecos:
            c0, f0, c1, f1 = (t0, s0, t1, s1) if girada else (s0, t0, s1, t1)
            hx0 = px + 2 * MARGEN + int(np.ceil(c0 * densidad))
            hy0 = py + 2 * MARGEN + int(np.ceil(f0 * densidad))
            hx1 = px + int(np.floor(c1 * densidad))
            hy1 = py + int(np.floor(f1 * densidad))
            if hx1 - hx0 >= 8 and hy1 - hy0 >= 8:
                nuevos.append((hx0, hy0, hx1 - hx0, hy1 - hy0))
        depurados = []
        for i, (ax, ay, aw, ah) in enumerate(nuevos):
            contenido = False
            for j, (bx, by, bw, bh) in enumerate(nuevos):
                if (
                    i != j
                    and ax >= bx
                    and ay >= by
                    and ax + aw <= bx + bw
                    and ay + ah <= by + bh
                ):
                    contenido = True
                    break
            if not contenido:
                depurados.append((ax, ay, aw, ah))
        libres = depurados
    return True


def elegir_densidad(
    islas: list[Isla], lado: int, maxima: float, minima: float = 110.0, reservado: int = 0
) -> float:
    """La mayor densidad, en texeles por metro, con la que entran todas las islas."""
    densidad = maxima
    while densidad >= minima:
        if acomodar(islas, lado, densidad, reservado):
            return densidad
        densidad *= 0.98
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
    """Ruido de valor suave en [0, 1]."""
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


def _hebras_satinadas(
    transversal_px: np.ndarray, longitudinal_px: np.ndarray, largo_px: float, semilla: int
) -> np.ndarray:
    """Hebras rectas de 1 texel de ancho a lo largo del eje de esmerilado, en [-0,5, 0,5].

    Cada columna transversal tiene su propia fase y sus propios valores: no interpola a lo ancho,
    así que nunca dibuja curvas ni vetas parecidas a la madera.
    """
    col = np.floor(transversal_px).astype(np.int64)
    cero = np.zeros_like(col)
    desfase = _azar(col, cero, cero, semilla + 1) * np.float32(largo_px)
    pos = (longitudinal_px + desfase) / np.float32(largo_px)
    fila = np.floor(pos).astype(np.int64)
    frac = (pos - fila).astype(np.float32)
    peso = frac * frac * (3.0 - 2.0 * frac)
    a = _azar(col, fila, cero, semilla + 2)
    b = _azar(col, fila + 1, cero, semilla + 2)
    return (a * (1.0 - peso) + b * peso) - np.float32(0.5)


# ── la pintura de una isla ───────────────────────────────────────────────────────────────────


def _distancia_a_los_bordes(
    s: np.ndarray, t: np.ndarray, bordes: list[tuple[float, float, float, float]]
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Distancia al borde, distancia a esquina y si el borde más cercano corre en `t`."""
    minima = np.full(s.shape, 1e3, dtype=np.float32)
    borde_en_t = np.ones(s.shape, dtype=bool)
    esquinas_set: set[tuple[float, float]] = set()
    for s0, t0, s1, t1 in bordes:
        ds, dt = s1 - s0, t1 - t0
        largo2 = ds * ds + dt * dt
        if largo2 < 1e-12:
            continue
        parte = np.clip(((s - s0) * ds + (t - t0) * dt) / largo2, 0.0, 1.0)
        distancia = np.hypot(s - (s0 + parte * ds), t - (t0 + parte * dt))
        mejor = distancia < minima
        if mejor.any():
            minima = np.where(mejor, distancia, minima)
            if abs(dt) >= abs(ds):
                borde_en_t |= mejor
            else:
                borde_en_t &= ~mejor
        esquinas_set.add((round(s0, 3), round(t0, 3)))
        esquinas_set.add((round(s1, 3), round(t1, 3)))
    min_esquina = np.full(s.shape, 1e3, dtype=np.float32)
    for cs, ct in sorted(esquinas_set):
        np.minimum(min_esquina, np.hypot(s - cs, t - ct), out=min_esquina)
    return minima, min_esquina, borde_en_t


def _manchas_de_agua_bajas(
    s: np.ndarray,
    t: np.ndarray,
    altura: np.ndarray,
    z_de: tuple[float, float, float],
    densidad: float,
    receta: Receta,
    semilla: int,
) -> tuple[np.ndarray, np.ndarray]:
    """Gotas secas chicas y residuo mineral sólo cerca del piso cuando `receta.manchas > 0`."""
    if receta.manchas <= 0.0:
        cero = np.zeros(s.shape, dtype=np.float32)
        return cero, cero
    franja_baja = _suave(receta.altura_agua, 0.02, altura)
    if float(franja_baja.max()) <= 1e-4:
        cero = np.zeros(s.shape, dtype=np.float32)
        return cero, cero
    celda = 0.032
    cx, cy = np.floor(s / celda), np.floor(t / celda)
    relleno = np.zeros(s.shape, dtype=np.float32)
    aro = np.zeros(s.shape, dtype=np.float32)
    deformacion = _valor(s * 160.0, t * 160.0, np.zeros_like(s), semilla + 7) - 0.5
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            ix, iy = cx + dx, cy + dy
            cero = np.zeros_like(ix)
            px = (ix + 0.14 + 0.72 * _azar(ix, iy, cero, semilla + 1)) * celda
            py = (iy + 0.14 + 0.72 * _azar(ix, iy, cero, semilla + 2)) * celda
            # Gotas reales de salpicadura: de 2,5 a 7,5 mm de radio, nunca círculos grandes.
            radio = 0.0025 + 0.0050 * (_azar(ix, iy, cero, semilla + 3) ** 1.8)
            h_centro = np.maximum(z_de[0] + z_de[1] * px + z_de[2] * py - receta.suelo, 0.0)
            cerca = _suave(receta.altura_agua, 0.015, h_centro)
            probabilidad = receta.manchas * 0.55 * cerca
            existe = (_azar(ix, iy, cero, semilla + 4) < probabilidad).astype(np.float32)
            # Leve estiramiento vertical por escurrimiento.
            distancia = np.hypot(s - px, (t - py) * 0.82) + deformacion * radio * 0.55
            borde = max(0.85 / densidad, 0.0018)
            dentro = _suave(radio + borde, radio - borde * 0.6, distancia) * existe
            borde_mineral = (
                _suave(radio - 1.6 * borde, radio - 0.4 * borde, distancia)
                * _suave(radio + borde, radio, distancia)
                * existe
            )
            relleno = np.maximum(relleno, dentro * 0.55)
            aro = np.maximum(aro, borde_mineral)
    # Velo muy tenue de trapeado en los primeros centímetros junto al piso.
    cortina = _valor(s * 48.0, t * 9.0, np.zeros_like(s), semilla + 19)
    velo = _suave(0.46, 0.78, cortina) * _suave(0.14, 0.01, altura) * min(receta.manchas, 1.0)
    relleno_bajo = np.clip(relleno + 0.30 * velo, 0.0, 1.0) * franja_baja
    aro_bajo = np.clip(aro, 0.0, 1.0) * franja_baja
    return relleno_bajo, aro_bajo


def _rayones_finos(
    ancho: int,
    alto: int,
    densidad: float,
    cantidad: int,
    azar: np.random.Generator,
    angulo_base,
    aceptar,
    largo: tuple[float, float],
    fraccion_alineada: float = 0.58,
    dispersion: float = 0.24,
) -> tuple[np.ndarray, np.ndarray]:
    """Rayones finos a escala real, con leve curvatura y puntas afinadas.

    Devuelve dos capas en [0, 1]: `brunidos` (aplanan el grano y bajan la rugosidad) y `mates`
    (micro-surcos ásperos que suben la rugosidad).
    """
    brunidos = np.zeros((alto, ancho), dtype=np.float32)
    mates = np.zeros((alto, ancho), dtype=np.float32)
    if cantidad <= 0:
        return brunidos, mates
    x0 = azar.uniform(MARGEN, max(MARGEN + 1, ancho - MARGEN), cantidad)
    y0 = azar.uniform(MARGEN, max(MARGEN + 1, alto - MARGEN), cantidad)
    queda = azar.uniform(0.0, 1.0, cantidad) < aceptar(x0, y0)
    x0, y0 = x0[queda], y0[queda]
    n = len(x0)
    if n == 0:
        return brunidos, mates
    metros = np.exp(azar.uniform(np.log(largo[0]), np.log(largo[1]), n))
    pixeles = np.maximum(metros * densidad, 2.0)
    base = angulo_base(x0, y0) if callable(angulo_base) else angulo_base
    alineado = azar.uniform(0.0, 1.0, n) < fraccion_alineada
    angulo = np.where(
        alineado, base + azar.normal(0.0, dispersion, n), azar.uniform(0.0, np.pi, n)
    )
    curvatura = azar.normal(0.0, 0.45 if densidad < 220.0 else 0.65, n)
    fuerza = azar.uniform(0.35, 0.95, n)
    es_brunido = azar.uniform(0.0, 1.0, n) < 0.54
    pasos = int(np.ceil(pixeles.max() * 1.5)) + 2
    avance = np.linspace(0.0, 1.0, pasos, dtype=np.float32)[None, :]
    perfil = np.maximum(np.sin(np.pi * avance), 0.0) ** 0.55
    cos_a, sin_a = np.cos(angulo)[:, None], np.sin(angulo)[:, None]
    arco = (4.0 * avance * (1.0 - avance)) * curvatura[:, None]
    largo_px = pixeles[:, None] * avance
    xs = x0[:, None] + cos_a * largo_px - sin_a * arco
    ys = y0[:, None] + sin_a * largo_px + cos_a * arco
    xi, yi = np.floor(xs).astype(int), np.floor(ys).astype(int)
    dentro = (xi >= 0) & (xi < ancho) & (yi >= 0) & (yi < alto)
    aporte = (fuerza[:, None] * perfil).astype(np.float32)
    for capa, elegido in ((brunidos, es_brunido), (mates, ~es_brunido)):
        mascara = dentro & elegido[:, None]
        np.maximum.at(capa, (yi[mascara], xi[mascara]), aporte[mascara])
    return np.clip(brunidos, 0.0, 1.0), np.clip(mates, 0.0, 1.0)


def _huellas_de_dedos(
    s: np.ndarray,
    t: np.ndarray,
    azar: np.random.Generator,
    cantidad: int,
    aceptar,
    semilla: int,
) -> np.ndarray:
    """Yemas de dedos individuales, grupos de 2 a 3 dedos y breves arrastres de tacto."""
    marca = np.zeros(s.shape, dtype=np.float32)
    if cantidad <= 0:
        return marca
    max_s, max_t = float(s.max()), float(t.max())
    if max_s <= 0.008 or max_t <= 0.008:
        return marca
    micro = 0.80 + 0.20 * _valor(s * 340.0, t * 340.0, np.zeros_like(s), semilla + 61)
    for _ in range(cantidad):
        cs = azar.uniform(0.006, max(0.007, max_s - 0.006))
        ct = azar.uniform(0.006, max(0.007, max_t - 0.006))
        if azar.uniform() >= aceptar(cs, ct):
            continue
        giro_libre = 0.0 if azar.uniform() < 0.7 else azar.uniform(0, np.pi)
        angulo = azar.uniform(-0.65, 0.65) + giro_libre
        cos_a, sin_a = float(np.cos(angulo)), float(np.sin(angulo))
        # Un tercio de las marcas agrupa 2 o 3 dedos paralelos, como al empujar o sostener.
        dedos = int(azar.choice((1, 1, 2, 3)))
        arrastre = azar.uniform(1.0, 1.7) if dedos == 1 and azar.uniform() < 0.35 else 1.0
        paso_dedo = azar.uniform(0.015, 0.019)
        fuerza_base = azar.uniform(0.50, 0.95)
        for indice_dedo in range(dedos):
            despl = (indice_dedo - 0.5 * (dedos - 1)) * paso_dedo
            arco = -abs(indice_dedo - 0.5 * (dedos - 1)) * 0.004
            px = cs + cos_a * despl - sin_a * arco
            py = ct + sin_a * despl + cos_a * arco
            r_ancho = azar.uniform(0.0065, 0.0095)
            r_largo = azar.uniform(0.0110, 0.0175) * arrastre
            # Sólo evaluar en la ventana local de la yema para ir rápido en islas grandes.
            alcance = max(r_ancho, r_largo) * 1.45
            col_mask = (s[0] >= px - alcance) & (s[0] <= px + alcance)
            fil_mask = (t[:, 0] >= py - alcance) & (t[:, 0] <= py + alcance)
            if not col_mask.any() or not fil_mask.any():
                continue
            ventana = np.ix_(fil_mask, col_mask)
            ds = s[ventana] - px
            dt = t[ventana] - py
            u = ds * cos_a + dt * sin_a
            v = -ds * sin_a + dt * cos_a
            # Más presión hacia la punta de apoyo y desvanecimiento suave hacia atrás.
            sesgo = 0.85 + 0.22 * np.clip(v / max(r_largo, 1e-4), -1.0, 1.0)
            forma = np.hypot(u / r_ancho, v / r_largo)
            yema = _suave(1.12, 0.18, forma) * sesgo * micro[ventana]
            peso_dedo = fuerza_base * (0.82 ** indice_dedo)
            marca[ventana] = np.maximum(marca[ventana], yema * peso_dedo)
    return np.clip(marca, 0.0, 1.0)


def _peso_de_huellas(
    zs: np.ndarray,
    distancia_borde: np.ndarray | float,
    suelo: float,
    z_min_isla: float,
    z_max_isla: float,
    vertical: bool,
) -> np.ndarray:
    """Dónde apoyan las manos: nunca junto al piso ni arriba de 1,75 m."""
    if z_min_isla - suelo > 1.75 or z_max_isla - suelo < 0.34:
        return np.zeros_like(zs, dtype=np.float32)
    altura = np.maximum(zs - suelo, 0.0)
    sobre_piso = _suave(0.30, 0.48, altura)
    borde = 0.45 + 0.55 * np.exp(-np.asarray(distancia_borde, dtype=np.float32) / 0.06)
    mano = np.exp(-(((zs - ALTURA_DE_MANO) / ANCHO_DE_MANO) ** 2))
    if vertical and z_max_isla - suelo > 1.25:
        return np.clip(mano * borde * sobre_piso, 0.0, 1.0).astype(np.float32)
    if vertical and z_max_isla - suelo > 0.35:
        rel = np.clip((zs - z_min_isla) / max(z_max_isla - z_min_isla, 0.05), 0.0, 1.0)
        tramo = (0.18 + 0.78 * _suave(0.22, 0.80, rel)) * borde * sobre_piso
        return np.clip(tramo, 0.0, 1.0).astype(np.float32)
    borde_fino = 0.25 + 0.75 * np.exp(-np.asarray(distancia_borde, dtype=np.float32) / 0.04)
    return np.clip(0.80 * mano * borde_fino * sobre_piso, 0.0, 1.0).astype(np.float32)


def _fuera_de_huecos(
    cs: np.ndarray | float,
    ct: np.ndarray | float,
    huecos: list[tuple[float, float, float, float]],
) -> np.ndarray:
    cs_arr = np.asarray(cs)
    ct_arr = np.asarray(ct)
    libre = np.ones(cs_arr.shape, dtype=bool)
    for s0, t0, s1, t1 in huecos:
        adentro = (cs_arr > s0) & (cs_arr < s1) & (ct_arr > t0) & (ct_arr < t1)
        libre &= np.logical_not(adentro)
    return libre


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
    z_min_isla, z_max_isla = float(z.min()), float(z.max())
    semilla = receta.semilla * 1009 + isla.numero * 7919
    azar = np.random.default_rng(semilla)
    area = isla.ancho * isla.alto
    vertical = abs(float(isla.normal[2])) < 0.5
    z_de = (float(isla.origen[2]), float(isla.eje_s[2]), float(isla.eje_t[2]))
    distancia, distancia_esquina, borde_en_t = _distancia_a_los_bordes(s, t, isla.bordes)

    # El satinado sigue el eje largo de cada pieza; en marcos huecos sigue cada parante o riel.
    px_s, px_t = s * densidad, t * densidad
    grano_t = 0.68 * _hebras_satinadas(px_s, px_t, 4.5, semilla + 17) + 0.32 * _hebras_satinadas(
        px_s, px_t, 12.0, semilla + 21
    )
    grano_s = 0.68 * _hebras_satinadas(px_t, px_s, 4.5, semilla + 17) + 0.32 * _hebras_satinadas(
        px_t, px_s, 12.0, semilla + 21
    )
    if isla.huecos:
        en_t = borde_en_t
    else:
        en_t = np.full(s.shape, isla.alto >= isla.ancho, dtype=bool)
    grano = np.where(en_t, grano_t, grano_s) * receta.satinado

    # Variación suave y limpia de lámina, sin nubes oscuras de suciedad.
    tono = (_fbm(x, y, z, 1.4, 2, semilla + 11) - 0.5) * receta.variacion

    # Manchas de agua pequeñas sólo cerca del piso cuando la receta las habilita.
    relleno_agua, aro_agua = _manchas_de_agua_bajas(s, t, altura, z_de, densidad, receta, semilla)

    # Zona de tacto de manos (sin piso) y de roce general para rayones.
    huella_mapa = _peso_de_huellas(z, distancia, receta.suelo, z_min_isla, z_max_isla, vertical)
    roce_mapa = np.maximum(huella_mapa, 0.45 * _suave(0.30, 0.03, altura))

    def angulo_local(px: np.ndarray, py: np.ndarray) -> np.ndarray:
        yi = np.clip(np.floor(py).astype(int), 0, alto - 1)
        xi = np.clip(np.floor(px).astype(int), 0, ancho - 1)
        return np.where(en_t[yi, xi], np.pi / 2, 0.0)

    def aceptar_rayon_fino(px: np.ndarray, py: np.ndarray) -> np.ndarray:
        cs = px / densidad - MARGEN / densidad
        ct = py / densidad - MARGEN / densidad
        activo = _fuera_de_huecos(cs, ct, isla.huecos) if isla.huecos else 1.0
        zs = z_de[0] + z_de[1] * cs + z_de[2] * ct
        borde_piso = np.exp(-np.maximum(zs - receta.suelo, 0.0) / 0.26)
        mano = _peso_de_huellas(zs, 0.04, receta.suelo, z_min_isla, z_max_isla, vertical)
        return activo * np.clip(0.28 + 0.72 * np.maximum(mano, 0.75 * borde_piso), 0.0, 1.0)

    def aceptar_roce_bajo(px: np.ndarray, py: np.ndarray) -> np.ndarray:
        cs = px / densidad - MARGEN / densidad
        ct = py / densidad - MARGEN / densidad
        activo = _fuera_de_huecos(cs, ct, isla.huecos) if isla.huecos else 1.0
        zs = z_de[0] + z_de[1] * cs + z_de[2] * ct
        return activo * _suave(0.28, 0.02, np.maximum(zs - receta.suelo, 0.0))

    baja_densidad = densidad < 220.0
    largo_fino = (0.008, 0.025) if baja_densidad else (0.007, 0.034)
    alineacion_fina = 0.78 if baja_densidad else 0.58
    dispersion_fina = 0.13 if baja_densidad else 0.24
    n_finos = int(round(area * 920.0 * receta.rayones))
    brunidos, mates = _rayones_finos(
        ancho,
        alto,
        densidad,
        n_finos,
        azar,
        angulo_local,
        aceptar_rayon_fino,
        largo_fino,
        fraccion_alineada=alineacion_fina,
        dispersion=dispersion_fina,
    )
    if z_min_isla - receta.suelo < 0.28 and receta.rayones > 0.0:
        n_bajos = int(round(area * (180.0 if baja_densidad else 280.0) * receta.rayones))
        b_bajos, m_bajos = _rayones_finos(
            ancho,
            alto,
            densidad,
            n_bajos,
            azar,
            0.0 if not vertical else angulo_local,
            aceptar_roce_bajo,
            (0.014, 0.034) if baja_densidad else (0.018, 0.050),
            fraccion_alineada=0.72 if baja_densidad else 0.48,
            dispersion=0.14 if baja_densidad else 0.24,
        )
        brunidos = np.maximum(brunidos, b_bajos)
        mates = np.maximum(mates, m_bajos)

    huella = np.zeros_like(s)
    if receta.huellas > 0.0 and float(huella_mapa.max()) > 0.02:
        intentos = int(azar.poisson(area * 32.0 * receta.huellas))

        def aceptar_huella(cs: float, ct: float) -> float:
            if isla.huecos and not bool(_fuera_de_huecos(cs, ct, isla.huecos)):
                return 0.0
            zs = np.float32(z_de[0] + z_de[1] * cs + z_de[2] * ct)
            return float(
                _peso_de_huellas(zs, 0.025, receta.suelo, z_min_isla, z_max_isla, vertical)
            )

        huella = _huellas_de_dedos(s, t, azar, intentos, aceptar_huella, semilla)

    # Pulido suave donde hay roce frecuente, y suciedad contenida junto al piso y los encuentros.
    uso = roce_mapa * _suave(0.35, 0.75, _fbm(x, y, z, 3.6, 2, semilla + 37))
    ruido_borde = _fbm(x, y, z, 18.0, 2, semilla + 31)
    piso = np.exp(-altura / 0.025) * (0.55 + 0.45 * _fbm(x, y, z, 14.0, 2, semilla + 29))
    junta = np.exp(-distancia / 0.0050) * (0.45 + 0.55 * ruido_borde)
    esquina = np.exp(-distancia_esquina / 0.034) * (0.42 + 0.58 * ruido_borde)
    encuentro = np.clip(0.45 * junta + 0.90 * esquina, 0.0, 1.0)

    mugre = receta.mugre
    escala_color_rayon = float(np.clip(densidad / 230.0, 0.58, 1.0))
    # En el color todo es contenido: acero limpio usado, con leve sombra mate en los encuentros.
    factor_luz = (
        1.0
        + 0.055 * tono
        + 0.075 * grano
        + 0.022 * uso
        + 0.095 * escala_color_rayon * brunidos
        - 0.058 * escala_color_rayon * mates
        - 0.028 * huella
        - 0.13 * mugre * piso
        - 0.17 * mugre * encuentro
    )
    deposito_claro = np.clip(0.050 * relleno_agua + 0.090 * aro_agua, 0.0, 0.22)
    base = np.array(receta.color, dtype=np.float32)[None, None, :]
    color = base * factor_luz[..., None]
    color = color + (1.0 - color) * deposito_claro[..., None]
    color = np.clip(color, 0.0, 1.0)

    # La rugosidad (canal G del ORM) lleva el contraste franco que leen las sondas de reflejos:
    # las huellas, el agua y los rayones mates dispersan el reflejo; los rayones bruñidos y el
    # roce frecuente lo afilan.
    escala_r = receta.escala_rugosidad
    suciedad = np.minimum(piso + encuentro, 1.0)
    delta_rugosidad = (
        0.105 * grano
        + 0.145 * huella
        + 0.23 * mates
        - 0.16 * brunidos
        - 0.038 * uso
        + 0.17 * relleno_agua
        + 0.23 * aro_agua
        + 0.22 * mugre * suciedad
    ) * escala_r
    rugosidad = receta.rugosidad + delta_rugosidad
    metal = (
        receta.metal
        - 0.08 * huella
        - 0.16 * relleno_agua
        - 0.14 * aro_agua
        - 0.12 * mugre * suciedad
    )
    return (
        color.astype(np.float32),
        np.clip(rugosidad, 0.06, 0.94).astype(np.float32),
        np.clip(metal, 0.25, 1.0).astype(np.float32),
    )


# ── el atlas completo ────────────────────────────────────────────────────────────────────────

LADO_DEL_PARCHE = 8


def parche_liso(receta: Receta, lado: int, indice: int) -> tuple[float, float]:
    """La UV del centro del parche liso de la receta `indice`."""
    return (indice * LADO_DEL_PARCHE + LADO_DEL_PARCHE / 2) / lado, (LADO_DEL_PARCHE / 2) / lado


def _mascara_util_isla(isla: Isla, alto: int, ancho: int, densidad: float) -> np.ndarray | None:
    if not isla.huecos:
        return None
    columnas = (np.arange(ancho, dtype=np.float32) + 0.5 - MARGEN) / np.float32(densidad)
    filas = (np.arange(alto, dtype=np.float32) + 0.5 - MARGEN) / np.float32(densidad)
    s, t = np.meshgrid(columnas, filas)
    return _fuera_de_huecos(s, t, isla.huecos)


def armar_atlas(
    islas: list[Isla], recetas: list[Receta], lado: int, densidad: float
) -> tuple[np.ndarray, np.ndarray]:
    """El color (sRGB, 0..1) y el ORM (oclusión, rugosidad y metal) del atlas, `v` hacia arriba.

    Cada material conserva su tono medio: el detalle reparte la luz y cambia la rugosidad sin
    oscurecer ni aclarar la pieza entera. Los marcos huecos se copian antes que las islas alojadas
    adentro de sus huecos de vidrio.
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
        suma = np.zeros(3, dtype=np.float64)
        cantidad = 0
        for isla, c, _, _ in propias:
            mascara = _mascara_util_isla(isla, c.shape[0], c.shape[1], densidad)
            muestras = c[mascara] if mascara is not None else c.reshape(-1, 3)
            if len(muestras):
                suma += muestras.sum(axis=0)
                cantidad += len(muestras)
        media = (suma / max(cantidad, 1)).astype(np.float32)
        factor = np.array(receta.color, dtype=np.float32) / np.maximum(media, 1e-4)
        for i, (isla, c, r, m) in enumerate(pintadas):
            if isla.receta == receta:
                pintadas[i] = (isla, np.clip(c * factor, 0.0, 1.0), r, m)
    ordenadas = sorted(pintadas, key=lambda p: -(p[0].ancho * p[0].alto))
    for isla, c, r, m in ordenadas:
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
    anterior = np.zeros_like(bytes8)
    anterior[:, 1:] = bytes8[:, :-1]
    filtrado = (bytes8.astype(np.int16) - anterior.astype(np.int16)).astype(np.uint8)
    filas = np.concatenate(
        [np.ones((alto, 1), dtype=np.uint8), filtrado.reshape(alto, -1)], axis=1
    )
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
