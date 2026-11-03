"""Los biseles de un producto, horneados en el color de su etiqueta.

Un producto llega nuevo y sus aristas son filosas: sin nada que las marque, un borde se lee
como el corte de un polígono. Esta capa agrega dos cosas que un borde real tiene.

- **Una banda oscura** pegada a la arista, por donde la luz ambiente llega peor.
- **Un brillo fino** sobre la arista, donde el cartón o el plástico redondeado atrapa la luz.

Los dos salen de la malla real del producto, no de la imagen: `blender/hornear_biseles.py`
pone una copia aislada de la malla en Cycles y hornea en la UV de la etiqueta. La capa es un PNG
chico por etiqueta en `assets/source/biseles/`, con la misma ruta que la etiqueta. **No se pisa
el dibujo**: `blender/armar_atlas.py` la suma al armar el atlas, y el dibujo del artista queda
donde estaba. Si el artista cambia la etiqueta, la capa sigue valiendo mientras la malla no cambie.

## Qué guarda la capa

Un PNG RGB de 8 bits, al tamaño con el que viaja la etiqueta.

- **R** es el factor de luz: 255 no oscurece, 0 deja negro.
- **G** es el brillo: 0 no suma nada, 255 deja blanco.
- **B** no se usa.

Un píxel de la etiqueta pasa a `canal * R + G * (1 - canal * R)`. Con R en 255 y G en 0 sale el
mismo canal, así que una capa vacía no cambia nada. Y el resultado nunca pasa de 1.

## Por qué sólo el color y no un mapa de normales

Un mapa de normales suma una textura entera por producto, en memoria y en descarga. El bisel
horneado no suma ninguna: la etiqueta viaja con el mismo tamaño y el mismo formato. Lo que no
da es un brillo que cambie con la luz. En la góndola la luz de los productos ya es horneada.
"""

from pathlib import Path

from lib.repo import RAIZ

#: Dónde vive la capa de cada etiqueta, con la misma ruta de la etiqueta adentro de `source/`.
CARPETA = RAIZ / "assets" / "source" / "biseles"

#: El ancho del brillo fino y el de la banda oscura, en texeles de la capa. **Van en texeles y no
#: en metros** porque un bisel más angosto que un texel no se ve: en una caja de góndola un
#: texel mide unos 2 milímetros, y en una lata, menos. El radio en metros sale de la densidad de
#: texeles de cada etiqueta (`radio_en_metros`).
BRILLO_EN_TEXELES = 2.2
BANDA_EN_TEXELES = 8.0

#: Los límites del radio en metros, para que una etiqueta muy densa o muy rala no dé un bisel
#: invisible ni una esquina de goma.
RADIO_MINIMO = 0.0005
RADIO_MAXIMO = 0.02

#: Hasta dónde llega la oclusión del ambiente en las partes hundidas de la malla, en metros.
DISTANCIA_DE_OCLUSION = 0.02

#: Cuánto se tiene que desviar la normal de un bisel para contar como arista. Las facetas de un
#: cilindro de 32 lados se desvían menos que esto, y una arista de 90 grados, mucho más.
UMBRAL_DE_ARISTA = 0.03

#: Cuánto pesa cada pieza en el resultado. La banda y la oclusión oscurecen hasta
#: `OSCURECIMIENTO_MAXIMO`. El brillo sube hasta `BRILLO_MAXIMO`.
PESO_DE_LA_BANDA = 0.8
PESO_DE_LA_OCLUSION = 0.35
PESO_DEL_BRILLO = 2.0
OSCURECIMIENTO_MAXIMO = 0.35
BRILLO_MAXIMO = 0.55


def ruta_de_la_capa(clave: str) -> Path:
    """Dónde va la capa de una etiqueta. `clave` es la ruta de la etiqueta, con `source/`."""
    relativa = clave.removeprefix("source/")
    return CARPETA / relativa


def radio_en_metros(texeles: float, texeles_por_metro: float) -> float:
    """El ancho en metros de un bisel de `texeles` texeles, entre los límites."""
    return min(RADIO_MAXIMO, max(RADIO_MINIMO, texeles / texeles_por_metro))


def componer(canal: float, luz: float, brillo: float) -> float:
    """Un canal de la etiqueta con la capa encima. Los tres valores van de 0 a 1.

    Sirve igual para un número que para un arreglo de numpy: sólo usa aritmética.
    """
    oscurecido = canal * luz
    return oscurecido + brillo * (1.0 - oscurecido)
