"""El cierre de los envases: una aleta plana con dientes de sierra, igual para todos."""

import unittest

from lib.cierre_de_envases import cierre, vector_unitario

EJE = (0.0, 0.0, 1.0)
AFUERA = (0.0, 1.0, 0.0)
NORMAL = (1.0, 0.0, 0.0)


def _normal_de(c, cara):
    p = [c.vertices[i] for i in cara.vertices]
    a = [p[1][j] - p[0][j] for j in range(3)]
    b = [p[2][j] - p[0][j] for j in range(3)]
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


class CierreDeEnvases(unittest.TestCase):
    def _armar(self, **kw):
        return cierre((0.0, 0.1, -0.05), EJE, 0.1, AFUERA, 0.03, NORMAL, **kw)

    def test_la_punta_de_los_dientes_llega_a_la_salida_y_la_costura_al_origen(self):
        c = self._armar(dientes=6)
        ys = [v[1] for v in c.vertices]
        self.assertAlmostEqual(max(ys), 0.1 + 0.03)
        self.assertAlmostEqual(min(ys), 0.1)
        zs = [v[2] for v in c.vertices]
        self.assertAlmostEqual(min(zs), -0.05)
        self.assertAlmostEqual(max(zs), 0.05)

    def test_cada_lado_mira_hacia_su_normal(self):
        c = self._armar()
        for cara in c.caras:
            self.assertGreater(_normal_de(c, cara)[0] * cara.lado, 0.0)

    def test_si_la_terna_es_inversa_las_caras_siguen_mirando_a_su_lado(self):
        c = cierre((0.0, 0.0, 0.0), EJE, 0.1, AFUERA, 0.03, (-1.0, 0.0, 0.0))
        for cara in c.caras:
            self.assertLess(_normal_de(c, cara)[0] * cara.lado, 0.0)

    def test_los_lados_no_se_pisan(self):
        c = self._armar()
        xs = {round(v[0], 6) for v in c.vertices}
        self.assertTrue(all(abs(x) > 0.0019 for x in xs))
        self.assertTrue(any(x > 0 for x in xs) and any(x < 0 for x in xs))

    def test_la_banda_tiene_filas_enteras_y_cada_diente_su_cuadrilatero_y_su_punta(self):
        c = self._armar(dientes=5, surcos=2)
        por_lado = (2 * 2 - 1) + 5 * 2
        self.assertEqual(len(c.caras), por_lado * 2)
        self.assertEqual(c.triangulos(), ((2 * 2 - 1) * 2 + 5 * 2 + 5) * 2)

    def test_los_surcos_salen_del_plano_una_fila_si_y_una_no(self):
        c = self._armar(surcos=2, relieve=0.0015)
        salidas = {round(abs(v[0]) - 0.002, 6) for v in c.vertices}
        self.assertEqual(salidas, {0.0, 0.0015})

    def test_los_st_recorren_el_cuadrado_unidad(self):
        c = self._armar(dientes=4)
        s = [p[0] for cara in c.caras for p in cara.st]
        t = [p[1] for cara in c.caras for p in cara.st]
        self.assertEqual((min(s), max(s)), (0.0, 1.0))
        self.assertEqual((min(t), max(t)), (0.0, 1.0))

    def test_datos_imposibles_se_rechazan(self):
        with self.assertRaises(ValueError):
            self._armar(dientes=0)
        with self.assertRaises(ValueError):
            self._armar(diente=1.0)
        with self.assertRaises(ValueError):
            cierre((0, 0, 0), EJE, 0.0, AFUERA, 0.03, NORMAL)

    def test_un_vector_nulo_no_se_normaliza(self):
        with self.assertRaises(ValueError):
            vector_unitario((0.0, 0.0, 0.0))
        self.assertEqual(vector_unitario((0.0, 3.0, 0.0)), (0.0, 1.0, 0.0))


if __name__ == "__main__":
    unittest.main()
