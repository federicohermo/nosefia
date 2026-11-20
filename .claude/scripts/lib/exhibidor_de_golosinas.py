"""Lógica pura para restaurar el espesor del panel lateral colapsado del exhibidor de golosinas."""

from __future__ import annotations

#: Tolerancia para considerar que el panel ya coincide con el espesor objetivo.
TOLERANCIA = 1e-5


def espesor_de_panel(x_exterior: float, x_interior: float) -> float:
    """Distancia absoluta entre la cara exterior y la interior de un panel lateral."""
    return abs(x_exterior - x_interior)


def x_exterior_objetivo(
    x_exterior_actual: float,
    x_interior: float,
    espesor_referencia: float,
    signo_exterior: int,
) -> float:
    """Coordenada X objetivo de la cara exterior de un panel lateral.

    `signo_exterior` es +1 para el lateral izquierdo (lado freezer, +X) y -1 para el derecho (-X).
    Si el panel ya tiene el espesor de referencia dentro de `TOLERANCIA`, devuelve
    `x_exterior_actual` sin cambios para mantener idempotencia.
    """
    if espesor_referencia <= 0.0:
        raise ValueError(f"El espesor de referencia debe ser positivo: {espesor_referencia}")
    if signo_exterior not in (-1, 1):
        raise ValueError(f"signo_exterior debe ser -1 o +1: {signo_exterior}")
    objetivo = x_interior + signo_exterior * espesor_referencia
    if abs(x_exterior_actual - objetivo) <= TOLERANCIA:
        return x_exterior_actual
    return objetivo
