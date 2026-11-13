"""Las alturas de unos estantes con huecos iguales: lo único de `blender/parejar_estanteria_n.py`
que se puede probar sin abrir Blender."""

from __future__ import annotations


def alturas_con_huecos_iguales(
    piso: float, techo: float, grosor: float, cantidad: int
) -> list[float]:
    """La cara de arriba de cada uno de `cantidad` estantes, de abajo hacia arriba, para que los
    `cantidad` huecos midan lo mismo.

    El primero es el piso del nicho, en `piso`: su hueco es el de encima. Los demás son chapas de
    `grosor`, y el último hueco llega hasta `techo`, la cara de abajo de la tapa."""
    huecos_chapados = (techo - piso) - (cantidad - 1) * grosor
    if cantidad < 2 or huecos_chapados <= 0:
        raise ValueError("hacen falta dos estantes y alto para sus chapas")
    hueco = huecos_chapados / cantidad
    return [piso + i * (hueco + grosor) for i in range(cantidad)]
