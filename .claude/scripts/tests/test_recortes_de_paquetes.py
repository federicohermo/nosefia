"""Los recortes del arte que forman la textura de los paquetes de galletitas."""

import unittest

from lib import recortes_de_paquetes as recortes


def _se_pisan(a, b) -> bool:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return not (ax + aw <= bx or bx + bw <= ax or ay + ah <= by or by + bh <= ay)


class Recortes(unittest.TestCase):
    def test_cada_paquete_tiene_los_seis_recortes_y_cada_uno_tiene_area(self):
        for clave, por_zona in recortes.RECORTES.items():
            self.assertEqual(set(por_zona), set(recortes.ZONAS), clave)
            for zona, (x0, y0, x1, y1) in por_zona.items():
                self.assertGreater(x1 - x0, 0, f"{clave} {zona}")
                self.assertGreater(y1 - y0, 0, f"{clave} {zona}")

    def test_los_recortes_caen_dentro_del_arte_original(self):
        for clave, por_zona in recortes.RECORTES.items():
            for zona, (x0, y0, x1, y1) in por_zona.items():
                self.assertTrue(0 <= x0 < x1 <= 1254 and 0 <= y0 < y1 <= 1254, f"{clave} {zona}")

    def test_cada_fuente_existe_en_el_arte_del_artista(self):
        for clave, archivo in recortes.FUENTES.items():
            self.assertIn(clave, recortes.RECORTES)
            self.assertTrue(archivo.endswith(".png"))

    def test_las_aletas_de_un_panel_tienen_la_altura_de_su_panel(self):
        for clave, por_zona in recortes.RECORTES.items():
            alto_frente = recortes.medida(por_zona[recortes.FRENTE])[1]
            alto_dorso = recortes.medida(por_zona[recortes.DORSO])[1]
            for zona in (recortes.ALETA_FRENTE_IZQUIERDA, recortes.ALETA_FRENTE_DERECHA):
                self.assertEqual(recortes.medida(por_zona[zona])[1], alto_frente)
            for zona in (recortes.ALETA_DORSO_IZQUIERDA, recortes.ALETA_DORSO_DERECHA):
                self.assertEqual(recortes.medida(por_zona[zona])[1], alto_dorso)

    def test_el_frente_es_apaisado(self):
        for clave in recortes.FUENTES:
            self.assertGreater(recortes.relacion_del_frente(clave), 1.2)


class Disposicion(unittest.TestCase):
    def test_cada_recorte_entra_en_el_atlas_y_ninguno_se_pisa_con_su_relleno(self):
        for clave in recortes.FUENTES:
            atlas = recortes.disposicion(clave)
            self.assertEqual(atlas.ancho, recortes.ANCHO_DEL_ATLAS)
            self.assertEqual(set(atlas.rects), set(recortes.ZONAS))
            relleno = recortes.RELLENO
            ampliados = {}
            for zona, (x, y, w, h) in atlas.rects.items():
                self.assertEqual((w, h), recortes.medida(recortes.RECORTES[clave][zona]))
                self.assertGreaterEqual(x - relleno, 0)
                self.assertGreaterEqual(y - relleno, 0)
                self.assertLessEqual(x + w + relleno, atlas.ancho)
                self.assertLessEqual(y + h + relleno, atlas.alto)
                ampliados[zona] = (x - relleno, y - relleno, w + 2 * relleno, h + 2 * relleno)
            for a in ampliados:
                for b in ampliados:
                    if a < b:
                        self.assertFalse(_se_pisan(ampliados[a], ampliados[b]), f"{a} y {b}")

    def test_el_relleno_es_menor_que_la_mitad_del_aire(self):
        self.assertLess(2 * recortes.RELLENO, recortes.GUARDA + 1)

    def test_el_alto_del_atlas_es_multiplo_de_16(self):
        for clave in recortes.FUENTES:
            self.assertEqual(recortes.disposicion(clave).alto % 16, 0)


if __name__ == "__main__":
    unittest.main()
