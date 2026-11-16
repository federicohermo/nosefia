"""Un paquete de galletitas de tipo flow pack: cuerpo abombado y un cierre prensado a cada costado.

Es la forma de Oremos y de Pepito. Es Python puro, sin Blender: lo que decide la forma y su UV
vive acá, y `blender/armar_paquetes_de_galletitas.py` sólo lo lleva a la malla. El cierre de los
costados no se arma acá: es el de `lib/cierre_de_envases.py`, el mismo de las bolsas. Los recortes
del arte que forman la textura los decide `lib/recortes_de_paquetes.py`.

## La forma

El paquete mira a +x, tiene el ancho a lo largo de y y el alto en z. **Conserva el ancho y el
fondo del cubo que reemplaza**, así que no cambia ni cuántas unidades entran por estante ni por
caja. **El alto sale del arte**: el frente del envase tiene la proporción del panel FRONT del
arte, sin sus franjas prensadas, y el paquete apoya en el estante por la base y queda más bajo.

- **El cuerpo** tiene una sección de superelipse que se achata contra el frente y el dorso: casi
  plano en el medio, redondeado en los hombros de arriba y de abajo. Hacia cada costura se afina
  en `TRANSICION` metros hasta cerrarse.
- **Los cierres** salen de las costuras, a izquierda y derecha, y entran en el ancho de la caja.

## La UV

El **arte** cubre la zona visible del frente: de un afinado al otro a lo ancho, y de hombro a hombro
a lo alto. Su ancho es `2 * semiancho_de_arte` y su alto lo fija la proporción del arte, así que el
panel FRONT llena esa zona **de borde a borde, a una sola escala en x y en y**.

Lo que el arte no cubre, la UV lo deja en el borde del recorte, y el borde se repite: el afinado,
los dos cantos (que llevan el borde de arriba y de abajo del frente) y lo que sobra del dorso, cuyo
recorte es más apaisado que el frente y se pone a lo ancho. Nada de eso lleva arte.

La `u` mide el recorrido de la superficie a lo ancho, y la `v` el recorrido a lo alto: un píxel mide
lo mismo en x y en y.
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from dataclasses import dataclass
from functools import lru_cache

from lib import recortes_de_paquetes as recortes

#: Cuánto del ancho, de cada lado, es cierre.
FRANJA_DEL_CIERRE = 0.085

#: Qué tan plano es el frente: con 2 la sección sería una elipse.
PLANITUD = 6.0

#: Gajos de la sección en el frente y en el dorso, y en el canto de arriba y el de abajo.
GAJOS_DEL_FRENTE = 6
GAJOS_DEL_CANTO = 2

#: Cuánto antes de cada costura el cuerpo ya está afinándose, en metros.
TRANSICION = 0.02

#: Los anillos del cuerpo en el afinado, como fracción de la transición medida desde la costura:
#: cerca de ella se juntan, donde la curva se cierra.
ANILLOS_DEL_AFINADO = (0.0, 0.12, 0.3, 0.55, 0.8, 1.0)

FRENTE = "frente"
DORSO = "dorso"
ARRIBA = "arriba"
ABAJO = "abajo"
PANELES = (FRENTE, DORSO, ARRIBA, ABAJO)


@dataclass(frozen=True)
class Caja:
    """Lo que ocupa el paquete, en metros: `ancho` en y, `fondo` en x y `alto` en z."""

    ancho: float
    fondo: float
    alto: float
    #: Dónde empieza y dónde termina el arte del dorso, como fracción del recorrido del dorso: el
    #: recorte del dorso es más apaisado que el frente y no lo llena a lo alto. Las caras del dorso
    #: se cortan ahí, para que el borde del arte caiga sobre un vértice y no en medio de una cara.
    banda_del_dorso: tuple[float, float] = (0.0, 1.0)

    @property
    def semiancho_del_cuerpo(self) -> float:
        """Hasta dónde llega el cuerpo a cada lado: ahí empieza el cierre."""
        return self.ancho / 2 * (1 - 2 * FRANJA_DEL_CIERRE)

    @property
    def semiancho_de_arte(self) -> float:
        """Hasta dónde llega el arte a cada lado: donde empieza el afinado."""
        return self.semiancho_del_cuerpo - TRANSICION

    @property
    def salida_del_cierre(self) -> float:
        return self.ancho / 2 - self.semiancho_del_cuerpo


@dataclass(frozen=True)
class Seccion:
    """La sección del cuerpo en su punto más grueso, y a qué panel va cada tramo.

    `puntos` son `(x, z)` en metros, con `z` desde la base, en el orden en que se recorre: el
    frente de abajo hacia arriba, el canto de arriba hacia el dorso, el dorso de arriba hacia
    abajo y el canto de abajo hacia el frente. El primer punto no se repite al final. `tramos[k]`
    es el panel de la cara entre `puntos[k]` y el siguiente, y `recorrido[k]` los dos extremos de
    esa cara como fracción del recorrido de su panel.
    """

    puntos: tuple[tuple[float, float], ...]
    tramos: tuple[str, ...]
    recorrido: tuple[tuple[float, float], ...]
    largo_de_cada_panel: dict[str, float]


def _punto_de_la_curva(angulo: float, caja: Caja) -> tuple[float, float]:
    exponente = 2 / PLANITUD
    c, s = math.cos(angulo), math.sin(angulo)
    x = caja.fondo / 2 * math.copysign(abs(c) ** exponente, c)
    z = caja.alto / 2 + caja.alto / 2 * math.copysign(abs(s) ** exponente, s)
    return x, z


def _tramo_de_la_curva(desde: float, hasta: float, gajos: int, caja: Caja, cortes=None):
    """Los `gajos + 1` puntos de la curva entre dos ángulos, parejos en recorrido salvo que se den
    los `cortes`, fracciones del recorrido, y el largo."""
    muestras = 600
    puntos = [
        _punto_de_la_curva(desde + (hasta - desde) * i / muestras, caja)
        for i in range(muestras + 1)
    ]
    acumulado = [0.0]
    for a, b in zip(puntos, puntos[1:]):
        acumulado.append(acumulado[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    largo = acumulado[-1]
    elegidos = []
    for k in range(gajos + 1):
        meta = largo * (cortes[k] if cortes else k / gajos)
        i = min(range(len(acumulado)), key=lambda j: abs(acumulado[j] - meta))
        elegidos.append(puntos[i])
    elegidos[0], elegidos[-1] = puntos[0], puntos[-1]
    return elegidos, largo


@lru_cache(maxsize=None)
def seccion(caja: Caja) -> Seccion:
    cuarto = math.pi / 4
    tramos_de_la_curva = (
        (FRENTE, -cuarto, cuarto, GAJOS_DEL_FRENTE),
        (ARRIBA, cuarto, 3 * cuarto, GAJOS_DEL_CANTO),
        (DORSO, 3 * cuarto, 5 * cuarto, GAJOS_DEL_FRENTE),
        (ABAJO, 5 * cuarto, 7 * cuarto, GAJOS_DEL_CANTO),
    )
    puntos: list[tuple[float, float]] = []
    tramos: list[str] = []
    recorrido: list[tuple[float, float]] = []
    largos: dict[str, float] = {}
    for panel, desde, hasta, gajos in tramos_de_la_curva:
        cortes = None
        if panel == DORSO and caja.banda_del_dorso != (0.0, 1.0):
            desde_b, hasta_b = caja.banda_del_dorso
            medio = [desde_b + (hasta_b - desde_b) * k / (gajos - 2) for k in range(gajos - 1)]
            cortes = [0.0] + medio + [1.0]
        elegidos, _ = _tramo_de_la_curva(desde, hasta, gajos, caja, cortes)
        acumulado = [0.0]
        for a, b in zip(elegidos, elegidos[1:]):
            acumulado.append(acumulado[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
        total = acumulado[-1]
        largos[panel] = total
        for k in range(gajos):
            puntos.append(elegidos[k])
            tramos.append(panel)
            recorrido.append((acumulado[k] / total, acumulado[k + 1] / total))
    return Seccion(tuple(puntos), tuple(tramos), tuple(recorrido), largos)


def alto_del_paquete(producto: str, ancho: float, fondo: float) -> float:
    """El alto con el que el frente del envase, de hombro a hombro, tiene la proporción del arte.

    El arte mide `2 * semiancho_de_arte` de ancho, y su alto es ese ancho sobre la relación de
    aspecto del recorte del frente. El frente crece con el alto del paquete, así que se busca el
    alto con el que su recorrido da justo eso."""
    semiancho = ancho / 2 * (1 - 2 * FRANJA_DEL_CIERRE) - TRANSICION
    buscado = 2 * semiancho / recortes.relacion_del_frente(producto)
    bajo, alto = 0.0, ancho
    for _ in range(60):
        medio = (bajo + alto) / 2
        if seccion(Caja(ancho, fondo, medio)).largo_de_cada_panel[FRENTE] < buscado:
            bajo = medio
        else:
            alto = medio
    return round((bajo + alto) / 2, 4)


def caja_del_paquete(producto: str, ancho: float, fondo: float) -> Caja:
    """La caja del paquete: el ancho y el fondo dados, el alto del arte y la banda del dorso."""
    base = Caja(ancho, fondo, alto_del_paquete(producto, ancho, fondo))
    disposicion = recortes.disposicion(producto)
    _, _, ancho_d, alto_d = disposicion.rects[DORSO]
    largo = seccion(base).largo_de_cada_panel[DORSO]
    alto_del_arte = alto_d * (2 * base.semiancho_de_arte) / ancho_d
    sobra = max(0.0, largo - alto_del_arte) / 2
    return Caja(ancho, fondo, base.alto, (sobra / largo, 1.0 - sobra / largo))


def alturas_de_los_anillos(caja: Caja) -> list[float]:
    """La posición en y de cada anillo del cuerpo, de la costura izquierda a la derecha: juntos
    en el afinado, uno al empezarlo y uno en el medio, donde el cuerpo es plano."""
    semi = caja.semiancho_del_cuerpo
    del_lado = [semi - TRANSICION * r for r in ANILLOS_DEL_AFINADO]
    plano = [semi - TRANSICION - (semi - TRANSICION) / 2, 0.0]
    derecha = sorted(y for y in del_lado + plano if y >= 0)
    return [-y for y in reversed(derecha) if y > 0] + derecha


def grosor_en(y: float, caja: Caja, espesor_en_la_costura: float) -> float:
    """Qué fracción del grosor máximo tiene el cuerpo en `y`: la de la costura al borde del
    cierre y 1 pasada la transición. Sin quiebre donde empieza."""
    semi = caja.semiancho_del_cuerpo
    resto = max(0.0, min(1.0, (semi - abs(y)) / TRANSICION))
    return max(espesor_en_la_costura, math.sin(math.pi / 2 * resto))


@lru_cache(maxsize=None)
def recorrido_a_lo_ancho(caja: Caja, factor: float = 1.0) -> tuple[tuple[float, float], ...]:
    """El recorrido de la superficie a lo ancho hasta cada anillo del lado derecho: `(y, s)` con
    `s` en metros desde el centro. `factor` es qué fracción del grosor máximo tiene el punto de la
    sección que se recorre: el frente por el medio es 1 y el centro del canto es 0.

    Ahí el cuerpo se afina y la superficie es más larga que su proyección: medir `u` sobre `y` la
    estiraría. Se mide sobre la poligonal que unen los anillos, que es lo que la malla dibuja
    entre ellos."""
    espesor = 0.002 / (caja.fondo / 2)
    anillos = [y for y in alturas_de_los_anillos(caja) if y >= -1e-12]
    puntos = [(0.0, 0.0)]
    anterior = (0.0, caja.fondo / 2 * factor * grosor_en(0.0, caja, espesor))
    s = 0.0
    for y in anillos[1:]:
        x = caja.fondo / 2 * factor * grosor_en(y, caja, espesor)
        s += math.hypot(y - anterior[0], x - anterior[1])
        anterior = (y, x)
        puntos.append((y, s))
    return tuple(puntos)


def recorrido_hasta(y: float, caja: Caja, factor: float = 1.0) -> float:
    """El recorrido a lo ancho desde el centro hasta `y`, con signo. Pasada la costura, el
    cierre es plano: ahí el recorrido es la proyección."""
    tabla = recorrido_a_lo_ancho(caja, round(factor, 6))
    semi = caja.semiancho_del_cuerpo
    magnitud = abs(y)
    if magnitud >= semi - 1e-12:
        valor = tabla[-1][1] + max(0.0, magnitud - semi)
    else:
        i = max(j for j, (yj, _) in enumerate(tabla) if yj <= magnitud + 1e-12)
        i = min(i, len(tabla) - 2)
        (y0, s0), (y1, s1) = tabla[i], tabla[i + 1]
        valor = s0 + (s1 - s0) * (magnitud - y0) / (y1 - y0)
    return math.copysign(valor, y)


Rect = tuple[int, int, int, int]


def uv_en_el_recorte(disposicion: recortes.Disposicion, zona: str, u: float, v_abajo: float):
    """La UV de un punto de un recorte del atlas: `u` de izquierda a derecha y `v_abajo` de arriba
    hacia abajo del recorte, de 0 a 1 y sin salirse. Blender mide la `v` desde abajo."""
    x, y, ancho, alto = disposicion.rects[zona]
    u = min(max(u, 0.0), 1.0)
    v_abajo = min(max(v_abajo, 0.0), 1.0)
    return (x + u * ancho) / disposicion.ancho, 1.0 - (y + v_abajo * alto) / disposicion.alto


def pixeles_por_metro(disposicion: recortes.Disposicion, caja: Caja) -> float:
    """Cuántos píxeles del arte entran en un metro del frente, a lo ancho y a lo alto."""
    return disposicion.rects[FRENTE][2] / (2 * caja.semiancho_de_arte)


def uv_del_cuerpo(
    disposicion: recortes.Disposicion,
    panel: str,
    y: float,
    recorrido: float,
    caja: Caja,
    factor: float = 1.0,
) -> tuple[float, float]:
    """La UV de un punto del cuerpo: `y` a lo ancho, `recorrido` como fracción del recorrido de
    su panel (del frente de abajo hacia arriba, del dorso de arriba hacia abajo), y `factor` el
    grosor relativo del punto de la sección.

    El frente lleva el arte de un afinado al otro y de hombro a hombro. El dorso, el suyo a lo
    ancho y centrado a lo alto. Los cantos llevan el borde de arriba y el de abajo del frente.
    Fuera del arte la UV se queda en el borde del recorte."""
    media = caja.semiancho_de_arte
    a_lo_ancho = recorrido_hasta(y, caja, factor)
    u = 0.5 + a_lo_ancho / (2 * media)
    if panel == FRENTE:
        return uv_en_el_recorte(disposicion, FRENTE, u, 1.0 - recorrido)
    if panel == ARRIBA:
        return uv_en_el_recorte(disposicion, FRENTE, u, 0.0)
    if panel == ABAJO:
        return uv_en_el_recorte(disposicion, FRENTE, u, 1.0)
    largo = seccion(caja).largo_de_cada_panel[DORSO]
    metros_por_pixel = (2 * media) / disposicion.rects[DORSO][2]
    alto_del_arte = disposicion.rects[DORSO][3] * metros_por_pixel
    desde_arriba = recorrido * largo - (largo - alto_del_arte) / 2
    return uv_en_el_recorte(disposicion, DORSO, 1.0 - u, desde_arriba / alto_del_arte)


def uv_del_cierre(
    disposicion: recortes.Disposicion, lado: int, y: float, z: float, caja: Caja
) -> tuple[float, float]:
    """La UV de un punto del cierre. `lado` es 1 para la cara del frente y -1 para la del dorso.
    Cada cara lleva el prensado recto de su panel, de la costura hacia afuera."""
    afuera = min(max((abs(y) - caja.semiancho_del_cuerpo) / caja.salida_del_cierre, 0.0), 1.0)
    # La franja izquierda de un panel tiene el borde dentado a la izquierda: su costura queda a la
    # derecha. El dorso se ve desde atrás, así que su izquierda es el lado de y positivo.
    a_la_izquierda = (y < 0) if lado == 1 else (y > 0)
    if lado == 1:
        zona = (
            recortes.ALETA_FRENTE_IZQUIERDA if a_la_izquierda else recortes.ALETA_FRENTE_DERECHA
        )
    else:
        zona = recortes.ALETA_DORSO_IZQUIERDA if a_la_izquierda else recortes.ALETA_DORSO_DERECHA
    u = 1.0 - afuera if a_la_izquierda else afuera
    return uv_en_el_recorte(disposicion, zona, u, 1.0 - z / caja.alto)


def caras_de_un_anillo_a_otro(secc: Seccion) -> Sequence[tuple[int, int, str, tuple[float, float]]]:
    """Las caras entre dos anillos: `(k, k_siguiente, panel, recorrido)` por cada gajo."""
    n = len(secc.puntos)
    return [(k, (k + 1) % n, secc.tramos[k], secc.recorrido[k]) for k in range(n)]
