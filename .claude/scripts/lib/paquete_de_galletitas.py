"""Un paquete de galletitas de tipo flow pack: cuerpo abombado y un cierre prensado a cada costado.

Es la forma de Oremos y de Pepito. Es Python puro, sin Blender: lo que decide la forma, su UV y el
reparto de su textura vive acá, y `blender/armar_paquetes_de_galletitas.py` sólo lo lleva a la
malla. El cierre de los costados no se arma acá: es el de `lib/cierre_de_envases.py`, el mismo de
las bolsas.

## La forma

El paquete mira a +x, tiene el ancho a lo largo de y y el alto en z. **Conserva el ancho y el
fondo del cubo que reemplaza**, así que no cambia ni cuántas unidades entran por estante ni por
caja, y **baja el alto** hasta la proporción apaisada de un flow pack real: ancho sobre alto del
cuerpo sin las aletas, medido sobre la foto de referencia de cada producto (`RELACION_DEL_CUERPO`).
Apoya en el estante por la base y queda más bajo que el cubo.

- **El cuerpo** tiene una sección de superelipse que se achata contra el frente y el dorso: casi
  plano en el medio, redondeado en los hombros de arriba y de abajo. A lo largo se afina hacia
  cada costado hasta cerrarse en la costura.
- **Los cierres** salen de las costuras, a izquierda y derecha, y entran en el ancho de la caja.

## El desplegado

Cuatro paneles en una columna, de arriba abajo: el canto de arriba, el frente, el canto de abajo
y el dorso. El frente toca los dos cantos, así el fondo sigue de uno al otro. **Todos tienen la
misma densidad de texeles**, y cada panel tiene la `u` sobre el recorrido de la superficie a lo
ancho y la `v` sobre el recorrido a lo alto: un píxel mide lo mismo en x y en y.

El frente es un rectángulo recto: la aleta de cada punta, el afinado que lleva el cuerpo hasta la
costura, y entre los dos afinados la **zona segura del arte**, plana y sin curva. El afinado y los
hombros de arriba y de abajo no llevan arte: es el fondo que se estira donde el cuerpo se cierra.
Cada panel lleva un sangrado alrededor: lo que se pinta de más, para que el filtro no mezcle
paneles.
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from functools import lru_cache
from dataclasses import dataclass

#: Cuánto del ancho, de cada lado, es cierre.
FRANJA_DEL_CIERRE = 0.085

#: Qué tan plano es el frente: con 2 la sección sería una elipse.
PLANITUD = 6.0

#: Gajos de la sección en el frente y en el dorso, y en el canto de arriba y el de abajo.
GAJOS_DEL_FRENTE = 6
GAJOS_DEL_CANTO = 2

#: Cuánto antes de cada costura el cuerpo ya está afinándose, en metros.
TRANSICION = 0.025

#: Los anillos del cuerpo en el afinado, como fracción de la transición medida desde la costura:
#: cerca de ella se juntan, donde la curva se cierra.
ANILLOS_DEL_AFINADO = (0.0, 0.12, 0.3, 0.55, 0.8, 1.0)

#: El tamaño de la hoja de arte, en píxeles. Sale a un cuarto, 384 x 512, que va dentro del lado
#: de 512 con que viajan las etiquetas de producto.
LIENZO_ANCHO = 1536
LIENZO_ALTO = 2048

#: El aire entre los rectángulos de dos paneles, y hasta el borde de la hoja, en píxeles.
CALLE = 56

#: Lo que se pinta de más alrededor de cada panel, en píxeles. Menor que `CALLE / 2`.
SANGRADO = 24

#: Cuánto se aleja del borde del panel la zona segura del arte, en metros.
MARGEN_SEGURO = 0.004

#: Hasta dónde el frente sigue siendo plano: la fracción del grosor máximo bajo la cual la curva
#: del hombro ya se nota.
PLANO_HASTA = 0.97

#: Ancho sobre alto del cuerpo sin las aletas, medido sobre la foto de referencia de cada
#: producto: Oremos 793 x 651 y Pepito 353 x 311 píxeles.
RELACION_DEL_CUERPO = {"OREMOS": 793 / 651, "PEPITO": 353 / 311}

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


def alto_del_paquete(producto: str, ancho: float) -> float:
    """El alto que da la proporción apaisada del producto, al milímetro."""
    cuerpo = ancho * (1 - 2 * FRANJA_DEL_CIERRE)
    return round(cuerpo / RELACION_DEL_CUERPO[producto], 3)


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


Rect = tuple[int, int, int, int]


@lru_cache(maxsize=None)
def recorrido_a_lo_ancho(caja: Caja, factor: float = 1.0) -> tuple[tuple[float, float], ...]:
    """El recorrido de la superficie a lo ancho hasta cada anillo del lado derecho: `(y, s)` con
    `s` en metros desde el centro. `factor` es qué fracción del grosor máximo tiene el punto de la
    sección que se recorre: el frente por el medio es 1 y el centro del canto es 0.

    Ahí el cuerpo se afina y la superficie es más larga que su proyección: medir `u` sobre `y` la
    estiraría. Cada punto de la sección tiene su propio recorrido, porque a media altura el
    frente está más adelante que cerca de los hombros. Se mide sobre la poligonal que unen los
    anillos, que es lo que la malla dibuja entre ellos."""
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
        i = min(max(j for j, (yj, _) in enumerate(tabla) if yj <= magnitud + 1e-12), len(tabla) - 2)
        (y0, s0), (y1, s1) = tabla[i], tabla[i + 1]
        valor = s0 + (s1 - s0) * (magnitud - y0) / (y1 - y0)
    return math.copysign(valor, y)


def mitad_del_recorrido(caja: Caja) -> float:
    """La mitad del recorrido del frente a lo ancho, de una punta de cierre a la otra."""
    return recorrido_hasta(caja.ancho / 2, caja)


def factor_del_canto(caja: Caja) -> float:
    """El grosor relativo del punto más adelantado del canto de arriba: ahí el recorrido es el
    más largo, y es el que fija el ancho del panel."""
    return max(abs(x) for (x, _), panel in zip(seccion(caja).puntos, seccion(caja).tramos)
               if panel == ARRIBA) / (caja.fondo / 2)


def mitad_del_canto(caja: Caja) -> float:
    return recorrido_hasta(caja.semiancho_del_cuerpo, caja, factor_del_canto(caja))


def densidad(caja: Caja) -> float:
    """Los píxeles por metro de todos los paneles: la mayor, de a diez, con la que la columna
    entra en la hoja."""
    secc = seccion(caja)
    anchos = 2 * mitad_del_recorrido(caja)
    altos = (
        2 * secc.largo_de_cada_panel[FRENTE] + 2 * secc.largo_de_cada_panel[ARRIBA]
    )
    por_ancho = (LIENZO_ANCHO - 2 * CALLE) / anchos
    por_alto = (LIENZO_ALTO - 5 * CALLE) / altos
    return math.floor(min(por_ancho, por_alto) / 10) * 10.0


def desplegado(caja: Caja) -> dict[str, Rect]:
    """El rectángulo de cada panel en la hoja de arte, como `(x, y, ancho, alto)` en píxeles con
    el origen arriba a la izquierda. Los píxeles por metro son los mismos en todos los paneles y
    a lo ancho y a lo alto."""
    secc = seccion(caja)
    d = densidad(caja)
    ancho_f = round(2 * mitad_del_recorrido(caja) * d)
    ancho_c = round(2 * mitad_del_canto(caja) * d)
    alto_f = round(secc.largo_de_cada_panel[FRENTE] * d)
    alto_c = round(secc.largo_de_cada_panel[ARRIBA] * d)
    medidas = [
        (ARRIBA, ancho_c, alto_c),
        (FRENTE, ancho_f, alto_f),
        (ABAJO, ancho_c, alto_c),
        (DORSO, ancho_f, alto_f),
    ]
    rects: dict[str, Rect] = {}
    y = CALLE
    for panel, ancho, alto in medidas:
        rects[panel] = ((LIENZO_ANCHO - ancho) // 2, y, ancho, alto)
        y += alto + CALLE
    for panel, (x, y, w, h) in rects.items():
        if x < CALLE or x + w + CALLE > LIENZO_ANCHO or y + h + CALLE > LIENZO_ALTO:
            raise ValueError(f"el panel {panel} no entra en la hoja de arte")
    return rects


def _largo_plano_de_la_curva(caja: Caja, panel: str) -> tuple[float, float]:
    """De cada extremo del recorrido del frente, cuántos metros de hombro hasta que la
    sección se vuelve plana, con la poligonal que dibuja la malla: `(desde_abajo, desde_arriba)`."""
    secc = seccion(caja)
    puntos = [p for p, t in zip(secc.puntos, secc.tramos) if t == panel]
    siguiente = [p for p, t in zip(secc.puntos[1:] + secc.puntos[:1], secc.tramos) if t == panel]
    puntos = puntos + [siguiente[-1]]
    maximo = caja.fondo / 2
    acumulado = [0.0]
    for a, b in zip(puntos, puntos[1:]):
        acumulado.append(acumulado[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    total = acumulado[-1]

    def hasta_plano(orden):
        recorrido = 0.0
        pares = list(zip(puntos, puntos[1:]))
        if orden:
            pares = [(b, a) for a, b in reversed(pares)]
        for a, b in pares:
            if abs(b[0]) >= PLANO_HASTA * maximo:
                x0, x1 = abs(a[0]), abs(b[0])
                tramo = math.hypot(b[0] - a[0], b[1] - a[1])
                if x1 == x0:
                    return recorrido
                return recorrido + tramo * max(0.0, (PLANO_HASTA * maximo - x0) / (x1 - x0))
            recorrido += math.hypot(b[0] - a[0], b[1] - a[1])
        return total

    return hasta_plano(False), hasta_plano(True)


def zonas(caja: Caja) -> dict:
    """Las zonas de cada panel en la hoja, en píxeles: `{panel: {zona: rect}}`.

    Todo panel lleva su `panel` y su `sangrado` (el panel con `SANGRADO` de más por lado). El
    frente y el dorso llevan además las dos aletas, los dos afinados, y la `zona_segura` del arte;
    los cantos, los afinados y su zona segura. Lo que no es zona segura se pinta, pero sin arte:
    fondo continuo."""
    rects = desplegado(caja)
    d = densidad(caja)
    secc = seccion(caja)
    margen = round(MARGEN_SEGURO * d)
    semi = caja.semiancho_del_cuerpo
    salida = round(caja.salida_del_cierre * d)
    s_plano = recorrido_hasta(semi - TRANSICION, caja)
    afinado = round((recorrido_hasta(semi, caja) - s_plano) * d)
    resultado = {}
    for panel, (x, y, w, h) in rects.items():
        zona = {
            "panel": [x, y, w, h],
            "sangrado": [x - SANGRADO, y - SANGRADO, w + 2 * SANGRADO, h + 2 * SANGRADO],
        }
        if panel in (FRENTE, DORSO):
            zona["aleta_izquierda"] = [x, y, salida, h]
            zona["aleta_derecha"] = [x + w - salida, y, salida, h]
            zona["afinado_izquierdo"] = [x + salida, y, afinado, h]
            zona["afinado_derecho"] = [x + w - salida - afinado, y, afinado, h]
            desde_abajo, desde_arriba = _largo_plano_de_la_curva(caja, panel)
            if panel == DORSO:
                desde_abajo, desde_arriba = desde_arriba, desde_abajo
            hombro_abajo = round(desde_abajo * d)
            hombro_arriba = round(desde_arriba * d)
            x0 = x + salida + afinado + margen
            x1 = x + w - salida - afinado - margen
            y0 = y + hombro_arriba + margen
            y1 = y + h - hombro_abajo - margen
            zona["zona_segura"] = [x0, y0, x1 - x0, y1 - y0]
        else:
            f_canto = factor_del_canto(caja)
            largo_afinado = recorrido_hasta(semi, caja, f_canto) - recorrido_hasta(
                semi - TRANSICION, caja, f_canto
            )
            afinado_c = round(largo_afinado * d)
            zona["afinado_izquierdo"] = [x, y, afinado_c, h]
            zona["afinado_derecho"] = [x + w - afinado_c, y, afinado_c, h]
            zona["zona_segura"] = [
                x + afinado_c + margen, y + margen, w - 2 * (afinado_c + margen), h - 2 * margen,
            ]
        resultado[panel] = zona
    return resultado


def uv_en_el_panel(rect: Rect, u: float, v_abajo: float) -> tuple[float, float]:
    """La UV de un punto de un panel: `u` de izquierda a derecha y `v_abajo` de arriba hacia
    abajo del panel, ambas de 0 a 1. Blender mide la `v` desde abajo."""
    x, y, ancho, alto = rect
    return (x + u * ancho) / LIENZO_ANCHO, 1.0 - (y + v_abajo * alto) / LIENZO_ALTO


def u_del_cuerpo(panel: str, y: float, caja: Caja, factor: float = 1.0) -> float:
    """Dónde cae `y` a lo ancho de un panel, para un punto de la sección de grosor relativo
    `factor`. Todos miden el recorrido de la superficie con la misma escala que la `v`: un píxel
    mide lo mismo en x y en y. El dorso se lee al revés."""
    if panel == FRENTE:
        return 0.5 + recorrido_hasta(y, caja, factor) / (2 * mitad_del_recorrido(caja))
    if panel == DORSO:
        return 0.5 - recorrido_hasta(y, caja, factor) / (2 * mitad_del_recorrido(caja))
    return 0.5 + recorrido_hasta(y, caja, factor) / (2 * mitad_del_canto(caja))


def v_del_cuerpo(panel: str, recorrido: float) -> float:
    """Dónde cae un punto del recorrido de su panel, de arriba hacia abajo. El recorrido del
    frente y del dorso va de abajo hacia arriba y de arriba hacia abajo respectivamente; el del
    canto de arriba, del frente al dorso, y el del de abajo, del dorso al frente. En la hoja el
    canto de arriba toca el frente por abajo y el de abajo lo toca por arriba."""
    if panel == FRENTE:
        return 1.0 - recorrido
    if panel == DORSO:
        return recorrido
    return 1.0 - recorrido


def uv_del_cierre(lado: int, y: float, z: float, caja: Caja, rects: dict[str, Rect]):
    """La UV de un punto del cierre. `lado` es 1 para la cara del frente y -1 para la del dorso.
    En la costura la franja de arte cubre toda la altura del panel."""
    panel = FRENTE if lado == 1 else DORSO
    return uv_en_el_panel(rects[panel], u_del_cuerpo(panel, y, caja), 1.0 - z / caja.alto)


def caras_de_un_anillo_a_otro(secc: Seccion) -> Sequence[tuple[int, int, str, tuple[float, float]]]:
    """Las caras entre dos anillos: `(k, k_siguiente, panel, recorrido)` por cada gajo."""
    n = len(secc.puntos)
    return [(k, (k + 1) % n, secc.tramos[k], secc.recorrido[k]) for k in range(n)]
