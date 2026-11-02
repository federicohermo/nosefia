"""Los tests de `lib/desgaste.py`: qué hace la capa con una etiqueta.

Se afirma el comportamiento de la fórmula aprobada, con píxeles chicos hechos a mano: dónde
aclara, dónde no toca y cómo se reparte una capa entre varios productos.
"""

import unittest

from lib.desgaste import GIROS, aplicar, mediana, normalizar, preparar_capa


def etiqueta(*colores):
    """RGBA de 0..1 con el alfa opaco."""
    return [canal for color in colores for canal in (*color, 1.0)]


class Normalizar(unittest.TestCase):
    def test_una_capa_pareja_no_cambia_nada_sea_cual_sea_su_gris(self):
        for gris in (90, 128, 200):
            self.assertTrue(all(v == 0 for v in normalizar([gris] * 9)))

    def test_lo_que_cuenta_es_la_diferencia_con_el_fondo(self):
        a = normalizar([128, 128, 128, 160])
        b = normalizar([100, 100, 100, 132])
        self.assertEqual([round(v, 9) for v in a], [round(v, 9) for v in b])

    def test_la_mediana_de_un_conjunto_par_es_la_del_medio(self):
        self.assertEqual(mediana([1, 2, 3, 10]), 2.5)


class Aplicar(unittest.TestCase):
    def test_un_color_medio_se_aclara_donde_la_capa_es_clara(self):
        antes = etiqueta((0.5, 0.5, 0.5), (0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
        despues = aplicar(antes, [128, 128, 200])
        self.assertEqual(despues[0:3], antes[0:3])
        self.assertGreater(despues[8], antes[8])

    def test_un_color_medio_se_oscurece_donde_la_capa_es_oscura(self):
        antes = etiqueta((0.5, 0.5, 0.5), (0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
        despues = aplicar(antes, [128, 128, 60])
        self.assertLess(despues[8], antes[8])

    def test_el_negro_no_se_toca_por_marcada_que_sea_la_capa(self):
        antes = etiqueta((0.0, 0.0, 0.0), (0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
        despues = aplicar(antes, [255, 128, 128])
        self.assertEqual(despues[0:3], antes[0:3])

    def test_un_color_oscuro_cambia_menos_que_uno_claro(self):
        antes = etiqueta(*[(0.2, 0.2, 0.2), (0.9, 0.9, 0.9)] + [(0.5, 0.5, 0.5)] * 3)
        despues = aplicar(antes, [140, 140, 128, 128, 128])
        cambio_oscuro = despues[0] - antes[0]
        cambio_claro = despues[4] - antes[4]
        self.assertGreater(cambio_oscuro, 0)
        self.assertGreater(cambio_claro, cambio_oscuro)

    def test_el_alfa_no_se_toca(self):
        antes = [0.5, 0.5, 0.5, 0.25, 0.5, 0.5, 0.5, 0.75, 0.5, 0.5, 0.5, 1.0]
        despues = aplicar(antes, [128, 255, 0])
        self.assertEqual(despues[3::4], antes[3::4])

    def test_nada_sale_de_cero_a_uno(self):
        antes = etiqueta((0.99, 0.99, 0.99), (0.99, 0.99, 0.99), (0.05, 0.9, 0.9))
        despues = aplicar(antes, [128, 255, 0], fuerza=5.0)
        self.assertTrue(all(0.0 <= v <= 1.0 for v in despues))

    def test_sin_fuerza_la_etiqueta_queda_igual(self):
        antes = etiqueta((0.5, 0.4, 0.3), (0.6, 0.6, 0.6), (0.9, 0.2, 0.1))
        self.assertEqual(aplicar(antes, [10, 128, 250], fuerza=0.0), antes)

    def test_con_mas_fuerza_la_marca_pesa_mas(self):
        antes = etiqueta((0.5, 0.5, 0.5), (0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
        suave = aplicar(antes, [128, 128, 160], fuerza=0.5)
        entera = aplicar(antes, [128, 128, 160], fuerza=1.0)
        self.assertGreater(entera[8] - antes[8], suave[8] - antes[8])

    def test_una_capa_de_otro_tamano_se_rechaza(self):
        with self.assertRaises(ValueError):
            aplicar(etiqueta((0.5, 0.5, 0.5)), [128, 128])


def cuadrada(lado):
    return list(range(lado * lado))


class PrepararLaCapa(unittest.TestCase):
    def test_sin_nada_que_mover_devuelve_el_recorte_de_la_esquina(self):
        capa = cuadrada(4)
        self.assertEqual(preparar_capa(capa, 4, 3, 2), [0, 1, 2, 4, 5, 6])

    def test_cuatro_giros_de_noventa_vuelven_al_principio(self):
        capa = cuadrada(5)
        girada = capa
        for _ in range(4):
            girada = preparar_capa(girada, 5, 5, 5, giro=90)
        self.assertEqual(girada, capa)

    def test_cada_giro_da_una_marca_distinta(self):
        capa = cuadrada(4)
        vistas = {tuple(preparar_capa(capa, 4, 4, 4, giro=g)) for g in GIROS}
        self.assertEqual(len(vistas), len(GIROS))

    def test_el_espejo_cambia_la_marca(self):
        capa = cuadrada(4)
        self.assertNotEqual(preparar_capa(capa, 4, 4, 4, espejo=True), capa)

    def test_el_desplazamiento_da_la_vuelta_y_no_pierde_ninguna_marca(self):
        capa = cuadrada(6)
        movida = preparar_capa(capa, 6, 6, 6, desplazamiento=(0.25, 0.5))
        self.assertNotEqual(movida, capa)
        self.assertEqual(sorted(movida), sorted(capa))

    def test_dos_vecinos_con_la_misma_capa_no_muestran_la_misma_marca(self):
        capa = cuadrada(8)
        uno = preparar_capa(capa, 8, 8, 8, giro=90)
        otro = preparar_capa(capa, 8, 8, 8, giro=270, desplazamiento=(0.5, 0.0))
        self.assertNotEqual(uno, otro)

    def test_el_recorte_tiene_el_tamano_de_la_etiqueta(self):
        self.assertEqual(len(preparar_capa(cuadrada(10), 10, 10, 6, giro=90)), 60)

    def test_una_capa_mas_chica_que_la_etiqueta_se_rechaza(self):
        with self.assertRaises(ValueError):
            preparar_capa(cuadrada(4), 4, 5, 3)

    def test_un_giro_que_no_es_de_noventa_se_rechaza(self):
        with self.assertRaises(ValueError):
            preparar_capa(cuadrada(4), 4, 4, 4, giro=45)


if __name__ == "__main__":
    unittest.main()
