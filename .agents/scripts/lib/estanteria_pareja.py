"""Las alturas de unos estantes parejos: lo único de `blender/parejar_estanteria_n.py` que se
puede probar sin abrir Blender."""

from __future__ import annotations


def alturas_parejas(piso: float, tope: float, cantidad: int) -> list[float]:
    """Las alturas de `cantidad` estantes con la misma separación entre sí, el primero en `piso` y
    el último en `tope`."""
    if cantidad < 2 or tope <= piso:
        raise ValueError("hacen falta dos estantes y un tope más alto que el piso")
    separacion = (tope - piso) / (cantidad - 1)
    return [piso + i * separacion for i in range(cantidad)]
