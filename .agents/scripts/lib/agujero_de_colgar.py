"""El agujero para colgar en el cierre de una bolsa: una ventana en la banda lisa de la aleta.

Se aplica sobre un `Cierre` de `lib/cierre_de_envases.py` y no lo reemplaza: la aleta, sus dientes
y sus surcos siguen siendo los de todos los envases. Es Python puro, sin Blender.

## Qué hace

Corta una ventana en el medio de la banda, entre la primera y la última fila de surcos: las caras
de esas filas, que corren de punta a punta de la costura, se parten a los costados de la ventana.
Los bordes de la ventana quedan sobre las filas de arriba y de abajo, que ya la cubren. Cuatro
caras angostas unen el lado del frente con el del dorso por dentro de la ventana: desde afuera no
se ve el hueco entre las dos hojas.

## Lo que cuesta

Ocho caras más por cada fila que atraviesa la ventana, y las cuatro paredes: unos veinte
triángulos.
"""

from __future__ import annotations

from collections.abc import Callable, Sequence

from lib.cierre_de_envases import CaraDeCierre, Cierre, Vector

#: Dónde del largo de la costura va el centro del agujero y cuánto ocupa, en fracción de ella.
CENTRO = 0.5
ANCHO = 0.08


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
    alturas: Sequence[float],
    punto: Callable[[float, float, int], Vector],
    centro: float = CENTRO,
    ancho: float = ANCHO,
) -> Cierre:
    """El cierre con una ventana entre `alturas[1]` y `alturas[-2]`, en `centro` de la costura.

    `alturas` son los `t` de las filas de la banda lisa, de la costura hacia afuera. `punto` da
    la posición de un `(s, t)` de un lado (`1` o `-1`), con la misma regla con que se armó `c`.
    """
    if len(alturas) < 4:
        raise ValueError("el agujero necesita dos filas de banda entre la costura y los dientes")
    if not 0.0 < ancho < 1.0 or not 0.0 < centro - ancho / 2 < centro + ancho / 2 < 1.0:
        raise ValueError("el agujero cabe entre la costura y su otro extremo")
    s0, s1 = centro - ancho / 2, centro + ancho / 2
    t_bajo, t_alto = alturas[1], alturas[-2]
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

    def atraviesa(cara: CaraDeCierre) -> bool:
        ss = [s for s, _ in cara.st]
        ts = [t for _, t in cara.st]
        dentro = t_bajo - 1e-9 <= min(ts) and max(ts) <= t_alto + 1e-9
        return min(ss) == 0.0 and max(ss) == 1.0 and dentro

    caras: list[CaraDeCierre] = []
    for cara in c.caras:
        if not atraviesa(cara):
            caras.append(cara)
            continue
        t0, t1 = min(t for _, t in cara.st), max(t for _, t in cara.st)
        antihoraria = _area(cara.st) > 0
        for desde, hasta in ((0.0, s0), (s1, 1.0)):
            st = [(desde, t0), (hasta, t0), (hasta, t1), (desde, t1)]
            if not antihoraria:
                st = st[::-1]
            caras.append(
                CaraDeCierre(tuple(vertice(s, t, cara.lado) for s, t in st), tuple(st), cara.lado)
            )

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
