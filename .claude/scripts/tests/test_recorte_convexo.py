import unittest

from lib.recorte_convexo import recortar


class RecorteConvexo(unittest.TestCase):
    def test_los_dos_lados_conservan_su_frontera_sin_cruzarse(self):
        caja = [(x, y, z) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
        for positivo in (False, True):
            puntos = recortar(caja, (1, 0, 0), 0.25, positivo)
            self.assertTrue(puntos)
            self.assertTrue(all((p[0] >= 0.25 if positivo else p[0] <= 0.25) for p in puntos))
            self.assertTrue(all(-1 <= c <= 1 for p in puntos for c in p))
            frontera = {(p[1], p[2]) for p in puntos if p[0] == 0.25}
            self.assertTrue({(y, z) for y in (-1, 1) for z in (-1, 1)} <= frontera)

    def test_un_plano_fuera_del_solido_deja_un_lado_vacio(self):
        self.assertEqual(recortar([(0, 0, 0), (1, 1, 1)], (1, 0, 0), 2), [])
