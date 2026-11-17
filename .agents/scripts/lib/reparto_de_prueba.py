"""El mapa de las jornadas de prueba, derivado del mapa completo de `lib/reparto.py`.

Cada producto presente conserva su estante, su lado y su tanda principal. El lugar de un producto
ausente lo llena un producto presente de su misma cara, como tanda fija: `REEMPLAZOS` dice cuál.
Así un producto no cambia de lugar al pasar a la primera jornada completa.

Un estante que queda con un solo producto se reparte de punta a punta. Las cuentas de ese
reparto están acá, y las usa `blender/disponer_prueba.py`.
"""

from collections import Counter
from collections.abc import Iterable, Sequence
import math
import re

from lib.reparto import ESTANTES, PRODUCTOS, Tanda, partes

#: Qué producto presente llena el lugar de cada ausente. Los dos comparten la cara.
REEMPLAZOS: dict[str, str] = {
    "UAKALAS": "MAROLINI", "MARRANOS": "ARVECOR",
    "FROT_LUPS": "ZUCARACHAS", "FEEL_RICKY_FORT": "DON_SATURADOS",
    "AMARGADITO": "MALBARDO",
    "MACUMBAS": "PETISAS", "FLIM_POF": "PETISAS", "COSA_DE_MANI": "PETISAS",
    "LAYSNNT": "PROGRES", "CHISITOS": "PROGRES", "SALADICK": "PROGRES",
    "BURBALOO": "JORGILLO", "OREMOS": "PEPITO",
    "DUREXTRA": "DURONGA",
    "OAAAA": "PURA_COLA", "CINDOLOR": "MAYONCHIS",
}

#: Lo menos que se separan dos unidades al contar cuántas entran en un tramo, en metros. Las
#: cajas de 24 cm del mapa completo van a 1,3 cm.
AIRE_MINIMO = 0.01


def cara_de(estante: str) -> str:
    mueble, cara, _ = partes(estante)
    return f"{mueble}.{cara}"


#: Las caras que exhiben en las jornadas de prueba: las del mapa completo.
CARAS: tuple[str, ...] = tuple(sorted({cara_de(estante) for estante in ESTANTES}))


def producto_de_prueba(clave: str) -> str:
    """El producto que se ve en el lugar de `clave`: él mismo, o el que lo reemplaza."""
    return REEMPLAZOS.get(clave, clave)


def presentes() -> list[str]:
    """Los productos de las jornadas de prueba, en el orden del catálogo."""
    return [p.clave for p in PRODUCTOS if p.clave not in REEMPLAZOS]


def derivar(estantes: dict[str, tuple[Tanda, ...]]) -> dict[str, tuple[Tanda, ...]]:
    """El mapa de prueba de un mapa completo. La tanda de un ausente pasa a ser fija."""
    return {
        estante: tuple(
            Tanda(producto_de_prueba(t.producto), fija=t.fija or t.producto in REEMPLAZOS)
            for t in tandas
        )
        for estante, tandas in estantes.items()
    }


ESTANTES_DE_PRUEBA = derivar(ESTANTES)


def validar_reemplazos(estantes: dict[str, tuple[Tanda, ...]]) -> None:
    """Cada ausente tiene un reemplazo presente que ya exhibe en todas sus caras."""
    caras: dict[str, set[str]] = {}
    for estante, tandas in estantes.items():
        for t in tandas:
            caras.setdefault(t.producto, set()).add(cara_de(estante))
    for ausente, reemplazo in REEMPLAZOS.items():
        if reemplazo in REEMPLAZOS:
            raise ValueError(f"{ausente}: su reemplazo {reemplazo} también está ausente")
        if not caras.get(ausente, set()) <= caras.get(reemplazo, set()):
            raise ValueError(f"{ausente}: {reemplazo} no exhibe en su misma cara")


def validar_reparto_de_prueba(estantes: dict[str, tuple[Tanda, ...]]) -> None:
    """Sólo productos presentes, y una principal por cada uno."""
    principales: Counter[str] = Counter()
    for clave, tandas in estantes.items():
        for t in tandas:
            if t.producto in REEMPLAZOS:
                raise ValueError(f"Producto ausente en el mapa de prueba: {t.producto} en {clave}")
            if not t.fija:
                principales[t.producto] += 1
    if principales != Counter({p: 1 for p in presentes()}):
        raise ValueError("Cada producto presente requiere una sola principal")


def validar_identidades_de_prueba(identidades: Iterable[str]) -> None:
    if list(identidades) != presentes():
        raise ValueError("El mapa y el catálogo de prueba tienen identidades distintas")


def cuantas_entran(largo: float, ancho: float, paso: float) -> int:
    """Cuántas unidades de `ancho` entran en `largo`, una cada `paso`. Siempre al menos una."""
    return max(1, int((largo - ancho) / paso + 1e-6) + 1)


def paso_parejo(largo: float, ancho: float, cuantas: int, paso: float) -> float:
    """El paso que reparte las unidades de punta a punta. Una sola unidad conserva el suyo."""
    return (largo - ancho) / (cuantas - 1) if cuantas > 1 else paso


def repartir_columnas(columnas: int, frentes: Sequence[int]) -> list[int]:
    """Cuántas columnas le tocan a cada tanda de un estante, en proporción a su frente."""
    cortes = []
    acumulado = 0
    for frente in frentes:
        acumulado += frente
        cortes.append(round(columnas * acumulado / sum(frentes)))
    return [corte - anterior for anterior, corte in zip([0] + cortes, cortes)]


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
