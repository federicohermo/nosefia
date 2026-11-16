"""El agujero para colgar en el cierre de una bolsa: una ventana en la aleta.

Se aplica sobre un `Cierre` de `lib/cierre_de_envases.py` y no lo reemplaza: la aleta sigue
siendo la de todos los envases. Es Python puro, sin Blender.

## Qué hace

Corta una ventana en el medio de la aleta, entre `T_BAJO` y `T_ALTO`: la cara de cada lado, que
corre de punta a punta de la costura, se parte en tres franjas. La de abajo y la de arriba quedan
enteras, y la del medio deja sólo sus dos costados. Cuatro caras angostas unen el lado del frente
con el del dorso por dentro de la ventana: desde afuera no se ve el hueco entre las dos hojas.

## Lo que cuesta

Doce triángulos más que la aleta sin agujero, y ocho más las cuatro paredes.
"""

from __future__ import annotations

from collections.abc import Callable, Sequence

from lib.cierre_de_envases import CaraDeCierre, Cierre, Vector

#: Dónde del largo de la costura va el centro del agujero y cuánto ocupa, en fracción de ella.
CENTRO = 0.5
ANCHO = 0.08

#: Entre qué alturas de la aleta, de la costura (0) al borde de afuera (1), va la ventana.
T_BAJO, T_ALTO = 0.25, 0.75


def _area(st: Sequence[tuple[float, float]]) -> float:
    return sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(st, list(st[1:]) + list(st[:1]))) / 2


def _normal(p: Sequence[Vector]) -> Vector:
    a = [p[1][j] - p[0][j] for j in range(3)]
    b = [p[2][j] - p[0][j] for j in range(3)]
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def abrir_agujero(
    c: Cierre,
    punto: Callable[[float, float, int], Vector],
    centro: float = CENTRO,
    ancho: float = ANCHO,
    t_bajo: float = T_BAJO,
    t_alto: float = T_ALTO,
) -> Cierre:
    """El cierre con una ventana de `ancho` en `centro` de la costura, entre `t_bajo` y `t_alto`.

    `punto` da la posición de un `(s, t)` de un lado (`1` o `-1`), con la misma regla con que se
    armó `c`: sirve para los vértices nuevos de la ventana. La ventana se corta de las caras que
    van de punta a punta de la costura.
    """
    if not 0.0 < t_bajo < t_alto < 1.0:
        raise ValueError("la ventana va entre la costura y el borde de afuera del cierre")
    if not 0.0 < centro - ancho / 2 < centro + ancho / 2 < 1.0:
        raise ValueError("el agujero cabe entre un extremo de la costura y el otro")
    s0, s1 = centro - ancho / 2, centro + ancho / 2
    vertices = list(c.vertices)
    indices: dict[tuple[float, float, int], int] = {}
    for cara in c.caras:
        for i, (s, t) in zip(cara.vertices, cara.st):
            indices[(s, t, cara.lado)] = i

    def vertice(s: float, t: float, lado: int) -> int:
        if (s, t, lado) not in indices:
            indices[(s, t, lado)] = len(vertices)
            vertices.append(punto(s, t, lado))
        return indices[(s, t, lado)]

    def cara_de(st: list[tuple[float, float]], lado: int, antihoraria: bool) -> CaraDeCierre:
        if not antihoraria:
            st = st[::-1]
        return CaraDeCierre(tuple(vertice(s, t, lado) for s, t in st), tuple(st), lado)

    caras: list[CaraDeCierre] = []
    for cara in c.caras:
        ss = [s for s, _ in cara.st]
        t0, t1 = min(t for _, t in cara.st), max(t for _, t in cara.st)
        if min(ss) != 0.0 or max(ss) != 1.0 or t1 <= t_bajo or t0 >= t_alto:
            caras.append(cara)
            continue
        # Una cara de punta a punta se parte en franjas: lo de abajo y lo de arriba de la ventana
        # queda entero, y la franja de la ventana deja sólo sus dos costados.
        antihoraria = _area(cara.st) > 0
        cortes = sorted({t0, t1} | {t for t in (t_bajo, t_alto) if t0 < t < t1})
        for desde, hasta in zip(cortes, cortes[1:]):
            if t_bajo - 1e-9 <= desde and hasta <= t_alto + 1e-9:
                trozos = ((0.0, s0), (s1, 1.0))
            else:
                trozos = ((0.0, 1.0),)
            for a, b in trozos:
                st = [(a, desde), (b, desde), (b, hasta), (a, hasta)]
                caras.append(cara_de(st, cara.lado, antihoraria))

    # Las paredes: unen el lado del frente con el del dorso por el borde de la ventana. Miran hacia
    # el centro del agujero.
    medio = tuple(
        sum(punto(centro, (t_bajo + t_alto) / 2, lado)[j] for lado in (1, -1)) / 2
        for j in range(3)
    )
    for (sa, ta), (sb, tb) in (
        ((s0, t_bajo), (s1, t_bajo)),
        ((s1, t_bajo), (s1, t_alto)),
        ((s1, t_alto), (s0, t_alto)),
        ((s0, t_alto), (s0, t_bajo)),
    ):
        st = [(sa, ta), (sb, tb), (sb, tb), (sa, ta)]
        lados = [1, 1, -1, -1]
        ids = [vertice(s, t, lado) for (s, t), lado in zip(st, lados)]
        puntos = [vertices[i] for i in ids]
        normal = _normal(puntos)
        centro_de_la_pared = [sum(p[j] for p in puntos) / 4 for j in range(3)]
        hacia_adentro = sum(normal[j] * (medio[j] - centro_de_la_pared[j]) for j in range(3))
        if hacia_adentro < 0:
            ids, st = ids[::-1], st[::-1]
        caras.append(CaraDeCierre(tuple(ids), tuple(st), 1))
    return Cierre(tuple(vertices), tuple(caras))
