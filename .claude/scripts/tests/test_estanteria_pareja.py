import unittest

from lib.estanteria_pareja import alturas_parejas


class AlturasParejas(unittest.TestCase):
    def test_el_primero_esta_en_el_piso_y_el_ultimo_en_el_tope(self):
        alturas = alturas_parejas(0.352, 2.017, 5)
        self.assertEqual(len(alturas), 5)
        self.assertAlmostEqual(alturas[0], 0.352)
        self.assertAlmostEqual(alturas[-1], 2.017)

    def test_todas_las_separaciones_son_iguales(self):
        alturas = alturas_parejas(0.352, 2.017, 5)
        separaciones = [b - a for a, b in zip(alturas, alturas[1:])]
        self.assertAlmostEqual(max(separaciones), min(separaciones))

    def test_un_tope_que_no_esta_arriba_del_piso_es_un_error(self):
        for tope in (1.0, 0.5):
            with self.subTest(tope=tope), self.assertRaises(ValueError):
                alturas_parejas(1.0, tope, 5)

    def test_un_solo_estante_no_tiene_separacion(self):
        with self.assertRaises(ValueError):
            alturas_parejas(0.3, 2.0, 1)


if __name__ == "__main__":
    unittest.main()
