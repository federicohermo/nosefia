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


def _se_pisan(a, b) -> bool:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return not (ax + aw <= bx or bx + bw <= ax or ay + ah <= by or by + bh <= ay)


class Proporcion(unittest.TestCase):
    def test_el_alto_da_la_relacion_de_aspecto_del_cuerpo_sin_las_aletas(self):
        for producto, relacion in forma.RELACION_DEL_CUERPO.items():
            alto = forma.alto_del_paquete(producto, 0.27)
            cuerpo = 0.27 * (1 - 2 * forma.FRANJA_DEL_CIERRE)
            self.assertAlmostEqual(cuerpo / alto, relacion, delta=0.01)

    def test_los_paquetes_son_apaisados_y_mas_bajos_que_el_cubo(self):
        for producto in forma.RELACION_DEL_CUERPO:
            alto = forma.alto_del_paquete(producto, 0.27)
            self.assertLess(alto, 0.27 * 0.8)
            self.assertGreater(0.27 / alto, 1.3)


class Desplegado(unittest.TestCase):
    CAJAS = {
        producto: forma.Caja(0.27, 0.08, forma.alto_del_paquete(producto, 0.27))
        for producto in forma.RELACION_DEL_CUERPO
    }

    def test_la_hoja_es_la_que_declara_y_los_paneles_entran_sin_pisarse(self):
        for caja in self.CAJAS.values():
            rects = forma.desplegado(caja)
            self.assertEqual(set(rects), set(forma.PANELES))
            for a, ra in rects.items():
                x, y, w, h = ra
                self.assertGreaterEqual(x, forma.CALLE)
                self.assertGreaterEqual(y, forma.CALLE)
                self.assertLessEqual(x + w + forma.CALLE, forma.LIENZO_ANCHO)
                self.assertLessEqual(y + h + forma.CALLE, forma.LIENZO_ALTO)
                for b, rb in rects.items():
                    if a < b:
                        self.assertFalse(_se_pisan(ra, rb), f"{a} y {b} se pisan")

    def test_el_sangrado_de_un_panel_no_toca_el_de_otro(self):
        self.assertLess(2 * forma.SANGRADO, forma.CALLE)
        for caja in self.CAJAS.values():
            zonas = forma.zonas(caja)
            for a in zonas:
                for b in zonas:
                    if a < b:
                        self.assertFalse(_se_pisan(zonas[a]["sangrado"], zonas[b]["sangrado"]))

    def test_los_cantos_tocan_el_frente_por_el_borde_que_les_toca(self):
        rects = forma.desplegado(self.CAJAS["OREMOS"])
        arriba, frente, abajo = rects[forma.ARRIBA], rects[forma.FRENTE], rects[forma.ABAJO]
        self.assertLess(arriba[1], frente[1])
        self.assertLess(frente[1], abajo[1])
        self.assertEqual(forma.v_del_cuerpo(forma.ARRIBA, 0.0), 1.0)
        self.assertEqual(forma.v_del_cuerpo(forma.ABAJO, 1.0), 0.0)

    def test_un_pixel_mide_lo_mismo_a_lo_ancho_y_a_lo_alto_y_en_todos_los_paneles(self):
        for caja in self.CAJAS.values():
            rects = forma.desplegado(caja)
            secc = forma.seccion(caja)
            d = forma.densidad(caja)
            esperado = {
                forma.FRENTE: (2 * forma.mitad_del_recorrido(caja), forma.FRENTE),
                forma.DORSO: (2 * forma.mitad_del_recorrido(caja), forma.DORSO),
                forma.ARRIBA: (2 * forma.mitad_del_canto(caja), forma.ARRIBA),
                forma.ABAJO: (2 * forma.mitad_del_canto(caja), forma.ABAJO),
            }
            for panel, (largo, tramo) in esperado.items():
                _, _, ancho_px, alto_px = rects[panel]
                self.assertAlmostEqual(ancho_px / largo / d, 1.0, delta=0.005)
                largo_del_tramo = secc.largo_de_cada_panel[tramo]
                self.assertAlmostEqual(alto_px / largo_del_tramo / d, 1.0, delta=0.005)

    def test_la_zona_segura_cabe_en_su_panel_y_el_frente_es_apaisado(self):
        for caja in self.CAJAS.values():
            for panel, z in forma.zonas(caja).items():
                x, y, w, h = z["panel"]
                sx, sy, sw, sh = z["zona_segura"]
                self.assertGreaterEqual(sx, x)
                self.assertGreaterEqual(sy, y)
                self.assertLessEqual(sx + sw, x + w)
                self.assertLessEqual(sy + sh, y + h)
            segura = forma.zonas(caja)[forma.FRENTE]["zona_segura"]
            self.assertGreater(segura[2] / segura[3], 1.2)

    def test_las_aletas_y_los_afinados_no_pisan_la_zona_segura(self):
        for caja in self.CAJAS.values():
            for panel, z in forma.zonas(caja).items():
                for clave in ("aleta_izquierda", "aleta_derecha"):
                    if clave in z:
                        self.assertFalse(_se_pisan(z[clave], z["zona_segura"]), f"{panel} {clave}")
                for clave in ("afinado_izquierdo", "afinado_derecho"):
                    if clave in z:
                        self.assertFalse(_se_pisan(z[clave], z["zona_segura"]), f"{panel} {clave}")

    def test_la_uv_del_cuerpo_y_del_cierre_cae_en_el_cuadrado(self):
        caja = self.CAJAS["PEPITO"]
        rects = forma.desplegado(caja)
        secc = forma.seccion(caja)
        semi = caja.semiancho_del_cuerpo
        for panel, (r0, r1) in zip(secc.tramos, secc.recorrido):
            for y in (-semi, 0.0, semi):
                for r in (r0, r1):
                    u, v = forma.uv_en_el_panel(
                        rects[panel],
                        forma.u_del_cuerpo(panel, y, caja),
                        forma.v_del_cuerpo(panel, r),
                    )
                    self.assertTrue(0.0 <= u <= 1.0 and 0.0 <= v <= 1.0)
        c = cierre((0, semi, 0), (0, 0, 1), caja.alto, (0, 1, 0), caja.salida_del_cierre, (1, 0, 0))
        for cara in c.caras:
            for i in cara.vertices:
                _, y, z = c.vertices[i]
                u, v = forma.uv_del_cierre(cara.lado, y, z, caja, rects)
                self.assertTrue(0.0 <= u <= 1.0 and 0.0 <= v <= 1.0)

    def test_el_cierre_ocupa_su_largo_real_en_el_extremo_del_panel(self):
        caja = self.CAJAS["OREMOS"]
        rects = forma.desplegado(caja)
        x, _, ancho, _ = rects[forma.FRENTE]
        u_punta, _ = forma.uv_del_cierre(1, caja.ancho / 2, 0.05, caja, rects)
        u_costura, _ = forma.uv_del_cierre(1, caja.semiancho_del_cuerpo, 0.05, caja, rects)
        self.assertAlmostEqual((u_punta * forma.LIENZO_ANCHO - x) / ancho, 1.0)
        franja = 1 - (u_costura * forma.LIENZO_ANCHO - x) / ancho
        largo = franja * ancho / forma.densidad(caja)
        self.assertAlmostEqual(largo, caja.salida_del_cierre, 3)

    def test_el_dorso_se_lee_al_reves_que_el_frente(self):
        caja = self.CAJAS["OREMOS"]
        frente = forma.u_del_cuerpo(forma.FRENTE, 0.05, caja)
        dorso = forma.u_del_cuerpo(forma.DORSO, 0.05, caja)
        self.assertAlmostEqual(frente + dorso, 1.0)

    def test_el_recorrido_a_lo_ancho_es_mas_largo_que_su_proyeccion_donde_el_cuerpo_se_afina(self):
        caja = self.CAJAS["OREMOS"]
        semi = caja.semiancho_del_cuerpo
        self.assertGreater(forma.recorrido_hasta(semi, caja), semi)
        self.assertAlmostEqual(forma.recorrido_hasta(0.0, caja), 0.0)
        self.assertAlmostEqual(
            forma.recorrido_hasta(-0.05, caja), -forma.recorrido_hasta(0.05, caja)
        )

    def test_un_punto_mas_cerca_de_los_hombros_recorre_menos_que_el_del_medio(self):
        caja = self.CAJAS["OREMOS"]
        semi = caja.semiancho_del_cuerpo
        cerca = forma.recorrido_hasta(semi, caja, 0.8)
        self.assertLess(cerca, forma.recorrido_hasta(semi, caja, 1.0))

    def test_los_anillos_van_de_costura_a_costura_y_se_juntan_en_el_afinado(self):
        caja = self.CAJAS["OREMOS"]
        ys = forma.alturas_de_los_anillos(caja)
        self.assertAlmostEqual(ys[0], -caja.semiancho_del_cuerpo)
        self.assertAlmostEqual(ys[-1], caja.semiancho_del_cuerpo)
        self.assertEqual(ys, sorted(ys))
        self.assertLess(ys[1] - ys[0], ys[len(ys) // 2] - ys[len(ys) // 2 - 1])


class Cuerpo(unittest.TestCase):
    def test_el_cuerpo_se_cierra_en_la_costura_y_llena_su_grosor_adentro(self):
        semi = CAJA.semiancho_del_cuerpo
        costura = forma.grosor_en(semi, CAJA, 0.05)
        self.assertAlmostEqual(costura, 0.05)
        self.assertAlmostEqual(forma.grosor_en(0.0, CAJA, 0.05), 1.0)
        self.assertGreater(forma.grosor_en(semi - forma.TRANSICION / 2, CAJA, 0.05), costura)

    def test_los_cierres_entran_en_el_ancho_de_la_caja(self):
        self.assertAlmostEqual(
            CAJA.semiancho_del_cuerpo + CAJA.salida_del_cierre, CAJA.ancho / 2
        )


if __name__ == "__main__":
    unittest.main()
