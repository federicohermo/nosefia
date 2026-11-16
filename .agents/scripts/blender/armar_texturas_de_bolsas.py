"""Arma las texturas de las bolsas de Petisas, Macumbas y Don Saturados al estilo de Chisitos.

    python .claude/scripts/blender/armar_texturas_de_bolsas.py [--aplicar] [--hoja RUTA]

Corre con el Python del sistema y necesita Pillow, numpy y scipy. No corre adentro de Blender.
Sin `--aplicar` escribe en `reports/texturas-de-bolsas/`; con `--aplicar` escribe las tres
texturas en `assets/source/products-textured/bolsas/`, que es donde las lee `armar_bolsas.py` y
el atlas. Es idempotente: no usa azar, y dos corridas dejan los mismos bytes.

## Por qué

El arte de las tres galletitas viaja de dos formas que no sirven a una bolsa: dos mitades en un
rectángulo apaisado, y un costado aparte de 160 x 512. La bolsa nueva es un cuerpo abombado con
dos cierres, y toma el desplegado de las papas: frente, dorso, costados y la franja de cada
cierre, todo en una sola imagen.

## Qué conserva y qué agrega

El logo, los colores y las ilustraciones son los del juego: el frente y el dorso salen de cada
textura actual, a su proporción, sin estirarlos para llenar el cuadrado. Lo que la forma nueva
pide se completa con el mismo arte:

- **El fondo se extiende** hacia los bordes con el reflejo del propio fondo, y no con arte nuevo.
- **El prensado** de cada cierre es el de Chisitos: el relieve de sus primeras filas, medido en
  la textura de las papas y llevado a la franja de arriba y a la de abajo de cada panel.
- **Los sellos** octogonales son los recortes de los de Chisitos, a su tamaño de cada frente.
- **El dorso de Macumbas** se arma con el fondo y el logo de su frente más los datos del envase,
  porque la textura actual no tiene dorso.
- **Los costados** son los que el producto ya tenía, con el logo en vertical, fundidos en sus
  orillas con el borde del frente y el del dorso.

## El desplegado

La imagen y sus cuatro regiones las declara `lib/desplegado_de_bolsas.py`, que comparte con
`armar_bolsas.py`: cambiar una región es cambiar una línea allá.

## Lo que cuesta

Tres PNG de 512 x 352, que viajan al atlas de etiquetas. Cada una reemplaza al par `completo` y
`costado` de su producto, que ocupaba 512 x 283 y 160 x 512.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude" / "scripts"))
from lib.consola import configurar  # noqa: E402
from lib.desplegado_de_bolsas import ALTO, ANCHO, PRENSADO, REGIONES  # noqa: E402

FUENTES = RAIZ / "assets" / "source"
DESTINO = FUENTES / "products-textured" / "bolsas"
REPORTE = RAIZ / "reports" / "texturas-de-bolsas"


ARTE = {
    "petisas": FUENTES / "products-cam/petisas/petisas completo.png",
    "macumbas": FUENTES / "products-cam/macumbas/macumbas completo.png",
    "donsaturados": FUENTES / "products-cam/don saturados/Don Saturados completo.png",
}
CHISITOS = FUENTES / "products-textured/chizitos/chisito.png"
COSTADOS_ACTUALES = {
    "petisas": FUENTES / "products-cam/petisas/petisas costado.png",
    "macumbas": FUENTES / "products-cam/macumbas/macumbas costado.png",
    "donsaturados": FUENTES / "products-cam/don saturados/Don Saturados costado.png",
}

#: De dónde salen el prensado y los sellos en la textura de Chisitos (1254 x 1254).
CHISITOS_PANEL = (174, 224, 631, 1066)
CHISITOS_SELLOS = ((312, 260, 408, 358), (422, 260, 517, 358), (531, 260, 626, 358))
#: Los sellos de abajo, en el orden de `CHISITOS_SELLOS`.
GRASAS, SODIO, CALORIAS = 0, 1, 2

Caja = tuple[int, int, int, int]

#: Cuánto se borronea el fondo que se agrega alrededor del arte, en píxeles.
LARGO_DEL_BORROSO = 24.0


def cargar(ruta: Path) -> np.ndarray:
    """La imagen como flotantes RGB de 0 a 255. Lo transparente se pinta del color de su vecino."""
    imagen = Image.open(ruta).convert("RGBA")
    datos = np.asarray(imagen, dtype=np.float32)
    return datos[..., :3]


def a_imagen(matriz: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(matriz + 0.5, 0, 255).astype(np.uint8))


def a_matriz(imagen: Image.Image) -> np.ndarray:
    return np.asarray(imagen.convert("RGB"), dtype=np.float32)


def reducir(matriz: np.ndarray, ancho: int, alto: int) -> np.ndarray:
    """Achica con promedio por área: el arte mide miles de píxeles y el atlas, cientos."""
    imagen = a_imagen(matriz)
    return a_matriz(imagen.resize((ancho, alto), Image.Resampling.BOX, reducing_gap=None))


def recortar(matriz: np.ndarray, caja: Caja) -> np.ndarray:
    x0, y0, x1, y1 = caja
    return matriz[y0:y1, x0:x1]


def extender(
    arte: np.ndarray, arriba: int, abajo: int, izquierda: int, derecha: int, modo: str
) -> np.ndarray:
    """Agranda el lienzo con el borde del arte, más borroso cuanto más lejos de él.

    `symmetric` refleja el borde: conserva el grano del fondo, y sirve donde el borde es fondo
    con dibujo. `edge` lo repite: sirve donde el borde es un fondo liso y el reflejo copiaría
    el logo. El borroso evita que se lea como un espejo.
    """
    alto, ancho = arte.shape[:2]
    lleno = np.pad(arte, ((arriba, abajo), (izquierda, derecha), (0, 0)), mode=modo)
    if not (arriba or abajo or izquierda or derecha):
        return lleno
    # Arriba y abajo el borroso corre a lo largo de la costura, y a los lados a lo alto: lo que
    # queda es un fondo parejo, sin las vetas que el borde del arte dibujaría como dientes en la
    # franja del cierre.
    a_lo_ancho = ndimage.gaussian_filter(lleno, sigma=(0, LARGO_DEL_BORROSO, 0))
    a_lo_alto = ndimage.gaussian_filter(lleno, sigma=(LARGO_DEL_BORROSO, 0, 0))
    y, x = np.mgrid[0 : lleno.shape[0], 0 : lleno.shape[1]]
    # La distancia de cada píxel al rectángulo del arte, en píxeles.
    dy = np.maximum(np.maximum(arriba - y, y - (arriba + alto - 1)), 0)
    dx = np.maximum(np.maximum(izquierda - x, x - (izquierda + ancho - 1)), 0)
    borroso = np.where((dy >= dx)[..., None], a_lo_ancho, a_lo_alto)
    peso = np.clip(np.hypot(dx, dy) / 6.0, 0.0, 1.0)[..., None]
    return lleno * (1 - peso) + borroso * peso


def encajar(
    arte: np.ndarray, ancho: int, alto: int, y: int, modo: str, ancho_del_arte: int | None = None
) -> np.ndarray:
    """Un panel de `ancho` x `alto`: el arte a su proporción y su fondo extendido hasta cubrirlo.

    `y` es la fila donde empieza el arte, centrado a lo ancho. El arte entra entero: lo que no
    cubre se rellena con su fondo. Con `ancho_del_arte` el arte se ensancha hasta ese ancho, que
    reparte lo que se estira entre todo el arte y deja menos fondo por completar.
    """
    alto_de_origen, ancho_de_origen = arte.shape[:2]
    escala = min(ancho / ancho_de_origen, (alto - y) / alto_de_origen)
    nuevo_ancho, nuevo_alto = round(ancho_de_origen * escala), round(alto_de_origen * escala)
    nuevo_ancho = ancho_del_arte or nuevo_ancho
    chico = reducir(arte, nuevo_ancho, nuevo_alto)
    izquierda = (ancho - nuevo_ancho) // 2
    return extender(
        chico, y, alto - y - nuevo_alto, izquierda, ancho - izquierda - nuevo_ancho, modo
    )


def prensado() -> np.ndarray:
    """La ganancia del prensado de Chisitos: una columna de factores por fila, de la punta hacia
    adentro. Vale 1 donde la bolsa no está arrugada. Sale de la franja de la izquierda del panel,
    donde no hay arte, medida contra el fondo liso que la sigue."""
    x0, y0, x1, _ = CHISITOS_PANEL
    luz = cargar(CHISITOS).mean(axis=2)
    franja = luz[y0 - 4 : y0 + 40, x0 + 10 : x0 + 60].mean(axis=1)
    fondo = float(np.median(franja[12:36]))
    ganancia = np.clip(franja / fondo, 0.6, 1.12)
    return ganancia[4:40]


def aplicar_prensado(panel: np.ndarray) -> np.ndarray:
    """Marca en las dos puntas del panel las filas del prensado de Chisitos."""
    ganancia = prensado()
    perfil = np.interp(
        np.linspace(0, len(ganancia) - 1, PRENSADO), np.arange(len(ganancia)), ganancia
    )
    salida = panel.copy()
    salida[:PRENSADO] *= perfil[:, None, None]
    salida[-PRENSADO:] *= perfil[::-1, None, None]
    return salida


def sello(indice: int, lado: int) -> tuple[np.ndarray, np.ndarray]:
    """El sello `indice` de Chisitos con su borde blanco, sin el fondo verde, llevado a `lado`
    píxeles de ancho. La máscara es la zona negra del sello y 3 píxeles de su borde."""
    imagen = cargar(CHISITOS)
    x0, y0, x1, y1 = CHISITOS_SELLOS[indice]
    recorte = recortar(imagen, (x0 - 10, y0 - 10, x1 + 11, y1 + 11))
    oscuro = recorte.mean(axis=2) < 45
    etiquetas, _ = ndimage.label(oscuro)
    mayor = np.argmax(np.bincount(etiquetas.ravel())[1:]) + 1
    zona = ndimage.binary_fill_holes(etiquetas == mayor)
    zona = ndimage.binary_dilation(zona, iterations=3)
    ys, xs = np.where(zona)
    caja = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    recorte, zona = recortar(recorte, caja), zona[caja[1] : caja[3], caja[0] : caja[2]]
    alto = round(lado * recorte.shape[0] / recorte.shape[1])
    mascara = reducir(np.repeat(zona[..., None] * 255.0, 3, axis=2), lado, alto)[..., :1] / 255.0
    return reducir(recorte, lado, alto), mascara


def pegar_sellos(panel: np.ndarray, cuales: tuple[int, ...], x: int, y: int, lado: int) -> None:
    """Pega los sellos en fila, de izquierda a derecha, desde la esquina `(x, y)`."""
    for k, indice in enumerate(cuales):
        chico, mascara = sello(indice, lado)
        alto, ancho = chico.shape[:2]
        x_k = x + k * (ancho + 3)
        zona = panel[y : y + alto, x_k : x_k + ancho]
        panel[y : y + alto, x_k : x_k + ancho] = zona * (1 - mascara) + chico * mascara


def costado(
    panel_frente: np.ndarray, panel_dorso: np.ndarray, lado: str, logo: Path
) -> np.ndarray:
    """Un costado: va de la columna del borde del frente a la columna del borde del dorso.

    Sale acostado: sus columnas son la altura de la bolsa, de abajo hacia arriba, y sus filas
    van del frente al dorso. Lleva el costado que ya tenía el producto, con el logo en vertical,
    y sus dos orillas se funden con el borde del panel que tocan.
    """
    region = REGIONES["derecha"]
    ancho_del_costado, largo = region[3] - region[1], region[2] - region[0]
    if lado == "derecha":
        del_frente = panel_frente[:, -4:].mean(axis=1)
        del_dorso = panel_dorso[:, :4].mean(axis=1)
    else:
        del_frente = panel_frente[:, :4].mean(axis=1)
        del_dorso = panel_dorso[:, -4:].mean(axis=1)
    # Las columnas van de abajo hacia arriba: la fila 0 del panel es la de arriba.
    del_frente, del_dorso = del_frente[::-1], del_dorso[::-1]
    arte = Image.open(logo).convert("RGB").transpose(Image.Transpose.ROTATE_270)
    if lado == "izquierda":
        arte = arte.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    tira = reducir(a_matriz(arte), largo, ancho_del_costado)
    # El costado se funde con el frente y con el dorso en sus orillas, y el logo queda al medio.
    paso = np.linspace(0.0, 1.0, ancho_del_costado)[:, None, None]
    hacia_el_frente = np.clip(1.0 - paso / 0.3, 0.0, 1.0)
    hacia_el_dorso = np.clip((paso - 0.7) / 0.3, 0.0, 1.0)
    tira = tira * (1 - hacia_el_frente - hacia_el_dorso) + (
        del_frente[None] * hacia_el_frente + del_dorso[None] * hacia_el_dorso
    )
    sombra = 1.0 - 0.15 * np.sin(np.linspace(0.0, np.pi, ancho_del_costado))[:, None, None]
    return tira * sombra


def rellenar(lienzo: np.ndarray, cubierto: np.ndarray) -> np.ndarray:
    """Llena lo que ninguna región cubre con el píxel cubierto más cercano: sin negro entre
    paneles, que el filtro y los primeros mips mezclarían con el borde de cada uno."""
    _, indices = ndimage.distance_transform_edt(~cubierto, return_indices=True)
    return lienzo[indices[0], indices[1]]


def tipografia(tamano: int, negrita: bool = True) -> ImageFont.ImageFont:
    for nombre in ("arialbd.ttf", "arial.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(nombre if negrita else nombre.replace("bd", ""), tamano)
        except OSError:
            continue
    return ImageFont.load_default()


def paneles_de(producto: str) -> tuple[np.ndarray, np.ndarray]:
    """El frente y el dorso de un producto, como paneles de 244 x 244 sin prensado ni sellos.

    El frente conserva la proporción de su arte y completa el fondo; el dorso se lleva al
    cuadrado sin más, como ya lo hacía el modelo anterior, porque casi no se ve.
    """
    lado = REGIONES["frente"][2] - REGIONES["frente"][0]
    arte = cargar(ARTE[producto])
    if producto == "macumbas":
        frente = recortar(arte, (910, 0, 3376, 2015))
        return encajar(frente, lado, lado, 34, "edge"), dorso_de_macumbas(frente, lado)
    cajas, ancho_del_arte = {
        "petisas": (((40, 6, 2488, 2730), (2500, 6, 4968, 2730)), 238),
        "donsaturados": (((60, 6, 2476, 2933), (2492, 6, 4982, 2933)), 232),
    }[producto]
    frente, dorso = (recortar(arte, caja) for caja in cajas)
    return encajar(frente, lado, lado, 10, "edge", ancho_del_arte), reducir(dorso, lado, lado)


def pegar_difuminado(panel: np.ndarray, pieza: np.ndarray, x: int, y: int, borde: int = 10) -> None:
    """Pega `pieza` con el borde que se funde con el fondo: sin el rectángulo del recorte."""
    alto, ancho = pieza.shape[:2]
    rampa_y = np.clip(np.minimum(np.arange(alto), np.arange(alto)[::-1]) / borde, 0, 1)
    rampa_x = np.clip(np.minimum(np.arange(ancho), np.arange(ancho)[::-1]) / borde, 0, 1)
    mascara = (rampa_y[:, None] * rampa_x[None, :])[..., None]
    zona = panel[y : y + alto, x : x + ancho]
    panel[y : y + alto, x : x + ancho] = zona * (1 - mascara) + pieza * mascara


def dorso_de_macumbas(frente: np.ndarray, lado: int) -> np.ndarray:
    """El dorso de Macumbas: el marrón de su frente, su logo y los datos del envase.

    La textura actual no tiene dorso. Éste lleva un degradé entre las dos puntas del frente, el
    logo del frente, un cuadro de información nutricional, el peso y un código de barras.
    """
    alto, ancho = frente.shape[:2]
    # El fondo sale de las dos puntas del frente, que son marrón liso: un degradé de una a otra.
    arriba = frente[: alto // 40].mean(axis=(0, 1))
    abajo = frente[-(alto // 40) :].mean(axis=(0, 1))
    tramo = np.linspace(0.0, 1.0, lado)[:, None, None]
    panel = (arriba * (1 - tramo) + abajo * tramo) * np.ones((1, lado, 1)) * 0.85
    logo = recortar(frente, (int(0.03 * ancho), int(0.03 * alto), ancho, int(0.71 * alto)))
    ancho_del_logo = 196
    chico = reducir(logo, ancho_del_logo, round(ancho_del_logo * logo.shape[0] / logo.shape[1]))
    pegar_difuminado(panel, chico, 22, 12)
    y_de_abajo = 12 + chico.shape[0] + 6
    imagen = a_imagen(panel)
    dibujo = ImageDraw.Draw(imagen, "RGBA")
    claro, tinta = (244, 238, 224, 240), (40, 24, 18, 255)
    dibujo.rectangle((14, y_de_abajo, 230, y_de_abajo + 74), fill=claro)
    dibujo.text((18, y_de_abajo + 3), "INFORMACIÓN NUTRICIONAL", font=tipografia(7), fill=tinta)
    for k, (nombre, valor) in enumerate(
        (("Valor energético", "150 kcal"), ("Carbohidratos", "21 g"), ("Grasas totales", "6 g"),
         ("Grasas saturadas", "3 g"), ("Proteínas", "1,5 g"), ("Sodio", "95 mg"))
    ):
        y = y_de_abajo + 14 + k * 10
        dibujo.line((18, y + 9, 226, y + 9), fill=(40, 24, 18, 120), width=1)
        dibujo.text((18, y), nombre, font=tipografia(6, False), fill=tinta)
        dibujo.text((176, y), valor, font=tipografia(6, False), fill=tinta)
    crema = (240, 232, 220, 255)
    dibujo.text((14, 208), "CONT. NET. 118 g", font=tipografia(9), fill=crema)
    letra_chica = tipografia(5, False)
    leyenda = "GALLETAS SÁNDWICH CON CREMA SABOR CHOCOLATE"
    dibujo.text((14, 219), leyenda, font=letra_chica, fill=crema)
    # El código de barras: franjas fijas, sin azar.
    dibujo.rectangle((166, 206, 230, 226), fill=claro)
    x = 170
    barras = (1, 2, 1, 1, 3, 1, 2, 1, 1, 2, 3, 1, 1, 2, 1, 3, 1, 1, 2, 1, 2, 1, 1, 3, 1, 2)
    for k, ancho_de_barra in enumerate(barras):
        if k % 2 == 0:
            dibujo.rectangle((x, 209, x + ancho_de_barra - 1, 223), fill=tinta)
        x += ancho_de_barra + 1
    return a_matriz(imagen)


#: Qué sellos lleva cada producto y dónde: `(sellos, x, y, lado)` en el panel del frente.
SELLOS = {
    "petisas": ((GRASAS, CALORIAS), 14, 14, 36),
    "macumbas": ((GRASAS, CALORIAS), 160, 14, 36),
    "donsaturados": ((SODIO, CALORIAS), 160, 196, 36),
}


def armar(producto: str) -> np.ndarray:
    frente, dorso = paneles_de(producto)
    sellos, x, y, lado_del_sello = SELLOS[producto]
    pegar_sellos(frente, sellos, x, y, lado_del_sello)
    frente, dorso = aplicar_prensado(frente), aplicar_prensado(dorso)
    lienzo = np.zeros((ALTO, ANCHO, 3), dtype=np.float32)
    cubierto = np.zeros((ALTO, ANCHO), dtype=bool)
    for nombre, panel in (
        ("frente", frente),
        ("dorso", dorso),
        ("derecha", costado(frente, dorso, "derecha", COSTADOS_ACTUALES[producto])),
        ("izquierda", costado(frente, dorso, "izquierda", COSTADOS_ACTUALES[producto])),
    ):
        x0, y0, x1, y1 = REGIONES[nombre]
        lienzo[y0:y1, x0:x1] = panel
        cubierto[y0:y1, x0:x1] = True
    return rellenar(lienzo, cubierto)


def hoja(texturas: dict[str, Image.Image], ruta: Path) -> None:
    """Una hoja con cada textura actual (la `completo` y el `costado`) al lado de la nueva."""
    margen, ancho_actual, alto_actual = 12, 512, 320
    ancho_total = margen + ancho_actual + 110 + margen + ANCHO + margen
    lienzo = Image.new("RGB", (ancho_total, margen + len(texturas) * (ALTO + margen)), (38, 38, 38))
    dibujo = ImageDraw.Draw(lienzo)
    for fila, (producto, nueva) in enumerate(texturas.items()):
        y = margen + fila * (ALTO + margen)
        actual = Image.open(ARTE[producto]).convert("RGB")
        actual = actual.resize((ancho_actual, round(ancho_actual * actual.height / actual.width)))
        lienzo.paste(actual, (margen, y))
        costado = Image.open(COSTADOS_ACTUALES[producto]).convert("RGB")
        lienzo.paste(costado.resize((100, alto_actual)), (margen + ancho_actual + 8, y))
        lienzo.paste(nueva, (margen + ancho_actual + 110 + margen, y))
        amarillo = (255, 255, 0)
        dibujo.text((margen + 4, y + 2), f"{producto}: actual", font=tipografia(12), fill=amarillo)
        dibujo.text(
            (margen + ancho_actual + 110 + margen + 4, y + ALTO - 16),
            f"{producto}: nueva",
            font=tipografia(12),
            fill=(255, 255, 0),
        )
    ruta.parent.mkdir(parents=True, exist_ok=True)
    lienzo.save(ruta)


def main() -> None:
    configurar()
    parser = argparse.ArgumentParser()
    parser.add_argument("--aplicar", action="store_true")
    parser.add_argument("--hoja", type=Path)
    argumentos = parser.parse_args()
    destino = DESTINO if argumentos.aplicar else REPORTE
    destino.mkdir(parents=True, exist_ok=True)
    armadas = {}
    for producto in ARTE:
        armadas[producto] = a_imagen(armar(producto))
        armadas[producto].save(destino / f"{producto}.png", optimize=True)
        print(f"{producto}: {destino / (producto + '.png')}")
    if argumentos.hoja:
        hoja(armadas, argumentos.hoja)
        print(f"hoja: {argumentos.hoja}")


if __name__ == "__main__":
    main()
