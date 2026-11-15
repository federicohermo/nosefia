"""El desplegado de las bolsas de galletitas: dónde cae cada cara en la textura de 512 x 352.

Lo comparten `armar_texturas_de_bolsas.py`, que pinta cada región, y `armar_bolsas.py`, que lleva
las UV de la malla a ella. **Es lo único que sabe las dos cosas**: cambiar una región es cambiar
una línea acá, y las dos herramientas siguen de acuerdo.

## La imagen

Cuatro regiones, en píxeles y de arriba a abajo: el frente y el dorso, cuadrados, lado a lado,
y debajo los dos costados, acostados. Cada panel lleva en su primera y su última fila el prensado
del cierre; la aleta del cierre repite esa franja.

## Qué no hace

No sabe de Blender ni de Pillow: sólo devuelve números.
"""

from __future__ import annotations

ANCHO = 512
ALTO = 352

#: Cuántas filas, en cada punta de un panel, ocupa el prensado del cierre.
PRENSADO = 12

#: Cada región como `(x0, y0, x1, y1)`, en píxeles de la imagen. Los extremos son exclusivos.
REGIONES: dict[str, tuple[int, int, int, int]] = {
    "frente": (8, 8, 252, 252),
    "dorso": (260, 8, 504, 252),
    "derecha": (8, 260, 252, 296),
    "izquierda": (8, 304, 252, 340),
}

#: Las regiones cuyo largo corre a lo ancho de la imagen: el costado va acostado.
ACOSTADAS = ("derecha", "izquierda")


def recorte(nombre: str) -> tuple[float, float, float, float]:
    """La región como `(u0, u1, v0, v1)`, con `v` creciendo hacia arriba como en Blender.

    Entra medio píxel por cada lado: el filtro bilineal del borde no mezcla la región vecina.
    """
    x0, y0, x1, y1 = REGIONES[nombre]
    return (
        (x0 + 0.5) / ANCHO,
        (x1 - 0.5) / ANCHO,
        1.0 - (y1 - 0.5) / ALTO,
        1.0 - (y0 + 0.5) / ALTO,
    )


def banda_del_cierre() -> float:
    """El alto de la franja de prensado, en fracción de la imagen, medido sobre `v`."""
    return PRENSADO / ALTO
