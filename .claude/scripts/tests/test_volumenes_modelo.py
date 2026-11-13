import unittest

from lib.volumenes_modelo import pieza_mayor


class PiezaMayor(unittest.TestCase):
    def test_elige_la_pieza_mas_larga_de_un_mueble_de_varias(self):
        fila = {
            "global_piezas": [
                4.6, 0.1, -7.8, 1.0, 1.9, 0.4,
                7.4, 0.1, -5.0, 0.5, 1.9, 2.3,
                7.4, 0.1, -2.7, 0.5, 1.9, 2.3,
            ]
        }
        self.assertEqual(pieza_mayor(fila), [7.4, 0.1, -5.0, 0.5, 1.9, 2.3])

    def test_un_mueble_de_una_sola_pieza_es_su_propia_caja(self):
        fila = {"global_piezas": [4.0, 0.1, -4.4, 1.0, 1.9, 4.0]}
        self.assertEqual(pieza_mayor(fila), [4.0, 0.1, -4.4, 1.0, 1.9, 4.0])


if __name__ == "__main__":
    unittest.main()
