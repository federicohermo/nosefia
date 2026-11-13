"""Las cuentas de `blender/gondola_a_la_pared.py`: acortar una pieza y ponerlas en la pared.

Nada de acá toca Blender: son números de una dimensión, y por eso se prueban sin abrirlo.
"""

from __future__ import annotations

from collections.abc import Sequence

#: Dos vértices a menos de esto, a lo largo de una cara, son del mismo grupo.
SEPARACION_ENTRE_GRUPOS = 0.4


def agrupar(
    valores: Sequence[float], separacion: float = SEPARACION_ENTRE_GRUPOS
) -> list[tuple[float, float]]:
    """Los grupos de valores cercanos, de menor a mayor, cada uno como `(desde, hasta)`."""
    grupos: list[list[float]] = []
    for valor in sorted(valores):
        if grupos and valor - grupos[-1][1] < separacion:
            grupos[-1][1] = valor
        else:
            grupos.append([valor, valor])
    return [(desde, hasta) for desde, hasta in grupos]


class Recorrido:
    """Una función de la posición vieja a la nueva a lo largo de una pieza que se acorta.

    Cada grupo viaja entero, sin deformarse, y lo que hay entre dos grupos se encoge en la misma
    proporción. La pieza queda centrada donde estaba y pierde lo mismo en las dos puntas, salvo
    con `centrada=False`: entonces conserva su primera punta y pierde todo en la última.
    """

    def __init__(
        self, grupos: Sequence[tuple[float, float]], acortar: float, centrada: bool = True
    ) -> None:
        huecos = [b[0] - a[1] for a, b in zip(grupos, grupos[1:])]
        if not huecos or sum(huecos) <= acortar:
            raise ValueError("lo que hay entre los grupos no alcanza para acortar tanto")
        factor = (sum(huecos) - acortar) / sum(huecos)
        self._viejos = list(grupos)
        self._nuevos: list[tuple[float, float]] = []
        desde = grupos[0][0] + (acortar / 2 if centrada else 0.0)
        for i, (a, b) in enumerate(grupos):
            self._nuevos.append((desde, desde + (b - a)))
            if i < len(huecos):
                desde += (b - a) + huecos[i] * factor

    def __call__(self, valor: float) -> float:
        viejos, nuevos = self._viejos, self._nuevos
        if valor <= viejos[0][0]:
            return valor + nuevos[0][0] - viejos[0][0]
        if valor >= viejos[-1][1]:
            return valor + nuevos[-1][1] - viejos[-1][1]
        for (a, b), (na, nb), (c, _), (nc, _) in zip(viejos, nuevos, viejos[1:], nuevos[1:]):
            if a <= valor <= b:
                return valor + na - a
            if b < valor < c:
                return nb + (valor - b) * (nc - nb) / (c - b)
        return valor + nuevos[-1][0] - viejos[-1][0]


def repartir_en_la_pared(largos: Sequence[float], desde: float, hasta: float) -> list[float]:
    """Dónde empieza cada pieza, en orden, con el mismo hueco entre dos vecinas y las puntas
    justo en `desde` y en `hasta`."""
    sobra = (hasta - desde) - sum(largos)
    if sobra < 0 or len(largos) < 2:
        raise ValueError("las piezas no entran en la pared")
    hueco = sobra / (len(largos) - 1)
    salida = []
    posicion = desde
    for largo in largos:
        salida.append(posicion)
        posicion += largo + hueco
    return salida
