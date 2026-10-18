"""Una suite pertenece a una sola partición, independientemente del orden y la plataforma."""

import hashlib
from collections import Counter
from dataclasses import dataclass
from pathlib import PurePosixPath
from xml.etree import ElementTree


@dataclass(frozen=True)
class ParticionTests:
    indice: int
    total: int

    def __post_init__(self) -> None:
        if self.total < 1 or not 0 <= self.indice < self.total:
            raise ValueError("la partición requiere 0 <= índice < total y total positivo")

    @classmethod
    def desde_texto(cls, texto: str) -> "ParticionTests":
        try:
            indice, total = texto.split("/")
            return cls(int(indice), int(total))
        except ValueError as error:
            raise ValueError(
                "la partición debe tener la forma ÍNDICE/TOTAL, por ejemplo 0/4"
            ) from error


def _ruta_relativa(ruta: str) -> str:
    normalizada = PurePosixPath(ruta.replace("\\", "/"))
    if (
        normalizada.is_absolute()
        or not normalizada.parts
        or ".." in normalizada.parts
        or ":" in str(normalizada)
    ):
        raise ValueError(f"la suite debe tener una ruta relativa al proyecto: {ruta!r}")
    return normalizada.as_posix()


def seleccionar_suites(suites: list[str], particion: ParticionTests) -> list[str]:
    normalizadas = sorted(_ruta_relativa(ruta) for ruta in suites)
    if len(set(normalizadas)) != len(normalizadas):
        raise ValueError("la lista contiene suites duplicadas")
    seleccionadas = [
        ruta
        for ruta in normalizadas
        if int.from_bytes(hashlib.sha256(ruta.encode("utf-8")).digest()[:4], "big")
        % particion.total == particion.indice
    ]
    if not seleccionadas:
        raise ValueError(f"la partición {particion.indice}/{particion.total} no contiene suites")
    return seleccionadas


def comprobar_reporte(suites: list[str], xml: str) -> list[str]:
    """Un exit cero con descubrimiento vacío no demuestra que corrieron los archivos pedidos."""
    try:
        raiz = ElementTree.fromstring(xml)
    except ElementTree.ParseError as error:
        raise ValueError(f"el reporte JUnit no es XML válido: {error}") from error
    if raiz.tag != "testsuites":
        raise ValueError("el reporte JUnit no contiene testsuites")
    ejecutadas = []
    for suite in raiz.findall("testsuite"):
        nombre = suite.get("name", "")
        paquete = suite.get("package", "")
        if not nombre or not paquete:
            raise ValueError("el reporte contiene una suite sin nombre o paquete")
        ruta = _ruta_relativa(f"{paquete}/{nombre}.gd")
        casos = int(suite.get("tests", "0"))
        if casos < 1 or len(suite.findall("testcase")) != casos:
            raise ValueError(f"el reporte contiene una suite sin todos sus casos: {ruta}")
        ejecutadas.append(ruta)
    esperadas = Counter(_ruta_relativa(ruta) for ruta in suites)
    observadas = Counter(ejecutadas)
    if not esperadas or esperadas != observadas:
        faltantes = sorted((esperadas - observadas).elements())
        sobrantes = sorted((observadas - esperadas).elements())
        raise ValueError(
            f"cobertura de suites incompleta: faltantes={faltantes}, sobrantes={sobrantes}"
        )
    return sorted(ejecutadas)
