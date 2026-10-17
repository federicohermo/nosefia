"""Qué producto va en qué estante del local, y cómo se para cada uno de frente al pasillo.

Es el dato que el acomodador (`blender/acomodar.py`) lleva al `.blend`, y el que se itera con el
usuario mirando capturas: mover un producto de estante es mover una línea de `ESTANTES` y volver
a correr el acomodador. **Qué entra y cómo se ordena no se decide acá**: lo calcula
`lib/gondola.py` con las medidas de cada estante.

## Las reglas que el reparto tiene que cumplir

Las verifica `tests/test_reparto.py` sobre este mismo dato, antes de que llegue al `.blend`:

- cada producto exhibido tiene **una sola** tanda principal; Duronga conserva su destino
  provisional de no comestibles. Lo que se repite para completar un estante es fijo;
- los faltantes de apertura van en las principales a altura de la mano: niveles 1 y 2 de los
  cuatro existentes, tanto en laterales como en cabeceras; 0 y 3 llevan referencias fijas.
  Las filas de adelante de ambas tienen casilleros interactuables;
- un estante de lado lleva dos tandas, mitad y mitad, o una sola principal que lo ocupa
  entero;
- los destinos y sus productos siguen los sectores del mapa aprobado;
- Cosa de Maní, Flin Puf, Burbaloo, Marranos y Poético llevan una fila en todas sus tandas;
  Amargadito sólo en la principal. Actroncito y Prongles conservan sus dos hileras;
- la heladera lleva lo que se vende frío: cada uno se repone en una sola tanda, y lo que
  repite para llenar una bandeja es fijo;

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
    # De frente, y no de costado: el lateral de la caja se ve liso, porque sus UV caen en una
    # zona lisa del atlas. La caja y sus texturas no se tocan.
    Producto("ACTRONCITO", "Actroncito", "Actroncito-col", _MENOS_Y, _X),
    Producto("DUREXTRA", "Durextra", "durextra-col.001", _MENOS_Y, _Z),
    Producto("BURBALOO", "Burbaloo", "burgaloo-convcol", _X, _Z),
    Producto("ZUCARACHAS", "Zucarachas", "Zucarachas-col", _MENOS_X, _Z),
    Producto("LAYSNNT", "Laysntt", "snackpapas1-convcol.002", _X, _Z),
    Producto("MALBARDO", "Malbardo", "malbardocig-convcol", _MENOS_Y, _Z),
    Producto("PROGRES", "Prongles", "pringles3-convcol.001", _MENOS_X, _Z),
    Producto("JORGILLO", "Jorgillo", "alfajorescaja2-2oeste1-col.001", _Z, _X),
    Producto("ARVECOR", "Arvejas", "lataarvejas-convcol.002", (-0.0177, -0.9998, 0.0), _Z),
    Producto("CHISITOS", "Chisitos", "chisitos2-convcol.001", _X, _Z),
    Producto("OREMOS", "Oremos", "oremos-col", _X, _Z),
    Producto("PEPITO", "Pepitos", "pepitos2-col.025", _X, _Z),
    Producto("SALADICK", "Saladik", "saladix-2oeste2-col", _MENOS_X, _Z),
    Producto("UAKALAS", "Uakas", "wakas-col.021", _MENOS_X, _Z),
    Producto("PURA_COLA", "Pura Cola", "bebida helada02-este2-convcol", (-0.97, -0.2432, 0.0), _Z),
    Producto("FROT_LUPS", "Frotlups", "cereal-2norte2-col", _MENOS_X, _Z),
    Producto("MAROLINI", "Marolini", "fideos2-col", _MENOS_X, _Z),
    Producto("AMARGADITO", "Amargadito", "amargadito-convcol", _MENOS_X, _Z),
    Producto("CINDOLOR", "Cindolor", "cindolor-convcol.001", _MENOS_X, _Z),
    Producto("FLIM_POF", "Flinpuf", "flimpof-convcol", _MENOS_X, _Z),
    Producto("DON_SATURADOS", "Donsaturados", "donsaturados-convcol.001", _MENOS_X, _Z),
    Producto("PETISAS", "Petisas", "petisas-convcol", _MENOS_X, _Z),
    Producto("MACUMBAS", "Macumbas", "macumbas-convcol", _MENOS_X, _Z),
    Producto("COSA_DE_MANI", "Cosa de Maní", "cosademani-col", _MENOS_X, _Z),
    Producto("DURONGA", "Duronga", "duronga-col.001", _MENOS_Y, _Z),
    Producto("FERNET_GOD", "Fernet God", "Fernetgod-col", (-0.9535, 0.3015, 0.0), _Z),
    Producto("MAYONCHIS", "Mayonchis", "mayonchis-col", _MENOS_X, _Z),
    Producto("OAAAA", "Oaaaa", "oaaa-col", _MENOS_X, _Z),
    Producto("TERMINATOR", "Terminator", "terminator-col", _MENOS_X, _Z),
    Producto("MARRANOS", "Marranos", "atun-col", (0.7534, -0.6575, 0.0), _Z),
    Producto("FEEL_RICKY_FORT", "Feel Ricky Fort", "feelrickyfort-col", _X, _Z),
    Producto("POETICO", "Poético", "poetico-convcol", (0.7649, -0.6443, 0.0), _Z),
)

#: Los muebles del local, por la letra con que los nombra `ESTANTES`.
MUEBLES: dict[str, str] = {
    "A": "gondolanueva-col",
    "B": "gondolanueva2-col",
    "N": "gondolanueva-col.001",
    "H1": "heladeranueva-col",
    "H2": "heladeranueva-col.001",
}

#: Los muebles que son heladera. Sus bandejas no se achican: el hueco de atrás queda adentro de
#: un mueble cerrado y con luz propia.
HELADERAS = ("H1", "H2")

#: Las caras de una góndola que son cabecera.
CABECERAS = ("norte", "sur")

#: Lo que se vende frío, y por eso va en la heladera y en ningún otro lado.
FRIOS = ("PURA_COLA", "OAAAA", "CINDOLOR", "MAYONCHIS")

#: Lo que se exhibe en una cabecera y en ningún otro lado.
DE_CABECERA = ("MALBARDO", "AMARGADITO", "FERNET_GOD", "TERMINATOR", "SALADICK",
               "JORGILLO", "BURBALOO", "FLIM_POF")

#: Capacidad para futuras declaraciones explícitas; los 32 productos actuales se exhiben.
SOLO_DEPOSITO: tuple[str, ...] = ()

#: Identidades del diseño, sin traducir nombres comerciales ni asignar marcas desconocidas.
SECTORES = {
    "heladera_1": ("PURA_COLA", "OAAAA"),
    "heladera_2": ("CINDOLOR", "MAYONCHIS"),
    "no_comestibles": ("ACTRONCITO", "DUREXTRA", "POETICO", "DURONGA"),
    "cabecera_no_comestibles": ("MALBARDO",),
    "cabecera_almacen": ("AMARGADITO",),
    "almacen": ("MAROLINI", "ARVECOR", "UAKALAS", "MARRANOS"),
    "cereales": ("ZUCARACHAS", "FROT_LUPS"),
    "bebidas_sin_refrigerar": ("FERNET_GOD", "TERMINATOR"),
    "dulces_primera_isla": ("MACUMBAS", "PEPITO"),
    "dulces_segunda_isla": ("OREMOS", "PETISAS", "COSA_DE_MANI", "FEEL_RICKY_FORT"),
    "salados": ("DON_SATURADOS", "PROGRES", "CHISITOS", "LAYSNNT", "SALADICK"),
    "golosinas": ("BURBALOO", "FLIM_POF", "JORGILLO"),
}

#: Cada columna conserva su sector también en zócalo y referencias superiores.
DESTINOS = {
    "H1.sur": ("heladera_1",), "H2.sur": ("heladera_2",),
    "N.sur": ("no_comestibles", "no_comestibles"),
    "A.oeste": ("almacen", "almacen"),
    "A.este": ("dulces_primera_isla", "cereales"),
    "A.sur.0": ("cabecera_almacen",), "A.sur.1": ("cabecera_almacen",),
    "A.sur.2": ("cabecera_no_comestibles",), "A.sur.3": ("cabecera_no_comestibles",),
    "A.norte": ("bebidas_sin_refrigerar",),
    "B.este": ("dulces_segunda_isla", "dulces_segunda_isla"),
    "B.oeste": ("salados", "salados"),
    "B.sur.0": ("golosinas",), "B.sur.1": ("golosinas",),
    "B.sur.2": ("salados",), "B.sur.3": ("salados",),
    "B.norte": ("golosinas", "golosinas"),
}


#: Las cinco excepciones globales del arte vigente, confirmadas para #434. Actroncito y
#: Prongles conservan las dos hileras que ya tenían: se corrige la lista antigua, no su arte.
DE_UNA_FILA = ("COSA_DE_MANI", "FLIM_POF", "BURBALOO", "MARRANOS", "POETICO")


@dataclass(frozen=True)
class Tanda:
    """Una tanda de un estante. `fija` repite un producto y abre llena; su fila de adelante
    conserva casilleros interactuables. La principal recibe los faltantes de apertura."""

    producto: str
    fija: bool = False
    filas: int | None = None

    def __post_init__(self) -> None:
        if self.filas is not None and (not self.fija or self.filas not in (1, 2)):
            raise ValueError("sólo una tanda fija puede declarar una o dos filas")
        if self.producto in DE_UNA_FILA and self.filas == 2:
            raise ValueError("la excepción global de una fila también rige las tandas fijas")

    @property
    def cantidad_de_filas(self) -> int:
        """Una fija puede declarar su encaje; si no, rige la excepción global de una fila."""
        if self.filas is not None:
            return self.filas
        if self.producto in DE_UNA_FILA:
            return 1
        return 2


def _p(clave: str) -> Tanda:
    return Tanda(clave)


def _f(clave: str, filas: int | None = None) -> Tanda:
    return Tanda(clave, fija=True, filas=filas)


#: Qué lleva cada estante, de izquierda a derecha para quien lo mira desde el pasillo.
#:
#: **Se itera.** Los lugares a la altura de la mano son más que los productos, y no se completan
#: con tandas fijas. Un producto solo ocupa el estante entero. Las tandas fijas
#: van arriba de todo y en el zócalo, y repiten un producto que se repone en otro lado.
ESTANTES: dict[str, tuple[Tanda, ...]] = {
    # Góndola del medio, la de la derecha entrando: su cara oeste da al pasillo central.
    "A.oeste.3": (_f("MAROLINI"), _f("ARVECOR")),
    "A.oeste.2": (_p("MAROLINI"), _p("ARVECOR")),
    "A.oeste.1": (_p("UAKALAS"), _p("MARRANOS")),
    "A.oeste.0": (_f("UAKALAS"), _f("MARRANOS")),
    "A.este.3": (_f("MACUMBAS"), _f("ZUCARACHAS")),
    "A.este.2": (_p("MACUMBAS"), _p("ZUCARACHAS")),
    "A.este.1": (_p("PEPITO"), _p("FROT_LUPS")),
    "A.este.0": (_f("PEPITO"), _f("FROT_LUPS")),
    "A.sur.3": (_f("MALBARDO"),),
    "A.sur.2": (_p("MALBARDO"),),
    "A.sur.1": (_p("AMARGADITO"),),
    "A.sur.0": (_f("AMARGADITO"),),
    "A.norte.3": (_f("TERMINATOR"),),
    "A.norte.2": (_p("TERMINATOR"),),
    "A.norte.1": (_p("FERNET_GOD"),),
    "A.norte.0": (_f("FERNET_GOD"),),
    # Góndola del medio, la de la izquierda: su cara este da al pasillo central.
    "B.este.3": (_f("OREMOS"), _f("PETISAS")),
    "B.este.2": (_p("OREMOS"), _p("PETISAS")),
    "B.este.1": (_p("COSA_DE_MANI"), _p("FEEL_RICKY_FORT")),
    "B.este.0": (_f("COSA_DE_MANI"), _f("FEEL_RICKY_FORT")),
    "B.oeste.3": (_f("DON_SATURADOS"), _f("PROGRES")),
    "B.oeste.2": (_p("DON_SATURADOS"), _p("PROGRES")),
    "B.oeste.1": (_p("CHISITOS"), _p("LAYSNNT")),
    "B.oeste.0": (_f("CHISITOS"), _f("LAYSNNT")),
    "B.sur.3": (_f("SALADICK"),),
    "B.sur.2": (_p("SALADICK"),),
    "B.sur.1": (_p("FLIM_POF"),),
    "B.sur.0": (_f("FLIM_POF"),),
    "B.norte.3": (_f("JORGILLO"),),
    "B.norte.2": (_p("JORGILLO"),),
    "B.norte.1": (_p("BURBALOO"),),
    "B.norte.0": (_f("BURBALOO"),),
    # La estantería existente de no comestibles.
    "N.sur.3": (_f("ACTRONCITO"), _f("DUREXTRA")),
    "N.sur.2": (_p("ACTRONCITO"), _p("DUREXTRA")),
    "N.sur.1": (_p("POETICO"), _p("DURONGA")),
    "N.sur.0": (_f("POETICO"), _f("DURONGA")),
    # Las heladeras. Lo frío es menos que las bandejas: cada uno va una vez con casilleros, y las
    # bandejas que sobran llevan repetidos fijos de lo frío. Decidido por el usuario el
    # 2026-09-29, igual que los estantes de góndola que no se completan sin repetir.
    "H1.sur.0": (_f("OAAAA"),),
    "H1.sur.1": (_p("OAAAA"),),
    "H1.sur.2": (_p("PURA_COLA"),),
    "H1.sur.3": (_f("PURA_COLA"),),
    "H2.sur.0": (_f("MAYONCHIS"),),
    "H2.sur.1": (_p("MAYONCHIS"),),
    "H2.sur.2": (_p("CINDOLOR"),),
    "H2.sur.3": (_f("CINDOLOR"),),
}


def sector_de(estante: str, columna: int) -> str:
    destino = estante if estante in DESTINOS else estante.rsplit(".", 1)[0]
    sectores = DESTINOS[destino]
    return sectores[columna]


def validar_tandas(principales: dict[str, int]) -> None:
    """Un vacío declarado es distinto de perder una fuente o inventar una identidad."""
    conocidas = {p.clave for p in PRODUCTOS}
    if principales.keys() - conocidas:
        raise ValueError("producto sin sector declarado")
    for p in PRODUCTOS:
        esperado = 0 if p.clave in SOLO_DEPOSITO else 1
        if principales.get(p.clave, 0) != esperado:
            raise ValueError(f"{p.nombre}: se requieren {esperado} tandas principales")


def validar_reparto(estantes: dict[str, tuple[Tanda, ...]]) -> None:
    principales: dict[str, int] = {}
    for estante, tandas in estantes.items():
        for columna, t in enumerate(tandas):
            sector = sector_de(estante, columna)
            if t.producto not in SECTORES[sector]:
                raise ValueError(f"{t.producto} no pertenece a {sector} en {estante}")
            if not t.fija:
                principales[t.producto] = principales.get(t.producto, 0) + 1
    validar_tandas(principales)


def producto(clave: str) -> Producto:
    for candidato in PRODUCTOS:
        if candidato.clave == clave:
            return candidato
    raise KeyError(clave)


def partes(estante: str) -> tuple[str, str, int]:
    """El mueble, la cara y el nivel de un estante."""
    mueble, cara, nivel = estante.split(".")
    return mueble, cara, int(nivel)


def cara_de_isla(_normal: tuple[float, float, float], medio: tuple[float, float, float]) -> str:
    if abs(medio[1]) > abs(medio[0]):
        return "norte" if medio[1] > 0 else "sur"
    return "oeste" if medio[0] < 0 else "este"


def es_heladera(estante: str) -> bool:
    return partes(estante)[0] in HELADERAS


def es_cabecera(estante: str) -> bool:
    mueble, cara, _ = partes(estante)
    return mueble in ("A", "B") and cara in CABECERAS
