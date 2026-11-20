"""La hoja del baño queda con dos caras planas de un solo cuadrilátero, conservando la rejilla."""

import math
import unittest

from lib.hoja_del_bano import (
    desviacion_maxima_de_caras_grandes,
    esquinas_exteriores,
    plano_exterior_por_lado,
    proyectar_uv_afin,
)


def _hoja_con_panel_hundido(
    ancho: float = 1.2,
    alto: float = 2.0,
    espesor: float = 0.08,
    hundimiento: float = 0.01,
) -> tuple[list[tuple[float, float, float]], list[tuple[int, int, int, int]], set[int]]:
    ext = espesor / 2.0
    intr = ext - hundimiento
    mx = ancho * 0.1
    mz = alto * 0.1
    vertices = [
        (0.0, -ext, 0.0),
        (ancho, -ext, 0.0),
        (ancho, -ext, alto),
        (0.0, -ext, alto),
        (0.0, ext, 0.0),
        (ancho, ext, 0.0),
        (ancho, ext, alto),
        (0.0, ext, alto),
        (mx, -intr, mz),
        (ancho - mx, -intr, mz),
        (ancho - mx, -intr, alto - mz),
        (mx, -intr, alto - mz),
        (mx, intr, mz),
        (ancho - mx, intr, mz),
        (ancho - mx, intr, alto - mz),
        (mx, intr, alto - mz),
    ]
    caras: list[tuple[int, int, int, int]] = []
    for i in range(4):
        j = (i + 1) % 4
        caras.extend([(i, j, 8 + j, 8 + i), (4 + j, 4 + i, 12 + i, 12 + j), (j, i, 4 + i, 4 + j)])
    caras.extend([(8, 9, 10, 11), (15, 14, 13, 12)])
    return vertices, caras, set(range(len(vertices)))


class TestHojaDelBano(unittest.TestCase):
    def test_las_esquinas_exteriores_arman_dos_caras_planas_sin_inclinacion(self) -> None:
        vertices, caras, cuerpo = _hoja_con_panel_hundido()
        self.assertGreater(desviacion_maxima_de_caras_grandes(vertices, caras), 1.0)

        frente = esquinas_exteriores(vertices, cuerpo, -1)
        dorso = esquinas_exteriores(vertices, cuerpo, 1)

        self.assertEqual(frente, [0, 1, 2, 3])
        self.assertEqual(dorso, [7, 6, 5, 4])
        self.assertLess(desviacion_maxima_de_caras_grandes(vertices, [frente, dorso]), 1e-6)

    def test_proyeccion_uv_conserva_coordenadas_del_panel_al_extender_al_borde(self) -> None:
        referencias = [
            ((0.12, 0.20), (0.0, 0.0)),
            ((1.08, 0.20), (1.0, 0.0)),
            ((1.08, 1.80), (1.0, 1.0)),
            ((0.12, 1.80), (0.0, 1.0)),
        ]
        # En el centro de una ranura dentro del panel, la UV extrapolada coincide con la original.
        uv_centro = proyectar_uv_afin(referencias, (0.60, 0.36))
        self.assertAlmostEqual(uv_centro[0], 0.5, places=6)
        self.assertAlmostEqual(uv_centro[1], 0.1, places=6)
        # En las esquinas exteriores de la hoja, la UV sale fuera de [0, 1] de forma lineal.
        u0, v0 = proyectar_uv_afin(referencias, (0.0, 0.0))
        u1, v1 = proyectar_uv_afin(referencias, (1.2, 2.0))
        self.assertLess(u0, 0.0)
        self.assertLess(v0, 0.0)
        self.assertGreater(u1, 1.0)
        self.assertGreater(v1, 1.0)

    def test_rechaza_cuerpo_sin_espesor(self) -> None:
        planos = [(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (1.0, 0.0, 2.0), (0.0, 0.0, 2.0)]
        with self.assertRaises(ValueError):
            plano_exterior_por_lado(planos, {0, 1, 2, 3})

    def test_desviacion_mide_el_angulo_de_inclinacion_de_un_trapecio(self) -> None:
        vertices, caras, _ = _hoja_con_panel_hundido(
            ancho=1.0, alto=2.0, espesor=0.08, hundimiento=0.01
        )
        esperado = math.degrees(math.atan2(0.01, 0.1))
        self.assertAlmostEqual(
            desviacion_maxima_de_caras_grandes(vertices, caras), esperado, places=2
        )


if __name__ == "__main__":
    unittest.main()
