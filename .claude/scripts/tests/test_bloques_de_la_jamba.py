import unittest

from lib.bloques_de_la_jamba import (
    frente_sin_junta_interna,
    orientar_perfil_ccw,
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


if __name__ == "__main__":
    unittest.main()
