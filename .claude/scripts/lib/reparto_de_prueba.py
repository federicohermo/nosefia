from collections import Counter
from collections.abc import Iterable
import math
import re

from lib.reparto import PRODUCTOS, Tanda


CARAS = {
    "A.oeste": ("ARVECOR", "MAROLINI"),
    "A.este": ("TERMINATOR", "ZUCARACHAS"),
    "A.norte": ("FERNET_GOD",),
    "A.sur": ("MALBARDO",),
    "B.este": ("PEPITO", "PETISAS"),
    "B.oeste": ("PROGRES", "DON_SATURADOS"),
    "B.norte": ("POETICO",),
    "B.sur": ("JORGILLO",),
    "N.sur": ("ACTRONCITO", "DURONGA"),
    "H1.sur": ("PURA_COLA",),
    "H2.sur": ("MAYONCHIS",),
}

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
