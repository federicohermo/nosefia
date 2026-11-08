"""El tono del cuerpo de las góndolas, que no entierre su detalle.

La chapa y el panel de la góndola viajaban con un negro de brillo 0,08. En ese negro el detalle
no se lee, y la luz horneada casi no rebota: las franjas rojas quedan apagadas. Las ménsulas
triangulares usan una paleta de tres grises distintos, de 0,15 a 0,25, y al lado del negro se ven
de otro color.

Todo el cuerpo de la góndola pasa a **un solo gris**, `TONO`:

- Las texturas de `TEXTURAS` se multiplican por un factor por canal hasta llegar a su tono: el
  detalle conserva su proporción y sólo cambia el nivel.
- Los grises de la paleta (`PIXELES_GRISES`) valen `TONO`, y su rojo vale `ROJO`. El píxel 4 de la
  paleta era un azul casi negro, el del frente de los estantes: ahora es del mismo gris.
- Los materiales lisos de `COLORES_LISOS` toman su tono como color base.
- **La grilla de alambre de las cabeceras** viajaba con una textura de media 0,12 y un metal de
  0,5, que sin reflejo se ve negro. Toma el mismo gris que el cuerpo.
- **Los laterales de los exhibidores** (Oremos, Pepito) tenían un color base azul que teñía por
  segunda vez una textura ya oscura. Pasan a blanco, y la textura sube su negro hasta `PISO_AZUL`.
- **El fondo de los exhibidores es azul marino.** Su textura ya era casi negra y el color base
  la volvía a teñir de azul: el panel del fondo salía negro. Pasa a `AZUL` y el color base a blanco.

El tono es más claro que el de la puerta (0,21) a propósito: la puerta se ve de cerca con la luz
del jugador, y una góndola a tres metros recibe menos. La herramienta es
`blender/aclarar_gondolas.py`. **Escribe el `.blend`.**
"""

from pathlib import Path

from lib.repo import RAIZ

CARPETA = RAIZ / "assets" / "source" / "textures" / "gondola"

#: El gris del cuerpo de la góndola, en valores de imagen de 0 a 1.
TONO = (0.30, 0.30, 0.31)

#: El azul marino del fondo de los exhibidores, en valores de imagen.
AZUL = (0.14, 0.26, 0.46)

#: El negro más claro que puede tener la textura de un lateral de exhibidor: el azul del cartel.
PISO_AZUL = (0.12, 0.16, 0.30)

#: El rojo de las franjas de los estantes y de los portaprecios. La luz horneada de la góndola es
#: baja y el rojo de la paleta (0,81) se veía granate al lado del rojo de los productos.
ROJO = (0.95, 0.22, 0.25)

#: Las imágenes del modelo que forman el cuerpo, y el tono al que va cada una.
TEXTURAS = {
    "gondola_chapa_blanca_512_basecolor_negra": TONO,
    "gondola_panel_blanca_1024_basecolor_negra": TONO,
    "gondola_parante_ranura_blanca": TONO,
    "gondola_grilla_alambre": TONO,
    "exhibidor fondo.png": AZUL,
}

#: Las imágenes con arte que no se multiplican: su negro sube hasta el piso y el resto conserva
#: su proporción, así el texto blanco no se pasa de 1.
PISOS = {
    "exhibidor lateral.png": PISO_AZUL,
    "exhibidor lateral pepito.png": PISO_AZUL,
}

#: Materiales cuyo color base tiñe de nuevo una textura que ya trae su color: pasan a blanco.
SIN_TINTE = (
    "EXHIBIDOR | Fondo",
    "EXHIBIDOR | Azul",
    "EXHIBIDOR | Lateral",
    "EXHIBIDOR | Lateral Pepito",
)

#: La paleta de 5 píxeles de las ménsulas y los bordes, y cuáles de sus píxeles son grises.
PALETA = "gondola_paleta"
PIXELES_GRISES = (0, 1, 3, 4)
PIXEL_ROJO = 2

#: Materiales de un solo color que forman el cuerpo, sin metal que los oscurezca, y su tono.
COLORES_LISOS = {
    "GONDOLA | Paleta cabecera": TONO,
    "ESTANTE | Nicho negro": TONO,
    "GONDOLA | Mensula blanca": TONO,
    "GONDOLA | Zocalo grafito": TONO,
    "GONDOLA | Metal negro": TONO,
    "GONDOLA | Parante gris claro": TONO,
    "EXHIBIDOR | Estante": AZUL,
    "GONDOLA | Portaprecio rojo": ROJO,
}


def a_lineal(valor: float) -> float:
    """Un valor de imagen de 0 a 1 como color lineal, que es lo que guarda el color base."""
    if valor <= 0.04045:
        return valor / 12.92
    return ((valor + 0.055) / 1.055) ** 2.4


def factores(
    medias: tuple[float, float, float], tono: tuple[float, float, float] = TONO
) -> tuple[float, float, float]:
    """Cuánto multiplicar cada canal para que su media sea la del tono."""
    return tuple(objetivo / max(media, 1e-6) for objetivo, media in zip(tono, medias))


def ruta_de_la_textura(nombre: str) -> Path:
    """El PNG nuevo de una imagen del modelo, con o sin su extensión."""
    return CARPETA / f"{Path(nombre).stem}.png"
