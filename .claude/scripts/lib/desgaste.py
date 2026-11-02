"""La capa de desgaste: marcas de uso sobre una etiqueta, sin redibujarla.

Una etiqueta que se regenera con una imagen generada corre sus contornos y cambia sus letras.
Una capa de desgaste no: se **suma** al dibujo original, y el dibujo queda donde estaba.

## La capa

Una imagen en escala de grises. El gris 128 es «no cambia nada», lo más claro aclara y lo más
oscuro oscurece. Una capa generada nunca queda exactamente en 128, así que se le resta su
mediana: lo que cuenta es la diferencia con su propio gris de fondo.

## La fórmula

Con `D` la capa en 0..255 y `A` la etiqueta en 0..1:

    D = (D - 128) / 127
    D -= mediana(D)
    mascara = luminancia(A) en 0..255 > 24
    B = clip(A + (D * fuerza * mascara) * (0.35 + 0.65 * A), 0, 1)

La **máscara** deja el negro como está: una marca clara sobre un contorno negro lo rompería. El
factor `0.35 + 0.65 * A` hace que el color oscuro cambie menos que el claro, y que el desgaste
no deje manchas lavadas sobre el azul profundo ni sobre el rojo. El alfa no se toca.

## Una capa, varios productos

Dos productos vecinos no pueden mostrar la misma marca. Una misma capa sirve a varios si a cada
uno se la gira, se la espeja o se la desplaza distinto: `preparar_capa`. El desplazamiento da la
vuelta por el borde, así que ninguna marca se pierde.

Toda la matemática es de la biblioteca estándar. El script que lee y escribe los PNG corre
adentro de Blender (`blender/aplicar_desgaste.py`) y le pasa listas planas de píxeles.
"""

from collections.abc import Sequence

#: El gris que significa «no cambia nada».
GRIS_NEUTRO = 128

#: Cuánto vale 1.0 de la capa, en niveles de gris.
ESCALA_DE_LA_CAPA = 127

#: Lo que no pasa de este brillo, en 0..255, no se toca.
UMBRAL_DE_BRILLO = 24

#: El factor de cuánto cambia un color: el mínimo, y lo que suma el propio color.
PISO = 0.35
PESO_DEL_COLOR = 0.65

GIROS = (0, 90, 180, 270)


def mediana(valores: Sequence[float]) -> float:
    ordenados = sorted(valores)
    medio = len(ordenados) // 2
    if len(ordenados) % 2:
        return ordenados[medio]
    return (ordenados[medio - 1] + ordenados[medio]) / 2


def normalizar(capa: Sequence[float]) -> list[float]:
    """La capa de 0..255 como diferencia con su propio fondo: 0 no cambia nada."""
    diferencias = [(valor - GRIS_NEUTRO) / ESCALA_DE_LA_CAPA for valor in capa]
    fondo = mediana(diferencias)
    return [valor - fondo for valor in diferencias]


def luminancia(rojo: float, verde: float, azul: float) -> float:
    """El brillo de un color de 0..1, en 0..255 (Rec. 709)."""
    return 255 * (0.2126 * rojo + 0.7152 * verde + 0.0722 * azul)


def aplicar(
    pixeles: Sequence[float], capa: Sequence[float], fuerza: float = 1.0
) -> list[float]:
    """La etiqueta con el desgaste encima.

    `pixeles` es RGBA de 0..1, fila por fila, y `capa` tiene un valor de 0..255 por píxel, del
    mismo tamaño que la etiqueta. Devuelve RGBA con el alfa intacto.
    """
    if len(pixeles) != 4 * len(capa):
        raise ValueError(f"la capa tiene {len(capa)} píxeles y la etiqueta {len(pixeles) // 4}")
    diferencia = normalizar(capa)
    salida = list(pixeles)
    for i, d in enumerate(diferencia):
        base = 4 * i
        rojo, verde, azul = pixeles[base], pixeles[base + 1], pixeles[base + 2]
        if luminancia(rojo, verde, azul) <= UMBRAL_DE_BRILLO:
            continue
        d *= fuerza
        for canal, valor in enumerate((rojo, verde, azul)):
            nuevo = valor + d * (PISO + PESO_DEL_COLOR * valor)
            salida[base + canal] = min(1.0, max(0.0, nuevo))
    return salida


def _filas(valores: Sequence[float], ancho: int) -> list[list[float]]:
    return [list(valores[i : i + ancho]) for i in range(0, len(valores), ancho)]


def preparar_capa(
    capa: Sequence[float],
    lado: int,
    ancho: int,
    alto: int,
    giro: int = 0,
    espejo: bool = False,
    desplazamiento: tuple[float, float] = (0.0, 0.0),
) -> list[float]:
    """La capa cuadrada de `lado`, vista de otra manera y recortada al tamaño de la etiqueta.

    `giro` va en sentidos de reloj de 90 grados, `espejo` da vuelta los lados, y el
    desplazamiento es una fracción del lado, con vuelta por el borde. El recorte toma la esquina
    de arriba a la izquierda: la capa tiene que ser tan grande como el lado mayor de la etiqueta.
    """
    if giro not in GIROS:
        raise ValueError(f"el giro es uno de {GIROS}, y llegó {giro}")
    if len(capa) != lado * lado:
        raise ValueError(f"una capa de lado {lado} no tiene {len(capa)} píxeles")
    if lado < max(ancho, alto):
        raise ValueError(f"la capa mide {lado} y la etiqueta {ancho}x{alto}: no la cubre")
    filas = _filas(capa, lado)
    if espejo:
        filas = [fila[::-1] for fila in filas]
    for _ in range(giro // 90):
        filas = [list(fila) for fila in zip(*filas[::-1])]
    corrida_x = round(desplazamiento[0] * lado) % lado
    corrida_y = round(desplazamiento[1] * lado) % lado
    filas = filas[corrida_y:] + filas[:corrida_y]
    filas = [fila[corrida_x:] + fila[:corrida_x] for fila in filas]
    return [valor for fila in filas[:alto] for valor in fila[:ancho]]
