import unittest

from lib.estanteria_pareja import alturas_con_huecos_iguales

PISO, TECHO, GROSOR = 0.352, 2.553, 0.04


class HuecosIguales(unittest.TestCase):
    def _huecos(self, alturas: list[float]) -> list[float]:
        """Lo que queda libre encima de cada estante: hasta la chapa de arriba o hasta el techo."""
        debajo_de_cada_chapa = [a - GROSOR for a in alturas[1:]] + [TECHO]
        return [techo - a for a, techo in zip(alturas, debajo_de_cada_chapa)]

    def test_el_primero_esta_en_el_piso(self):
        self.assertAlmostEqual(alturas_con_huecos_iguales(PISO, TECHO, GROSOR, 5)[0], PISO)

    def test_los_cinco_huecos_miden_lo_mismo(self):
        huecos = self._huecos(alturas_con_huecos_iguales(PISO, TECHO, GROSOR, 5))
        self.assertEqual(len(huecos), 5)
        self.assertAlmostEqual(max(huecos), min(huecos))

    def test_el_ultimo_hueco_llega_justo_al_techo(self):
        alturas = alturas_con_huecos_iguales(PISO, TECHO, GROSOR, 5)
        hueco = self._huecos(alturas)[-1]
        self.assertAlmostEqual(alturas[-1] + hueco, TECHO)

    def test_las_chapas_estan_cada_vez_mas_arriba(self):
        alturas = alturas_con_huecos_iguales(PISO, TECHO, GROSOR, 5)
        self.assertEqual(alturas, sorted(alturas))

    def test_sin_alto_para_las_chapas_es_un_error(self):
        with self.assertRaises(ValueError):
            alturas_con_huecos_iguales(1.0, 1.1, 0.04, 5)

    def test_un_solo_estante_no_alcanza(self):
        with self.assertRaises(ValueError):
            alturas_con_huecos_iguales(PISO, TECHO, GROSOR, 1)


if __name__ == "__main__":
    unittest.main()
