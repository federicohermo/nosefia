"""El cierre prensado de un envase flexible: una aleta plana con dientes de sierra.

Es la **única** construcción del cierre. La usan los envases con cierre a los costados (los
paquetes apaisados de galletitas) y los de cierre arriba y abajo (las bolsas), cada uno con su
eje: nadie arma su propio cierre. Es Python puro, sin Blender: lo ejerce la suite del harness, y
el script de cada envase pone los vértices en su malla.

## La aleta

Una aleta se apoya sobre una costura recta y sale hacia afuera, en el plano medio del envase. Cada
lado (el del frente y el del dorso) es una cara aparte, separada del plano medio, para que no se
pisen. La costura es el eje `s`, de 0 a 1; hacia afuera es `t`, de 0 a 1. El borde de afuera es un
diente de sierra: cada diente es un triángulo cuya punta llega a `t = 1`, y entre dos dientes la
aleta llega sólo a `1 - diente`.

El prensado se hace de dos maneras:

- **En la malla**, la cresta de cada diente sale un poco del plano (`relieve`), alternando con el
  valle: la luz marca las arrugas que el cierre tiene en la realidad.
- **En la textura**, que cada envase pinta: cada vértice lleva su `(s, t)` y quien llama lo lleva a
  su UV. La aleta no tiene letras: repite la franja del borde del frente o del dorso.

## Lo que cuesta

Por diente y por lado, cuatro caras: unos seis triángulos. Un cierre de ocho dientes tiene unos
cien triángulos entre sus dos lados.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

Vector = tuple[float, float, float]

#: Cuántos dientes lleva un cierre por defecto.
DIENTES = 8

#: Cuánto del largo de la aleta, hacia afuera, es el diente. El resto es la banda lisa.
DIENTE = 0.35

#: Cuánto sale la cresta de cada diente del plano de la aleta, en metros.
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
    relieve: float = RELIEVE,
    separacion: float = SEPARACION,
) -> Cierre:
    """El cierre apoyado en la costura que va de `origen` a `origen + eje * largo`.

    `eje`, `afuera` y `normal` son unitarios y perpendiculares entre sí. `salida` es lo que sale
    la aleta de la costura, hasta la punta de sus dientes. `normal` es hacia donde mira el lado
    del frente. La costura queda en el plano medio: las dos caras se separan de él `separacion`,
    y la cresta de cada diente sale `relieve` más.
    """
    if dientes < 1:
        raise ValueError("un cierre lleva al menos un diente")
    if not 0.0 < diente < 1.0:
        raise ValueError("el diente es una fracción del largo de la aleta, entre 0 y 1")
    if min(largo, salida) <= 0:
        raise ValueError("el largo y la salida del cierre son positivos")

    t_valle = 1.0 - diente
    # Con la base a la derecha de `afuera` mirando a `normal`, el orden antihorario en (s, t) mira
    # hacia `normal`: si la terna no es directa, se invierte el orden.
    directa = _punto(_cruz(eje, afuera), normal) > 0

    vertices: list[Vector] = []
    caras: list[CaraDeCierre] = []

    def punto(s: float, t: float, lado: int, cresta: bool) -> Vector:
        salto = lado * (separacion + (relieve if cresta else 0.0))
        return _suma(origen, _por(eje, s * largo), _por(afuera, t * salida), _por(normal, salto))

    for lado in (1, -1):
        base: dict[tuple[float, float, bool], int] = {}

        def vertice(s: float, t: float, cresta: bool, lado: int = lado, base=base) -> int:
            clave = (s, t, cresta)
            if clave not in base:
                base[clave] = len(vertices)
                vertices.append(punto(s, t, lado, cresta))
            return base[clave]

        def cara(puntos: list[tuple[float, float, bool]], lado: int = lado) -> None:
            ids = [vertice(s, t, c) for s, t, c in puntos]
            st = [(s, t) for s, t, _ in puntos]
            # Los puntos vienen antihorarios en (s, t). Mirando hacia `normal` eso es el orden
            # directo; el lado del dorso mira al revés.
            invertir = (lado == 1) != directa
            if invertir:
                ids, st = ids[::-1], st[::-1]
            caras.append(CaraDeCierre(tuple(ids), tuple(st), lado))

        for k in range(dientes):
            s0, s1 = k / dientes, (k + 1) / dientes
            medio = (s0 + s1) / 2
            # Dos cuadriláteros de banda: del valle a la cresta y de la cresta al valle.
            cara([(s0, 0.0, False), (medio, 0.0, True), (medio, t_valle, True), (s0, t_valle, False)])
            cara([(medio, 0.0, True), (s1, 0.0, False), (s1, t_valle, False), (medio, t_valle, True)])
            # La punta del diente son dos triángulos que se juntan en su cresta.
            cara([(s0, t_valle, False), (medio, t_valle, True), (medio, 1.0, True)])
            cara([(medio, t_valle, True), (s1, t_valle, False), (medio, 1.0, True)])
    return Cierre(tuple(vertices), tuple(caras))


def vector_unitario(v: Vector) -> Vector:
    n = math.sqrt(_punto(v, v))
    if n == 0:
        raise ValueError("un vector nulo no marca ninguna dirección")
    return _por(v, 1.0 / n)
