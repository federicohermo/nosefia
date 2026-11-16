"""Qué recortes del arte original arman la textura de Oremos y de Pepito, y dónde caen en el atlas.

Es Python puro: lo que decide **de dónde sale cada píxel de la textura** vive acá, y
`blender/recortar_paquetes_de_galletitas.py` sólo copia. La textura de cada paquete es un atlas de
**recortes rectangulares del arte del artista** (`assets/source/products-textured/galletitas/`),
copiados tal cual, sin escalar, sin componer y sin pintar nada:

- `frente`: el panel FRONT del desplegado del artista, sin las franjas prensadas de los costados.
  Llena el frente del envase de borde a borde.
- `dorso`: el panel BACK, sin sus franjas. Llena el dorso a lo ancho.
- Cuatro franjas de **prensado recto**, una por cada cara de cada aleta: las del FRONT y las del
  BACK, sin el borde dentado de afuera.

Lo que el arte no cubre (el afinado de los costados, los hombros, los cantos y lo que sobra del
dorso) no lleva píxeles propios: la UV se queda en el borde del recorte, y el borde se repite. El
color de borde es el del propio panel.

Cada recorte lleva `RELLENO` píxeles repetidos alrededor, para que el filtro no mezcle un recorte
con el de al lado ni con lo que haya detrás.

## Cómo se midieron los recortes

Sobre cada panel del arte, con la ayuda de ampliaciones: el límite de abajo y de arriba es el borde
azul del panel menos 2 o 4 píxeles, y el de los costados es donde terminan los surcos de la franja
prensada, más lo que mide su reborde claro. Las medidas son del arte actual: si el artista lo
cambia, hay que volver a medirlas.
"""

from __future__ import annotations

from dataclasses import dataclass

FUENTES = {"OREMOS": "oremos.png", "PEPITO": "pepito.png"}

FRENTE = "frente"
DORSO = "dorso"
ALETA_FRENTE_IZQUIERDA = "aleta_frente_izquierda"
ALETA_FRENTE_DERECHA = "aleta_frente_derecha"
ALETA_DORSO_IZQUIERDA = "aleta_dorso_izquierda"
ALETA_DORSO_DERECHA = "aleta_dorso_derecha"
ZONAS = (
    FRENTE,
    DORSO,
    ALETA_FRENTE_IZQUIERDA,
    ALETA_FRENTE_DERECHA,
    ALETA_DORSO_IZQUIERDA,
    ALETA_DORSO_DERECHA,
)

Rect = tuple[int, int, int, int]

#: `(x0, y0, x1, y1)` en el arte original, con `x1` e `y1` excluidos. Las franjas de las aletas
#: se miran desde afuera: la izquierda de un panel es la que tiene el borde dentado a la izquierda.
RECORTES: dict[str, dict[str, tuple[int, int, int, int]]] = {
    "OREMOS": {
        FRENTE: (258, 214, 1005, 700),
        DORSO: (257, 741, 1012, 1034),
        ALETA_FRENTE_IZQUIERDA: (194, 214, 244, 700),
        ALETA_FRENTE_DERECHA: (1016, 214, 1066, 700),
        ALETA_DORSO_IZQUIERDA: (196, 741, 246, 1034),
        ALETA_DORSO_DERECHA: (1022, 741, 1062, 1034),
    },
    "PEPITO": {
        FRENTE: (243, 252, 1016, 787),
        DORSO: (133, 839, 1121, 1043),
        ALETA_FRENTE_IZQUIERDA: (180, 252, 232, 787),
        ALETA_FRENTE_DERECHA: (1026, 252, 1074, 787),
        ALETA_DORSO_IZQUIERDA: (76, 839, 124, 1043),
        ALETA_DORSO_DERECHA: (1131, 839, 1180, 1043),
    },
}

#: El ancho del atlas, en píxeles. Sale a la mitad, que es el lado con que viajan las etiquetas
#: de producto.
ANCHO_DEL_ATLAS = 1024

#: El aire entre recortes y hasta el borde del atlas, en píxeles, y los píxeles que se repiten
#: alrededor de cada recorte. El relleno es menor que la mitad del aire.
GUARDA = 16
RELLENO = 8


@dataclass(frozen=True)
class Disposicion:
    """El atlas de un paquete: su tamaño y el rectángulo `(x, y, ancho, alto)` de cada zona."""

    ancho: int
    alto: int
    rects: dict[str, Rect]


def medida(rect: tuple[int, int, int, int]) -> tuple[int, int]:
    x0, y0, x1, y1 = rect
    return x1 - x0, y1 - y0


def relacion_del_frente(clave: str) -> float:
    """Ancho sobre alto del frente del arte, sin las franjas prensadas."""
    ancho, alto = medida(RECORTES[clave][FRENTE])
    return ancho / alto


def _arriba_a_16(valor: int) -> int:
    return -(-valor // 16) * 16


def disposicion(clave: str) -> Disposicion:
    """Dónde cae cada recorte en el atlas. En una fila el frente con sus dos franjas, en la
    siguiente el dorso, y sus franjas a la derecha si entran y si no en una fila más."""
    recortes = RECORTES[clave]
    rects: dict[str, Rect] = {}
    y = GUARDA
    ancho_f, alto_f = medida(recortes[FRENTE])
    rects[FRENTE] = (GUARDA, y, ancho_f, alto_f)
    x = GUARDA + ancho_f + GUARDA
    for zona in (ALETA_FRENTE_IZQUIERDA, ALETA_FRENTE_DERECHA):
        ancho, alto = medida(recortes[zona])
        rects[zona] = (x, y, ancho, alto)
        x += ancho + GUARDA
    y += alto_f + GUARDA
    ancho_d, alto_d = medida(recortes[DORSO])
    rects[DORSO] = (GUARDA, y, ancho_d, alto_d)
    x = GUARDA + ancho_d + GUARDA
    anchos = [medida(recortes[z])[0] + GUARDA for z in (ALETA_DORSO_IZQUIERDA, ALETA_DORSO_DERECHA)]
    entran = x + sum(anchos)
    if entran <= ANCHO_DEL_ATLAS:
        for zona in (ALETA_DORSO_IZQUIERDA, ALETA_DORSO_DERECHA):
            ancho, alto = medida(recortes[zona])
            rects[zona] = (x, y, ancho, alto)
            x += ancho + GUARDA
        y += alto_d + GUARDA
    else:
        y += alto_d + GUARDA
        x = GUARDA
        for zona in (ALETA_DORSO_IZQUIERDA, ALETA_DORSO_DERECHA):
            ancho, alto = medida(recortes[zona])
            rects[zona] = (x, y, ancho, alto)
            x += ancho + GUARDA
        y += alto_d + GUARDA
    for zona, (rx, ry, rw, rh) in rects.items():
        if rx + rw + GUARDA > ANCHO_DEL_ATLAS:
            raise ValueError(f"el recorte {zona} de {clave} no entra a lo ancho del atlas")
    return Disposicion(ANCHO_DEL_ATLAS, _arriba_a_16(y), rects)
