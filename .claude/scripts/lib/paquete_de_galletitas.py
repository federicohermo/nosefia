"""Un paquete de galletitas de tipo flow pack: cuerpo abombado y un cierre prensado a cada costado.

Es la forma de Oremos y de Pepito. Es Python puro, sin Blender: lo que decide la forma, su UV y el
reparto de su textura vive acá, y `blender/armar_paquetes_de_galletitas.py` sólo lo lleva a la
malla. El cierre de los costados no se arma acá: es el de `lib/cierre_de_envases.py`, el mismo de
las bolsas.

## La forma

El paquete mira a +x, tiene el ancho a lo largo de y y el alto en z. Ocupa la misma caja que el
cubo que reemplaza: lo mide quien lo arma, y no cambia ni cuántas unidades entran por estante ni
por caja.

- **El cuerpo** tiene una sección de superelipse que se achata contra el frente y el dorso: casi
  plano en el medio, redondeado en los hombros de arriba y de abajo. A lo largo se afina hacia
  cada costado hasta cerrarse en la costura.
- **Los cierres** salen de las costuras, a izquierda y derecha, y entran en el ancho de la caja.

## El desplegado

Cuatro paneles: el frente, el dorso, el canto de arriba y el de abajo. El frente lleva el arte
entero y el resto va a la mitad de densidad: es lo que se ve. Cada panel tiene la `u` a lo largo
del ancho y la `v` sobre el recorrido de la superficie, así el arte no se aplasta en la curva. Los
cierres repiten la franja de los extremos del frente y del dorso: no llevan letras.
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from dataclasses import dataclass

#: Cuánto del ancho, de cada lado, es cierre.
FRANJA_DEL_CIERRE = 0.085

#: Qué tan plano es el frente: con 2 la sección sería una elipse.
PLANITUD = 4.0

#: Gajos de la sección en el frente y en el dorso, y en el canto de arriba y el de abajo.
GAJOS_DEL_FRENTE = 6
GAJOS_DEL_CANTO = 2

#: Anillos del cuerpo a lo largo del ancho, de costura a costura.
INTERVALOS = 10

#: Cuánto antes de cada costura el cuerpo ya está afinándose, en metros.
TRANSICION = 0.05

#: El ancho de la hoja de arte, en píxeles. Sale a la mitad, que es el lado con que viajan las
#: etiquetas de producto.
LIENZO_ANCHO = 1024
LIENZO_ALTO = 576

#: El aire entre paneles del lienzo, en píxeles.
CALLE = 12

#: Cuántos píxeles por metro lleva el frente, y qué fracción de eso el resto de los paneles.
DENSIDAD_DEL_FRENTE = 640 / 0.27
FRACCION_DEL_RESTO = 0.5

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

    @property
    def semiancho_del_cuerpo(self) -> float:
        """Hasta dónde llega el cuerpo a cada lado: ahí empieza el cierre."""
        return self.ancho / 2 * (1 - 2 * FRANJA_DEL_CIERRE)

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


def _tramo_de_la_curva(desde: float, hasta: float, gajos: int, caja: Caja):
    """Los `gajos + 1` puntos de la curva entre dos ángulos, parejos en recorrido, y el largo."""
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
        meta = largo * k / gajos
        i = min(range(len(acumulado)), key=lambda j: abs(acumulado[j] - meta))
        elegidos.append(puntos[i])
    elegidos[0], elegidos[-1] = puntos[0], puntos[-1]
    return elegidos, largo


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
        elegidos, largo = _tramo_de_la_curva(desde, hasta, gajos, caja)
        largos[panel] = largo
        acumulado = [0.0]
        for a, b in zip(elegidos, elegidos[1:]):
            acumulado.append(acumulado[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
        total = acumulado[-1]
        for k in range(gajos):
            puntos.append(elegidos[k])
            tramos.append(panel)
            recorrido.append((acumulado[k] / total, acumulado[k + 1] / total))
    return Seccion(tuple(puntos), tuple(tramos), tuple(recorrido), largos)


def alturas_de_los_anillos(caja: Caja) -> list[float]:
    """La posición en y de cada anillo del cuerpo, de la costura izquierda a la derecha. Se
    juntan cerca de las costuras, donde el cuerpo se cierra."""
    semi = caja.semiancho_del_cuerpo
    return [-semi * math.cos(math.pi * i / INTERVALOS) for i in range(INTERVALOS + 1)]


def grosor_en(y: float, caja: Caja, espesor_en_la_costura: float) -> float:
    """Qué fracción del grosor máximo tiene el cuerpo en `y`: la de la costura al borde del
    cierre y 1 pasada la transición. Sin quiebre donde empieza."""
    semi = caja.semiancho_del_cuerpo
    resto = max(0.0, min(1.0, (semi - abs(y)) / TRANSICION))
    return max(espesor_en_la_costura, math.sin(math.pi / 2 * resto))


Rect = tuple[int, int, int, int]


def desplegado(caja: Caja) -> dict[str, Rect]:
    """El rectángulo de cada panel en la hoja de arte, como `(x, y, ancho, alto)` en píxeles con
    el origen arriba a la izquierda."""
    secc = seccion(caja)
    ancho_f = round(caja.ancho * DENSIDAD_DEL_FRENTE)
    alto_f = round(secc.largo_de_cada_panel[FRENTE] * DENSIDAD_DEL_FRENTE)
    densidad = DENSIDAD_DEL_FRENTE * FRACCION_DEL_RESTO
    ancho_d = round(caja.ancho * densidad)
    alto_d = round(secc.largo_de_cada_panel[DORSO] * densidad)
    ancho_c = round(2 * caja.semiancho_del_cuerpo * densidad)
    alto_c = round(secc.largo_de_cada_panel[ARRIBA] * densidad)
    x_resto = CALLE + ancho_f + CALLE
    rects = {
        FRENTE: (CALLE, CALLE, ancho_f, alto_f),
        DORSO: (x_resto, CALLE, ancho_d, alto_d),
        ARRIBA: (x_resto, CALLE + alto_d + CALLE, ancho_c, alto_c),
        ABAJO: (x_resto, CALLE + alto_d + CALLE + alto_c + CALLE, ancho_c, alto_c),
    }
    for panel, (x, y, w, h) in rects.items():
        if x + w + CALLE > LIENZO_ANCHO or y + h + CALLE > LIENZO_ALTO:
            raise ValueError(f"el panel {panel} no entra en la hoja de arte")
    return rects


def uv_en_el_panel(rect: Rect, u: float, v_abajo: float) -> tuple[float, float]:
    """La UV de un punto de un panel: `u` de izquierda a derecha y `v_abajo` de arriba hacia
    abajo del panel, ambas de 0 a 1. Blender mide la `v` desde abajo."""
    x, y, ancho, alto = rect
    return (x + u * ancho) / LIENZO_ANCHO, 1.0 - (y + v_abajo * alto) / LIENZO_ALTO


def u_del_cuerpo(panel: str, y: float, caja: Caja) -> float:
    """Dónde cae `y` a lo ancho de un panel. El frente y el dorso cubren el ancho entero, con las
    franjas del cierre en los extremos, y el dorso se lee al revés. Los cantos cubren el cuerpo."""
    if panel == FRENTE:
        return (y + caja.ancho / 2) / caja.ancho
    if panel == DORSO:
        return (caja.ancho / 2 - y) / caja.ancho
    semi = caja.semiancho_del_cuerpo
    return (y + semi) / (2 * semi)


def v_del_cuerpo(panel: str, recorrido: float) -> float:
    """Dónde cae un punto del recorrido de su panel, de arriba hacia abajo. El recorrido del
    frente y del dorso va de abajo hacia arriba y de arriba hacia abajo respectivamente; el del
    canto de arriba, del frente al dorso, y el del de abajo, del dorso al frente. En la hoja el
    frente de los cantos queda abajo."""
    if panel == FRENTE:
        return 1.0 - recorrido
    if panel == DORSO:
        return recorrido
    if panel == ARRIBA:
        return 1.0 - recorrido
    return recorrido


def uv_del_cierre(lado: int, y: float, z: float, caja: Caja, rects: dict[str, Rect]):
    """La UV de un punto del cierre. `lado` es 1 para la cara del frente y -1 para la del dorso.
    En la costura la franja de arte cubre toda la altura del panel."""
    panel = FRENTE if lado == 1 else DORSO
    return uv_en_el_panel(rects[panel], u_del_cuerpo(panel, y, caja), 1.0 - z / caja.alto)


def caras_de_un_anillo_a_otro(secc: Seccion) -> Sequence[tuple[int, int, str, tuple[float, float]]]:
    """Las caras entre dos anillos: `(k, k_siguiente, panel, recorrido)` por cada gajo."""
    n = len(secc.puntos)
    return [(k, (k + 1) % n, secc.tramos[k], secc.recorrido[k]) for k in range(n)]
