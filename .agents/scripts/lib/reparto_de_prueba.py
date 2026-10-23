from collections import Counter
from collections.abc import Iterable
from dataclasses import dataclass
from itertools import product
import math
import re

from lib.gondola import Envase, MARGEN
from lib.reparto import PRODUCTOS, Tanda


def tramo_con_referencia(
    largo_del_estante: float, izquierda: float, largo: float, retiro: float,
    extremos: tuple[float, float] = (0.0, 0.0),
    separaciones: tuple[float, float] = (0.0, 0.0),
    cabecera: bool = False,
) -> tuple[float, float]:
    """El retiro frontal no recorta el ancho transversal de una cabecera.

    En los laterales, la banda medida ya reserva dos márgenes de la tanda de la punta;
    se agrega sólo el retiro y el aire que todavía faltan detrás de ella.
    """
    if cabecera:
        return izquierda, izquierda + largo
    inicio = max(izquierda, retiro, extremos[0] - 2 * MARGEN + separaciones[0])
    fin = min(
        izquierda + largo,
        largo_del_estante - max(retiro, extremos[1] - 2 * MARGEN + separaciones[1]),
    )
    return inicio, fin


def pasos_del_estante(productos: tuple[str, ...], referencias: dict[str, float]) -> list[float]:
    """La separación de cada producto del estante: la de referencia, salvo Terminator.

    Terminator toma la de su vecino porque con la suya de referencia las cajas quedan casi
    solapadas junto al resto del estante.
    """
    pasos = [referencias[producto] for producto in productos]
    if len(productos) == 2:
        for indice, producto in enumerate(productos):
            if producto in CON_EL_PASO_DEL_VECINO:
                pasos[indice] = referencias[productos[1 - indice]]
    return pasos


def centros_con_referencia(
    largo: float, envases: list[Envase], cuentas: list[int], huecos: list[float],
    extremos: tuple[float, float] | None = None,
    *, minimo: float, aire_central: float = 0.0,
) -> list[list[float]]:
    """El cupo sale de las columnas que caben con el ritmo de referencia y sus márgenes.

    El encuentro de dos tandas deja la mayor separación de las dos y el sobrante va a los
    bordes: así el paso es el mismo entre las unidades vecinas, sean o no del mismo producto.
    """
    if not envases or len(envases) != len(cuentas) or len(cuentas) != len(huecos):
        raise ValueError("el reparto requiere un envase y una separación por tanda")
    if extremos is not None and len(envases) != 2:
        raise ValueError("los extremos requieren las dos mitades longitudinales")
    if len(envases) > 2:
        raise ValueError("el mapa admite una tanda o las dos mitades longitudinales")
    if any(n < 1 or h < minimo for n, h in zip(cuentas, huecos)):
        raise ValueError("el reparto no conserva el mínimo de aire entre unidades")
    dos = len(envases) == 2
    union = max(aire_central, *huecos) if dos else 0.0
    bordes = extremos or ((aire_central / 2,) * 2 if dos else (0.0, 0.0))
    disponible = largo - sum(bordes) - union
    candidatas = []
    for candidata in product(*(range(1, limite + 1) for limite in cuentas)):
        bloques = [n * e.ancho + (n - 1) * h
                   for n, e, h in zip(candidata, envases, huecos)]
        sobrante = disponible - sum(bloques)
        if sobrante < -1e-9:
            continue
        if dos:
            inicio = bordes[0] + sobrante / 2
            if not inicio + bloques[0] / 2 < largo / 2 < inicio + bloques[0] + union + bloques[1] / 2:
                continue
        candidatas.append((sum(candidata), -abs(bloques[0] - bloques[-1]), candidata, bloques))
    if not candidatas:
        raise ValueError("ni una columna cabe conservando los márgenes y el aire")
    _, _, cuentas, bloques = max(candidatas)
    inicio = bordes[0] + (disponible - sum(bloques)) / 2
    inicios = [inicio, inicio + bloques[0] + union][:len(envases)]
    return [
        [desde + envase.ancho / 2 + columna * (envase.ancho + hueco) for columna in range(cuenta)]
        for envase, cuenta, hueco, desde in zip(envases, cuentas, huecos, inicios)
    ]


CARAS = {
    "A.oeste": ("ARVECOR", "MAROLINI"),
    "A.este": ("TERMINATOR", "ZUCARACHAS"),
    "A.norte": ("FERNET_GOD",),
    "A.sur": ("MALBARDO",),
    "B.este": ("PEPITO", "PETISAS"),
    "B.oeste": ("PROGRES", "DON_SATURADOS"),
    "B.norte": ("JORGILLO",),
    "B.sur": ("POETICO",),
    "N.sur": ("ACTRONCITO", "DURONGA"),
    "H1.sur": ("PURA_COLA",),
    "H2.sur": ("MAYONCHIS",),
}

ESTANTES_DE_PRUEBA = {
    f"{cara}.{nivel}": tuple(Tanda(p, fija=nivel != 1) for p in productos)
    for cara, productos in CARAS.items()
    for nivel in range(4)
}

CON_EL_PASO_DEL_VECINO = frozenset({"TERMINATOR"})

RETIROS_POR_ESTANTE_DE_PRUEBA = {
    f"{letra}.{cara}.{nivel}": 0.04
    for letra in ("A", "B")
    for cara in ("este", "oeste")
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


@dataclass(frozen=True)
class Banda:
    x0: float
    x1: float
    y0: float
    y1: float


def bandas_del_nivel(
    x0: float, x1: float, y0: float, y1: float, norte: float, sur: float
) -> dict[str, Banda]:
    """Las cabeceras reservan el fondo medido de sus envases sobre la chapa real."""
    if x1 <= x0 or y1 - y0 <= norte + sur or min(norte, sur) <= 0:
        raise ValueError("La chapa no alcanza para las caras del mapa")
    centro = (x0 + x1) / 2
    return {
        "norte": Banda(x0, x1, y1 - norte, y1),
        "sur": Banda(x0, x1, y0, y0 + sur),
        "oeste": Banda(x0, centro, y0 + sur, y1 - norte),
        "este": Banda(centro, x1, y0 + sur, y1 - norte),
    }


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
