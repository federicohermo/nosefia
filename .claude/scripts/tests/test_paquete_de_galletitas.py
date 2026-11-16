"""La forma de los paquetes de galletitas: su sección, su alto y su UV."""

import math
import unittest

from lib import paquete_de_galletitas as forma
from lib import recortes_de_paquetes as recortes
from lib.cierre_de_envases import cierre

ANCHO, FONDO = 0.27, 0.08
CAJAS = {clave: forma.caja_del_paquete(clave, ANCHO, FONDO) for clave in recortes.FUENTES}


class Seccion(unittest.TestCase):
    def test_cada_tramo_es_un_panel_y_su_recorrido_va_de_cero_a_uno(self):
        for caja in CAJAS.values():
            secc = forma.seccion(caja)
            self.assertEqual(set(secc.tramos), set(forma.PANELES))
            for panel in forma.PANELES:
                r = [rec for t, rec in zip(secc.tramos, secc.recorrido) if t == panel]
                self.assertAlmostEqual(r[0][0], 0.0)
                self.assertAlmostEqual(r[-1][1], 1.0)
                for (_, fin), (inicio, _) in zip(r, r[1:]):
                    self.assertAlmostEqual(fin, inicio)

    def test_la_seccion_no_se_sale_de_la_caja_y_toca_sus_cuatro_lados(self):
        for caja in CAJAS.values():
            xs = [p[0] for p in forma.seccion(caja).puntos]
            zs = [p[1] for p in forma.seccion(caja).puntos]
            self.assertLessEqual(max(xs), caja.fondo / 2 + 1e-9)
            self.assertGreaterEqual(min(xs), -caja.fondo / 2 - 1e-9)
            self.assertGreaterEqual(min(zs), -1e-9)
            self.assertLessEqual(max(zs), caja.alto + 1e-9)
            self.assertGreater(max(xs), 0.0)
            self.assertLess(min(xs), 0.0)


class Alto(unittest.TestCase):
    def test_el_frente_tiene_la_proporcion_del_arte(self):
        for clave, caja in CAJAS.items():
            frente = forma.seccion(caja).largo_de_cada_panel[forma.FRENTE]
            relacion = 2 * caja.semiancho_de_arte / frente
            self.assertAlmostEqual(relacion / recortes.relacion_del_frente(clave), 1.0, delta=0.002)

    def test_el_ancho_y_el_fondo_son_los_del_cubo_y_el_alto_baja(self):
        for caja in CAJAS.values():
            self.assertEqual((caja.ancho, caja.fondo), (ANCHO, FONDO))
            self.assertLess(caja.alto, 0.27 * 0.6)

    def test_un_arte_mas_apaisado_da_un_paquete_mas_bajo(self):
        mas_apaisado = max(recortes.FUENTES, key=recortes.relacion_del_frente)
        menos = min(recortes.FUENTES, key=recortes.relacion_del_frente)
        self.assertLess(CAJAS[mas_apaisado].alto, CAJAS[menos].alto)

    def test_la_banda_del_dorso_cae_en_el_medio_y_sobre_vertices(self):
        for caja in CAJAS.values():
            desde, hasta = caja.banda_del_dorso
            self.assertAlmostEqual(desde + hasta, 1.0)
            secc = forma.seccion(caja)
            fracciones = [r[0] for t, r in zip(secc.tramos, secc.recorrido) if t == forma.DORSO]
            self.assertTrue(any(abs(f - desde) < 0.002 for f in fracciones))
            self.assertTrue(any(abs(f - hasta) < 0.002 for f in fracciones))


class Uv(unittest.TestCase):
    def test_el_frente_llena_su_recorte_de_borde_a_borde(self):
        for clave, caja in CAJAS.items():
            atlas = recortes.disposicion(clave)
            x, y, w, h = atlas.rects[recortes.FRENTE]
            semi = caja.semiancho_de_arte
            esquinas = [
                forma.uv_del_cuerpo(atlas, forma.FRENTE, -semi, 0.0, caja),
                forma.uv_del_cuerpo(atlas, forma.FRENTE, semi, 1.0, caja),
            ]
            (u0, v0), (u1, v1) = esquinas
            self.assertAlmostEqual(u0 * atlas.ancho, x)
            self.assertAlmostEqual(u1 * atlas.ancho, x + w)
            self.assertAlmostEqual((1 - v0) * atlas.alto, y + h)
            self.assertAlmostEqual((1 - v1) * atlas.alto, y)

    def test_un_pixel_mide_lo_mismo_a_lo_ancho_y_a_lo_alto_en_el_frente(self):
        for clave, caja in CAJAS.items():
            atlas = recortes.disposicion(clave)
            _, _, ancho, alto = atlas.rects[recortes.FRENTE]
            frente = forma.seccion(caja).largo_de_cada_panel[forma.FRENTE]
            por_metro = ancho / (2 * caja.semiancho_de_arte)
            self.assertAlmostEqual(por_metro / (alto / frente), 1.0, delta=0.002)

    def test_fuera_del_arte_la_uv_se_queda_en_el_borde_del_recorte(self):
        for clave, caja in CAJAS.items():
            atlas = recortes.disposicion(clave)
            semi = caja.semiancho_del_cuerpo
            semi_arte = caja.semiancho_de_arte
            en_el_borde = forma.uv_del_cuerpo(atlas, forma.FRENTE, semi_arte, 0.5, caja)
            afinado = forma.uv_del_cuerpo(atlas, forma.FRENTE, semi, 0.5, caja)
            self.assertEqual(en_el_borde, afinado)
            arriba = forma.uv_del_cuerpo(atlas, forma.ARRIBA, 0.0, 0.5, caja)
            otro = forma.uv_del_cuerpo(atlas, forma.ARRIBA, 0.0, 0.1, caja)
            self.assertEqual(arriba, otro)
            x, y, w, h = atlas.rects[recortes.FRENTE]
            self.assertAlmostEqual((1 - arriba[1]) * atlas.alto, y)
            abajo = forma.uv_del_cuerpo(atlas, forma.ABAJO, 0.0, 0.5, caja)
            self.assertAlmostEqual((1 - abajo[1]) * atlas.alto, y + h)

    def test_el_dorso_se_pone_a_lo_ancho_y_centrado_a_lo_alto(self):
        for clave, caja in CAJAS.items():
            atlas = recortes.disposicion(clave)
            x, y, w, h = atlas.rects[recortes.DORSO]
            medio = forma.uv_del_cuerpo(atlas, forma.DORSO, 0.0, 0.5, caja)
            self.assertAlmostEqual(medio[0] * atlas.ancho, x + w / 2)
            self.assertAlmostEqual((1 - medio[1]) * atlas.alto, y + h / 2)
            desde, hasta = caja.banda_del_dorso
            techo = forma.uv_del_cuerpo(atlas, forma.DORSO, 0.0, desde, caja)
            piso = forma.uv_del_cuerpo(atlas, forma.DORSO, 0.0, hasta, caja)
            self.assertAlmostEqual((1 - techo[1]) * atlas.alto, y, delta=0.5)
            self.assertAlmostEqual((1 - piso[1]) * atlas.alto, y + h, delta=0.5)

    def test_el_dorso_se_lee_al_reves_que_el_frente(self):
        for clave, caja in CAJAS.items():
            atlas = recortes.disposicion(clave)
            frente = forma.uv_del_cuerpo(atlas, forma.FRENTE, 0.05, 0.5, caja)[0] * atlas.ancho
            dorso = forma.uv_del_cuerpo(atlas, forma.DORSO, 0.05, 0.5, caja)[0] * atlas.ancho
            fx, _, fw, _ = atlas.rects[recortes.FRENTE]
            dx, _, dw, _ = atlas.rects[recortes.DORSO]
            self.assertAlmostEqual((frente - fx) / fw + (dorso - dx) / dw, 1.0)

    def test_la_uv_de_todo_cae_dentro_del_atlas(self):
        for clave, caja in CAJAS.items():
            atlas = recortes.disposicion(clave)
            secc = forma.seccion(caja)
            semi = caja.semiancho_del_cuerpo
            for panel in forma.PANELES:
                for y in (-semi, -caja.semiancho_de_arte, 0.0, semi):
                    for r in (0.0, 0.5, 1.0):
                        u, v = forma.uv_del_cuerpo(atlas, panel, y, r, caja)
                        self.assertTrue(0.0 <= u <= 1.0 and 0.0 <= v <= 1.0)
            c = cierre(
                (0, semi, 0), (0, 0, 1), caja.alto, (0, 1, 0), caja.salida_del_cierre, (1, 0, 0)
            )
            for cara in c.caras:
                for i in cara.vertices:
                    _, y, z = c.vertices[i]
                    u, v = forma.uv_del_cierre(atlas, cara.lado, y, z, caja)
                    self.assertTrue(0.0 <= u <= 1.0 and 0.0 <= v <= 1.0)
            self.assertGreater(len(secc.puntos), 0)

    def test_la_costura_de_la_aleta_toca_el_borde_de_adentro_de_su_franja(self):
        caja = CAJAS["OREMOS"]
        atlas = recortes.disposicion("OREMOS")
        semi = caja.semiancho_del_cuerpo
        x, _, w, _ = atlas.rects[recortes.ALETA_FRENTE_DERECHA]
        costura = forma.uv_del_cierre(atlas, 1, semi, 0.05, caja)[0] * atlas.ancho
        punta = forma.uv_del_cierre(atlas, 1, caja.ancho / 2, 0.05, caja)[0] * atlas.ancho
        self.assertAlmostEqual(costura, x)
        self.assertAlmostEqual(punta, x + w)
        x, _, w, _ = atlas.rects[recortes.ALETA_FRENTE_IZQUIERDA]
        costura = forma.uv_del_cierre(atlas, 1, -semi, 0.05, caja)[0] * atlas.ancho
        self.assertAlmostEqual(costura, x + w)

    def test_el_dorso_toma_la_franja_del_lado_que_se_ve_desde_atras(self):
        caja = CAJAS["PEPITO"]
        atlas = recortes.disposicion("PEPITO")
        x, _, w, _ = atlas.rects[recortes.ALETA_DORSO_IZQUIERDA]
        u = forma.uv_del_cierre(atlas, -1, caja.ancho / 2, 0.05, caja)[0] * atlas.ancho
        self.assertTrue(x - 0.5 <= u <= x + w + 0.5)


class Cuerpo(unittest.TestCase):
    def test_el_recorrido_a_lo_ancho_es_mas_largo_que_su_proyeccion_donde_el_cuerpo_se_afina(self):
        caja = CAJAS["OREMOS"]
        semi = caja.semiancho_del_cuerpo
        self.assertGreater(forma.recorrido_hasta(semi, caja), semi)
        self.assertAlmostEqual(forma.recorrido_hasta(0.0, caja), 0.0)
        self.assertAlmostEqual(
            forma.recorrido_hasta(-0.05, caja), -forma.recorrido_hasta(0.05, caja)
        )

    def test_el_recorrido_del_arte_es_la_proyeccion(self):
        caja = CAJAS["PEPITO"]
        self.assertAlmostEqual(
            forma.recorrido_hasta(caja.semiancho_de_arte, caja), caja.semiancho_de_arte, 6
        )

    def test_los_anillos_van_de_costura_a_costura_y_se_juntan_en_el_afinado(self):
        caja = CAJAS["OREMOS"]
        ys = forma.alturas_de_los_anillos(caja)
        self.assertAlmostEqual(ys[0], -caja.semiancho_del_cuerpo)
        self.assertAlmostEqual(ys[-1], caja.semiancho_del_cuerpo)
        self.assertEqual(ys, sorted(ys))
        self.assertTrue(any(math.isclose(y, caja.semiancho_de_arte) for y in ys))
        self.assertLess(ys[1] - ys[0], ys[len(ys) // 2] - ys[len(ys) // 2 - 1])

    def test_el_cuerpo_se_cierra_en_la_costura_y_llena_su_grosor_adentro(self):
        caja = CAJAS["OREMOS"]
        semi = caja.semiancho_del_cuerpo
        self.assertAlmostEqual(forma.grosor_en(semi, caja, 0.05), 0.05)
        self.assertAlmostEqual(forma.grosor_en(0.0, caja, 0.05), 1.0)
        self.assertGreater(forma.grosor_en(semi - forma.TRANSICION / 2, caja, 0.05), 0.05)

    def test_los_cierres_entran_en_el_ancho_de_la_caja(self):
        caja = CAJAS["OREMOS"]
        self.assertAlmostEqual(caja.semiancho_del_cuerpo + caja.salida_del_cierre, caja.ancho / 2)


if __name__ == "__main__":
    unittest.main()
