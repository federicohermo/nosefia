"""La forma de los paquetes de galletitas: su sección, su UV y el reparto de su hoja de arte."""

import unittest

from lib import paquete_de_galletitas as forma
from lib.cierre_de_envases import cierre

CAJA = forma.Caja(ancho=0.27, fondo=0.08, alto=0.27)


class Seccion(unittest.TestCase):
    def test_cada_tramo_es_un_panel_y_su_recorrido_va_de_cero_a_uno(self):
        secc = forma.seccion(CAJA)
        self.assertEqual(set(secc.tramos), set(forma.PANELES))
        for panel in forma.PANELES:
            r = [rec for t, rec in zip(secc.tramos, secc.recorrido) if t == panel]
            self.assertAlmostEqual(r[0][0], 0.0)
            self.assertAlmostEqual(r[-1][1], 1.0)
            for (_, fin), (inicio, _) in zip(r, r[1:]):
                self.assertAlmostEqual(fin, inicio)

    def test_la_seccion_no_se_sale_de_la_caja_y_toca_sus_cuatro_lados(self):
        xs = [p[0] for p in forma.seccion(CAJA).puntos]
        zs = [p[1] for p in forma.seccion(CAJA).puntos]
        self.assertLessEqual(max(xs), CAJA.fondo / 2 + 1e-9)
        self.assertGreaterEqual(min(xs), -CAJA.fondo / 2 - 1e-9)
        self.assertGreaterEqual(min(zs), -1e-9)
        self.assertLessEqual(max(zs), CAJA.alto + 1e-9)
        self.assertGreater(max(xs), 0.0)
        self.assertLess(min(xs), 0.0)

    def test_el_frente_y_el_dorso_son_mas_largos_que_los_cantos(self):
        largos = forma.seccion(CAJA).largo_de_cada_panel
        self.assertGreater(largos[forma.FRENTE], largos[forma.ARRIBA])
        self.assertAlmostEqual(largos[forma.FRENTE], largos[forma.DORSO])


class Cuerpo(unittest.TestCase):
    def test_el_cuerpo_se_cierra_en_la_costura_y_llena_su_grosor_adentro(self):
        semi = CAJA.semiancho_del_cuerpo
        costura = forma.grosor_en(semi, CAJA, 0.05)
        self.assertAlmostEqual(costura, 0.05)
        self.assertAlmostEqual(forma.grosor_en(0.0, CAJA, 0.05), 1.0)
        self.assertGreater(forma.grosor_en(semi / 2, CAJA, 0.05), costura)

    def test_los_anillos_van_de_costura_a_costura_y_se_juntan_en_las_puntas(self):
        ys = forma.alturas_de_los_anillos(CAJA)
        self.assertAlmostEqual(ys[0], -CAJA.semiancho_del_cuerpo)
        self.assertAlmostEqual(ys[-1], CAJA.semiancho_del_cuerpo)
        self.assertEqual(ys, sorted(ys))
        self.assertLess(ys[1] - ys[0], ys[len(ys) // 2 + 1] - ys[len(ys) // 2])

    def test_los_cierres_entran_en_el_ancho_de_la_caja(self):
        self.assertAlmostEqual(
            CAJA.semiancho_del_cuerpo + CAJA.salida_del_cierre, CAJA.ancho / 2
        )


class Desplegado(unittest.TestCase):
    def test_los_paneles_entran_en_la_hoja_y_no_se_pisan(self):
        rects = forma.desplegado(CAJA)
        self.assertEqual(set(rects), set(forma.PANELES))
        for a in list(rects.items()):
            for b in list(rects.items()):
                if a[0] >= b[0]:
                    continue
                ax, ay, aw, ah = a[1]
                bx, by, bw, bh = b[1]
                separados = ax + aw <= bx or bx + bw <= ax or ay + ah <= by or by + bh <= ay
                self.assertTrue(separados, f"{a[0]} y {b[0]} se pisan")

    def test_las_uv_del_cuerpo_y_del_cierre_caen_en_el_cuadrado(self):
        rects = forma.desplegado(CAJA)
        secc = forma.seccion(CAJA)
        semi = CAJA.semiancho_del_cuerpo
        for panel, (r0, r1) in zip(secc.tramos, secc.recorrido):
            for y in (-semi, 0.0, semi):
                for r in (r0, r1):
                    u, v = forma.uv_en_el_panel(
                        rects[panel],
                        forma.u_del_cuerpo(panel, y, CAJA),
                        forma.v_del_cuerpo(panel, r),
                    )
                    self.assertTrue(0.0 <= u <= 1.0 and 0.0 <= v <= 1.0)
        c = cierre((0, semi, 0), (0, 0, 1), CAJA.alto, (0, 1, 0), CAJA.salida_del_cierre, (1, 0, 0))
        for cara in c.caras:
            for i in cara.vertices:
                _, y, z = c.vertices[i]
                u, v = forma.uv_del_cierre(cara.lado, y, z, CAJA, rects)
                self.assertTrue(0.0 <= u <= 1.0 and 0.0 <= v <= 1.0)

    def test_el_cierre_ocupa_su_largo_real_en_el_extremo_del_panel(self):
        rects = forma.desplegado(CAJA)
        semi = CAJA.semiancho_del_cuerpo
        x, _, ancho, _ = rects[forma.FRENTE]
        u_punta, _ = forma.uv_del_cierre(1, CAJA.ancho / 2, 0.1, CAJA, rects)
        u_costura, _ = forma.uv_del_cierre(1, semi, 0.1, CAJA, rects)
        self.assertAlmostEqual((u_punta * forma.LIENZO_ANCHO - x) / ancho, 1.0)
        franja = 1 - (u_costura * forma.LIENZO_ANCHO - x) / ancho
        largo = franja * ancho / forma.DENSIDAD_DEL_FRENTE
        self.assertAlmostEqual(largo, CAJA.salida_del_cierre, 3)

    def test_un_pixel_mide_lo_mismo_a_lo_ancho_y_a_lo_alto_en_cada_panel(self):
        rects = forma.desplegado(CAJA)
        secc = forma.seccion(CAJA)
        densidad = forma.DENSIDAD_DEL_FRENTE
        mitad = forma.mitad_del_recorrido(CAJA)
        esperado = {
            forma.FRENTE: (2 * mitad, secc.largo_de_cada_panel[forma.FRENTE], densidad),
            forma.DORSO: (2 * mitad, secc.largo_de_cada_panel[forma.DORSO], densidad / 2),
            forma.ARRIBA: (
                2 * forma.mitad_del_canto(CAJA),
                secc.largo_de_cada_panel[forma.ARRIBA],
                densidad / 2,
            ),
        }
        for panel, (largo, alto, px_por_metro) in esperado.items():
            _, _, ancho_px, alto_px = rects[panel]
            self.assertAlmostEqual(ancho_px / largo / px_por_metro, 1.0, delta=0.01)
            self.assertAlmostEqual(alto_px / alto / px_por_metro, 1.0, delta=0.01)

    def test_el_recorrido_a_lo_ancho_es_mas_largo_que_su_proyeccion_donde_el_cuerpo_se_afina(self):
        semi = CAJA.semiancho_del_cuerpo
        self.assertGreater(forma.recorrido_hasta(semi, CAJA), semi)
        self.assertAlmostEqual(forma.recorrido_hasta(0.0, CAJA), 0.0)
        self.assertAlmostEqual(
            forma.recorrido_hasta(-0.05, CAJA), -forma.recorrido_hasta(0.05, CAJA)
        )

    def test_un_punto_mas_cerca_de_los_hombros_recorre_menos_que_el_del_medio(self):
        semi = CAJA.semiancho_del_cuerpo
        cerca = forma.recorrido_hasta(semi, CAJA, 0.8)
        self.assertLess(cerca, forma.recorrido_hasta(semi, CAJA, 1.0))

    def test_el_dorso_se_lee_al_reves_que_el_frente(self):
        frente = forma.u_del_cuerpo(forma.FRENTE, 0.05, CAJA)
        dorso = forma.u_del_cuerpo(forma.DORSO, 0.05, CAJA)
        self.assertAlmostEqual(frente + dorso, 1.0)

    def test_el_frente_de_los_cantos_queda_abajo_en_la_hoja(self):
        arriba, abajo = forma.ARRIBA, forma.ABAJO
        self.assertGreater(forma.v_del_cuerpo(arriba, 0.0), forma.v_del_cuerpo(arriba, 1.0))
        self.assertLess(forma.v_del_cuerpo(abajo, 0.0), forma.v_del_cuerpo(abajo, 1.0))


if __name__ == "__main__":
    unittest.main()
