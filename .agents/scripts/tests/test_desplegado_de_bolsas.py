"""El desplegado de las bolsas de galletitas: las regiones caben en la imagen y no se pisan."""

import unittest

from lib import atlas
from lib.desplegado_de_bolsas import (
    ACOSTADAS,
    ALTO,
    ANCHO,
    PRENSADO,
    REGIONES,
    banda_del_cierre,
    recorte,
)

PRODUCTOS_DE_LAS_BOLSAS = ("petisas", "macumbas", "donsaturados")


def _se_pisan(a, b):
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


class DesplegadoDeBolsas(unittest.TestCase):
    def test_cada_region_cabe_en_la_imagen(self):
        for nombre, (x0, y0, x1, y1) in REGIONES.items():
            self.assertTrue(0 <= x0 < x1 <= ANCHO and 0 <= y0 < y1 <= ALTO, nombre)

    def test_ninguna_region_pisa_a_otra(self):
        nombres = list(REGIONES)
        for i, a in enumerate(nombres):
            for b in nombres[i + 1 :]:
                self.assertFalse(_se_pisan(REGIONES[a], REGIONES[b]), f"{a} pisa a {b}")

    def test_las_regiones_dejan_un_borde_para_que_el_filtro_no_mezcle_vecinas(self):
        for nombre, (x0, y0, x1, y1) in REGIONES.items():
            for otro, (a0, b0, a1, b1) in REGIONES.items():
                if otro != nombre:
                    separacion = max(a0 - x1, x0 - a1, b0 - y1, y0 - b1)
                    self.assertGreaterEqual(separacion, 8, f"{nombre} y {otro}")

    def test_frente_y_dorso_son_cuadrados_del_mismo_lado(self):
        medidas = {
            n: (REGIONES[n][2] - REGIONES[n][0], REGIONES[n][3] - REGIONES[n][1])
            for n in ("frente", "dorso")
        }
        self.assertEqual(medidas["frente"], medidas["dorso"])
        self.assertEqual(medidas["frente"][0], medidas["frente"][1])

    def test_los_costados_van_acostados_y_miden_lo_mismo_que_el_frente_de_largo(self):
        largo = REGIONES["frente"][3] - REGIONES["frente"][1]
        for nombre in ACOSTADAS:
            x0, y0, x1, y1 = REGIONES[nombre]
            self.assertEqual(x1 - x0, largo)
            self.assertLess(y1 - y0, x1 - x0)

    def test_el_recorte_queda_adentro_de_la_region_y_adentro_de_cero_a_uno(self):
        for nombre, (x0, y0, x1, y1) in REGIONES.items():
            u0, u1, v0, v1 = recorte(nombre)
            self.assertTrue(0.0 < u0 < u1 < 1.0 and 0.0 < v0 < v1 < 1.0, nombre)
            self.assertAlmostEqual(u0 * ANCHO, x0 + 0.5)
            self.assertAlmostEqual((1.0 - v1) * ALTO, y0 + 0.5)

    def test_la_banda_del_cierre_cabe_en_el_panel(self):
        alto_del_panel = REGIONES["frente"][3] - REGIONES["frente"][1]
        self.assertLess(2 * PRENSADO, alto_del_panel)
        self.assertAlmostEqual(banda_del_cierre() * ALTO, PRENSADO)


class LasTexturasEntranAlAtlas(unittest.TestCase):
    def test_las_tres_bolsas_viajan_como_una_sola_textura_cada_una(self):
        for producto in PRODUCTOS_DE_LAS_BOLSAS:
            self.assertIn(f"source/products-textured/bolsas/{producto}.png", atlas.ETIQUETAS)

    def test_el_par_completo_y_costado_de_las_tres_ya_no_viaja(self):
        viejas = [r for r in atlas.ETIQUETAS if r.startswith("source/products-cam/")]
        for producto in PRODUCTOS_DE_LAS_BOLSAS:
            propias = [r for r in viejas if producto in r.lower().replace(" ", "")]
            self.assertFalse(propias, producto)

    def test_la_textura_nueva_cabe_en_el_lado_con_el_que_viaja_un_producto(self):
        for producto in PRODUCTOS_DE_LAS_BOLSAS:
            clave = f"source/products-textured/bolsas/{producto}.png"
            self.assertGreaterEqual(atlas.lado_de(clave), max(ANCHO, ALTO))
