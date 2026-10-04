"""Las juntas conservan su fase después de la inversión V obligatoria de glTF."""

import unittest

from lib.piso_del_bano import coordenada_del_piso, coordenada_del_zocalo


class JuntasDelPisoTest(unittest.TestCase):
    def test_piso_y_pared_este_coinciden_despues_de_exportar(self):
        piso = coordenada_del_piso((13.43466, 7.2, .10223747))
        zocalo = coordenada_del_zocalo(
            (13.41866, 7.2, .21223747), (-1, 0, 0), .10223747
        )
        self.assertAlmostEqual((1 - piso[1]) * 5, -13)
        self.assertAlmostEqual(zocalo[0] * 5, 18)
        # Escalar después de exportar causaba el desfase de media cerámica.
        uv_vieja_en_motor = (1 - 7.2 / .6) * .3
        self.assertAlmostEqual(uv_vieja_en_motor * 5, -16.5)

    def test_piso_y_retorno_de_la_jamba_comparten_coordenada_x(self):
        piso = coordenada_del_piso((8.0, 5.97848, .10223747))
        zocalo = coordenada_del_zocalo((8.0, 5.99448, .15), (0, 1, 0), .10223747)
        self.assertEqual(piso[0], zocalo[0])
        self.assertAlmostEqual(piso[0] * 5, 20)

    def test_el_canto_horizontal_del_zocalo_usa_la_cuadricula_del_piso(self):
        punto = (8.30786, 5.99448, .21223747)
        self.assertEqual(
            coordenada_del_piso(punto),
            coordenada_del_zocalo(punto, (0, 0, 1), .10223747),
        )

    def test_cada_ceramica_mide_cuarenta_centimetros(self):
        antes = coordenada_del_piso((11.2, 3.6, .10223747))
        despues = coordenada_del_piso((11.6, 4.0, .10223747))
        self.assertAlmostEqual(despues[0] - antes[0], .2)
        self.assertAlmostEqual(despues[1] - antes[1], .2)


if __name__ == "__main__":
    unittest.main()
