"""El agujero para colgar: una ventana en la banda de un cierre, con sus paredes."""

import unittest

from lib import cierre_de_envases as ce
from lib.agujero_de_colgar import ANCHO, CENTRO, T_ALTO, T_BAJO, abrir_agujero

LARGO, SALIDA = 0.24, 0.0156


def _cierre():
    return ce.cierre(
        (0.0, 0.0, 0.0), (0.0, 1.0, 0.0), LARGO, (0.0, 0.0, 1.0), SALIDA, (1.0, 0.0, 0.0)
    )


def _punto(s, t, lado):
    return (lado * ce.SEPARACION, s * LARGO, t * SALIDA)


def _area(st):
    return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(st, st[1:] + st[:1]))) / 2


class AgujeroDeColgar(unittest.TestCase):
    def setUp(self):
        self.original = _cierre()
        self.con = abrir_agujero(self.original, _punto)
        self.s0, self.s1 = CENTRO - ANCHO / 2, CENTRO + ANCHO / 2

    def _paredes(self):
        return self.con.caras[len(self.con.caras) - 4 :]

    def test_ninguna_cara_de_la_banda_cubre_la_ventana(self):
        for cara in self.con.caras[: len(self.con.caras) - 4]:
            ss = [s for s, _ in cara.st]
            ts = [t for _, t in cara.st]
            dentro_de_las_filas = min(ts) >= T_BAJO - 1e-9 and max(ts) <= T_ALTO + 1e-9
            cubre = min(ss) < self.s1 - 1e-9 and max(ss) > self.s0 + 1e-9
            self.assertFalse(dentro_de_las_filas and cubre)

    def test_la_banda_pierde_exactamente_el_area_de_la_ventana(self):
        antes = sum(_area(list(c.st)) for c in self.original.caras)
        despues = sum(_area(list(c.st)) for c in self.con.caras[:-4])
        ventana = (self.s1 - self.s0) * (T_ALTO - T_BAJO) * 2
        self.assertAlmostEqual(antes - despues, ventana)

    def test_las_paredes_unen_el_frente_con_el_dorso_y_miran_al_centro_de_la_ventana(self):
        centro = _punto(CENTRO, (T_BAJO + T_ALTO) / 2, 1)
        for cara in self._paredes():
            puntos = [self.con.vertices[i] for i in cara.vertices]
            self.assertEqual(len({p[0] > 0 for p in puntos}), 2)
            a = [puntos[1][j] - puntos[0][j] for j in range(3)]
            b = [puntos[2][j] - puntos[0][j] for j in range(3)]
            normal = (
                a[1] * b[2] - a[2] * b[1],
                a[2] * b[0] - a[0] * b[2],
                a[0] * b[1] - a[1] * b[0],
            )
            medio = [sum(p[j] for p in puntos) / 4 for j in range(3)]
            hacia = sum(normal[j] * (centro[j] - medio[j]) for j in (1, 2))
            self.assertGreater(hacia, 0.0)

    def test_toda_cara_nombra_vertices_que_existen(self):
        for cara in self.con.caras:
            self.assertTrue(all(0 <= i < len(self.con.vertices) for i in cara.vertices))

    def test_la_ventana_cabe_dentro_del_cierre(self):
        with self.assertRaises(ValueError):
            abrir_agujero(self.original, _punto, centro=0.98, ancho=0.2)

    def test_la_aleta_plana_queda_en_tres_franjas_con_la_del_medio_partida(self):
        por_lado = len(self.con.caras[:-4]) // 2
        self.assertEqual(por_lado, 1 + 2 + 1)
        self.assertEqual(self.con.triangulos(), self.original.triangulos() + 12 + 8)
