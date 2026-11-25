import unittest

from lib.exhibidor_de_golosinas import (
    espesor_de_panel,
    x_exterior_objetivo,
)


class ExhibidorDeGolosinas(unittest.TestCase):
    def test_mide_espesor_positivo_en_panel_sano_y_cero_en_colapsado(self):
        self.assertAlmostEqual(espesor_de_panel(-1.094, -1.074), 0.020)
        self.assertAlmostEqual(espesor_de_panel(0.432, 0.432), 0.0)

    def test_restaura_espesor_del_panel_izquierdo_espejando_el_derecho(self):
        objetivo = x_exterior_objetivo(
            x_exterior_actual=0.432,
            x_interior=0.432,
            espesor_referencia=0.020,
            signo_exterior=1,
        )
        self.assertAlmostEqual(objetivo, 0.452)

    def test_es_idempotente_cuando_el_panel_ya_tiene_el_espesor_esperado(self):
        objetivo = x_exterior_objetivo(
            x_exterior_actual=0.452,
            x_interior=0.432,
            espesor_referencia=0.020,
            signo_exterior=1,
        )
        self.assertAlmostEqual(objetivo, 0.452)

    def test_falla_si_el_espesor_de_referencia_no_es_positivo(self):
        with self.assertRaises(ValueError):
            x_exterior_objetivo(0.432, 0.432, 0.0, 1)


if __name__ == "__main__":
    unittest.main()
