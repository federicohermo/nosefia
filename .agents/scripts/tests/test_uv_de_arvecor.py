"""Comportamiento de la corrección de material y UV de la lata de Arvecor."""

import math
import unittest

from lib.uv_de_arvecor import (
    Cara,
    U_PLATEADO,
    V_PLATEADO,
    V_SUPERIOR_ETIQUETA,
    alinear_banda_superior,
    corregir_franja_metalica,
    es_cara_del_cuerpo_cilindrico,
)


def _anillo(radio: float, z: float, lados: int) -> list[tuple[float, float, float]]:
    return [
        (radio * math.cos(2 * math.pi * i / lados), radio * math.sin(2 * math.pi * i / lados), z)
        for i in range(lados)
    ]


def _cilindro_en_dos_bandas(
    lados: int = 8, radio: float = 0.06
) -> tuple[list[tuple[float, float, float]], list[Cara], list[Cara]]:
    """Dos bandas cilíndricas apiladas sobre el mismo radio, con la superior rota en dos caras."""
    vertices = (
        _anillo(radio, 0.0, lados)
        + _anillo(radio, 0.10, lados)
        + _anillo(radio, 0.11, lados)
    )
    inferiores: list[Cara] = []
    superiores: list[Cara] = []
    u_min, u_max = 0.02, 0.98
    for i in range(lados):
        j = (i + 1) % lados
        u0 = u_min + (u_max - u_min) * i / lados
        u1 = u_min + (u_max - u_min) * (i + 1) / lados
        v_abajo = (i, j, lados + j, lados + i)
        inferiores.append(
            Cara(i, v_abajo, ((u0, 0.04), (u1, 0.04), (u1, 0.48), (u0, 0.48)))
        )
        # Dos caras desplazadas al borde opuesto, como las caras rotas del modelo real.
        su0, su1 = (0.02, 0.05) if i in (2, 3) else (u0 + 0.0004, u1 + 0.0004)
        v_arriba = (lados + i, lados + j, 2 * lados + j, 2 * lados + i)
        superiores.append(
            Cara(100 + i, v_arriba, ((su0, 0.481), (su1, 0.481), (su1, 0.517), (su0, 0.517)))
        )
    return vertices, inferiores, superiores


class ParticionDeMateriales(unittest.TestCase):
    def test_distingue_cuerpo_cilindrico_de_hombro_cuello_y_tapas(self):
        lados = 8
        radio_cuerpo = 0.06
        radio_cuello = 0.045
        vertices = (
            _anillo(radio_cuerpo, 0.0, lados)
            + _anillo(radio_cuerpo, 0.10, lados)
            + _anillo(radio_cuerpo, 0.11, lados)
            + _anillo(radio_cuello, 0.125, lados)
            + _anillo(radio_cuello, 0.14, lados)
        )
        cuerpo_bajo = (0, 1, lados + 1, lados)
        cuerpo_alto = (lados, lados + 1, 2 * lados + 1, 2 * lados)
        hombro = (2 * lados, 2 * lados + 1, 3 * lados + 1, 3 * lados)
        cuello = (3 * lados, 3 * lados + 1, 4 * lados + 1, 4 * lados)
        tapa = tuple(range(4 * lados, 5 * lados))

        self.assertTrue(es_cara_del_cuerpo_cilindrico(vertices, cuerpo_bajo, radio_cuerpo))
        self.assertTrue(es_cara_del_cuerpo_cilindrico(vertices, cuerpo_alto, radio_cuerpo))
        self.assertFalse(es_cara_del_cuerpo_cilindrico(vertices, hombro, radio_cuerpo))
        self.assertFalse(es_cara_del_cuerpo_cilindrico(vertices, cuello, radio_cuerpo))
        self.assertFalse(es_cara_del_cuerpo_cilindrico(vertices, tapa, radio_cuerpo))


class ContinuidadDeLaBandaSuperior(unittest.TestCase):
    def test_cada_cara_superior_continua_u_y_v_desde_su_vecina_inferior(self):
        vertices, inferiores, superiores = _cilindro_en_dos_bandas()
        corregidas = alinear_banda_superior(
            vertices, inferiores, superiores, v_superior=V_SUPERIOR_ETIQUETA
        )

        por_arista = {
            frozenset((cara.vertices[2], cara.vertices[3])): cara for cara in inferiores
        }
        for cara in corregidas:
            arista = frozenset((cara.vertices[0], cara.vertices[1]))
            inferior = por_arista[arista]
            uv_inf = dict(zip(inferior.vertices, inferior.uvs))
            uv_sup = dict(zip(cara.vertices, cara.uvs))
            for vertice in arista:
                self.assertAlmostEqual(uv_sup[vertice][0], uv_inf[vertice][0], places=6)
                self.assertAlmostEqual(uv_sup[vertice][1], uv_inf[vertice][1], places=6)
            for vertice, (_, v) in zip(cara.vertices, cara.uvs):
                if vertice not in arista:
                    self.assertAlmostEqual(v, V_SUPERIOR_ETIQUETA, places=6)

    def test_las_caras_vecinas_de_la_banda_superior_no_saltan_salvo_en_la_costura(self):
        vertices, inferiores, superiores = _cilindro_en_dos_bandas(lados=12)
        corregidas = alinear_banda_superior(
            vertices, inferiores, superiores, v_superior=V_SUPERIOR_ETIQUETA
        )

        saltos = 0
        for indice, actual in enumerate(corregidas):
            siguiente = corregidas[(indice + 1) % len(corregidas)]
            u_der = actual.uvs[1][0]
            u_izq = siguiente.uvs[0][0]
            if abs(u_der - u_izq) > 1e-6:
                saltos += 1
        self.assertEqual(saltos, 1)

    def test_es_idempotente(self):
        vertices, inferiores, superiores = _cilindro_en_dos_bandas()
        primera = alinear_banda_superior(
            vertices, inferiores, superiores, v_superior=V_SUPERIOR_ETIQUETA
        )
        segunda = alinear_banda_superior(
            vertices, inferiores, primera, v_superior=V_SUPERIOR_ETIQUETA
        )
        self.assertEqual(primera, segunda)

    def test_falla_si_una_cara_superior_no_comparte_arista_con_la_banda_inferior(self):
        vertices, inferiores, superiores = _cilindro_en_dos_bandas()
        vertices.append((0.06, 0.0, 0.105))
        vertices.append((0.06, 0.01, 0.105))
        desconectada = Cara(999, (len(vertices) - 2, len(vertices) - 1, 17, 16), ((0, 0),) * 4)
        with self.assertRaises(ValueError):
            alinear_banda_superior(
                vertices, inferiores, superiores + [desconectada], V_SUPERIOR_ETIQUETA
            )


class FranjaMetalicaSuperior(unittest.TestCase):
    def test_el_cuello_sale_con_area_positiva_y_dentro_de_la_franja_plateada(self):
        lados = 8
        vertices = (
            _anillo(0.06, 0.09, lados)
            + _anillo(0.045, 0.103, lados)
            + _anillo(0.045, 0.117, lados)
        )
        hombro: list[Cara] = []
        cuello: list[Cara] = []
        for i in range(lados):
            j = (i + 1) % lados
            # Primera cara se sale en U y V (como p95 y el borde bajo del hombro real).
            u0 = 0.013 if i == 0 else U_PLATEADO[0] + (U_PLATEADO[1] - U_PLATEADO[0]) * i / lados
            u1 = U_PLATEADO[0] + (U_PLATEADO[1] - U_PLATEADO[0]) * (i + 1) / lados
            v_sup = 0.548 if i == 1 else 0.540
            hombro.append(
                Cara(
                    i,
                    (i, j, lados + j, lados + i),
                    ((u0, 0.517), (u1, 0.517), (u1, v_sup), (u0, v_sup)),
                )
            )
            # Cuello degenerado: los vertices de arriba y abajo tienen la misma UV (area cero).
            cuello.append(
                Cara(
                    50 + i,
                    (lados + i, lados + j, 2 * lados + j, 2 * lados + i),
                    ((0.2, 0.96), (0.25, 0.95), (0.25, 0.95), (0.2, 0.96)),
                )
            )

        hombro_ok, cuello_ok = corregir_franja_metalica(
            vertices, hombro, cuello, u_rango=U_PLATEADO, v_rango=V_PLATEADO
        )

        for cara in hombro_ok + cuello_ok:
            for u, v in cara.uvs:
                self.assertGreaterEqual(u, U_PLATEADO[0] - 1e-6)
                self.assertLessEqual(u, U_PLATEADO[1] + 1e-6)
                self.assertGreaterEqual(v, V_PLATEADO[0] - 1e-6)
                self.assertLessEqual(v, V_PLATEADO[1] + 1e-6)

        for cara in cuello_ok:
            us = [p[0] for p in cara.uvs]
            vs = [p[1] for p in cara.uvs]
            area = abs(sum(us[k] * vs[(k + 1) % 4] - us[(k + 1) % 4] * vs[k] for k in range(4))) / 2
            self.assertGreater(area, 1e-4)

        hombro_2, cuello_2 = corregir_franja_metalica(
            vertices, hombro_ok, cuello_ok, u_rango=U_PLATEADO, v_rango=V_PLATEADO
        )
        self.assertEqual((hombro_ok, cuello_ok), (hombro_2, cuello_2))


if __name__ == "__main__":
    unittest.main()
