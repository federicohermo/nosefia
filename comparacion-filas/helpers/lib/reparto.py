"""Qué producto va en qué estante del local, y cómo se para cada uno de frente al pasillo.

Es el dato que el acomodador (`blender/acomodar.py`) lleva al `.blend`, y el que se itera con el
usuario mirando capturas: mover un producto de estante es mover una línea de `ESTANTES` y volver
a correr el acomodador. **Qué entra y cómo se ordena no se decide acá**: lo calcula
`lib/gondola.py` con las medidas de cada estante.

## Las reglas que el reparto tiene que cumplir

Las verifica `tests/test_reparto.py` sobre este mismo dato, antes de que llegue al `.blend`:

- cada producto exhibido tiene **una sola** tanda con casilleros; Duronga sólo tiene su fuente
  exportable y caja en el depósito. Lo que se repite para
  completar un estante es fijo;
- se repone sólo a la altura de la mano: en una cara de lado, en los estantes que no son ni el
  de arriba ni el zócalo, y en una cabecera, en los niveles activos 0 y 1. Esos estantes no
  llevan ninguna tanda fija, y los demás llevan sólo tandas fijas;
- un estante de lado lleva dos tandas, mitad y mitad, o una sola con casilleros que lo ocupa
  entero;
- los destinos y sus productos siguen los sectores del mapa aprobado;
- Actroncito, Cosa de Maní, Prongles, Flin Puf y Burbaloo van en una sola fila: su tanda con
  casilleros es toda de casilleros;
- la heladera lleva lo que se vende frío: cada uno se repone en una sola tanda, y lo que
  repite para llenar una bandeja es fijo;
- la cuarta chapa física de cada cabecera queda sin exhibición, como en el reparto vigente.

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
    Producto("LAYSNTT", "Laysntt", "snackpapas1-convcol.002", _X, _Z),
    Producto("MALBARDO", "Malbardo", "malbardocig-convcol", _MENOS_Y, _Z),
    Producto("PRONGLES", "Prongles", "pringles3-convcol.001", _MENOS_X, _Z),
    Producto("JORGILLO", "Jorgillo", "alfajorescaja2-2oeste1-col.001", _Z, _X),
    Producto("ARVEJAS", "Arvejas", "lataarvejas-convcol.002", (-0.0177, -0.9998, 0.0), _Z),
    Producto("CHISITOS", "Chisitos", "chisitos2-convcol.001", _X, _Z),
    Producto("OREMOS", "Oremos", "oremos-col", _X, _Z),
    Producto("PEPITOS", "Pepitos", "pepitos2-col.025", _X, _Z),
    Producto("SALADIK", "Saladik", "saladix-2oeste2-col", _MENOS_X, _Z),
    Producto("UAKAS", "Uakas", "wakas-col.021", _MENOS_X, _Z),
    Producto("CORACOLA", "Coracola", "bebida helada02-este2-convcol", (-0.97, -0.2432, 0.0), _Z),
    Producto("FROTLUPS", "Frotlups", "cereal-2norte2-col", _MENOS_X, _Z),
    Producto("MAROLINI", "Marolini", "fideos2-col", _MENOS_X, _Z),
    Producto("AMARGADITO", "Amargadito", "amargadito-convcol", _MENOS_X, _Z),
    Producto("CINDOLOR", "Cindolor", "cindolor-convcol.001", _MENOS_X, _Z),
    Producto("FLINPUF", "Flinpuf", "flimpof-convcol", _MENOS_X, _Z),
    Producto("DONSATURADOS", "Donsaturados", "donsaturados-convcol.001", _MENOS_X, _Z),
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
FRIOS = ("CORACOLA", "FERNET_GOD", "CINDOLOR", "MAYONCHIS")

#: Lo que se exhibe en una cabecera y en ningún otro lado.
DE_CABECERA = ("MALBARDO", "AMARGADITO", "OAAAA", "TERMINATOR", "SALADIK",
               "JORGILLO", "BURBALOO", "FLINPUF")

#: La cuarta chapa de cabecera existe, pero no amplía los niveles activos ni sus alturas.
ESTANTES_SIN_EXHIBICION = tuple(f"{m}.{c}.3" for m in ("A", "B") for c in CABECERAS)
SOLO_DEPOSITO = ("DURONGA",)

#: Identidades del diseño, sin traducir nombres comerciales ni asignar marcas desconocidas.
SECTORES = {
    "heladera_1": ("CORACOLA", "FERNET_GOD"),
    "heladera_2": ("CINDOLOR", "MAYONCHIS"),
    "no_comestibles": ("ACTRONCITO", "DUREXTRA", "POETICO"),
    "cabecera_no_comestibles": ("MALBARDO",),
    "cabecera_almacen": ("AMARGADITO",),
    "almacen": ("MAROLINI", "ARVEJAS", "UAKAS", "MARRANOS"),
    "cereales": ("ZUCARACHAS", "FROTLUPS"),
    "bebidas_sin_refrigerar": ("OAAAA", "TERMINATOR"),
    "dulces_primera_isla": ("MACUMBAS", "PEPITOS"),
    "dulces_segunda_isla": ("OREMOS", "PETISAS", "COSA_DE_MANI", "FEEL_RICKY_FORT"),
    "salados": ("DONSATURADOS", "PRONGLES", "CHISITOS", "LAYSNTT", "SALADIK"),
    "golosinas": ("BURBALOO", "FLINPUF", "JORGILLO"),
}

#: Cada columna conserva su sector también en zócalo y referencias superiores.
DESTINOS = {
    "H1.sur": ("heladera_1",), "H2.sur": ("heladera_2",),
    "N.sur": ("no_comestibles", "no_comestibles"),
    "A.oeste": ("almacen", "almacen"),
    "A.este": ("dulces_primera_isla", "cereales"),
    "A.sur.0": ("cabecera_almacen",), "A.sur.1": ("cabecera_no_comestibles",),
    "A.sur.2": ("cabecera_no_comestibles",),
    "A.norte": ("bebidas_sin_refrigerar",),
    "B.este": ("dulces_segunda_isla", "dulces_segunda_isla"),
    "B.oeste": ("salados", "salados"),
    "B.sur.0": ("salados",), "B.sur.1": ("golosinas",), "B.sur.2": ("golosinas",),
    "B.norte": ("golosinas", "golosinas"),
}


#: Lo que va en una sola fila, toda de casilleros. Dos filas de Actroncito o de Cosa de Maní
#: piden un estante más hondo que cualquier otro producto, y la góndola crecía para ellos: con
#: Actroncito en el zócalo, una del medio medía 54 cm más que la otra. Medido el 2026-09-29:
#: Actroncito mide 0,395 de fondo y Cosa de Maní 0,340. Las Prongles van en una fila para que su
#: estante dé los casilleros que una jornada les hace faltar. Flin Puf y Burbaloo llevan una
#: fila por decisión del usuario al revisar el reparto el 2026-10-02; sus tandas fijas se conservan.
DE_UNA_FILA = ("ACTRONCITO", "COSA_DE_MANI", "PRONGLES", "FLINPUF", "BURBALOO")


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
#: **Se itera.** Los lugares a la altura de la mano son más que los productos, y no se completan
#: con tandas fijas. Un producto solo ocupa el estante entero. Las tandas fijas
#: van arriba de todo y en el zócalo, y repiten un producto que se repone en otro lado.
ESTANTES: dict[str, tuple[Tanda, ...]] = {
    # Góndola del medio, la de la derecha entrando: su cara oeste da al pasillo central.
    "A.oeste.3": (_f("UAKAS"), _f("MARRANOS")),
    "A.oeste.2": (_p("MAROLINI"), _p("ARVEJAS")),
    "A.oeste.1": (_p("UAKAS"), _p("MARRANOS")),
    "A.oeste.0": (_f("MAROLINI"), _f("ARVEJAS")),
    "A.este.3": (_f("PEPITOS"), _f("FROTLUPS")),
    "A.este.2": (_p("MACUMBAS"), _p("ZUCARACHAS")),
    "A.este.1": (_p("PEPITOS"), _p("FROTLUPS")),
    "A.este.0": (_f("MACUMBAS"), _f("ZUCARACHAS")),
    "A.sur.2": (_f("MALBARDO"),),
    "A.sur.1": (_p("MALBARDO"),),
    "A.sur.0": (_p("AMARGADITO"),),
    "A.norte.2": (_f("OAAAA"),),
    "A.norte.1": (_p("OAAAA"),),
    "A.norte.0": (_p("TERMINATOR"),),
    # Góndola del medio, la de la izquierda: su cara este da al pasillo central.
    "B.este.3": (_f("COSA_DE_MANI"), _f("FEEL_RICKY_FORT")),
    "B.este.2": (_p("OREMOS"), _p("PETISAS")),
    "B.este.1": (_p("COSA_DE_MANI"), _p("FEEL_RICKY_FORT")),
    "B.este.0": (_f("OREMOS"), _f("PETISAS")),
    "B.oeste.3": (_f("CHISITOS"), _f("LAYSNTT")),
    "B.oeste.2": (_p("DONSATURADOS"), _p("PRONGLES")),
    "B.oeste.1": (_p("CHISITOS"), _p("LAYSNTT")),
    "B.oeste.0": (_f("DONSATURADOS"), _f("PRONGLES")),
    "B.sur.2": (_f("JORGILLO"),),
    "B.sur.1": (_p("JORGILLO"),),
    "B.sur.0": (_p("SALADIK"),),
    "B.norte.2": (_f("BURBALOO"), _f("FLINPUF")),
    "B.norte.1": (_p("BURBALOO"),),
    "B.norte.0": (_p("FLINPUF"),),
    # La estantería existente de no comestibles.
    "N.sur.3": (_f("POETICO"),),
    "N.sur.2": (_p("ACTRONCITO"), _p("DUREXTRA")),
    "N.sur.1": (_p("POETICO"),),
    "N.sur.0": (_f("ACTRONCITO"), _f("DUREXTRA")),
    # Las heladeras. Lo frío es menos que las bandejas: cada uno va una vez con casilleros, y las
    # bandejas que sobran llevan repetidos fijos de lo frío. Decidido por el usuario el
    # 2026-09-29, igual que los estantes de góndola que no se completan sin repetir.
    "H1.sur.0": (_p("FERNET_GOD"),),
    "H1.sur.1": (_f("FERNET_GOD"),),
    "H1.sur.2": (_p("CORACOLA"),),
    "H1.sur.3": (_f("CORACOLA"),),
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


def cara_de_isla(normal: tuple[float, float, float], medio: tuple[float, float, float]) -> str:
    """Clasifica una chapa de isla por su normal y centro relativo al mueble."""
    # Las cabeceras son rampas: las altas acortan su fondo y el centro cruza el antiguo
    # umbral espacial de 1,9 m. Su inclinación conserva la identidad de la cara.
    if abs(normal[1]) > 0.01:
        return "norte" if medio[1] > 0 else "sur"
    return "oeste" if medio[0] < 0 else "este"


def es_heladera(estante: str) -> bool:
    return partes(estante)[0] in HELADERAS


def es_cabecera(estante: str) -> bool:
    mueble, cara, _ = partes(estante)
    return mueble in ("A", "B") and cara in CABECERAS
