"""Una suite pertenece a una sola partición, independientemente del orden y la plataforma."""

import math
from collections import Counter
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import PurePosixPath
from types import MappingProxyType
from xml.etree import ElementTree


# Las 20 suites más lentas del run 39087916563, commit
# 563abcf781df923d67cbdb1ef82d5a0334dcf7a9. Son estimaciones, nunca el inventario.
SEGUNDOS_ESTIMADOS: Mapping[str, float] = MappingProxyType({
    # Provisionales: JUnit local Windows con fixed-fps 60, 2026-10-19; falta calibrar en CI.
    "test/escenas/lo_soltado_fuera_de_los_solidos_test.gd": 24.0,
    "test/escenas/agarre_fisico_test.gd": 13.0,
    "test/escenas/objetos/caja_que_se_lleva_test.gd": 71.055,
    "test/escenas/reposicion_manual_test.gd": 68.623,
    "test/escenas/objetos/apoyos_de_bordes_de_cajas_test.gd": 58.918,
    "test/escenas/hoja_que_arrastra_test.gd": 40.436,
    "test/escenas/freno_de_la_hoja_test.gd": 58.0,
    "test/escenas/hoja_contra_la_esquina_test.gd": 128.0,
    "test/escenas/giro_parejo_test.gd": 35.820,
    "test/escenas/objetos/mancha_en_el_piso_test.gd": 28.310,
    "test/escenas/objetos/balde_que_se_apoya_test.gd": 27.052,
    "test/escenas/unidades_sueltas_del_cierre_test.gd": 17.931,
    "test/escenas/jornada_integrada_test.gd": 15.338,
    "test/escenas/recorrido_por_el_modelo_test.gd": 14.468,
    "test/escenas/puestos/caja_registradora_test.gd": 14.419,
    "test/escenas/objetos/producto_soltado_test.gd": 10.251,
    "test/escenas/un_lugar_por_producto_test.gd": 8.815,
    "test/escenas/deposito_ordenado_test.gd": 8.583,
    "test/escenas/atencion_de_la_segunda_jornada_test.gd": 8.244,
    "test/escenas/puestos/bano_publico_test.gd": 7.696,
    "test/escenas/puestos/heladeras_del_local_test.gd": 5.659,
    "test/escenas/puestos/contenedor_de_basura_test.gd": 5.599,
})
SEGUNDOS_POR_SUITE_NUEVA = 1.0
# Los otros gates comparten la última partición. Sus imports agregaron unos 50 s
# en esa corrida; reservar toda su duración contaría dos veces el trabajo concurrente.
SEGUNDOS_RESERVADOS_PARA_GATES = 50.0


# Estas suites afirman pasos de simulación y estado físico a 60 Hz, sin depender de
# duración real, relojes monotónicos ni cantidad variable de frames de presentación.
# Cambiar ese contrato en las suites o en su código ejercido requiere volver a comparar
# ambos modos, o retirar la ruta de esta lista. Las demás suites conservan reloj normal.
SUITES_FISICA_60 = frozenset({
    "test/escenas/lo_soltado_fuera_de_los_solidos_test.gd",
    "test/escenas/agarre_fisico_test.gd",
})


@dataclass(frozen=True)
class GrupoTests:
    suites: tuple[str, ...]
    fps_fijos: int | None = None

    @property
    def nombre(self) -> str:
        return "normal" if self.fps_fijos is None else "fisica60"


def agrupar_suites(suites: list[str]) -> tuple[GrupoTests, ...]:
    normalizadas = sorted(_ruta_relativa(ruta) for ruta in suites)
    if len(set(normalizadas)) != len(normalizadas):
        raise ValueError("la lista contiene suites duplicadas")
    normales = tuple(ruta for ruta in normalizadas if ruta not in SUITES_FISICA_60)
    fisicas = tuple(ruta for ruta in normalizadas if ruta in SUITES_FISICA_60)
    return tuple(
        grupo for grupo in (GrupoTests(normales), GrupoTests(fisicas, 60)) if grupo.suites
    )


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


def seleccionar_suites(
    suites: list[str],
    particion: ParticionTests,
    segundos_estimados: Mapping[str, float] | None = None,
) -> list[str]:
    normalizadas = sorted(_ruta_relativa(ruta) for ruta in suites)
    if len(set(normalizadas)) != len(normalizadas):
        raise ValueError("la lista contiene suites duplicadas")
    estimaciones = SEGUNDOS_ESTIMADOS if segundos_estimados is None else segundos_estimados
    costos = {}
    for ruta, segundos in estimaciones.items():
        normalizada = _ruta_relativa(ruta)
        if normalizada in costos:
            raise ValueError("las estimaciones contienen suites duplicadas")
        if (
            isinstance(segundos, bool)
            or not isinstance(segundos, (int, float))
            or not math.isfinite(segundos)
            or segundos <= 0
        ):
            raise ValueError(f"el costo estimado debe ser finito y positivo: {ruta!r}")
        costos[normalizada] = segundos
    cargas = [0.0] * particion.total
    cargas[-1] = SEGUNDOS_RESERVADOS_PARA_GATES
    asignadas: list[list[str]] = [[] for _ in range(particion.total)]
    for ruta in sorted(
        normalizadas,
        key=lambda ruta: (-costos.get(ruta, SEGUNDOS_POR_SUITE_NUEVA), ruta),
    ):
        indice = min(
            range(particion.total),
            key=lambda indice: (bool(asignadas[indice]), cargas[indice], indice),
        )
        asignadas[indice].append(ruta)
        cargas[indice] += costos.get(ruta, SEGUNDOS_POR_SUITE_NUEVA)
    seleccionadas = sorted(asignadas[particion.indice])
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
    return comprobar_cobertura(suites, ejecutadas)


def comprobar_cobertura(suites: list[str], ejecutadas: list[str]) -> list[str]:
    esperadas = Counter(_ruta_relativa(ruta) for ruta in suites)
    observadas = Counter(_ruta_relativa(ruta) for ruta in ejecutadas)
    if not esperadas or esperadas != observadas:
        faltantes = sorted((esperadas - observadas).elements())
        sobrantes = sorted((observadas - esperadas).elements())
        raise ValueError(
            f"cobertura de suites incompleta: faltantes={faltantes}, sobrantes={sobrantes}"
        )
    return sorted(ejecutadas)
