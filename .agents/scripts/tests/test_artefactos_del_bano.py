"""La división física sigue las piezas: la tapa no eleva el apoyo del tanque."""

import unittest

from lib.artefactos_del_bano import (
    area_firmada, componentes, corte_horizontal, grilla_del_fondo, volumen_por_altura,
)


class PiezasConApoyoPropio(unittest.TestCase):
    def test_componentes_con_aristas_en_orden_arbitrario_y_un_vertice_suelto(self):
        resultado = list(componentes(7, [(2, 1), (0, 2), (5, 4), (3, 5)]))
        self.assertEqual(resultado, [{0, 1, 2}, {3, 4, 5}, {6}])

    def test_un_tanque_alto_con_base_baja_no_se_confunde_con_la_tapa(self):
        self.assertEqual(volumen_por_altura([.584, 1.031, .98]), 92)

    def test_tapa_y_cuerpo_quedan_separados_del_tanque(self):
        self.assertEqual(volumen_por_altura([.64, 1.085]), 91)
        self.assertEqual(volumen_por_altura([.105, .63]), 90)

    def test_el_pulsador_no_se_incluye_en_el_plano_de_apoyo(self):
        self.assertIsNone(volumen_por_altura([1.033, 1.04]))

    def test_el_corte_separa_el_borde_interior_del_exterior(self):
        vertices = [(x * escala, y * escala, z) for escala in (1, .5)
                    for z in (-1, 1) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        caras = [(base+i, base+(i+1) % 4, base+(i+1) % 4+4, base+i+4)
                 for base in (0, 8) for i in range(4)]
        anillos = corte_horizontal(vertices, caras, .13)
        self.assertEqual(sorted(abs(area_firmada(a)) for a in anillos), [1, 4])

    def test_un_corte_abierto_no_se_acepta_como_superficie_de_agua(self):
        with self.assertRaisesRegex(AssertionError, "corte no cerrado"):
            corte_horizontal([(0, 0, -1), (1, 0, 1), (0, 1, 1)], [(0, 1, 2)], .1)


class FondoConCarasDistribuidas(unittest.TestCase):
    def test_el_parche_conserva_el_borde_y_cubre_el_fondo_sin_abrazar_un_solo_vertice(self):
        borde = [(0, 0, .99), (1, 0, .99), (2, 0, .99), (2, 1, .99),
                 (2, 2, .99), (1, 2, .99), (0, 2, .99), (0, 1, .99)]
        vertices, caras, indices_del_borde = grilla_del_fondo(borde)
        self.assertEqual([vertices[i] for i in indices_del_borde], borde)
        self.assertEqual(vertices[4], (1, 1, .99))
        self.assertEqual(len(caras), 4)
        self.assertTrue(all(len(cara) == 4 for cara in caras))
        self.assertEqual(sum(area_firmada([vertices[i] for i in cara]) for cara in caras), 4)

    def test_un_borde_sin_cuatro_lados_compatibles_no_se_rellena(self):
        with self.assertRaisesRegex(ValueError, "cuatro lados"):
            grilla_del_fondo([(0, 0, 0)] * 7)


if __name__ == "__main__":
    unittest.main()
