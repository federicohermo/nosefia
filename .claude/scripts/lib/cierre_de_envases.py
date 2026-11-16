"""El cierre prensado de un envase flexible: una aleta plana de borde recto.

Es la **única** construcción del cierre. La usan los envases con cierre a los costados (los
paquetes apaisados de galletitas) y los de cierre arriba y abajo (las bolsas), cada uno con su
eje: nadie arma su propio cierre. Es Python puro, sin Blender: lo ejerce la suite del harness, y
el script de cada envase pone los vértices en su malla.

## La aleta

Una aleta se apoya sobre una costura recta y sale hacia afuera, en el plano medio del envase. Cada
lado (el del frente y el del dorso) es una cara aparte, separada del plano medio, para que no se
pisen. La costura es el eje `s`, de 0 a 1; hacia afuera es `t`, de 0 a 1. **El borde de afuera
es recto**, como el de Chisitos y el de Lay'snt't: la aleta es un rectángulo de lado a lado de la
costura. Con `diente` mayor que cero el borde sería un diente de sierra, cada diente un triángulo
que llega a `t = 1`: ningún envase lo usa, y el parámetro queda para quien lo pida.

El prensado se hace de dos maneras:

- **En la malla**, la banda tiene surcos paralelos a la costura: filas de vértices que salen del
  plano `relieve`, una sí y una no. La luz marca los surcos que el cierre tiene en la realidad.
  Con `surcos=0` la aleta es una sola cara plana por lado, y la textura lleva todo el prensado: es
  el cierre de las bolsas de papas.
- **En la textura**, que cada envase pinta: cada vértice lleva su `(s, t)` y quien llama lo lleva a
  su UV. La aleta no tiene letras: repite la franja del borde del frente o del dorso.

## Lo que cuesta

Con dos surcos, cuatro filas de una cara: ocho triángulos por lado y dieciséis entre los dos lados
de un cierre. Sin surcos, dos triángulos por lado.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

Vector = tuple[float, float, float]

#: Cuántos dientes lleva el borde si lo lleva. Sin efecto con `DIENTE` en cero.
DIENTES = 8

#: Cuánto del largo de la aleta, hacia afuera, es el diente. El resto es la banda lisa. Con cero el
#: borde es recto.
DIENTE = 0.0

#: Cuántos surcos paralelos a la costura lleva la banda lisa de la aleta.
SURCOS = 2

#: Cuánto sale cada surco del plano de la aleta, en metros.
RELIEVE = 0.0015

#: Cuánto se separa cada lado del plano medio, en metros.
SEPARACION = 0.002


@dataclass(frozen=True)
class CaraDeCierre:
    """Una cara del cierre: los índices de sus vértices, el `(s, t)` de cada uno y su lado.

    `lado` es `1` para el que mira hacia `normal` (el frente) y `-1` para el opuesto (el dorso).
    Los vértices van en el orden que da la normal hacia afuera de su lado.
    """

    vertices: tuple[int, ...]
    st: tuple[tuple[float, float], ...]
    lado: int


@dataclass(frozen=True)
class Cierre:
    """Los vértices del cierre y sus caras, de los dos lados."""

    vertices: tuple[Vector, ...]
    caras: tuple[CaraDeCierre, ...]

    def triangulos(self) -> int:
        return sum(len(c.vertices) - 2 for c in self.caras)


def _suma(*terminos: Vector) -> Vector:
    return (
        sum(t[0] for t in terminos),
        sum(t[1] for t in terminos),
        sum(t[2] for t in terminos),
    )


def _por(v: Vector, k: float) -> Vector:
    return (v[0] * k, v[1] * k, v[2] * k)


def _cruz(a: Vector, b: Vector) -> Vector:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def _punto(a: Vector, b: Vector) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cierre(
    origen: Vector,
    eje: Vector,
    largo: float,
    afuera: Vector,
    salida: float,
    normal: Vector,
    dientes: int = DIENTES,
    diente: float = DIENTE,
    surcos: int = SURCOS,
    relieve: float = RELIEVE,
    separacion: float = SEPARACION,
) -> Cierre:
    """El cierre apoyado en la costura que va de `origen` a `origen + eje * largo`.

    `eje`, `afuera` y `normal` son unitarios y perpendiculares entre sí. `salida` es lo que sale
    la aleta de la costura, hasta su borde de afuera. `normal` es hacia donde mira el lado
    del frente. La costura queda en el plano medio: las dos caras se separan de él `separacion`,
    y los surcos salen `relieve` más.
    """
    if dientes < 1 or surcos < 0:
        raise ValueError("un cierre lleva al menos un diente, y cero o más surcos")
    if not 0.0 <= diente < 1.0:
        raise ValueError("el diente es una fracción de la aleta: de 0 a 1, sin llegar a 1")
    if min(largo, salida) <= 0:
        raise ValueError("el largo y la salida del cierre son positivos")

    t_valle = 1.0 - diente
    filas = 2 * surcos or 1
    relieve = relieve if surcos else 0.0
    alturas = [t_valle * i / filas for i in range(filas + 1)]
    # Con la terna directa, el orden antihorario en (s, t) mira hacia `normal`.
    directa = _punto(_cruz(eje, afuera), normal) > 0

    vertices: list[Vector] = []
    caras: list[CaraDeCierre] = []

    for lado in (1, -1):
        ids: dict[tuple[float, float], int] = {}

        def vertice(s: float, t: float, lado: int = lado, ids=ids) -> int:
            if (s, t) not in ids:
                ids[(s, t)] = len(vertices)
                # Los surcos son las filas impares de la banda.
                fila = alturas.index(t) if t in alturas else 0
                salto = lado * (separacion + (relieve if fila % 2 else 0.0))
                a_lo_largo, hacia_afuera = _por(eje, s * largo), _por(afuera, t * salida)
                vertices.append(_suma(origen, a_lo_largo, hacia_afuera, _por(normal, salto)))
            return ids[(s, t)]

        def cara(puntos: list[tuple[float, float]], lado: int = lado) -> None:
            indices = [vertice(s, t) for s, t in puntos]
            st = list(puntos)
            if (lado == 1) != directa:
                indices, st = indices[::-1], st[::-1]
            caras.append(CaraDeCierre(tuple(indices), tuple(st), lado))

        # La banda lisa: una fila de surcos tras otra, enteras a lo largo de la costura. Con
        # dientes, la última se parte por dientes, para que cada punta tenga sus vértices.
        enteras = zip(alturas[:-1], alturas[1:]) if not diente else zip(alturas[:-2], alturas[1:-1])
        for t0, t1 in enteras:
            cara([(0.0, t0), (1.0, t0), (1.0, t1), (0.0, t1)])
        if not diente:
            continue
        t0, t1 = alturas[-2], alturas[-1]
        for k in range(dientes):
            s0, s1 = k / dientes, (k + 1) / dientes
            cara([(s0, t0), (s1, t0), (s1, t1), (s0, t1)])
            cara([(s0, t1), (s1, t1), ((s0 + s1) / 2, 1.0)])
    return Cierre(tuple(vertices), tuple(caras))


def vector_unitario(v: Vector) -> Vector:
    n = math.sqrt(_punto(v, v))
    if n == 0:
        raise ValueError("un vector nulo no marca ninguna dirección")
    return _por(v, 1.0 / n)
