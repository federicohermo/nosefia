import unittest

from lib.bloques_de_la_jamba import (
    frente_sin_junta_interna,
    orientar_perfil_ccw,
    revestimiento_conectado,
    techo_lineal,
)


class BloquesDeLaJamba(unittest.TestCase):
    def test_frente_sin_junta_interna_conserva_proyeccion_de_pared_si_no_cruza_junta(self):
        # Bloque de 0.40 m, junta en 0.26 m desde el borde, inicio en -0.03 m -> s_prev = -0.14 < -0.03
        u_de = frente_sin_junta_interna(
            u_borde=-10.527,
            sentido=1,
            junta=0.2607,
            inicio_frente=-0.03,
            ancho_bloque=0.40,
            junta_h=0.0103125,
        )
        self.assertIsNone(u_de)

    def test_frente_sin_junta_interna_estira_el_mismo_bloque_si_cruza_junta_cerca_del_borde(self):
        # Caso real puerta_sur derecha h=11: junta=0.3941, s_prev=-0.0059 cae dentro de [-0.03, 0.389]
        u_borde = -10.527
        junta = 0.3941
        junta_h = 0.0103125
        brazo = junta - junta_h / 2
        u_de = frente_sin_junta_interna(
            u_borde=u_borde,
            sentido=1,
            junta=junta,
            inicio_frente=-0.03,
            ancho_bloque=0.40,
            junta_h=junta_h,
        )
        self.assertIsNotNone(u_de)
        # En el extremo libre (brazo) coincide exactamente con la pared
        self.assertAlmostEqual(u_de(brazo), u_borde + brazo)
        # En el borde de la jamba (-0.03) termina justo antes de la junta anterior (sin cruzarla)
        self.assertAlmostEqual(u_de(-0.03), u_borde + junta - 0.40 + junta_h / 2)
        # El recorrido total en U es menor a un bloque completo: no hay ninguna junta interna
        self.assertLess(abs(u_de(brazo) - u_de(-0.03)), 0.40)

    def test_orientar_perfil_ccw_mantiene_sentido_antihorario_en_perfil_no_convexo(self):
        # Perfil en L con escalón (no convexo), dado en sentido horario
        horario = [(0.34, 0.0), (0.20, 0.0), (0.0, 0.0), (0.0, -0.26), (-0.03, -0.26),
                   (-0.03, 0.03), (0.20, 0.03), (0.20, 0.01), (0.34, 0.01)]
        resultado = orientar_perfil_ccw(horario)
        area2 = sum(
            a[0] * b[1] - b[0] * a[1]
            for a, b in zip(resultado, resultado[1:] + resultado[:1])
        )
        self.assertGreater(area2, 0.0)

    def test_revestimiento_conectado_forma_una_sola_componente_sin_uniones_en_t(self):
        vertices, caras = revestimiento_conectado(
            x=8.083,
            y_min=12.46,
            y_hueco_min=13.14,
            y_hueco_max=14.78,
            y_max=15.46,
            z_piso=0.10,
            z_dintel=2.72,
            z_techo=3.12,
        )
        # Sin vértices duplicados
        redondeados = {(round(v[0], 6), round(v[1], 6), round(v[2], 6)) for v in vertices}
        self.assertEqual(len(redondeados), len(vertices))
        # Todas las caras miran hacia +X y forman una sola componente conexa
        vecinos = {i: set() for i in range(len(caras))}
        aristas = {}
        for idx, cara in enumerate(caras):
            a, b, c = (vertices[i] for i in cara[:3])
            nx = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
            self.assertGreater(nx, 0.0)
            for k in range(len(cara)):
                e = tuple(sorted((cara[k], cara[(k + 1) % len(cara)])))
                for previo in aristas.get(e, ()):
                    vecinos[idx].add(previo)
                    vecinos[previo].add(idx)
                aristas.setdefault(e, []).append(idx)
        visitadas = set()
        pendientes = [0]
        while pendientes:
            actual = pendientes.pop()
            if actual not in visitadas:
                visitadas.add(actual)
                pendientes.extend(vecinos[actual] - visitadas)
        self.assertEqual(len(visitadas), len(caras))
        # Ningún vértice cae en el interior de una arista ajena (sin uniones en T)
        for v_idx, p in enumerate(vertices):
            for u, w in aristas:
                if v_idx in (u, w):
                    continue
                pu, pw = vertices[u], vertices[w]
                dy, dz = pw[1] - pu[1], pw[2] - pu[2]
                largo2 = dy * dy + dz * dz
                t = ((p[1] - pu[1]) * dy + (p[2] - pu[2]) * dz) / largo2
                if 1e-6 < t < 1.0 - 1e-6:
                    dist2 = (p[1] - (pu[1] + t * dy)) ** 2 + (p[2] - (pu[2] + t * dz)) ** 2
                    self.assertGreater(dist2, 1e-10)

    def test_techo_lineal_interpola_pendiente_y_conserva_extremos(self):
        z_en = techo_lineal(8.08, 3.118, 10.80, 2.868)
        self.assertAlmostEqual(z_en(8.08), 3.118)
        self.assertAlmostEqual(z_en(10.80), 2.868)
        self.assertAlmostEqual(z_en(9.44), 2.993)


if __name__ == "__main__":
    unittest.main()
