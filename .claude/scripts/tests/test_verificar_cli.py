"""Consultar la ayuda o errar una opción nunca debe arrancar Godot.

En el lote del 2026-10-13, dos carriles pidieron `--help` y lanzaron la suite completa.
Se sustituyen todos los nodos para ejercer el cableado sin procesos externos.
"""

import io
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest import mock

import verificar


class ArgumentosDeVerificar(unittest.TestCase):
    def setUp(self):
        self.harness = self._nodo("harness")
        self.tests = self._nodo("tests")
        parche = mock.patch.object(verificar, "NODOS", (self.harness, self.tests))
        parche.start()
        self.addCleanup(parche.stop)
        self.salida = io.StringIO()
        self.errores = io.StringIO()

    def _nodo(self, nombre):
        nodo = mock.Mock(return_value=verificar.Resultado(nombre, 0, "", 0.0))
        nodo.__name__ = "nodo_" + nombre
        return nodo

    def _ejecutar(self, argumentos):
        with redirect_stdout(self.salida), redirect_stderr(self.errores):
            with self.assertRaises(SystemExit) as salida:
                verificar.main(argumentos)
        return salida.exception.code

    def _ningun_nodo_corrio(self):
        self.harness.assert_not_called()
        self.tests.assert_not_called()

    def test_ayuda_explica_las_opciones_sin_correr_nodos(self):
        self.assertEqual(self._ejecutar(["--help"]), 0)
        self.assertIn("--solo", self.salida.getvalue())
        self.assertIn("harness", self.salida.getvalue())
        self.assertIn("tests", self.salida.getvalue())
        self.assertEqual(self.errores.getvalue(), "")
        self._ningun_nodo_corrio()

    def test_una_opcion_desconocida_o_abreviada_no_arranca_la_suite(self):
        for argumentos in (["--desconocido"], ["--sol", "tests"], ["tests"]):
            with self.subTest(argumentos=argumentos):
                self.assertEqual(self._ejecutar(argumentos), 2)
                self._ningun_nodo_corrio()
        self.assertNotEqual(self.errores.getvalue(), "")

    def test_un_nodo_inexistente_falla_antes_de_correr(self):
        self.assertEqual(self._ejecutar(["--solo", "ausente"]), 2)
        self.assertIn("ausente", self.errores.getvalue())
        self._ningun_nodo_corrio()

    def test_solo_sin_valor_falla_sin_traceback_ni_nodos(self):
        self.assertEqual(self._ejecutar(["--solo"]), 2)
        self.assertIn("--solo", self.errores.getvalue())
        self.assertNotIn("Traceback", self.errores.getvalue())
        self._ningun_nodo_corrio()

    def test_solo_no_acepta_una_lista_con_comas(self):
        self.assertEqual(self._ejecutar(["--solo", "harness,tests"]), 2)
        self._ningun_nodo_corrio()

    def test_solo_tests_ejecuta_unicamente_el_nodo_pedido(self):
        self.assertEqual(self._ejecutar(["--solo", "tests"]), 0)
        self.tests.assert_called_once_with()
        self.harness.assert_not_called()
        self.assertIn("1/1 nodos en verde", self.salida.getvalue())

    def test_sin_opciones_conserva_la_corrida_completa(self):
        self.assertEqual(self._ejecutar([]), 0)
        self.harness.assert_called_once_with()
        self.tests.assert_called_once_with()
        self.assertIn("2/2 nodos en verde", self.salida.getvalue())

    def test_sin_opciones_un_nodo_rojo_falla_sin_omitir_los_demas(self):
        self.harness.return_value = verificar.Resultado("harness", 1, "fallo esperado", 0.0)
        self.assertEqual(self._ejecutar([]), 1)
        self.harness.assert_called_once_with()
        self.tests.assert_called_once_with()
        self.assertIn("fallo esperado", self.salida.getvalue())
        self.assertIn("1/2 nodos en verde", self.salida.getvalue())
        self.assertIn("1 falló", self.salida.getvalue())

    def test_sin_opciones_un_salteado_sigue_contandose_aparte(self):
        self.harness.return_value = verificar.Resultado(
            "harness", 0, "no hay nada que mirar", 0.0, salteado=True
        )
        self.assertEqual(self._ejecutar([]), 0)
        self.harness.assert_called_once_with()
        self.tests.assert_called_once_with()
        self.assertIn("no hay nada que mirar", self.salida.getvalue())
        self.assertIn("1/2 nodos en verde", self.salida.getvalue())
        self.assertIn("1 salteado", self.salida.getvalue())


if __name__ == "__main__":
    unittest.main()
