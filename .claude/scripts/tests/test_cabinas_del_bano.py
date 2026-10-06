"""El despeje de la jamba considera la placa móvil, además del espesor de la hoja."""

import math
import unittest

from lib.cabinas_del_bano import seccion_del_poste


def se_solapan(primero, segundo):
    for contorno in (primero, segundo):
        for i, punto in enumerate(contorno):
            siguiente = contorno[(i + 1) % len(contorno)]
            normal = (punto[1] - siguiente[1], siguiente[0] - punto[0])
            a = [x * normal[0] + y * normal[1] for x, y in primero]
            b = [x * normal[0] + y * normal[1] for x, y in segundo]
            if max(a) <= min(b) or max(b) <= min(a):
                return False
    return True


class MontajeDeCabinaTest(unittest.TestCase):
    def test_jamba_deja_girar_hoja_y_placa_sin_cambiar_el_eje(self):
        for eje, extremo in ((11.455, 12.05), (13.065, 13.43)):
            poste = seccion_del_poste(eje, extremo, 3.3225, 3.3775)
            for parte in (
                [(-1.01, -.024), (-.01, -.024), (-.01, .024), (-1.01, .024)],
                [(-.08, -.036), (-.009, -.036), (-.009, -.022), (-.08, -.022)],
            ):
                for paso in range(19):
                    angulo = math.radians(paso * 5)
                    c, s = math.cos(angulo), math.sin(angulo)
                    movil = [(eje + x * c - y * s, 3.35 + x * s + y * c)
                             for x, y in parte]
                    with self.subTest(eje=eje, angulo=paso * 5, parte=parte):
                        self.assertFalse(se_solapan(movil, poste))

    def test_chaflan_de_treinta_y_cinco_no_despeja_la_bisagra(self):
        poste_anterior = [(.035, -.0275), (.5, -.0275), (.5, .0275), (.015, .0275)]
        placa_abierta = [(.036, -.08), (.036, -.009), (.022, -.009), (.022, -.08)]
        self.assertTrue(se_solapan(placa_abierta, poste_anterior))


if __name__ == "__main__":
    unittest.main()
