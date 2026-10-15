"""Una descomposición física nunca puede rellenar el paso que deja la malla."""

import unittest

from lib.volumen_rectilineo import agrupar


class VolumenRectilineo(unittest.TestCase):
    def test_una_habitacion_con_puerta_conserva_el_vacio_y_cada_celda_una_vez(self):
        celdas = {(x, y, z) for x in range(8) for y in range(5) for z in range(8)
                  if y == 0 or ((x in (0, 7) or z in (0, 7)) and not (x == 3 and z == 0))}
        ocupacion = []
        for inicio, fin in agrupar(celdas):
            ocupacion.extend((x, y, z) for x in range(inicio[0], fin[0])
                             for y in range(inicio[1], fin[1])
                             for z in range(inicio[2], fin[2]))
        self.assertEqual(set(ocupacion), celdas)
        self.assertEqual(len(ocupacion), len(celdas))
        self.assertNotIn((3, 2, 0), ocupacion)
        self.assertNotIn((4, 2, 4), ocupacion)

    def test_un_bloque_completo_se_agrupa_en_un_solo_solido(self):
        self.assertEqual(agrupar({(x, y, z) for x in range(3) for y in range(2)
                                 for z in range(4)}), [((0, 0, 0), (3, 2, 4))])
