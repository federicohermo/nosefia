from collections import Counter
from collections.abc import Iterable
from dataclasses import dataclass
import math
import re
from statistics import mean

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


def centros_con_referencia(
    largo: float, envases: list[Envase], cuentas: list[int], huecos: list[float],
    extremos: tuple[float, float] | None = None,
    *, minimo: float, aire_central: float = 0.0,
) -> list[list[float]]:
    """Reserva primero aire a ambos lados de cada mitad, y después conserva el ritmo.

    La holgura deseada en una cabecera no compite con los huecos entre unidades.
    Cada tanda se centra en su propio tramo, con la división longitudinal siempre abierta.
    """
    if not envases or len(envases) != len(cuentas) or len(cuentas) != len(huecos):
        raise ValueError("el reparto requiere un envase y una separación por tanda")
    if extremos is not None and len(envases) != 2:
        raise ValueError("los extremos requieren las dos mitades longitudinales")
    if len(envases) > 2:
        raise ValueError("el mapa admite una tanda o las dos mitades longitudinales")
    central = aire_central if len(envases) == 2 else 0.0
    bordes = extremos or ((central / 2,) * 2)
    if len(envases) == 1:
        bordes = (0.0, 0.0)
    disponible = largo - sum(bordes) - central
    anchos = [n * e.ancho for e, n in zip(envases, cuentas)]
    espacios = [max(0, n - 1) * h for n, h in zip(cuentas, huecos)]
    if any(n < 1 or (n > 1 and h < minimo) for n, h in zip(cuentas, huecos)):
        raise ValueError("el reparto no conserva el mínimo de aire entre unidades")
    faltante = max(0.0, sum(anchos) + sum(espacios) - disponible)
    activas = [a + h > disponible / len(envases) for a, h in zip(anchos, espacios)]
    reducible = sum((n - 1) * (h - minimo)
                    for n, h, activa in zip(cuentas, huecos, activas) if activa)
    if faltante > reducible + 1e-9:
        raise ValueError("el cupo no cabe conservando los mínimos de aire de exhibición")
    factor = 1 - faltante / reducible if reducible else 1.0
    pasos = [minimo + max(0.0, factor) * (h - minimo) if activa else h
             for h, activa in zip(huecos, activas)]
    bloques = [a + (n - 1) * h for a, n, h in zip(anchos, cuentas, pasos)]
    medio = largo / 2
    franjas = [(bordes[0], medio - central / 2), (medio + central / 2, largo - bordes[1])]
    if len(envases) == 1:
        franjas = [(0.0, largo)]
    # Como en el reparto completo, un bloque puede requerir una fracción más de ancho que
    # el otro. La frontera entre ambos queda abierta; no se comprime un bloque contra ella.
    if any(ancho > fin - inicio + 1e-9
           for ancho, (inicio, fin) in zip(bloques, franjas)):
        sobrante = max(0.0, disponible - sum(bloques))
        primero = bordes[0] + sobrante / 4
        segundo = primero + bloques[0] + central + sobrante / 2
        franjas = [(primero, primero + bloques[0]), (segundo, segundo + bloques[1])]
    salida = []
    for envase, cuenta, paso, ancho, (inicio, fin) in zip(
        envases, cuentas, pasos, bloques, franjas
    ):
        centro = inicio + (fin - inicio - ancho) / 2 + envase.ancho / 2
        salida.append([centro + columna * (envase.ancho + paso) for columna in range(cuenta)])
    if len(salida) == 2 and not mean(salida[0]) < medio < mean(salida[1]):
        raise ValueError("el reparto pierde las dos mitades longitudinales")
    return salida


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
