from collections import Counter
from collections.abc import Iterable
import math
import re
from typing import NamedTuple

from lib.reparto import PRODUCTOS, Tanda


class Frente(NamedTuple):
    """Cómo se ve un producto en cada estante de su cara: cuántas unidades, cada cuántos metros, y
    en qué punto del largo del estante cae el medio de la tanda."""

    cuantas: int
    paso: float
    medio: float


#: El reparto de las jornadas de prueba. Va declarado porque es una decisión de exhibición: se ve
#: igual en todos los estantes de una cara y no depende de qué tanda ocupa ese lugar en el mapa
#: completo.
FRENTES = {
    "A.oeste": {"ARVECOR": Frente(9, 0.165, -3.216), "MAROLINI": Frente(5, 0.303, -1.706)},
    "A.este": {"TERMINATOR": Frente(9, 0.165, 1.7135), "ZUCARACHAS": Frente(5, 0.303, 3.214)},
    "A.norte": {"POETICO": Frente(4, 0.2117, 0.1666)},
    "A.sur": {"FERNET_GOD": Frente(6, 0.1407, -0.1667)},
    "B.este": {"PEPITO": Frente(5, 0.31, 1.757), "PETISAS": Frente(5, 0.265, 3.202)},
    "B.oeste": {"PROGRES": Frente(11, 0.1424, -3.0878), "DON_SATURADOS": Frente(5, 0.265, -1.6411)},
    "B.norte": {"MALBARDO": Frente(6, 0.142, -2.7491)},
    "B.sur": {"JORGILLO": Frente(3, 0.3011, 2.7491)},
    "N.sur": {"ACTRONCITO": Frente(4, 0.2535, 3.1947), "DURONGA": Frente(4, 0.2535, 2.1148)},
    "H1.sur": {"PURA_COLA": Frente(5, 0.1641, -1.496)},
    "H2.sur": {"MAYONCHIS": Frente(3, 0.2918, -0.446)},
}

CARAS = {cara: tuple(frentes) for cara, frentes in FRENTES.items()}

ESTANTES_DE_PRUEBA = {
    f"{cara}.{nivel}": tuple(Tanda(p, fija=nivel != 1) for p in productos)
    for cara, productos in CARAS.items()
    for nivel in range(4)
}

def validar_reparto_de_prueba(estantes: dict[str, tuple[Tanda, ...]]) -> None:
    if estantes.keys() != ESTANTES_DE_PRUEBA.keys():
        raise ValueError("La prueba requiere los cuatro niveles de cada cara")
    principales = Counter()
    for clave, tandas in estantes.items():
        cara, _ = clave.rsplit(".", 1)
        if tuple(t.producto for t in tandas) != CARAS[cara]:
            raise ValueError(f"Productos ajenos al mapa de prueba en {clave}")
        nivel = int(clave.rsplit(".", 1)[1])
        if nivel not in (1, 2) and any(not t.fija for t in tandas):
            raise ValueError(f"La principal requiere altura de reposición: {clave}")
        principales.update(t.producto for t in tandas if not t.fija)
    presentes = {p for productos in CARAS.values() for p in productos}
    if principales != Counter({p: 1 for p in presentes}):
        raise ValueError("Cada producto presente requiere una principal")


def validar_identidades_de_prueba(identidades: Iterable[str]) -> None:
    presentes = {p for productos in CARAS.values() for p in productos}
    esperadas = [p.clave for p in PRODUCTOS if p.clave in presentes]
    if list(identidades) != esperadas:
        raise ValueError("El mapa y el catálogo de prueba tienen identidades distintas")


def bases_del_contenido(texto: str) -> dict[str, tuple[tuple[float, ...], ...]]:
    bases = {}
    for bloque in re.split(r"(?=^\[)", texto, flags=re.M):
        identidad = re.search(r"^metadata/producto_id = (\d+)$", bloque, re.M)
        if identidad is None:
            continue
        indice = int(identidad[1])
        transformacion = re.search(r"^transform = Transform3D\(([^)]+)\)$", bloque, re.M)
        if indice >= len(PRODUCTOS) or transformacion is None:
            raise ValueError("La base horneada no identifica un producto válido")
        clave = PRODUCTOS[indice].clave
        valores = [float(n) for n in transformacion[1].split(",")]
        if clave in bases or len(valores) != 12 or not all(math.isfinite(v) for v in valores):
            raise ValueError("La base horneada está repetida o incompleta")
        bases[clave] = tuple(tuple(valores[fila * 3 + columna] for columna in range(3))
                            for fila in range(3))
    if bases.keys() != {p.clave for p in PRODUCTOS}:
        raise ValueError("Faltan bases horneadas del catálogo")
    return bases
