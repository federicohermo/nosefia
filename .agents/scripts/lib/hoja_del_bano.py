"""Lógica pura para dejar planas las dos caras grandes de la hoja de entrada al baño.

La hoja nació con un panel central hundido respecto del perímetro, unido por cuatro trapecios
inclinados en cada cara y dos materiales en la cara exterior. Reemplazar los cinco cuadriláteros
de cada cara grande por uno solo sobre el plano exterior elimina tanto las normales inclinadas
como la costura rectangular entre marco y panel, conservando intactas la posición física de la
rejilla, el espesor en los bordes, las dimensiones y los herrajes.
"""

import math
from collections.abc import Iterable, Sequence

Vertice = tuple[float, float, float]
Uv = tuple[float, float]


def _normal_de_cara(vertices: Sequence[Vertice], cara: Sequence[int]) -> Vertice:
    nx = ny = nz = 0.0
    total = len(cara)
    for i in range(total):
        x1, y1, z1 = vertices[cara[i]]
        x2, y2, z2 = vertices[cara[(i + 1) % total]]
        nx += (y1 - y2) * (z1 + z2)
        ny += (z1 - z2) * (x1 + x2)
        nz += (x1 - x2) * (y1 + y2)
    largo = math.sqrt(nx * nx + ny * ny + nz * nz)
    if largo <= 1e-12:
        raise ValueError("La cara tiene área nula")
    return (nx / largo, ny / largo, nz / largo)


def desviacion_maxima_de_caras_grandes(
    vertices: Sequence[Vertice], caras: Iterable[Sequence[int]]
) -> float:
    """Ángulo máximo, en grados, entre las caras grandes (|ny| > 0.5) y el eje Y local."""
    maxima = 0.0
    for cara in caras:
        _, ny, _ = _normal_de_cara(vertices, cara)
        if abs(ny) <= 0.5:
            continue
        angulo = math.degrees(math.acos(min(1.0, abs(ny))))
        if angulo > maxima:
            maxima = angulo
    return maxima


def proyectar_uv_afin(
    referencias: Sequence[tuple[tuple[float, float], Uv]],
    punto: tuple[float, float],
) -> Uv:
    """Extrapola el mapeo UV afín de un panel plano hacia cualquier punto (x, z) de la cara.

    Conserva la posición física exacta de la rejilla cuando el panel central se extiende hasta el
    perímetro exterior de la hoja.
    """
    if len(referencias) < 3:
        raise ValueError("Se necesitan al menos tres referencias para el mapeo afín")
    (x0, z0), (u0, v0) = referencias[0]
    mejor = None
    mejor_det = 0.0
    for i in range(1, len(referencias)):
        (x1, z1), uv1 = referencias[i]
        for j in range(i + 1, len(referencias)):
            (x2, z2), uv2 = referencias[j]
            det = (x1 - x0) * (z2 - z0) - (x2 - x0) * (z1 - z0)
            if abs(det) > abs(mejor_det):
                mejor_det = det
                mejor = ((x1, z1), uv1, (x2, z2), uv2)
    if mejor is None or abs(mejor_det) <= 1e-10:
        raise ValueError("Las referencias UV son colineales")
    (x1, z1), (u1, v1), (x2, z2), (u2, v2) = mejor
    dx1, dz1 = x1 - x0, z1 - z0
    dx2, dz2 = x2 - x0, z2 - z0
    px, pz = punto[0] - x0, punto[1] - z0

    def _evaluar(a0: float, a1: float, a2: float) -> float:
        da1, da2 = a1 - a0, a2 - a0
        gx = (da1 * dz2 - da2 * dz1) / mejor_det
        gz = (dx1 * da2 - dx2 * da1) / mejor_det
        return a0 + gx * px + gz * pz

    return (_evaluar(u0, u1, u2), _evaluar(v0, v1, v2))


def plano_exterior_por_lado(
    vertices: Sequence[Vertice],
    indices_del_cuerpo: Iterable[int],
) -> tuple[float, float]:
    """Devuelve `(y_neg, y_pos)` del perímetro exterior del cuerpo de la hoja."""
    cuerpo = set(indices_del_cuerpo)
    if not cuerpo:
        raise ValueError("El cuerpo de la hoja no tiene vértices")
    ys = [vertices[i][1] for i in cuerpo]
    y_min = min(ys)
    y_max = max(ys)
    if y_max - y_min <= 1e-4:
        raise ValueError("El cuerpo de la hoja no tiene espesor en Y")
    return y_min, y_max


def esquinas_exteriores(
    vertices: Sequence[Vertice],
    indices_del_cuerpo: Iterable[int],
    lado: int,
    tolerancia: float = 1e-3,
) -> list[int]:
    """Las cuatro esquinas del perímetro en `lado` (-1 para -Y, +1 para +Y), ordenadas.

    Para `lado == -1` devuelve `[abajo_izq, abajo_der, arriba_der, arriba_izq]` (normal -Y).
    Para `lado == +1` devuelve `[arriba_izq, arriba_der, abajo_der, abajo_izq]` (normal +Y).
    """
    if lado not in (-1, 1):
        raise ValueError("lado debe ser -1 o 1")
    y_min, y_max = plano_exterior_por_lado(vertices, indices_del_cuerpo)
    objetivo = y_min if lado < 0 else y_max
    en_plano = [i for i in set(indices_del_cuerpo) if abs(vertices[i][1] - objetivo) <= tolerancia]
    if len(en_plano) != 4:
        raise ValueError(f"Se esperaban 4 esquinas exteriores en lado {lado}, hay {len(en_plano)}")
    cx = sum(vertices[i][0] for i in en_plano) / 4.0
    cz = sum(vertices[i][2] for i in en_plano) / 4.0
    # Ángulo alrededor del centro en (x, z): abajo_izq (-3pi/4), abajo_der (-pi/4), arriba_der, arriba_izq.
    ordenados = sorted(en_plano, key=lambda i: math.atan2(vertices[i][2] - cz, vertices[i][0] - cx))
    return ordenados if lado < 0 else list(reversed(ordenados))
