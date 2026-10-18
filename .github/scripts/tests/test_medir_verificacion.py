import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


RUTA = Path(__file__).resolve().parents[1] / "medir_verificacion.py"
SPEC = importlib.util.spec_from_file_location("medir_verificacion", RUTA)
medir = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(medir)


class MedicionTests(unittest.TestCase):
    def datos_validos(self):
        return {
            "godot": [
                {"fase": "import", "codigo": 0, "wall_s": 1},
                {"fase": "tests", "codigo": 0, "wall_s": 2},
            ],
            "suites": ["test/a_test.gd"],
            "suites_verificadas": 1,
            "casos": 3,
        }

    def test_cantidad_rechaza_fuera_de_la_matriz(self):
        for texto in ("0", "-1", "257"):
            with self.subTest(texto=texto), self.assertRaises(argparse.ArgumentTypeError):
                medir.cantidad(texto)
        self.assertEqual(medir.cantidad("256"), 256)

    def test_matriz_contiene_cada_indice_una_vez(self):
        with patch("builtins.print") as imprimir:
            self.assertEqual(medir.main(["matriz", "4"]), 0)
        self.assertEqual(json.loads(imprimir.call_args.args[0]), {"indice": [0, 1, 2, 3]})

    def test_trabajo_completo_es_valido(self):
        medir.comprobar_trabajo(self.datos_validos())

    def test_cobertura_incompleta_es_roja(self):
        datos = self.datos_validos()
        datos["suites_verificadas"] = 0
        with self.assertRaisesRegex(ValueError, "cobertura incompleta"):
            medir.comprobar_trabajo(datos)

    def test_cero_casos_es_rojo(self):
        datos = self.datos_validos()
        datos["casos"] = 0
        with self.assertRaisesRegex(ValueError, "no ejecutó casos"):
            medir.comprobar_trabajo(datos)

    def test_fallo_del_motor_es_rojo(self):
        datos = self.datos_validos()
        datos["godot"][1]["codigo"] = 17
        with self.assertRaisesRegex(ValueError, "Godot falló"):
            medir.comprobar_trabajo(datos)

    def test_sin_ejecucion_real_es_rojo(self):
        datos = self.datos_validos()
        datos["godot"] = []
        with self.assertRaisesRegex(ValueError, "ejecución real"):
            medir.comprobar_trabajo(datos)
        datos = self.datos_validos()
        datos["godot"][1]["wall_s"] = 0
        with self.assertRaisesRegex(ValueError, "sin trabajo"):
            medir.comprobar_trabajo(datos)

    def test_wrapper_conserva_codigo_y_argumentos_del_motor(self):
        with tempfile.TemporaryDirectory() as carpeta:
            metricas = Path(carpeta) / "godot.jsonl"
            entorno = {"CI_GODOT_REAL": "motor", "CI_GODOT_METRICAS": str(metricas)}
            with patch.dict("os.environ", entorno), patch.object(
                medir, "ejecutar_medido", return_value={"codigo": 17, "wall_s": 1}
            ) as ejecutar:
                self.assertEqual(medir.main(["godot", "--headless", "--import"]), 17)
            ejecutar.assert_called_once_with(["motor", "--headless", "--import"])
            self.assertEqual(json.loads(metricas.read_text())["fase"], "import")

    def test_snapshot_rechaza_ruta_distinta(self):
        with patch.object(Path, "read_text", return_value=json.dumps({
            "workspace": "/otro/workspace", "python": sys.version,
        })):
            with self.assertRaisesRegex(ValueError, "mismo workspace"):
                medir.validar_snapshot()

    def test_worker_conserva_no_cero_y_guarda_metricas_aunque_falte_junit(self):
        raiz = Path.cwd()
        sys.path.insert(0, str(raiz / ".claude/scripts"))
        with tempfile.TemporaryDirectory() as carpeta:
            entorno = {"GODOT_BIN": sys.executable, "RUNNER_TEMP": carpeta}
            try:
                os.chdir(carpeta)
                with patch.dict("os.environ", entorno), patch.object(
                    medir, "identidad", return_value={}
                ), patch.object(medir, "captura", return_value="version"), patch.object(
                    medir, "ejecutar_medido", return_value={"codigo": 17}
                ), patch("lib.archivos.scripts_gd", return_value={"test/a_test.gd": ""}):
                    self.assertEqual(medir.verificar(0, 1, "independiente", "prueba"), 17)
                datos = json.loads(Path("reports/medicion-ci/worker.json").read_text())
                self.assertEqual(datos["codigo"], 17)
                self.assertIn("JUnit", datos["error"])
            finally:
                os.chdir(raiz)


if __name__ == "__main__":
    unittest.main()
