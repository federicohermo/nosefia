"""El color de una caja nueva se lleva al de su original, y los roces nuevos quedan."""

import math
import random
import unittest

from lib.color_de_caja import (
    NEGRO,
    TOLERANCIA,
    a_lab,
    a_srgb,
    ajustar,
    aplicar,
    contenido,
    pesos,
    reducir,
    saturacion_y_brillo,
)

LADO = 12


def _caja(base, variacion: float, semilla: int):
    """Un desplegado chico: cartón de un color con roces al azar, y las esquinas negras."""
    azar = random.Random(semilla)
    pixeles = []
    for fila in range(LADO):
        for columna in range(LADO):
            if fila < 3 and columna < 3:
                pixeles.append((0.0, 0.0, 0.0))
                continue
            roce = (azar.random() - 0.5) * variacion
            pixeles.append(tuple(min(1.0, max(0.0, canal + roce)) for canal in base))
    return LADO, LADO, pixeles


def _medidas(imagen):
    return saturacion_y_brillo(imagen[2], contenido(imagen))


def _correlacion(xs, ys):
    media_x, media_y = sum(xs) / len(xs), sum(ys) / len(ys)
    cov = sum((x - media_x) * (y - media_y) for x, y in zip(xs, ys))
    var_x = sum((x - media_x) ** 2 for x in xs)
    var_y = sum((y - media_y) ** 2 for y in ys)
    return cov / math.sqrt(var_x * var_y)


class LaMedida(unittest.TestCase):
    def test_un_gris_no_tiene_saturacion(self):
        self.assertEqual(saturacion_y_brillo([(0.5, 0.5, 0.5)])[0], 0)

    def test_un_color_puro_tiene_la_saturacion_maxima_y_su_brillo(self):
        saturacion, brillo = saturacion_y_brillo([(1.0, 0.0, 0.0)])
        self.assertEqual((saturacion, brillo), (255, 255))

    def test_la_mascara_deja_afuera_lo_que_no_cuenta(self):
        pixeles = [(0.8, 0.2, 0.2), (0.0, 0.0, 0.0)]
        self.assertEqual(
            saturacion_y_brillo(pixeles, [True, False]), saturacion_y_brillo(pixeles[:1])
        )

    def test_sin_nada_que_medir_se_rechaza(self):
        with self.assertRaises(ValueError):
            saturacion_y_brillo([(0.0, 0.0, 0.0)], [False])

    def test_el_negro_de_las_esquinas_no_es_contenido(self):
        _, _, pixeles = _caja((0.6, 0.45, 0.3), 0.1, 1)
        mascara = contenido((LADO, LADO, pixeles))
        self.assertFalse(mascara[0])
        self.assertTrue(mascara[3 * LADO + 3])
        self.assertTrue(all(round(255 * max(p)) > NEGRO for p, d in zip(pixeles, mascara) if d))


class ElColor(unittest.TestCase):
    def test_ir_a_lab_y_volver_no_cambia_un_color(self):
        for color in ((0.2, 0.5, 0.7), (0.9, 0.1, 0.4), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0)):
            for esperado, obtenido in zip(color, a_srgb(*a_lab(*color))):
                self.assertAlmostEqual(esperado, obtenido, places=6)


class LaReduccion(unittest.TestCase):
    def test_una_imagen_que_cabe_queda_como_esta(self):
        imagen = _caja((0.6, 0.45, 0.3), 0.1, 2)
        self.assertEqual(reducir(imagen, 64), imagen)

    def test_un_color_parejo_sigue_siendo_ese_color_y_toma_el_tamano_pedido(self):
        color = (0.6, 0.45, 0.3)
        ancho, alto, pixeles = reducir((40, 30, [color] * 1200), 8)
        self.assertEqual((ancho, alto, len(pixeles)), (8, 8, 64))
        for pixel in pixeles:
            for esperado, obtenido in zip(color, pixel):
                self.assertAlmostEqual(esperado, obtenido, delta=1 / 255)

    def test_los_pesos_de_cada_pixel_suman_uno(self):
        for _, ps in pesos(50, 7):
            self.assertAlmostEqual(sum(ps), 1.0)


class LlevarUnaCajaAlColorDeSuOriginal(unittest.TestCase):
    def setUp(self):
        self.original = _caja((0.55, 0.42, 0.28), 0.20, 3)
        self.nueva = _caja((0.72, 0.52, 0.30), 0.30, 4)
        self.ajuste = ajustar(self.nueva, self.original)
        self.resultado = aplicar(self.ajuste, self.nueva)

    def test_la_caja_nueva_empieza_fuera_del_criterio(self):
        saturacion, brillo = _medidas(self.nueva)
        meta_saturacion, meta_brillo = _medidas(self.original)
        self.assertGreater(saturacion - meta_saturacion + brillo - meta_brillo, 2 * TOLERANCIA)

    def test_la_saturacion_y_el_brillo_medios_quedan_a_la_tolerancia_del_original(self):
        saturacion, brillo = _medidas(self.resultado)
        meta_saturacion, meta_brillo = _medidas(self.original)
        self.assertAlmostEqual(saturacion, meta_saturacion, delta=TOLERANCIA)
        self.assertAlmostEqual(brillo, meta_brillo, delta=TOLERANCIA)

    def test_los_roces_siguen_donde_estaban(self):
        luz_antes = [a_lab(*p)[0] for p in self.nueva[2][3 * LADO + 3 :]]
        luz_despues = [a_lab(*p)[0] for p in self.resultado[2][3 * LADO + 3 :]]
        self.assertGreater(_correlacion(luz_antes, luz_despues), 0.98)

    def test_los_roces_no_se_aplastan(self):
        def desvio(imagen):
            luces = [a_lab(*p)[0] for p, d in zip(imagen[2], contenido(imagen)) if d]
            media = sum(luces) / len(luces)
            return math.sqrt(sum((x - media) ** 2 for x in luces) / len(luces))

        self.assertGreater(desvio(self.resultado), 0.7 * desvio(self.original))

    def test_el_negro_queda_negro(self):
        self.assertEqual(self.resultado[2][0], (0.0, 0.0, 0.0))

    def test_el_tamano_no_cambia(self):
        self.assertEqual(self.resultado[:2], self.nueva[:2])
        self.assertEqual(len(self.resultado[2]), len(self.nueva[2]))

    def test_una_caja_que_ya_tiene_el_color_no_cambia(self):
        caja = _caja((0.55, 0.42, 0.28), 0.20, 5)
        igual = aplicar(ajustar(caja, caja), caja)
        diferencia = max(abs(a - b) for p, q in zip(caja[2], igual[2]) for a, b in zip(p, q))
        self.assertLess(diferencia, 3 / 255)


if __name__ == "__main__":
    unittest.main()
