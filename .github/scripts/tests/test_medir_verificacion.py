import argparse
import importlib.util
import json
import os
from pathlib import Path
import platform
import sys
import tempfile
import unittest
from unittest.mock import patch


RUTA = Path(__file__).resolve().parents[1] / "medir_verificacion.py"
SPEC = importlib.util.spec_from_file_location("medir_verificacion", RUTA)
medir = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(medir)


class MedicionTests(unittest.TestCase):
    NATIVO = {"receta_sha256": "a" * 64, "binario_sha256": "b" * 64,
              "plataforma": "linux-x86_64", "archivos": {"Godot_v4": "b" * 64}}

    def setUp(self):
        nativo = patch.object(medir, "validar_motor", return_value=self.NATIVO)
        self.nativo = nativo.start()
        self.addCleanup(nativo.stop)

    def snapshot_importaciones(self):
        return {
            "tipo": "importaciones", "workspace": str(Path.cwd()), "python": "otro Python",
            "sistema": platform.system(), "arquitectura": platform.machine(),
            "godot_version": "4.x.stable", "commit": "commit-preparado",
            "motor_nativo": self.NATIVO,
            "arbol_juego": {"src": "arbol-src", "test": "arbol-test", "assets": "arbol-assets"},
        }

    def captura_snapshot(self, *comando):
        return {
            ("motor-worker", "--version"): "4.x.stable",
            ("git", "rev-parse", "HEAD"): "commit-preparado",
            ("git", "rev-parse", "HEAD:src"): "arbol-src",
            ("git", "rev-parse", "HEAD:test"): "arbol-test",
            ("git", "rev-parse", "HEAD:assets"): "arbol-assets",
        }[comando]

    def datos_validos(self):
        return {
            "godot": [
                {"fase": "import", "codigo": 0, "wall_s": 1},
                {"fase": "tests", "codigo": 0, "wall_s": 2},
            ],
            "suites": ["test/a_test.gd"],
            "grupos": [{"nombre": "normal", "suites": ["test/a_test.gd"], "fps_fijos": None}],
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

    def test_dos_grupos_requieren_dos_ejecuciones_reales(self):
        datos = self.datos_validos()
        datos["grupos"].append({"nombre": "fisica60", "suites": ["test/b_test.gd"], "fps_fijos": 60})
        datos["suites"].append("test/b_test.gd")
        datos["suites_verificadas"] = 2
        datos["casos"] = 4
        with self.assertRaisesRegex(ValueError, "ejecución real"):
            medir.comprobar_trabajo(datos)
        datos["godot"].append({"fase": "tests", "codigo": 0, "wall_s": 1})
        medir.comprobar_trabajo(datos)
        datos["godot"][-1]["codigo"] = 100
        with self.assertRaisesRegex(ValueError, "Godot falló"):
            medir.comprobar_trabajo(datos)

    def test_una_importacion_extra_o_un_plan_vacio_no_es_trabajo_completo(self):
        for cambio in ("import", "vacio"):
            datos = self.datos_validos()
            if cambio == "import":
                datos["godot"].append({"fase": "import", "codigo": 0, "wall_s": 1})
            else:
                datos["grupos"] = []
            with self.subTest(cambio=cambio), self.assertRaisesRegex(ValueError, "ejecución real"):
                medir.comprobar_trabajo(datos)

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
            "tipo": "completo", "workspace": "/otro/workspace", "python": sys.version,
        })):
            with self.assertRaisesRegex(ValueError, "mismo workspace"):
                medir.validar_snapshot()

    def test_importaciones_valida_motor_del_worker_sin_requerir_venv(self):
        with patch.object(Path, "read_text", return_value=json.dumps(
            self.snapshot_importaciones()
        )), patch.dict("os.environ", {"GODOT_BIN": "motor-worker"}), patch.object(
            medir, "captura", side_effect=self.captura_snapshot
        ) as captura:
            self.assertEqual(medir.validar_snapshot("importaciones"), 0)
        captura.assert_any_call("motor-worker", "--version")

    def test_importaciones_rechaza_snapshot_incompatible(self):
        diferencias = (
            ("tipo", "completo", "tipo de snapshot"),
            ("workspace", "/otro/workspace", "mismo workspace"),
            ("sistema", "otro sistema", "mismo sistema"),
            ("arquitectura", "otra arquitectura", "arquitectura"),
            ("godot_version", "otro motor", "motor no coincide"),
            ("motor_nativo", self.NATIVO | {"receta_sha256": "c" * 64}, "identidad nativa"),
            ("motor_nativo", self.NATIVO | {
                "archivos": self.NATIVO["archivos"] | {"motor.dll": "d" * 64},
            }, "identidad nativa"),
            ("commit", "otro-commit", "commit empaquetado"),
            ("arbol_juego", {"src": "otro-arbol"}, "árbol src"),
        )
        for campo, valor, mensaje in diferencias:
            datos = self.snapshot_importaciones() | {campo: valor}
            with self.subTest(campo=campo), patch.object(
                Path, "read_text", return_value=json.dumps(datos)
            ), patch.dict("os.environ", {"GODOT_BIN": "motor-worker"}), patch.object(
                medir, "captura", side_effect=self.captura_snapshot
            ), self.assertRaisesRegex(ValueError, mensaje):
                medir.validar_snapshot("importaciones")

    def test_snapshot_y_git_coherentes_rechazan_commit_objetivo_distinto(self):
        with patch.object(Path, "read_text", return_value=json.dumps(
            self.snapshot_importaciones()
        )), patch.dict("os.environ", {
            "GODOT_BIN": "motor-worker", "CI_COMMIT_ESPERADO": "otro-commit",
        }), patch.object(medir, "captura", side_effect=self.captura_snapshot):
            with self.assertRaisesRegex(ValueError, "commit objetivo externo"):
                medir.validar_snapshot("importaciones")

    def test_snapshot_sin_identidad_nativa_no_se_acepta_por_version_coincidente(self):
        datos = self.snapshot_importaciones()
        del datos["motor_nativo"]
        with patch.object(Path, "read_text", return_value=json.dumps(datos)), (
            patch.dict("os.environ", {"GODOT_BIN": "motor-worker"})
        ), patch.object(medir, "captura", side_effect=self.captura_snapshot), (
            self.assertRaisesRegex(ValueError, "identidad nativa")
        ):
            medir.validar_snapshot("importaciones")

    def test_snapshot_no_ejecuta_un_motor_que_no_pasa_su_validacion(self):
        self.nativo.side_effect = ValueError("oficial sin parche")
        with patch.object(Path, "read_text", return_value=json.dumps(
            self.snapshot_importaciones()
        )), patch.dict("os.environ", {"GODOT_BIN": "oficial"}), patch.object(
            medir, "captura"
        ) as capturar, self.assertRaisesRegex(ValueError, "sin parche"):
            medir.validar_snapshot("importaciones")
        capturar.assert_not_called()

    def test_preparador_rechaza_oficial_antes_de_importar(self):
        self.nativo.side_effect = ValueError("oficial sin parche")
        with patch.object(medir, "identidad", return_value={}), (
            patch.dict("os.environ", {"GODOT_BIN": "oficial"})
        ), patch.object(medir, "ejecutar_medido") as ejecutar, (
            self.assertRaisesRegex(ValueError, "sin parche")
        ):
            medir.preparar()
        ejecutar.assert_not_called()

    def test_worker_rechaza_oficial_antes_de_crear_o_usar_wrapper(self):
        self.nativo.side_effect = ValueError("oficial sin parche")
        anterior = Path.cwd()
        with tempfile.TemporaryDirectory() as carpeta:
            try:
                os.chdir(carpeta)
                with (
                    patch.dict("os.environ", {"GODOT_BIN": "oficial", "RUNNER_TEMP": carpeta}),
                    patch.object(medir, "identidad", return_value={}),
                    patch.object(medir, "ejecutar_medido") as ejecutar,
                    patch("lib.archivos.scripts_gd", return_value={"test/a_test.gd": ""}),
                ):
                    self.assertEqual(medir.verificar(0, 1, "independiente", "prueba"), 1)
                    self.assertEqual(os.environ["GODOT_BIN"], "oficial")
                ejecutar.assert_not_called()
                self.assertFalse(Path("godot-medido").exists())
                datos = json.loads(Path("reports/medicion-ci/worker.json").read_text())
                self.assertIn("sin parche", datos["error"])
            finally:
                os.chdir(anterior)

    def test_importaciones_empaqueta_cache_y_manifest_sin_fuentes_git_ni_herramientas(self):
        raiz = Path.cwd()
        with tempfile.TemporaryDirectory() as carpeta:
            try:
                os.chdir(carpeta)
                incluidos = (
                    ".godot/imported/modelo.glb-md5.mesh",
                    ".godot/imported/modelo.glb-md5.md5",
                    ".godot/editor/filesystem_cache10",
                    ".godot/global_script_class_cache.cfg", ".godot/uid_cache.bin",
                    ".ci-tools/snapshot.json",
                )
                excluidos = (
                    "src/modelo.gd", ".git/config", ".ci-tools/python/bin/python",
                    ".ci-tools/godot/Godot_v4", ".godot/editor/proyecto.godot-folding",
                )
                for nombre in incluidos + excluidos:
                    ruta = Path(nombre)
                    ruta.parent.mkdir(parents=True, exist_ok=True)
                    ruta.touch()
                entradas = medir.nombres_snapshot("importaciones").decode().split("\0")[:-1]
                archivos = set()
                for entrada in entradas:
                    ruta = Path(entrada)
                    archivos.update(
                        archivo.as_posix() for archivo in (
                            ruta.rglob("*") if ruta.is_dir() else [ruta]
                        ) if archivo.is_file()
                    )
                self.assertEqual(archivos, set(incluidos))
            finally:
                os.chdir(raiz)

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

    def test_worker_exige_el_plan_actual_y_un_xml_por_grupo(self):
        raiz = Path.cwd()
        sys.path.insert(0, str(raiz / ".claude/scripts"))
        fisica = "test/escenas/agarre_fisico_test.gd"
        grupos = [
            {"nombre": "normal", "suites": ["test/a_test.gd"], "fps_fijos": None},
            {"nombre": "fisica60", "suites": [fisica], "fps_fijos": 60},
        ]
        for modo in ("completo", "ausente", "plan_distinto", "duplicado"):
            with self.subTest(modo=modo), tempfile.TemporaryDirectory() as carpeta:
                try:
                    os.chdir(carpeta)
                    reportes = Path("reports/particion-0-de-1-nueva")
                    reportes.mkdir(parents=True)
                    plan = grupos[:1] if modo == "plan_distinto" else grupos
                    (reportes / "grupos.json").write_text(json.dumps(plan), encoding="utf-8")
                    for grupo, nombre, paquete in (
                        ("normal", "a_test", "test"),
                        ("fisica60", "agarre_fisico_test", "test/escenas"),
                    ):
                        if modo == "ausente" and grupo == "fisica60":
                            continue
                        destino = reportes / grupo / "report_1"
                        destino.mkdir(parents=True)
                        xml = (
                            f'<testsuites><testsuite name="{nombre}" package="{paquete}" tests="1">'
                            '<testcase name="test_regla" /></testsuite></testsuites>'
                        )
                        (destino / "results.xml").write_text(xml, encoding="utf-8")
                        if modo == "duplicado" and grupo == "normal":
                            (destino.parent / "results.xml").write_text(xml, encoding="utf-8")
                    metricas = Path("reports/medicion-ci/godot.jsonl")
                    metricas.parent.mkdir()

                    def ejecutar(*args):
                        datos = [
                            {"fase": fase, "codigo": 0, "wall_s": 1}
                            for fase in ("import", "tests", "tests")
                        ]
                        metricas.write_text("\n".join(map(json.dumps, datos)), encoding="utf-8")
                        return {"codigo": 0}

                    with (
                        patch.dict("os.environ", {"GODOT_BIN": sys.executable, "RUNNER_TEMP": carpeta}),
                        patch.object(medir, "identidad", return_value={}),
                        patch.object(medir, "captura", return_value="version"),
                        patch.object(medir, "ejecutar_medido", side_effect=ejecutar),
                        patch("lib.archivos.scripts_gd", return_value=dict.fromkeys(["test/a_test.gd", fisica])),
                    ):
                        codigo = medir.verificar(0, 1, "independiente", "prueba")
                    self.assertEqual(codigo, 0 if modo == "completo" else 1)
                    datos = json.loads(metricas.with_name("worker.json").read_text(encoding="utf-8"))
                    if modo == "completo":
                        self.assertEqual(datos["suites_verificadas"], 2)
                        self.assertEqual(datos["casos"], 2)
                    else:
                        self.assertIn("error", datos)
                finally:
                    os.chdir(raiz)


if __name__ == "__main__":
    unittest.main()
