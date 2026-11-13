"""Los tests de `lib/gondola_a_la_pared.py`: las cuentas que acortan una pieza y las alinean."""

import unittest

from lib.gondola_a_la_pared import Recorrido, agrupar, repartir_en_la_pared

#: Los grupos de vértices de una cara larga de la góndola, de punta a punta.
GRUPOS = [(0.95, 1.01), (1.62, 1.88), (3.10, 3.25), (3.92, 3.98)]


class Agrupar(unittest.TestCase):
    def test_une_lo_cercano_y_separa_lo_lejano(self):
        valores = [0.95, 1.01, 1.62, 1.67, 1.83, 1.88, 3.10, 3.25, 3.92, 3.98]
        self.assertEqual(agrupar(valores), GRUPOS)

    def test_sin_valores_no_hay_grupos(self):
        self.assertEqual(agrupar([]), [])


class AcortarUnaPieza(unittest.TestCase):
    def test_la_pieza_queda_del_largo_pedido(self):
        recorrido = Recorrido(GRUPOS, 0.75)
        self.assertAlmostEqual(recorrido(3.98) - recorrido(0.95), 3.03 - 0.75)

    def test_cada_grupo_viaja_sin_deformarse(self):
        recorrido = Recorrido(GRUPOS, 0.75)
        for desde, hasta in GRUPOS:
            self.assertAlmostEqual(recorrido(hasta) - recorrido(desde), hasta - desde)

    def test_pierde_lo_mismo_en_las_dos_puntas(self):
        recorrido = Recorrido(GRUPOS, 0.75)
        self.assertAlmostEqual(recorrido(0.95) - 0.95, 0.375)
        self.assertAlmostEqual(3.98 - recorrido(3.98), 0.375)

    def test_lo_que_hay_entre_grupos_se_encoge_en_la_misma_proporcion(self):
        recorrido = Recorrido(GRUPOS, 0.75)
        huecos = [(1.62 - 1.01), (3.10 - 1.88), (3.92 - 3.25)]
        nuevos = [
            recorrido(1.62) - recorrido(1.01),
            recorrido(3.10) - recorrido(1.88),
            recorrido(3.92) - recorrido(3.25),
        ]
        proporciones = [n / h for n, h in zip(nuevos, huecos)]
        self.assertAlmostEqual(max(proporciones), min(proporciones))
        self.assertLess(max(proporciones), 1.0)

    def test_conserva_el_orden_de_todos_los_puntos(self):
        recorrido = Recorrido(GRUPOS, 0.75)
        puntos = [0.9 + i * 0.01 for i in range(120)]
        nuevos = [recorrido(p) for p in puntos]
        self.assertEqual(nuevos, sorted(nuevos))

    def test_no_acorta_mas_de_lo_que_hay_entre_los_grupos(self):
        with self.assertRaises(ValueError):
            Recorrido(GRUPOS, 3.0)

    def test_acortar_cero_no_mueve_nada(self):
        recorrido = Recorrido(GRUPOS, 0.0)
        for punto in (0.95, 1.3, 2.5, 3.98):
            self.assertAlmostEqual(recorrido(punto), punto)


class PonerEnFila(unittest.TestCase):
    def test_las_puntas_tocan_los_bordes_y_los_huecos_son_iguales(self):
        largos = [1.0, 2.28, 2.28, 0.98]
        desdes = repartir_en_la_pared(largos, -0.6, 6.9)
        self.assertAlmostEqual(desdes[0], -0.6)
        self.assertAlmostEqual(desdes[-1] + largos[-1], 6.9)
        huecos = [b - (a + largo) for a, b, largo in zip(desdes, desdes[1:], largos)]
        self.assertAlmostEqual(max(huecos), min(huecos))
        self.assertGreater(min(huecos), 0.0)

    def test_piezas_que_no_entran_dan_error(self):
        with self.assertRaises(ValueError):
            repartir_en_la_pared([4.0, 4.0], 0.0, 7.0)
