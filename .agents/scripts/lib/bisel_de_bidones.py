"""Perfil y reglas puras para el bisel no destructivo de los bidones de limpieza."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
import math

MODOS_DE_NORMALES: frozenset[str] = frozenset(
    {"FACE_AREA", "CORNER_ANGLE", "FACE_AREA_WITH_ANGLE"}
)


@dataclass(frozen=True)
class PerfilDeBisel:
    """Parámetros canónicos de la pila de biselado para los bidones."""

    objetos: tuple[str, ...] = (
        "bidón jabon01-col",
        "bidón jabon01-col.001",
        "bidón jabon01-col.002",
    )
    ancho_en_metros: float = 0.006
    segmentos: int = 2
    perfil: float = 0.5
    angulo_minimo_grados: float = 30.0
    modo_de_normales: str = "FACE_AREA"
    peso_de_normales: int = 100
    nombre_bisel: str = "Bisel de bidón"
    nombre_triangulos: str = "Triángulos para exportación"
    nombre_normales: str = "Normales de caras y biseles"


PERFIL_DE_BIDONES = PerfilDeBisel()


def validar_perfil(perfil: PerfilDeBisel) -> None:
    """Valida que los parámetros del perfil estén en rangos válidos para Blender."""
    if not perfil.objetos or any(not nombre.strip() for nombre in perfil.objetos):
        raise ValueError("objetos debe contener al menos un nombre no vacío")
    if len(set(perfil.objetos)) != len(perfil.objetos):
        raise ValueError(f"objetos contiene nombres repetidos: {perfil.objetos}")
    if not (math.isfinite(perfil.ancho_en_metros) and perfil.ancho_en_metros > 0.0):
        raise ValueError(f"ancho_en_metros debe ser positivo: {perfil.ancho_en_metros}")
    if perfil.segmentos < 1:
        raise ValueError(f"segmentos debe ser al menos 1: {perfil.segmentos}")
    if not (math.isfinite(perfil.perfil) and 0.0 <= perfil.perfil <= 1.0):
        raise ValueError(f"perfil debe estar entre 0 y 1: {perfil.perfil}")
    if not (
        math.isfinite(perfil.angulo_minimo_grados) and 0.0 < perfil.angulo_minimo_grados < 180.0
    ):
        raise ValueError(
            f"angulo_minimo_grados debe estar en (0, 180): {perfil.angulo_minimo_grados}"
        )
    if perfil.modo_de_normales not in MODOS_DE_NORMALES:
        raise ValueError(f"modo_de_normales inválido: {perfil.modo_de_normales}")
    if not (1 <= perfil.peso_de_normales <= 100):
        raise ValueError(f"peso_de_normales debe estar en [1, 100]: {perfil.peso_de_normales}")
    nombres = (perfil.nombre_bisel, perfil.nombre_triangulos, perfil.nombre_normales)
    if any(not nombre.strip() for nombre in nombres) or len(set(nombres)) != len(nombres):
        raise ValueError(f"los nombres de modificadores deben ser no vacíos y distintos: {nombres}")


def peso_de_arista(angulo_en_grados: float, angulo_minimo: float) -> float:
    """Devuelve 1.0 si el ángulo entre caras alcanza el umbral de bisel y 0.0 si no."""
    if not (math.isfinite(angulo_minimo) and angulo_minimo > 0.0):
        raise ValueError(f"angulo_minimo debe ser positivo: {angulo_minimo}")
    if not (math.isfinite(angulo_en_grados) and 0.0 <= angulo_en_grados <= 180.0):
        raise ValueError(f"angulo_en_grados debe estar en [0, 180]: {angulo_en_grados}")
    return 1.0 if angulo_en_grados >= angulo_minimo else 0.0


def pila_esperada(perfil: PerfilDeBisel) -> tuple[tuple[str, str], ...]:
    """Tuplas (nombre, tipo) en el orden exacto de la pila de modificadores."""
    return (
        (perfil.nombre_bisel, "BEVEL"),
        (perfil.nombre_triangulos, "TRIANGULATE"),
        (perfil.nombre_normales, "WEIGHTED_NORMAL"),
    )


def pila_coincide(actual: Sequence[tuple[str, str]], perfil: PerfilDeBisel) -> bool:
    """Indica si la pila de modificadores actual coincide en nombres, tipos y orden."""
    return tuple(actual) == pila_esperada(perfil)
