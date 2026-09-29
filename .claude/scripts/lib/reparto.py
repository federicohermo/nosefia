"""Qué producto va en qué estante del local, y cómo se para cada uno de frente al pasillo.

Es el dato que el acomodador (`blender/acomodar.py`) lleva al `.blend`, y el que se itera con el
usuario mirando capturas: mover un producto de estante es mover una línea de `ESTANTES` y volver
a correr el acomodador. **Qué entra y cómo se ordena no se decide acá**: lo calcula
`lib/gondola.py` con las medidas de cada estante.

## Las reglas que el reparto tiene que cumplir

Las verifica `tests/test_reparto.py` sobre este mismo dato, antes de que llegue al `.blend`:

- cada producto del catálogo tiene **una sola** tanda con casilleros; lo que se repite para
  completar un estante es fijo;
- un estante de lado lleva entre dos y cuatro productos distintos, y una cabecera puede llevar
  uno solo;
- Malbardo, Durextra, Laysntt, Chisitos y Duronga van en cabecera;
- la heladera lleva lo que se vende frío, y cada uno una sola vez;
- ningún estante de góndola queda vacío.

## Cómo se nombra un estante

`<mueble>.<cara>.<nivel>`: el mueble por su letra en `MUEBLES`, la cara por el punto cardinal
hacia el que mira —las cabeceras son `norte` y `sur`—, y el nivel contando desde abajo, con el
zócalo como 0. En Blender el norte es +Y y el este +X.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Producto:
    """Un producto del catálogo y su unidad en el `.blend`.

    `frente` y `arriba` están en las coordenadas de la malla: son las direcciones que tienen que
    quedar mirando al pasillo y hacia arriba. **Se miden una vez y no se recalculan**: salen de
    cómo estaba parada cada unidad cuando el artista la dejó mirando al pasillo, y guardarlas
    así hace que acomodar dos veces dé lo mismo. En un envase redondo el frente no es un eje: es
    el lado de la etiqueta.
    """

    clave: str
    nombre: str
    objeto: str
    frente: tuple[float, float, float]
    arriba: tuple[float, float, float]


_X = (1.0, 0.0, 0.0)
_MENOS_X = (-1.0, 0.0, 0.0)
_MENOS_Y = (0.0, -1.0, 0.0)
_Z = (0.0, 0.0, 1.0)

#: En el orden de `Producto.Id`. `tests/test_reparto.py` lo compara con el catálogo del juego.
PRODUCTOS: tuple[Producto, ...] = (
    Producto("ACTRONCITO", "Actroncito", "Actroncito-col", _MENOS_Y, _X),
    Producto("DUREXTRA", "Durextra", "durextra-col", _MENOS_Y, _Z),
    Producto("BURBALOO", "Burbaloo", "burgaloo-convcol", _X, _Z),
    Producto("ZUCARACHAS", "Zucarachas", "Zucarachas-col", _MENOS_X, _Z),
    Producto("LAYSNTT", "Laysntt", "snackpapas1-convcol.003", _X, _Z),
    Producto("MALBARDO", "Malbardo", "malbardocig-convcol", _MENOS_Y, _Z),
    Producto("PRONGLES", "Prongles", "pringles3-convcol.002", _MENOS_X, _Z),
    Producto("JORGILLO", "Jorgillo", "alfajorescaja2-2oeste1-col", _Z, _X),
    Producto("ARVEJAS", "Arvejas", "lataarvejas-convcol.002", (-0.0177, -0.9998, 0.0), _Z),
    Producto("CHISITOS", "Chisitos", "chisitos2-convcol", _X, _Z),
    Producto("OREMOS", "Oremos", "oremos-col", _X, _Z),
    Producto("PEPITOS", "Pepitos", "pepitos2-col.025", _X, _Z),
    Producto("SALADIK", "Saladik", "saladix-2oeste2-col", _MENOS_X, _Z),
    Producto("UAKAS", "Uakas", "wakas-col.021", _MENOS_X, _Z),
    Producto("CORACOLA", "Coracola", "bebida helada02-este2-convcol", (-0.97, -0.2432, 0.0), _Z),
    Producto("FROTLUPS", "Frotlups", "cereal-2norte2-col", _MENOS_X, _Z),
    Producto("MAROLINI", "Marolini", "fideos2-col", _MENOS_X, _Z),
    Producto("AMARGADITO", "Amargadito", "amargadito-convcol", _MENOS_X, _Z),
    Producto("CINDOLOR", "Cindolor", "cindolor-convcol", _MENOS_X, _Z),
    Producto("FLINPUF", "Flinpuf", "flimpof-convcol", _MENOS_X, _Z),
    Producto("DONSATURADOS", "Donsaturados", "donsaturados-convcol", _MENOS_X, _Z),
    Producto("PETISAS", "Petisas", "petisas-convcol", _MENOS_X, _Z),
    Producto("MACUMBAS", "Macumbas", "macumbas-convcol", _MENOS_X, _Z),
    Producto("COSA_DE_MANI", "Cosa de Maní", "cosademani-col", _MENOS_X, _Z),
    Producto("DURONGA", "Duronga", "duronga-col", _MENOS_Y, _Z),
    Producto("FERNET_GOD", "Fernet God", "Fernetgod-col", (-0.9535, 0.3015, 0.0), _Z),
    Producto("MAYONCHIS", "Mayonchis", "mayonchis-col", _MENOS_X, _Z),
    Producto("OAAAA", "Oaaaa", "oaaa-col", _MENOS_X, _Z),
    Producto("TERMINATOR", "Terminator", "terminator-col", _MENOS_X, _Z),
    Producto("MARRANOS", "Marranos", "atun-col", (0.7534, -0.6575, 0.0), _Z),
    Producto("FEEL_RICKY_FORT", "Feel Ricky Fort", "feelrickyfort-col", _X, _Z),
)

#: Los muebles del local, por la letra con que los nombra `ESTANTES`.
MUEBLES: dict[str, str] = {
    "A": "gondolanueva-col",
    "B": "gondolanueva2-col",
    "N": "gondolanueva-col.001",
    "S": "gondolanueva-col.002",
    "H1": "heladeranueva-col",
    "H2": "heladeranueva-col.001",
}

#: Los muebles que son heladera. Sus bandejas no se achican: el hueco de atrás queda adentro de
#: un mueble cerrado y con luz propia.
HELADERAS = ("H1", "H2")

#: Las caras de una góndola que son cabecera.
CABECERAS = ("norte", "sur")

#: Lo que se vende frío, y por eso va en la heladera y en ningún otro lado.
FRIOS = ("CORACOLA", "FERNET_GOD", "TERMINATOR", "MAYONCHIS", "OAAAA")

#: Lo que se exhibe en una cabecera y en ningún otro lado.
DE_CABECERA = ("MALBARDO", "DUREXTRA", "LAYSNTT", "CHISITOS", "DURONGA")


#: Lo que no entra en dos filas en un estante de lado con panel detrás: su fondo pasa de la
#: mitad de los 0,646 m que el panel deja libres. Va en el zócalo, que no tiene panel. Medido el
#: 2026-09-29: Actroncito mide 0,395 de fondo y Cosa de Maní 0,340; arriba, el estante crecía
#: hasta asomar 15 cm por delante de los laterales de la góndola.
DEL_ZOCALO = ("ACTRONCITO", "COSA_DE_MANI")


@dataclass(frozen=True)
class Tanda:
    """Una tanda de un estante. `fija` es la que completa el estante repitiendo un producto: no
    tiene casilleros y nunca se vacía."""

    producto: str
    fija: bool = False


def _p(clave: str) -> Tanda:
    return Tanda(clave)


def _f(clave: str) -> Tanda:
    return Tanda(clave, fija=True)


#: Qué lleva cada estante, de izquierda a derecha para quien lo mira desde el pasillo.
#:
#: **Es la primera disposición, y se itera.** Cada producto se repone en un solo lugar y a la
#: altura de la mano cuando se pudo. Los estantes de lado piden al menos dos productos
#: distintos y hay menos productos que lugares: lo que completa un estante es una tanda fija de
#: un producto que se repone en otro lado.
ESTANTES: dict[str, tuple[Tanda, ...]] = {
    # Góndola del medio, la de la derecha entrando: su cara oeste da al pasillo central.
    "A.oeste.3": (_p("FROTLUPS"), _f("ZUCARACHAS")),
    "A.oeste.2": (_p("ZUCARACHAS"), _f("FEEL_RICKY_FORT")),
    "A.oeste.1": (_p("OREMOS"), _f("PEPITOS")),
    "A.oeste.0": (_f("MAROLINI"), _f("UAKAS")),
    "A.este.3": (_p("SALADIK"), _f("BURBALOO")),
    "A.este.2": (_p("PEPITOS"), _f("OREMOS")),
    "A.este.1": (_p("UAKAS"), _f("MAROLINI")),
    "A.este.0": (_f("JORGILLO"), _f("PETISAS")),
    "A.sur.2": (_p("PRONGLES"),),
    "A.sur.1": (_p("MALBARDO"),),
    "A.sur.0": (_p("MACUMBAS"),),
    "A.norte.2": (_f("CHISITOS"),),
    "A.norte.1": (_p("LAYSNTT"),),
    "A.norte.0": (_p("CHISITOS"),),
    # Góndola del medio, la de la izquierda: su cara este da al pasillo central.
    "B.este.3": (_p("BURBALOO"), _f("SALADIK")),
    "B.este.2": (_p("MAROLINI"), _f("UAKAS")),
    "B.este.1": (_p("FEEL_RICKY_FORT"), _f("CINDOLOR")),
    "B.este.0": (_f("DONSATURADOS"), _f("PETISAS")),
    "B.oeste.3": (_f("FLINPUF"), _f("SALADIK")),
    "B.oeste.2": (_p("JORGILLO"), _f("FROTLUPS")),
    "B.oeste.1": (_p("DONSATURADOS"), _f("PEPITOS")),
    "B.oeste.0": (_p("ACTRONCITO"), _f("MARRANOS")),
    "B.sur.2": (_p("DURONGA"),),
    "B.sur.1": (_p("DUREXTRA"),),
    "B.sur.0": (_f("LAYSNTT"),),
    "B.norte.2": (_f("MALBARDO"),),
    "B.norte.1": (_f("PRONGLES"),),
    "B.norte.0": (_f("MACUMBAS"),),
    # Las dos góndolas contra la pared del oeste.
    "N.este.3": (_p("FLINPUF"), _f("AMARGADITO")),
    "N.este.2": (_f("CINDOLOR"), _f("JORGILLO")),
    "N.este.1": (_p("PETISAS"), _f("DONSATURADOS")),
    # Marranos es una lata chata: en el estante de abajo el portaprecio le tapa la etiqueta —sube
    # 6,5 cm y la lata mide 8,6, medido el 2026-09-29—, así que su tanda con casilleros va arriba.
    "N.este.0": (_p("ARVEJAS"), _f("MARRANOS")),
    "S.este.3": (_p("AMARGADITO"), _f("CINDOLOR")),
    "S.este.2": (_p("CINDOLOR"), _f("AMARGADITO")),
    "S.este.1": (_p("MARRANOS"), _f("ARVEJAS")),
    "S.este.0": (_p("COSA_DE_MANI"), _f("FLINPUF")),
    # Las heladeras. La de abajo de cada una y la de arriba de la segunda quedan vacías: lo frío
    # es menos que las bandejas, y va una sola vez.
    "H1.este.1": (_p("CORACOLA"),),
    "H1.este.2": (_p("TERMINATOR"),),
    "H1.este.3": (_p("FERNET_GOD"),),
    "H2.este.1": (_p("MAYONCHIS"),),
    "H2.este.2": (_p("OAAAA"),),
}


def producto(clave: str) -> Producto:
    for candidato in PRODUCTOS:
        if candidato.clave == clave:
            return candidato
    raise KeyError(clave)


def partes(estante: str) -> tuple[str, str, int]:
    """El mueble, la cara y el nivel de un estante."""
    mueble, cara, nivel = estante.split(".")
    return mueble, cara, int(nivel)


def es_heladera(estante: str) -> bool:
    return partes(estante)[0] in HELADERAS


def es_cabecera(estante: str) -> bool:
    return partes(estante)[1] in CABECERAS
