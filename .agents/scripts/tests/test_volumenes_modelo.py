import unittest

from lib.volumenes_modelo import MESAS_Y_SILLAS, centro_entre_la_isla_y_las_mesas, pieza_mayor


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


def _modelo(este_de_las_mesas: float, oeste_de_la_isla: float) -> dict:
    modelo = {
        nombre: {"global_aabb": f"AABB(0.0, 0.1, 0.0, {este_de_las_mesas}, 0.9, 0.8)"}
        for nombre in MESAS_Y_SILLAS
    }
    modelo["salon_silla_2a"] = {
        "global_aabb": f"AABB({este_de_las_mesas}, 0.1, 0.0, 0.6, 0.9, 0.6)"
    }
    modelo["gondolanueva2"] = {
        "global_aabb": "AABB(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)",
        "global_piezas": [oeste_de_la_isla, 0.1, 0.0, 1.0, 1.9, 4.0],
    }
    return modelo


class ManchaEntreLaIslaYLasMesas(unittest.TestCase):
    def test_queda_en_el_medio_entre_lo_mas_al_este_de_las_mesas_y_la_isla(self):
        modelo = _modelo(este_de_las_mesas=0.3, oeste_de_la_isla=4.0)
        self.assertAlmostEqual(centro_entre_la_isla_y_las_mesas(modelo), (0.3 + 0.6 + 4.0) / 2)

    def test_si_la_isla_se_corre_la_mancha_la_sigue(self):
        cerca = centro_entre_la_isla_y_las_mesas(_modelo(0.3, 4.0))
        lejos = centro_entre_la_isla_y_las_mesas(_modelo(0.3, 5.0))
        self.assertAlmostEqual(lejos - cerca, 0.5)


if __name__ == "__main__":
    unittest.main()
