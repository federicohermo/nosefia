"""El tono del cuerpo de las góndolas, que no entierre su detalle.

La chapa y el panel de la góndola viajaban con un negro de brillo 0,08. En ese negro el detalle
no se lee, y la luz horneada casi no rebota: las franjas rojas quedan apagadas. Las ménsulas
triangulares usan una paleta de tres grises distintos, de 0,15 a 0,25, y al lado del negro se ven
de otro color.

Todo el cuerpo de la góndola pasa a **un solo gris**, `TONO`:

- Las texturas de `TEXTURAS` se multiplican por un factor por canal hasta llegar a su tono: el
  detalle conserva su proporción y sólo cambia el nivel.
- Los grises de la paleta (`PIXELES_GRISES`) valen `TONO`, y su rojo vale `ROJO`. El píxel 4 de la
  paleta era un azul casi negro, el de los estantes del exhibidor: vale `TONO_APARTE`.
- **El rojo de las franjas también emite** (`EMISION_ROJO`). La luz de afuera es verde azulada, y
  un rojo bajo esa luz sale casi negro: el albedo solo no alcanza.
- Los materiales lisos de `COLORES_LISOS` toman su tono como color base.
- **La grilla de alambre de las cabeceras** viajaba con una textura de media 0,12 y un metal de
  0,5, que sin reflejo se ve negro. Toma `TONO`, igual que el marco. Pasa a ser un dieléctrico
  rugoso: con metal 0,5 los huecos reflejaban la sonda del salón y se teñían del rojo de los
  productos.
- **Los agujeros no se aclaran** (`AGUJEROS`): los del panel perforado, los de la grilla y las
  ranuras del parante tienen que seguir negros para leerse como agujeros.
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

#: El gris del cuerpo de las góndolas centrales, en valores de imagen de 0 a 1.
TONO = (0.24, 0.24, 0.25)

#: El gris de las chapas, el panel perforado y los parantes. Con la rugosidad de `ASPEROS` ya no
#: tienen el brillo que reflejaba las cajas, y para quedar tan claras como antes necesitan más gris.
TONO_DE_LAS_CHAPAS = (0.29, 0.29, 0.30)

#: Los materiales del cuerpo que pasan a rugosidad 1,0. Con 0,55 reflejaban las cajas rojas y la
#: cara de abajo de los estantes salía marrón.
ASPEROS = {
    "GONDOLA | Chapa pintada blanca": 1.0,
    "GONDOLA | Panel perforado 50 mm": 1.0,
    "GONDOLA | Parante ranurado blanco": 1.0,
}

#: El gris de las ménsulas y los bordes de la paleta. Es más claro que el del cuerpo a propósito:
#: miran hacia abajo y la luz que reciben es poca. Medido en el juego, con `TONO` salían marrones y
#: más oscuras que el panel perforado.
TONO_DE_LA_PALETA = (0.36, 0.36, 0.37)

#: La rugosidad del material de la paleta. Con 0,5 reflejaba las cajas rojas y las ménsulas salían
#: marrones.
RUGOSIDAD_DE_LA_PALETA = 1.0

#: El gris de los estantes del exhibidor, que no cambia con el del cuerpo.
TONO_APARTE = (0.30, 0.30, 0.31)

#: El azul marino del fondo de los exhibidores, en valores de imagen.
AZUL = (0.14, 0.26, 0.46)

#: El negro más claro que puede tener la textura de un lateral de exhibidor: el azul del cartel.
PISO_AZUL = (0.12, 0.16, 0.30)

#: El rojo de las franjas de los estantes y de los portaprecios. La luz horneada de la góndola es
#: baja y el rojo de la paleta (0,81) se veía granate al lado del rojo de los productos.
ROJO = (0.95, 0.22, 0.25)

#: Las imágenes del modelo que forman el cuerpo, y el tono al que va cada una.
TEXTURAS = {
    "gondola_chapa_blanca_512_basecolor_negra": TONO_DE_LAS_CHAPAS,
    "gondola_panel_blanca_1024_basecolor_negra": TONO_DE_LAS_CHAPAS,
    "gondola_parante_ranura_blanca": TONO_DE_LAS_CHAPAS,
    "gondola_grilla_alambre": TONO,
    "exhibidor fondo.png": AZUL,
}

#: Los agujeros de las imágenes del cuerpo: no se aclaran, quedan negros. «oscuros» son los píxeles
#: bajo `UMBRAL_OSCURO`; «claros», los que están por encima del nivel del metal, como las ranuras
#: del parante. El tono se calcula y se aplica sólo sobre el metal.
AGUJEROS = {
    "gondola_panel_blanca_1024_basecolor_negra": "oscuros",
    "gondola_grilla_alambre": "oscuros",
    "gondola_parante_ranura_blanca": "claros",
}
UMBRAL_OSCURO = 0.06
SALTO_DE_RANURA = 0.004

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
PIXELES_GRISES = (0, 1)
PIXEL_DEL_EXHIBIDOR = 4
PIXEL_ROJO = 2

#: La imagen donde sólo el rojo de la paleta emite, y cuánto del `ROJO` emite. Es lo que lo
#: sostiene rojo cuando la luz horneada es verde azulada.
EMISION = "gondola_paleta_emision"
EMISION_ROJO = 0.6

#: Las juntas entre paneles del fondo del exhibidor: unas tiras de 1 cm con el píxel 3 de la paleta.
#: Eran más claras que el panel y estaban pegadas a los estantes. Ahora son más oscuras que el
#: panel y van a medio camino entre un estante y el siguiente.
PIXEL_DE_LAS_JUNTAS = 3
TONO_DE_LAS_JUNTAS = (0.10, 0.10, 0.105)
#: Las cuatro caras del exhibidor. El modificador `Muebles` de `gondolanueva2-col` las une y no lee
#: la malla de ese objeto: lo que se edita se edita acá.
CARAS_DEL_EXHIBIDOR = tuple(
    f"gondolanueva2-{cara}-noimp" for cara in ("este", "oeste", "norte", "sur")
)

#: Los laterales del exhibidor son una sola cara con dos lados: por dentro mostraban el arte, y el
#: cartel se leía al revés. La cara se cierra de un solo lado y un duplicado mira hacia adentro con
#: el azul liso del costado.
LATERALES = ("EXHIBIDOR | Lateral", "EXHIBIDOR | Lateral Pepito")
AZUL_LISO = "EXHIBIDOR | Azul liso"
COLOR_DEL_AZUL_LISO = (31 / 255, 55 / 255, 103 / 255)

#: Las dos imágenes de la paleta miden 5×1. Comprimidas a VRAM, el bloque de 4×4 se lleva el rojo y
#: los grises de las ménsulas: la build sale con las franjas y las ménsulas negras. Se importan sin
#: comprimir (`compress/mode=0`, sin mipmaps), y hay que dejar así su `.import`.
SIN_COMPRIMIR = (PALETA, EMISION)

#: Los materiales de la góndola que dejan de ser metal, y su rugosidad. La grilla reflejaba la
#: sonda del salón en cada hueco.
DIELECTRICOS = {"GONDOLA | Grilla de alambre": 0.8}

#: Materiales de un solo color que forman el cuerpo, sin metal que los oscurezca, y su tono.
COLORES_LISOS = {
    "ESTANTE | Nicho negro": TONO,
    "GONDOLA | Mensula blanca": TONO,
    "GONDOLA | Zocalo grafito": TONO,
    "GONDOLA | Paleta cabecera": TONO,
    "GONDOLA | Metal negro": TONO,
    "GONDOLA | Parante gris claro": TONO,
    "EXHIBIDOR | Estante": AZUL,
    "GONDOLA | Portaprecio rojo": ROJO,
}


#: La base de las mesas: el cromo de las barandas de la góndola, y su rugosidad. Con 0,25 y con 0,5 el
#: pie reflejaba los estantes rosados y de madera del mostrador y salía salmón; con 0,7 es gris.
BASE_DE_MESA = "MESA | Base cromada"
CROMO = "GONDOLA | Alambre cromado"
RUGOSIDAD_DEL_CROMO = 0.7
#: Un metal casi puro: con 1,0 el pie, que mira al techo, sólo refleja lo oscuro y sale negro.
METAL_DE_MESA = 0.9

#: Las patas de las sillas, de madera común. Color base en valores de imagen.
PATAS_DE_SILLA = "SILLA | Patas de madera"
MADERA = (0.55, 0.38, 0.22)

#: El material del salón que se reemplaza, y las mallas donde se reemplaza.
ACERO = "MOSTRADOR | Acero satinado"
MALLA_DE_MESA = "salon_mesa"
MALLA_DE_SILLA = "salon_silla"


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
