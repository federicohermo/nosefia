"""La profundidad de una exhibición no agrega casilleros ni pierde unidades."""

import unittest

from lib.gondola import separar_reserva


class ReservaDelModelo(unittest.TestCase):
    def test_tres_filas_conservan_todas_las_unidades_y_solo_el_frente_se_repone(self):
        principal, reserva = separar_reserva(["atras"] * 6 + ["adelante"] * 3)
        self.assertEqual(principal, [0, 1, 2, 6, 7, 8])
        self.assertEqual(reserva, [3, 4, 5])
        self.assertEqual(sorted(principal + reserva), list(range(9)))

    def test_una_fila_se_conserva_sin_reserva(self):
        self.assertEqual(separar_reserva(["adelante"] * 3), ([0, 1, 2], []))

    def test_el_frente_queda_al_final_aunque_los_rotulos_vengan_intercalados(self):
        self.assertEqual(separar_reserva(["adelante", "atras", "adelante", "atras"]),
                         ([1, 3, 0, 2], []))

    def test_una_fila_de_respaldo_incompleta_no_publica_una_disposicion_invalida(self):
        with self.assertRaises(ValueError):
            separar_reserva(["atras", "adelante", "adelante"])
