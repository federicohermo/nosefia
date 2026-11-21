"""Perfiles y reglas puras para el bisel no destructivo de puestos: PC, caja, lector y router."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
import math

MODOS_DE_NORMALES: frozenset[str] = frozenset(
    {"FACE_AREA", "CORNER_ANGLE", "FACE_AREA_WITH_ANGLE"}
)

NOMBRE_BISEL = "Bisel de puesto"
NOMBRE_TRIANGULOS = "Triángulos para exportación"
NOMBRE_NORMALES = "Normales de caras y biseles"
MODO_DE_NORMALES = "FACE_AREA"
PESO_DE_NORMALES = 100
LADOS_BASE_LECTOR = 48
LADOS_CONTORNO_MOUSE = 16
CORTE_CHAIKIN_MOUSE = 0.25
CURVATURA_HOMBRO_MOUSE = 0.08
ANCHO_BISEL_BASE_MOUSE = 0.002
SEGMENTOS_BISEL_BASE_MOUSE = 2


@dataclass(frozen=True)
class PiezaDeBisel:
    """Parámetros de biselado para una malla individual de superficie dura."""

    nombre: str
    ancho_en_metros: float
    segmentos: int = 2
    perfil: float = 0.5
    angulo_minimo_grados: float = 30.0
    aplicar_escala: bool = False
    soldar_vertices_metros: float = 0.0
    longitud_minima_arista_metros: float = 0.0
    excluir_adyacentes_menores_metros: float = 0.0


@dataclass(frozen=True)
class PiezaSuavizada:
    """Limpieza de vértices duplicados y normales pesadas sin bisel para geometría fina."""

    nombre: str
    soldar_vertices_metros: float = 0.0005
    angulo_filo_grados: float = 60.0


PIEZAS_DEL_LOCAL: tuple[PiezaDeBisel, ...] = (
    PiezaDeBisel("base compu-col", 0.0035),
    PiezaDeBisel(
        "monitor pantalla-col",
        0.0035,
        longitud_minima_arista_metros=0.006,
        excluir_adyacentes_menores_metros=0.006,
    ),
    PiezaDeBisel("monitor soporte-col", 0.0035),
    PiezaDeBisel("teclado-col", 0.0035, aplicar_escala=True),
    PiezaDeBisel("cajaregistradora-col", 0.0045, soldar_vertices_metros=0.001),
    PiezaDeBisel(
        "lector de productos-col",
        0.0035,
        angulo_minimo_grados=40.0,
        longitud_minima_arista_metros=0.006,
        excluir_adyacentes_menores_metros=0.006,
    ),
)

NOMBRE_MOUSE = "mouse-col"

PIEZAS_DEL_ROUTER: tuple[PiezaDeBisel, ...] = (
    PiezaDeBisel("router-col", 0.0025, angulo_minimo_grados=40.0),
    PiezaDeBisel("luces_botones-col", 0.0015, aplicar_escala=True),
    PiezaDeBisel("powerrouter_col", 0.0012),
)

PIEZAS_SUAVIZADAS_DEL_ROUTER: tuple[PiezaSuavizada, ...] = (
    PiezaSuavizada("antenas-col", soldar_vertices_metros=0.0005, angulo_filo_grados=60.0),
)


def validar_pieza(pieza: PiezaDeBisel) -> None:
    """Valida que los parámetros de biselado estén en rangos válidos para Blender."""
    if not pieza.nombre.strip():
        raise ValueError("nombre no puede estar vacío")
    if not (math.isfinite(pieza.ancho_en_metros) and pieza.ancho_en_metros > 0.0):
        raise ValueError(f"ancho_en_metros debe ser positivo: {pieza.ancho_en_metros}")
    if pieza.segmentos < 1:
        raise ValueError(f"segmentos debe ser al menos 1: {pieza.segmentos}")
    if not (math.isfinite(pieza.perfil) and 0.0 <= pieza.perfil <= 1.0):
        raise ValueError(f"perfil debe estar entre 0 y 1: {pieza.perfil}")
    if not (
        math.isfinite(pieza.angulo_minimo_grados) and 0.0 < pieza.angulo_minimo_grados < 180.0
    ):
        raise ValueError(
            f"angulo_minimo_grados debe estar en (0, 180): {pieza.angulo_minimo_grados}"
        )


def ancho_local(ancho_en_metros: float, escala_mundo: float) -> float:
    """Convierte el ancho de bisel en metros al espacio local de una malla con escala uniforme."""
    escala = abs(escala_mundo)
    if not (math.isfinite(escala) and escala > 1e-6):
        raise ValueError(f"escala_mundo inválida: {escala_mundo}")
    if not (math.isfinite(ancho_en_metros) and ancho_en_metros > 0.0):
        raise ValueError(f"ancho_en_metros debe ser positivo: {ancho_en_metros}")
    return ancho_en_metros / escala


def peso_de_arista(angulo_en_grados: float, angulo_minimo: float) -> float:
    """Devuelve 1.0 si el ángulo entre caras alcanza el umbral de bisel y 0.0 si no."""
    if not (math.isfinite(angulo_minimo) and angulo_minimo > 0.0):
        raise ValueError(f"angulo_minimo debe ser positivo: {angulo_minimo}")
    if not (math.isfinite(angulo_en_grados) and 0.0 <= angulo_en_grados <= 180.0):
        raise ValueError(f"angulo_en_grados debe estar en [0, 180]: {angulo_en_grados}")
    return 1.0 if angulo_en_grados >= angulo_minimo else 0.0


def pila_esperada() -> tuple[tuple[str, str], ...]:
    """Tuplas (nombre, tipo) en el orden exacto de la pila de modificadores."""
    return (
        (NOMBRE_BISEL, "BEVEL"),
        (NOMBRE_TRIANGULOS, "TRIANGULATE"),
        (NOMBRE_NORMALES, "WEIGHTED_NORMAL"),
    )


def pila_suavizada_esperada() -> tuple[tuple[str, str], ...]:
    """Tuplas (nombre, tipo) para mallas suavizadas sin modificador de bisel."""
    return (
        (NOMBRE_TRIANGULOS, "TRIANGULATE"),
        (NOMBRE_NORMALES, "WEIGHTED_NORMAL"),
    )


def pila_coincide(actual: Sequence[tuple[str, str]]) -> bool:
    """Indica si la pila de modificadores actual coincide en nombres, tipos y orden."""
    return tuple(actual) == pila_esperada()


def anillos_circulares(
    centro_xy: tuple[float, float],
    estaciones_zr: Sequence[tuple[float, float]],
    lados: int = LADOS_BASE_LECTOR,
) -> list[list[tuple[float, float, float]]]:
    """Devuelve anillos de `lados` vértices sobre el círculo exacto de cada estación `(z, radio)`."""
    if lados < 3:
        raise ValueError(f"lados debe ser al menos 3: {lados}")
    if len(estaciones_zr) < 2:
        raise ValueError("estaciones_zr requiere al menos dos anillos")
    cx, cy = centro_xy
    anillos: list[list[tuple[float, float, float]]] = []
    for z, radio in estaciones_zr:
        if not (math.isfinite(radio) and radio > 0.0):
            raise ValueError(f"radio inválido: {radio}")
        anillo = [
            (
                cx + radio * math.cos(indice * math.tau / lados),
                cy + radio * math.sin(indice * math.tau / lados),
                z,
            )
            for indice in range(lados)
        ]
        anillos.append(anillo)
    return anillos

