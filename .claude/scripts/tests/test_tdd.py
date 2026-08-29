"""Los tests de `lib/tdd.py`: el espejo, la aserción, el apagado y el nombre.

Las cuatro reglas cierran cuatro formas distintas de la misma cosa —verde sin ejercer nada—,
así que cada una tiene su caso y su contracaso.
"""

import unittest

from lib.tdd import funciones_de_test, ruta_de_test, violaciones

CAPAS = ("src/dominio", "src/sistemas")
TESTS = "test"


def hallazgos(scripts, tests):
    return violaciones(scripts, tests, CAPAS, TESTS)


class RutaDeTest(unittest.TestCase):
    def test_el_espejo(self):
        self.assertEqual(ruta_de_test("src/dominio/turno.gd", CAPAS, TESTS),
                         "test/dominio/turno_test.gd")

    def test_conserva_los_subdirectorios(self):
        self.assertEqual(ruta_de_test("src/dominio/tareas/limpiar.gd", CAPAS, TESTS),
                         "test/dominio/tareas/limpiar_test.gd")

    def test_una_capa_sin_test_obligatorio_devuelve_none(self):
        self.assertIsNone(ruta_de_test("src/ui/hud.gd", CAPAS, TESTS))

    def test_normaliza_las_barras_de_windows(self):
        self.assertEqual(ruta_de_test("src\\dominio\\turno.gd", CAPAS, TESTS),
                         "test/dominio/turno_test.gd")


class ReglaDelEspejo(unittest.TestCase):
    def test_un_script_de_dominio_sin_test_es_hallazgo(self):
        encontrados = hallazgos({"src/dominio/turno.gd": "extends RefCounted\n"}, {})
        self.assertEqual(len(encontrados), 1)
        self.assertIn("test/dominio/turno_test.gd", encontrados[0][1])

    def test_con_su_test_no_lo_es(self):
        encontrados = hallazgos(
            {"src/dominio/turno.gd": "extends RefCounted\n"},
            {"test/dominio/turno_test.gd": "func test_algo():\n\tassert_int(1).is_equal(1)\n"},
        )
        self.assertEqual(encontrados, [])

    def test_la_ui_no_necesita_test(self):
        # Ahí el test necesita el `scene_runner` y un frame de verdad; exigirlo por gate
        # empujaría a escribir tests de humo que pasan sin ejercer nada — peor que no
        # tenerlos, porque además mienten.
        self.assertEqual(hallazgos({"src/ui/hud.gd": "extends Control\n"}, {}), [])


class ReglaDeLaAsercion(unittest.TestCase):
    def test_un_test_sin_asercion_es_hallazgo(self):
        encontrados = hallazgos({}, {"test/dominio/turno_test.gd": "func test_algo():\n\tpass\n"})
        self.assertEqual(len(encontrados), 1)
        self.assertIn("no tiene una sola aserción", encontrados[0][1])

    def test_cada_funcion_se_mira_por_separado(self):
        # Sin el corte por función, un archivo con un test que afirma y otro que no daría
        # verde entero por el primero.
        texto = (
            "func test_uno():\n\tassert_int(1).is_equal(1)\n\n"
            "func test_dos():\n\tvar x = 2\n"
        )
        encontrados = hallazgos({}, {"test/dominio/turno_test.gd": texto})
        self.assertEqual(len(encontrados), 1)
        self.assertIn("test_dos", encontrados[0][1])

    def test_una_funcion_que_no_es_test_no_necesita_asertar(self):
        texto = "func before_test():\n\tpass\n\nfunc test_uno():\n\tassert_bool(true).is_true()\n"
        self.assertEqual(hallazgos({}, {"test/dominio/turno_test.gd": texto}), [])

    def test_un_archivo_de_test_sin_una_sola_funcion_es_hallazgo(self):
        # Es la misma mentira un nivel más arriba: el archivo existe, la regla del espejo lo
        # da por cumplido, y no ejerce nada.
        encontrados = hallazgos({}, {"test/dominio/turno_test.gd": "extends GdUnitTestSuite\n"})
        self.assertEqual(len(encontrados), 1)
        self.assertIn("sin una sola", encontrados[0][1])


class ReglaDelApagado(unittest.TestCase):
    def test_assert_not_yet_implemented_no_cuenta_como_asercion(self):
        texto = "func test_algo():\n\tassert_not_yet_implemented()\n"
        encontrados = hallazgos({}, {"test/dominio/turno_test.gd": texto})
        self.assertEqual(len(encontrados), 1)
        self.assertIn("apagado", encontrados[0][1])

    def test_un_skip_es_hallazgo(self):
        texto = "func test_algo():\n\tskip(true)\n\tassert_int(1).is_equal(2)\n"
        encontrados = hallazgos({}, {"test/dominio/turno_test.gd": texto})
        self.assertEqual(len(encontrados), 1)
        self.assertIn("apagado", encontrados[0][1])

    def test_el_apagado_gana_sobre_la_falta_de_asercion(self):
        # Decir «está apagado» es más útil que decir «no afirma nada», que es la consecuencia
        # y no la causa.
        texto = "func test_algo():\n\tskip(true)\n"
        encontrados = hallazgos({}, {"test/dominio/turno_test.gd": texto})
        self.assertEqual(len(encontrados), 1)
        self.assertIn("apagado", encontrados[0][1])


class ReglaDelNombre(unittest.TestCase):
    def test_un_test_en_un_archivo_mal_nombrado_es_hallazgo(self):
        # No corre y no se queja: la suite pasa y el archivo con los tests está ahí, a la
        # vista, dando la impresión contraria.
        encontrados = hallazgos(
            {}, {"test/dominio/ayudas.gd": "func test_algo():\n\tassert_int(1).is_equal(1)\n"}
        )
        self.assertEqual(len(encontrados), 1)
        self.assertIn("no se descubre", encontrados[0][1])

    def test_un_ayudante_sin_tests_no_es_hallazgo(self):
        self.assertEqual(hallazgos({}, {"test/ayudas/tablero.gd": "class_name Tablero\n"}), [])


class FuncionesDeTest(unittest.TestCase):
    def test_corta_el_cuerpo_en_la_funcion_siguiente(self):
        texto = "func test_uno():\n\tassert_int(1)\n\nfunc otra():\n\tpass\n"
        funciones = funciones_de_test(texto)
        self.assertEqual(len(funciones), 1)
        self.assertNotIn("otra", funciones[0][1])

    def test_la_ultima_funcion_llega_hasta_el_final(self):
        texto = "func otra():\n\tpass\n\nfunc test_uno():\n\tassert_int(1)\n"
        self.assertIn("assert_int", funciones_de_test(texto)[0][1])


if __name__ == "__main__":
    unittest.main()
