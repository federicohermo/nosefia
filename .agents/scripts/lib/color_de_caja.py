"""Devolverle a una caja regenerada el color de su original, sin perder el desgaste nuevo.

Una caja que se regenera con una imagen generada sale más saturada y más clara que su original:
medido sobre las 31 cajas del lote, la mediana de saturación pasa de 85 a 95 y la de brillo de 100
a 109. El arte aprobado no se toca, así que se corrige el color y no el dibujo.

## El método

Se trabaja en Lab, que separa el brillo (`L`) del color (`a`, `b`). Dos pasos:

1. **Media y desvío por canal.** Cada canal de la caja nueva se lleva a la media y al desvío de
   su original: `(x - media_nueva) / desvio_nuevo * desvio_original + media_original`. Es una
   transformación lineal, así que los roces de la caja nueva, que son variaciones chicas
   alrededor de cada color, siguen siendo variaciones y sólo cambian de escala.
2. **El ajuste fino.** Igualar la media y el desvío en Lab no alcanza para igualar la saturación
   y el brillo de HSV, que es lo que el ojo y el criterio del usuario miden: la saturación media
   salía hasta 8 puntos fuera. Un multiplicador de color `g` (sobre `a` y `b`) y un corrimiento
   de brillo `dl` (sobre `L`) se buscan por bisección hasta que la media de saturación y la de
   brillo de HSV, medidas sobre la imagen reducida a 256 píxeles con el filtro de PIL, coinciden con las del original.
3. **La corrección.** El ajuste fino se busca sobre la muestra y se mide sobre la caja entera ya
   transformada y reducida, y las dos medidas difieren un par de puntos: los roces y el recorte al
   gamut no conmutan con el promedio. Se repite el ajuste corrigiendo el objetivo con lo que
   faltó, hasta que la caja entera queda a menos de `PRECISION` del original.

Las **esquinas negras** del desplegado no cuentan. Una caja es una cruz de seis caras sobre un
cuadrado, y el cuarto de la imagen que queda afuera es negro. En el negro, medio nivel de
ruido cambia la saturación de un píxel de 0 a 100, así que ese cuarto aportaba 14 puntos de los 86
de saturación media del original y sólo 4 de los 91 de la nueva: la medida sobre la imagen entera
miente sobre el cartón. Por eso **la media y el desvío, y la saturación y el brillo del ajuste fino,
se miden sólo sobre el contenido**, los píxeles de brillo mayor que `NEGRO`. Y el cambio se aplica
con un peso que crece desde 0 en el negro puro hasta 1 a `PIE_DE_LUZ` de luminosidad, así que el
negro del texto y de las esquinas queda como está y no se levanta a gris.

La bisección es válida porque los dos efectos son monótonos: más `dl`, más brillo; más `g`, más
saturación. `dl` se resuelve adentro de cada `g`, porque el recorte al gamut los acopla un poco.

## Qué no hace

No toca el alfa. No alinea las dos imágenes: sólo compara estadísticas, así que no importa que
el original y el nuevo tengan distinta resolución ni que un logo haya corrido unos píxeles.

Toda la matemática es de la biblioteca estándar. El script que lee y escribe los PNG corre
adentro de Blender (`blender/igualar_color_de_caja.py`), lo hace con los mismos pasos sobre
arreglos de numpy, y un test compara las dos implementaciones.
"""

import math
from collections.abc import Sequence
from dataclasses import dataclass, replace

Color = tuple[float, float, float]
#: Una imagen: ancho, alto y los colores sRGB de 0..1, fila por fila.
Imagen = tuple[int, int, list[Color]]

#: Matriz sRGB lineal → XYZ (D65), y el blanco de referencia.
_A_XYZ = (
    (0.4124564, 0.3575761, 0.1804375),
    (0.2126729, 0.7151522, 0.0721750),
    (0.0193339, 0.1191920, 0.9503041),
)
_BLANCO = (0.95047, 1.0, 1.08883)

#: La tolerancia del criterio: saturación y brillo medios, en niveles de 0..255.
TOLERANCIA = 2.0

#: Un píxel es contenido si su brillo, en niveles de 0..255, pasa de esto.
NEGRO = 16

#: La luminosidad (L de Lab) a la que el cambio se aplica entero. Más abajo se aplica a medias.
PIE_DE_LUZ = 12.0

#: A cuánto se busca quedar del original, y cuántas rondas de corrección se dan para llegar.
PRECISION = 0.25
RONDAS = 5

#: El lado de la muestra sobre la que se miden saturación y brillo.
LADO_DE_LA_MUESTRA = 256

#: El rango que recorre cada bisección, y cuántas vueltas da.
RANGO_DE_G = (0.2, 2.5)
RANGO_DE_DL = (-40.0, 40.0)
VUELTAS = 14

_EPSILON = 216 / 24389
_KAPPA = 24389 / 27


def _inversa(m: Sequence[Sequence[float]]) -> tuple[tuple[float, ...], ...]:
    (a, b, c), (d, e, f), (g, h, i) = m
    det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    return (
        ((e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det),
        ((f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det),
        ((d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det),
    )


_DE_XYZ = _inversa(_A_XYZ)


def _lineal(canal: float) -> float:
    return canal / 12.92 if canal <= 0.04045 else ((canal + 0.055) / 1.055) ** 2.4


def _gamma(canal: float) -> float:
    canal = min(1.0, max(0.0, canal))
    return 12.92 * canal if canal <= 0.0031308 else 1.055 * canal ** (1 / 2.4) - 0.055


def _f(t: float) -> float:
    return t ** (1 / 3) if t > _EPSILON else (_KAPPA * t + 16) / 116


def _f_inversa(t: float) -> float:
    return t**3 if t**3 > _EPSILON else (116 * t - 16) / _KAPPA


def a_lab(rojo: float, verde: float, azul: float) -> tuple[float, float, float]:
    """Un color sRGB de 0..1 como `(L, a, b)`."""
    lineal = (_lineal(rojo), _lineal(verde), _lineal(azul))
    x, y, z = (
        sum(m * c for m, c in zip(fila, lineal)) / blanco
        for fila, blanco in zip(_A_XYZ, _BLANCO)
    )
    fx, fy, fz = _f(x), _f(y), _f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def a_srgb(luz: float, a: float, b: float) -> tuple[float, float, float]:
    """Un color `(L, a, b)` como sRGB de 0..1, recortado al gamut."""
    fy = (luz + 16) / 116
    xyz = tuple(
        _f_inversa(f) * blanco for f, blanco in zip((fy + a / 500, fy, fy - b / 200), _BLANCO)
    )
    lineal = tuple(sum(m * c for m, c in zip(fila, xyz)) for fila in _DE_XYZ)
    rojo, verde, azul = (_gamma(min(1.0, max(0.0, c))) for c in lineal)
    return rojo, verde, azul


def _lanczos(x: float) -> float:
    if x == 0:
        return 1.0
    if abs(x) >= 3:
        return 0.0
    arco = math.pi * x
    return 3 * math.sin(arco) * math.sin(arco / 3) / (arco * arco)


def pesos(entrada: int, salida: int) -> list[tuple[int, list[float]]]:
    """Por cada píxel de salida, dónde empieza su ventana y los pesos, como los calcula PIL.

    Es el filtro de Lanczos de tres lóbulos, cuya ventana crece con cuánto se achica la imagen.
    Se reproduce el de PIL porque el criterio se mide con él: otro filtro da otra saturación.
    """
    escala = entrada / salida
    ancho_del_filtro = max(escala, 1.0)
    soporte = 3 * ancho_del_filtro
    ventanas = []
    for k in range(salida):
        centro = (k + 0.5) * escala
        inicio = max(int(centro - soporte + 0.5), 0)
        fin = min(int(centro + soporte + 0.5), entrada)
        crudos = [_lanczos((x + inicio - centro + 0.5) / ancho_del_filtro) for x in range(fin - inicio)]
        total = sum(crudos)
        ventanas.append((inicio, [peso / total for peso in crudos]))
    return ventanas


def _a_niveles(valor: float) -> float:
    return min(255, max(0, round(255 * valor))) / 255


def reducir(imagen: Imagen, lado: int = LADO_DE_LA_MUESTRA) -> Imagen:
    """La imagen reducida a lo sumo a `lado` por `lado`, con el filtro de Lanczos de PIL.

    Cada pasada, primero la horizontal y después la vertical, redondea a niveles de 8 bits y
    recorta, como PIL: el recorte de los rebotes del filtro en el negro es parte de lo que mide
    el criterio. Un eje que ya cabe queda como está.
    """
    ancho, alto, pixeles = imagen
    columnas, filas = min(ancho, lado), min(alto, lado)
    if columnas < ancho:
        ventanas = pesos(ancho, columnas)
        horizontal: list[Color] = []
        for fila in range(alto):
            base = fila * ancho
            for inicio, ps in ventanas:
                horizontal.append(
                    tuple(  # type: ignore[arg-type]
                        _a_niveles(sum(p * pixeles[base + inicio + i][c] for i, p in enumerate(ps)))
                        for c in range(3)
                    )
                )
        pixeles = horizontal
    if filas < alto:
        ventanas = pesos(alto, filas)
        vertical: list[Color] = [(0.0, 0.0, 0.0)] * (columnas * filas)
        for k, (inicio, ps) in enumerate(ventanas):
            for col in range(columnas):
                vertical[k * columnas + col] = tuple(  # type: ignore[assignment]
                    _a_niveles(
                        sum(p * pixeles[(inicio + i) * columnas + col][c] for i, p in enumerate(ps))
                    )
                    for c in range(3)
                )
        pixeles = vertical
    return columnas, filas, pixeles


def contenido(imagen: Imagen) -> list[bool]:
    """Qué píxeles son el cartón y no el negro de afuera."""
    return [round(255 * max(pixel)) > NEGRO for pixel in imagen[2]]


def saturacion_y_brillo(
    pixeles: Sequence[Color], mascara: Sequence[bool] | None = None
) -> tuple[float, float]:
    """La saturación y el brillo medios de HSV, en 0..255, de los píxeles de la máscara.

    **Se miden sobre niveles enteros de 8 bits y la saturación se trunca**, como hace PIL al
    convertir a HSV. Sin redondear, un píxel de 0,2 niveles de brillo cuenta con la saturación de
    un color pleno. Sin máscara, cuentan todos.
    """
    elegidos = [p for i, p in enumerate(pixeles) if mascara is None or mascara[i]]
    if not elegidos:
        raise ValueError("no hay píxeles que medir")
    saturacion = brillo = 0.0
    for pixel in elegidos:
        niveles = [round(255 * canal) for canal in pixel]
        maximo = max(niveles)
        brillo += maximo
        if maximo > 0:
            saturacion += math.floor(255 * (maximo - min(niveles)) / maximo)
    return saturacion / len(elegidos), brillo / len(elegidos)


def _media_y_desvio(valores: Sequence[float]) -> tuple[float, float]:
    media = sum(valores) / len(valores)
    return media, math.sqrt(sum((v - media) ** 2 for v in valores) / len(valores))


def _estadisticas(laboratorio: Sequence[Color], mascara: Sequence[bool]) -> tuple[Color, Color]:
    elegidos = [p for p, dentro in zip(laboratorio, mascara) if dentro]
    por_canal = [_media_y_desvio([p[canal] for p in elegidos]) for canal in range(3)]
    return (
        (por_canal[0][0], por_canal[1][0], por_canal[2][0]),
        (por_canal[0][1], por_canal[1][1], por_canal[2][1]),
    )


@dataclass(frozen=True)
class Ajuste:
    """Lo que hace falta para llevar una caja nueva al color de su original."""

    media_nueva: Color
    desvio_nuevo: Color
    media_original: Color
    desvio_original: Color
    g: float = 1.0
    dl: float = 0.0


def transformar(punto: Color, ajuste: Ajuste) -> Color:
    """Un color `(L, a, b)` de la caja nueva, ya con el color de su original."""
    luz, a, b = (
        (valor - media) / desvio * d_original + m_original if desvio > 0 else m_original
        for valor, media, desvio, m_original, d_original in zip(
            punto,
            ajuste.media_nueva,
            ajuste.desvio_nuevo,
            ajuste.media_original,
            ajuste.desvio_original,
        )
    )
    llevado = (luz + ajuste.dl, a * ajuste.g, b * ajuste.g)
    peso = min(1.0, max(0.0, punto[0] / PIE_DE_LUZ))
    return tuple(  # type: ignore[return-value]
        original + peso * (nuevo - original) for original, nuevo in zip(punto, llevado)
    )


def aplicar(ajuste: Ajuste, imagen: Imagen) -> Imagen:
    """La imagen con el ajuste puesto, ya en niveles de 8 bits: lo que se mide es lo que se guarda."""
    ancho, alto, pixeles = imagen
    salida = []
    for pixel in pixeles:
        rojo, verde, azul = a_srgb(*transformar(a_lab(*pixel), ajuste))
        salida.append((_a_niveles(rojo), _a_niveles(verde), _a_niveles(azul)))
    return ancho, alto, salida


def _bisecar(medida, objetivo: float, rango: tuple[float, float]) -> float:
    """El valor del rango donde `medida` (creciente) cruza `objetivo`."""
    bajo, alto = rango
    for _ in range(VUELTAS):
        medio = (bajo + alto) / 2
        if medida(medio) < objetivo:
            bajo = medio
        else:
            alto = medio
    return (bajo + alto) / 2


def _ajuste_fino(
    chica: Sequence[Color], base: Ajuste, mascara: Sequence[bool], objetivo: tuple[float, float]
) -> tuple[float, float]:
    """`(g, dl)` que llevan la muestra al objetivo de saturación y brillo."""

    def medir(g: float, dl: float) -> tuple[float, float]:
        ajuste = replace(base, g=g, dl=dl)
        pixeles = [a_srgb(*transformar(p, ajuste)) for p in chica]
        return saturacion_y_brillo(pixeles, mascara)

    def dl_para(g: float) -> float:
        return _bisecar(lambda dl: medir(g, dl)[1], objetivo[1], RANGO_DE_DL)

    g = _bisecar(lambda g: medir(g, dl_para(g))[0], objetivo[0], RANGO_DE_G)
    return g, dl_para(g)


def ajustar(nueva: Imagen, original: Imagen) -> Ajuste:
    """El ajuste que lleva `nueva` al color de `original`.

    Las estadísticas salen de las imágenes enteras. El ajuste fino se busca sobre la muestra y se
    corrige midiendo la caja entera transformada: ver «La corrección» en el encabezado.
    """
    media_n, desvio_n = _estadisticas([a_lab(*p) for p in nueva[2]], contenido(nueva))
    media_o, desvio_o = _estadisticas([a_lab(*p) for p in original[2]], contenido(original))
    base = Ajuste(media_n, desvio_n, media_o, desvio_o)
    muestra_o, muestra_n = reducir(original), reducir(nueva)
    meta = saturacion_y_brillo(muestra_o[2], contenido(muestra_o))
    mascara = contenido(muestra_n)
    chica = [a_lab(*p) for p in muestra_n[2]]
    objetivo = meta
    ajuste = base
    for _ in range(RONDAS):
        g, dl = _ajuste_fino(chica, base, mascara, objetivo)
        ajuste = replace(base, g=g, dl=dl)
        medido = saturacion_y_brillo(reducir(aplicar(ajuste, nueva))[2], mascara)
        faltante = (meta[0] - medido[0], meta[1] - medido[1])
        if max(abs(faltante[0]), abs(faltante[1])) <= PRECISION:
            break
        objetivo = (objetivo[0] + faltante[0], objetivo[1] + faltante[1])
    return ajuste
