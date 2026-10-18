"""Particionar conserva todas las suites y exige evidencia nueva de que corrieron."""

import io
import tempfile
import unittest
from collections import Counter
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

import verificar
from lib.particiones_de_tests import ParticionTests, comprobar_reporte, seleccionar_suites


SUITES = ["test/dominio/ejemplo_test.gd", "test/escenas/ejemplo_test.gd"]
XML = """<testsuites tests="2">
<testsuite name="ejemplo_test" package="test/dominio" tests="1">
<testcase name="test_regla" /></testsuite>
<testsuite name="ejemplo_test" package="test/escenas" tests="1">
<testcase name="test_escena" /></testsuite>
</testsuites>"""


class SeleccionDeSuites(unittest.TestCase):
    def test_las_particiones_cubren_cada_suite_exactamente_una_vez(self):
        suites = [f"test/escenas/suite_{numero}_test.gd" for numero in range(200)]
        particiones = [seleccionar_suites(suites, ParticionTests(i, 4)) for i in range(4)]
        self.assertEqual(Counter(ruta for parte in particiones for ruta in parte), Counter(suites))
        self.assertTrue(all(particiones))

    def test_la_asignacion_tiene_vectores_sha256_conocidos(self):
        # Primeros 32 bits de SHA256, big endian. Estos valores no usan hash() de Python.
        suites = ["f", "test", "hello", "abc"]
        self.assertEqual(seleccionar_suites(suites, ParticionTests(0, 4)), ["f"])
        self.assertEqual(seleccionar_suites(suites, ParticionTests(1, 4)), ["test"])
        self.assertEqual(seleccionar_suites(suites, ParticionTests(2, 4)), ["hello"])
        self.assertEqual(seleccionar_suites(suites, ParticionTests(3, 4)), ["abc"])

    def test_el_orden_de_descubrimiento_no_cambia_la_asignacion(self):
        suites = [f"test/dominio/suite_{numero}_test.gd" for numero in range(100)]
        for indice in range(4):
            with self.subTest(indice=indice):
                particion = ParticionTests(indice, 4)
                self.assertEqual(
                    seleccionar_suites(suites, particion),
                    seleccionar_suites(list(reversed(suites)), particion),
                )

    def test_normaliza_barras_y_puntos_antes_de_asignar(self):
        unix = [f"test/dominio/ejemplo_{numero}_test.gd" for numero in range(100)]
        windows = [".\\" + ruta.replace("/", "\\") for ruta in unix]
        for indice in range(4):
            with self.subTest(indice=indice):
                particion = ParticionTests(indice, 4)
                self.assertEqual(
                    seleccionar_suites(windows, particion), seleccionar_suites(unix, particion)
                )

    def test_una_sola_particion_conserva_todas_las_suites(self):
        self.assertEqual(
            seleccionar_suites(list(reversed(SUITES)), ParticionTests(0, 1)), SUITES
        )

    def test_rechaza_parametros_invalidos(self):
        for texto in ("", "0", "0/0", "-1/4", "4/4", "1/-4", "a/4", "0/4/2"):
            with self.subTest(texto=texto), self.assertRaises(ValueError):
                ParticionTests.desde_texto(texto)

    def test_rechaza_indices_invalidos_tambien_sin_cli(self):
        for indice, total in ((-1, 4), (4, 4), (0, 0), (0, -1)):
            with self.subTest(indice=indice, total=total), self.assertRaises(ValueError):
                ParticionTests(indice, total)

    def test_rechaza_un_descubrimiento_vacio_y_una_particion_vacia(self):
        for suites in ([], ["abc"]):
            with self.subTest(suites=suites), self.assertRaisesRegex(ValueError, "no contiene"):
                seleccionar_suites(suites, ParticionTests(0, 4))

    def test_rechaza_duplicados_despues_de_normalizar(self):
        with self.assertRaisesRegex(ValueError, "duplicadas"):
            seleccionar_suites(["test/a.gd", "test\\a.gd"], ParticionTests(0, 1))

    def test_rechaza_rutas_que_no_son_relativas_al_checkout(self):
        for ruta in ("", ".", "/test/a.gd", "C:\\test\\a.gd", "test/../a.gd"):
            with self.subTest(ruta=ruta), self.assertRaises(ValueError):
                seleccionar_suites([ruta], ParticionTests(0, 1))


class EvidenciaDeEjecucion(unittest.TestCase):
    def test_el_paquete_distingue_suites_con_el_mismo_nombre(self):
        self.assertEqual(comprobar_reporte(SUITES, XML), SUITES)

    def test_rechaza_una_suite_faltante_una_ajena_y_una_repetida(self):
        primero = '<testsuite name="ejemplo_test" package="test/dominio" tests="1">'
        cierre = '<testcase name="test_regla" /></testsuite>'
        for cuerpo in (primero + cierre, (primero + cierre) * 2, XML.replace("escenas", "ui")):
            xml = (
                cuerpo if cuerpo.startswith("<testsuites")
                else f"<testsuites>{cuerpo}</testsuites>"
            )
            with self.subTest(xml=xml), self.assertRaisesRegex(ValueError, "faltantes="):
                comprobar_reporte(SUITES, xml)

    def test_rechaza_xml_vacio_roto_o_sin_suites(self):
        for xml in ("", "<testsuites>", "<otra />", "<testsuites />"):
            with self.subTest(xml=xml), self.assertRaises(ValueError):
                comprobar_reporte(SUITES, xml)

    def test_rechaza_suites_sin_identidad_o_casos_ejecutados(self):
        for xml in (
            XML.replace('package="test/dominio"', ""),
            XML.replace('name="ejemplo_test"', ""),
            XML.replace('tests="1"', 'tests="0"'),
            XML.replace('tests="1"', 'tests="2"'),
            XML.replace('<testcase name="test_regla" />', ""),
        ):
            with self.subTest(xml=xml), self.assertRaises(ValueError):
                comprobar_reporte(SUITES, xml)


class CableadoDeLaSuite(unittest.TestCase):
    def _correr_suite(self, particion, xml=XML, codigo=0):
        self.temporal = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporal.cleanup)
        self.raiz = Path(self.temporal.name)
        self.comandos = []
        anterior = self.raiz / "reports" / "report_anterior"
        anterior.mkdir(parents=True)
        (anterior / "results.xml").write_text(XML, encoding="utf-8")

        def correr(nodo, comando, **opciones):
            self.comandos.append((comando, opciones))
            if "-rd" in comando:
                reportes = self.raiz / comando[comando.index("-rd") + 1]
                if particion is not None and xml is not None:
                    (reportes / "report_1").mkdir()
                    (reportes / "report_1" / "results.xml").write_text(xml, encoding="utf-8")
            return verificar.Resultado(
                nodo, codigo if "-rd" in comando else 0, "salida de gdUnit4", 0.1
            )

        with (
            patch.object(verificar, "RAIZ", self.raiz),
            patch.object(verificar, "scripts_gd", return_value=dict.fromkeys(SUITES, "")),
            patch.object(verificar, "resolver", return_value=("godot", None)),
            patch.object(verificar, "_correr", side_effect=correr),
        ):
            return verificar.nodo_tests(particion)

    def test_pasa_archivos_individuales_y_conserva_evidencia(self):
        resultado = self._correr_suite(ParticionTests(0, 1))
        comando, opciones = self.comandos[1]
        entradas = [comando[i + 1] for i, valor in enumerate(comando) if valor == "-a"]
        self.assertEqual(entradas, SUITES)
        self.assertEqual(resultado.codigo, 0)
        self.assertIn("2/2 suites", resultado.aviso)
        self.assertIn("--continue", comando)
        self.assertIn("--ignoreHeadlessMode", comando)
        self.assertEqual(comando[comando.index("--remote-debug") + 1], "tcp://127.0.0.1:0")
        self.assertIn("entorno", opciones)
        directorio = comando[comando.index("-rd") + 1]
        self.assertFalse(Path(directorio).is_absolute())
        self.assertTrue(directorio.startswith("reports/particion-0-de-1-"))
        reportes = self.raiz / directorio
        self.assertEqual(
            (reportes / "suites-esperadas.txt").read_text(encoding="utf-8").splitlines(), SUITES
        )
        self.assertEqual(
            (reportes / "salida-gdunit4.log").read_text(encoding="utf-8"), "salida de gdUnit4"
        )
        self.assertIn("2/2 suites", (reportes / "cobertura.txt").read_text(encoding="utf-8"))

    def test_sin_particion_conserva_el_comando_de_la_suite_completa(self):
        resultado = self._correr_suite(None)
        comando, _ = self.comandos[1]
        self.assertEqual(resultado.codigo, 0)
        self.assertEqual(comando[comando.index("-a") + 1], verificar.TESTS)
        self.assertEqual(comando[comando.index("-rd") + 1], verificar.REPORTES)

    def test_un_reporte_viejo_no_rescata_una_corrida_sin_suites(self):
        for xml in (None, "<testsuites />"):
            with self.subTest(xml=xml):
                self.assertEqual(self._correr_suite(ParticionTests(0, 1), xml).codigo, 1)

    def test_un_reporte_completo_no_oculta_el_codigo_de_fallo_del_motor(self):
        for xml in (XML, "<testsuites />"):
            with self.subTest(xml=xml):
                self.assertEqual(self._correr_suite(ParticionTests(0, 1), xml, codigo=3).codigo, 3)

    def test_un_fallo_de_importacion_no_lanza_los_tests(self):
        with (
            patch.object(verificar, "scripts_gd", return_value=dict.fromkeys(SUITES, "")),
            patch.object(verificar, "resolver", return_value=("godot", None)),
            patch.object(
                verificar, "_correr", return_value=verificar.Resultado("tests", 1, "", 0)
            ) as correr,
        ):
            self.assertEqual(verificar.nodo_tests(ParticionTests(0, 1)).codigo, 1)
            self.assertEqual(correr.call_count, 1)


class SeleccionDeNodos(unittest.TestCase):
    def _invocar(self, argumentos):
        llamadas = []

        def doble(nombre):
            def nodo(particion=None):
                llamadas.append((nombre, particion))
                return verificar.Resultado(nombre, 0, "", 0)

            nodo.__name__ = "nodo_" + nombre
            return nodo

        nodos = tuple(doble(n.__name__.removeprefix("nodo_")) for n in verificar.NODOS)
        with (
            patch.object(verificar, "NODOS", nodos),
            redirect_stdout(io.StringIO()),
            redirect_stderr(io.StringIO()),
            self.assertRaises(SystemExit) as salida,
        ):
            verificar.main(argumentos)
        return salida.exception.code, llamadas

    def test_los_gates_corren_una_vez_y_tests_en_cada_particion(self):
        llamadas = []
        for indice in range(4):
            codigo, nuevas = self._invocar(["--particion-tests", f"{indice}/4"])
            self.assertEqual(codigo, 0)
            esperados_en_esta = (
                {n.__name__.removeprefix("nodo_") for n in verificar.NODOS}
                if indice == 3 else {"tests"}
            )
            self.assertEqual({nombre for nombre, _ in nuevas}, esperados_en_esta)
            llamadas.extend(nuevas)
        esperados = {n.__name__.removeprefix("nodo_"): 1 for n in verificar.NODOS}
        esperados["tests"] = 4
        self.assertEqual(Counter(nombre for nombre, _ in llamadas), esperados)
        self.assertEqual(
            sorted(p.indice for nombre, p in llamadas if nombre == "tests"), [0, 1, 2, 3]
        )

    def test_sin_argumento_corre_todos_los_nodos_completos(self):
        codigo, llamadas = self._invocar([])
        self.assertEqual(codigo, 0)
        self.assertEqual(
            {nombre for nombre, _ in llamadas},
            {n.__name__.removeprefix("nodo_") for n in verificar.NODOS},
        )
        self.assertTrue(all(particion is None for _, particion in llamadas))

    def test_un_argumento_invalido_no_lanza_ningun_nodo(self):
        for argumentos in (
            ["--particion-tests", "4/4"],
            ["--particion-tests", "0/0"],
            ["--particion-tests", "1/4", "--solo", "lint"],
        ):
            with self.subTest(argumentos=argumentos):
                self.assertEqual(self._invocar(argumentos), (2, []))


if __name__ == "__main__":
    unittest.main()
