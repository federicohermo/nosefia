"""Las superficies del local que se leían como caricatura, y qué se le hace a cada una.

Un color liso, una textura que filtra por píxeles y un material con una sola rugosidad son tres
formas de la misma queja: la superficie se ve de dibujo. Cada receta de `RECETAS` arregla las
tres para un material del modelo, sin cambiar su tono medio ni su tamaño.

## Qué hace una receta

- **Color con variación.** Una mancha de escala grande, un grano fino y, si el material tiene
  juntas oscuras, algo de mugre en ellas. La media de cada canal queda donde estaba.
- **Rugosidad.** Un mapa chico, derivado de la misma variación, que reemplaza la rugosidad única.
- **Aire.** Para un mueble con malla propia, la oclusión y el bisel que ya hornean los productos
  (`lib/biseles.py`), y polvo suave en lo que mira para arriba.

## Los tamaños

El color sale con el lado con el que ya viajaba su textura y la rugosidad a 512: ninguna
superficie suma memoria de color, y una suma un mapa chico. Lo decide `lib/blender.py`, que mira
la carpeta de cada archivo. El color va en `textures/superficies/` y la rugosidad en
`textures/superficies/rugosidad/`.

La herramienta es `blender/mejorar_superficies.py`. **Escribe el `.blend`**: los materiales
apuntan a las imágenes nuevas, y las originales quedan en su carpeta.
"""

from dataclasses import dataclass
from pathlib import Path

from lib.repo import RAIZ

CARPETA = RAIZ / "assets" / "source" / "textures" / "superficies"
CARPETA_DE_RUGOSIDAD = CARPETA / "rugosidad"

#: El lado con el que sale cada mapa de rugosidad.
LADO_DE_LA_RUGOSIDAD = 512


@dataclass(frozen=True)
class Receta:
    material: str
    #: Cuánto varía el color en una mancha de escala grande, como fracción del color. Cero la apaga.
    mancha: float
    #: Cuántas manchas caben a lo largo de la textura.
    manchas_por_lado: int
    #: Cuánto varía el color de un píxel a otro.
    grano: float
    #: Cuánto se oscurece lo oscuro, para ensuciar las juntas. Cero la apaga.
    mugre: float
    #: La rugosidad en lo claro, la rugosidad en lo oscuro y cuánto varía de una mancha a otra.
    rugosidad: tuple[float, float, float]
    #: Hornear oclusión y bisel desde la malla del mueble.
    aire: bool = False
    #: Cuánto se aclara lo que mira para arriba. Cero lo apaga. Sólo con `aire`.
    polvo: float = 0.0
    #: Pasar la textura de filtro por píxeles a filtro suave.
    suavizar: bool = False


RECETAS = (
    Receta("HELADERA | Pura Cola", 0.035, 5, 0.015, 0.0, (0.30, 0.55, 0.10), True, 0.10, True),
    Receta("Material.019", 0.035, 5, 0.015, 0.0, (0.30, 0.55, 0.10), True, 0.10, True),
    Receta("local_ceramica", 0.05, 4, 0.02, 0.30, (0.35, 0.80, 0.12)),
    Receta("local_pared_pintada", 0.04, 3, 0.02, 0.0, (0.75, 0.85, 0.08)),
    Receta("GONDOLA | Chapa pintada blanca", 0.03, 4, 0.015, 0.0, (0.40, 0.60, 0.10)),
    Receta("FREEZER | Ploteo Frigordo", 0.03, 4, 0.012, 0.0, (0.28, 0.45, 0.08), True, 0.0),
)


def espacio_de_nombre(material: str) -> str:
    """El nombre de archivo de un material: sólo letras y números, separados con guion bajo."""
    letras = "".join(c if c.isalnum() else " " for c in material.lower())
    return "_".join(letras.split())


def ruta_del_color(receta: Receta) -> Path:
    return CARPETA / f"{espacio_de_nombre(receta.material)}_color.png"


def ruta_de_la_rugosidad(receta: Receta) -> Path:
    return CARPETA_DE_RUGOSIDAD / f"{espacio_de_nombre(receta.material)}_rugosidad.png"
