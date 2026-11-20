"""Lógica pura para los bloques de esquina de las jambas del depósito."""

from __future__ import annotations

from collections.abc import Callable, Sequence


def frente_sin_junta_interna(
    u_borde: float,
    sentido: int,
    junta: float,
    inicio_frente: float,
    ancho_bloque: float,
    junta_h: float,
) -> Callable[[float], float] | None:
    """Proyección U de un frente de jamba que evita cruzar una junta vertical cerca del borde.

    Cuando la junta anterior de la pared (`junta - ancho_bloque`) cae dentro del frente
    `[inicio_frente, brazo]`, proyectar la pared directa dejaba una tira angosta partida por esa
    junta contra el marco. En ese caso estira el mismo bloque de la pared sobre `[inicio_frente,
    brazo]`, conservando intacto el encuentro con la junta en `brazo`. Si no cae ninguna junta
    interna, devuelve `None` para conservar la proyección exacta de la pared.
    """
    brazo = junta - junta_h / 2.0
    junta_anterior = junta - ancho_bloque
    if junta_anterior <= inicio_frente - junta_h / 2.0:
        return None
    u_junta = u_borde + sentido * junta
    u_inicio = u_junta - sentido * (ancho_bloque - junta_h / 2.0)
    u_fin = u_junta - sentido * (junta_h / 2.0)
    largo = brazo - inicio_frente

    def u_de(s: float) -> float:
        parte = (s - inicio_frente) / largo
        return u_inicio + parte * (u_fin - u_inicio)

    return u_de


def orientar_perfil_ccw(puntos: Sequence[tuple[float, float]]) -> list[tuple[float, float]]:
    """Devuelve el perfil 2D orientado en sentido antihorario (área con signo positiva).

    Un perfil en L con escalón no es convexo: el centroide puede quedar del lado incorrecto de la
    cara del escalón y dar vuelta su normal. Orientar el polígono 2D garantiza normales hacia
    afuera en todas las caras laterales, incluso en perfiles no convexos.
    """
    lista = list(puntos)
    area2 = sum(
        a[0] * b[1] - b[0] * a[1]
        for a, b in zip(lista, lista[1:] + lista[:1])
    )
    return list(reversed(lista)) if area2 < 0.0 else lista


def revestimiento_conectado(
    x: float,
    y_min: float,
    y_hueco_min: float,
    y_hueco_max: float,
    y_max: float,
    z_piso: float,
    z_dintel: float,
    z_techo: float,
) -> tuple[list[tuple[float, float, float]], list[tuple[int, int, int, int]]]:
    """Construye la pared con hueco de puerta como una sola malla plana conexa sin uniones en T.

    Cinco cuadriláteros coplanares con vértices compartidos evitan que el desplegado de UV2 del
    motor parta el dintel en una isla aparte de los costados y marque costuras de luz sobre las
    esquinas del marco. Todas las caras miran hacia `+X`.
    """
    ys = (y_min, y_hueco_min, y_hueco_max, y_max)
    zs = (z_piso, z_dintel, z_techo)
    vertices = [(x, y, z) for z in zs for y in ys]

    def indice(col: int, fila: int) -> int:
        return fila * 4 + col

    rectangulos = (
        (0, 0),  # costado sur bajo
        (0, 1),  # costado sur sobre el dintel
        (1, 1),  # dintel
        (2, 1),  # costado norte sobre el dintel
        (2, 0),  # costado norte bajo
    )
    caras = [
        (
            indice(c, f),
            indice(c + 1, f),
            indice(c + 1, f + 1),
            indice(c, f + 1),
        )
        for c, f in rectangulos
    ]
    return vertices, caras


def techo_lineal(x0: float, z0: float, x1: float, z1: float) -> Callable[[float], float]:
    """Altura del techo inclinado en función de `x`, interpolada entre `(x0, z0)` y `(x1, z1)`."""
    dx = x1 - x0
    dz = z1 - z0

    def altura(x: float) -> float:
        return z0 + dz * (x - x0) / dx

    return altura
