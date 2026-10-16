"""Conducta de Tanda existente contra la confirmación final; no importa API nueva."""
import unittest

from lib.reparto import ESTANTES, Tanda


class DecisionDeFilas(unittest.TestCase):
    def test_actroncito_y_prongles_conservan_dos_filas_en_todas_sus_tandas(self):  # AC-STK-030
        for producto in ("ACTRONCITO", "PRONGLES"):
            for fija in (False, True):
                with self.subTest(producto=producto, fija=fija):
                    self.assertEqual(Tanda(producto, fija=fija).cantidad_de_filas, 2)

    def test_los_cinco_del_arte_tienen_una_fila_principal_y_fija(self):  # AC-STK-030
        for producto in ("COSA_DE_MANI", "FLINPUF", "BURBALOO", "MARRANOS", "POETICO"):
            for fija in (False, True):
                with self.subTest(producto=producto, fija=fija):
                    self.assertEqual(Tanda(producto, fija=fija).cantidad_de_filas, 1)

    def test_amargadito_solo_reduce_la_principal_y_conserva_su_fija_doble(self):  # AC-STK-030
        principal, = ESTANTES["A.sur.1"]
        fija, = ESTANTES["A.sur.0"]
        self.assertEqual(principal.cantidad_de_filas, 1)
        self.assertEqual(fija.cantidad_de_filas, 2)
        self.assertEqual(Tanda("AMARGADITO").cantidad_de_filas, 1)
        self.assertEqual(Tanda("AMARGADITO", fija=True).cantidad_de_filas, 2)

    def test_oaaaa_solo_reduce_la_fija_superior_y_conserva_principal_doble(self):  # AC-STK-030
        principal, = ESTANTES["A.norte.2"]
        fija, = ESTANTES["A.norte.3"]
        self.assertEqual(principal.cantidad_de_filas, 2)
        self.assertEqual(fija.cantidad_de_filas, 1)

    def test_fernet_solo_reduce_la_fija_inferior_y_conserva_principal_doble(self):  # AC-STK-030
        principal, = ESTANTES["H1.sur.1"]
        fija, = ESTANTES["H1.sur.0"]
        self.assertEqual(principal.cantidad_de_filas, 2)
        self.assertEqual(fija.cantidad_de_filas, 1)

    def test_una_fija_no_puede_eludir_la_excepcion_global_de_una_fila(self):  # AC-STK-030
        for producto in ("COSA_DE_MANI", "FLINPUF", "BURBALOO", "MARRANOS", "POETICO"):
            with self.subTest(producto=producto), self.assertRaises(ValueError):
                Tanda(producto, fija=True, filas=2)


if __name__ == "__main__":
    unittest.main()
