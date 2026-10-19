"""Particionar conserva todas las suites y exige evidencia nueva de que corrieron."""

import io
import json
import tempfile
import unittest
from collections import Counter
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

import verificar
from lib.particiones_de_tests import (
    ParticionTests,
    agrupar_suites,
    comprobar_cobertura,
    comprobar_reporte,
    seleccionar_suites,
)


SUITES = ["test/dominio/ejemplo_test.gd", "test/escenas/ejemplo_test.gd"]
XML = """<testsuites tests="2">
<testsuite name="ejemplo_test" package="test/dominio" tests="1">
<testcase name="test_regla" /></testsuite>
<testsuite name="ejemplo_test" package="test/escenas" tests="1">
<testcase name="test_escena" /></testsuite>
</testsuites>"""
FISICAS = [
    "test/escenas/agarre_fisico_test.gd",
    "test/escenas/lo_soltado_fuera_de_los_solidos_test.gd",
]


def reporte(suites):
    return "<testsuites>" + "".join(
        f'<testsuite name="{Path(ruta).stem}" package="{Path(ruta).parent.as_posix()}" '
        'tests="1"><testcase name="test_regla" /></testsuite>' for ruta in suites
    ) + "</testsuites>"


class GruposTemporales(unittest.TestCase):
    def test_solo_las_dos_rutas_auditadas_reciben_fps_fijos(self):
        nueva = "test/escenas/nueva_fisica_test.gd"
        suites = [*SUITES, nueva, *FISICAS]
        normal, fisica = agrupar_suites(list(reversed(suites)))
        self.assertEqual((normal.nombre, normal.fps_fijos), ("normal", None))
        self.assertEqual((fisica.nombre, fisica.fps_fijos), ("fisica60", 60))
        self.assertEqual(normal.suites, tuple(sorted([*SUITES, nueva])))
        self.assertEqual(fisica.suites, tuple(FISICAS))
        self.assertEqual(Counter(normal.suites + fisica.suites), Counter(suites))

    def test_omite_grupos_vacios_y_normaliza_rutas(self):
        self.assertEqual(agrupar_suites([]), ())
        self.assertEqual(len(agrupar_suites(SUITES)), 1)
        grupo, = agrupar_suites([ruta.replace("/", "\\") for ruta in FISICAS])
        self.assertEqual(grupo.suites, tuple(FISICAS))
        self.assertEqual(grupo.fps_fijos, 60)

    def test_rechaza_rutas_invalidas_y_duplicadas(self):
        for suites in ([SUITES[0], SUITES[0].replace("/", "\\")], ["../test.gd"]):
            with self.subTest(suites=suites), self.assertRaises(ValueError):
                agrupar_suites(suites)


class SeleccionDeSuites(unittest.TestCase):
    def test_las_particiones_cubren_cada_suite_exactamente_una_vez(self):
        suites = [f"test/escenas/suite_{numero}_test.gd" for numero in range(200)]
        particiones = [seleccionar_suites(suites, ParticionTests(i, 4)) for i in range(4)]
        self.assertEqual(Counter(ruta for parte in particiones for ruta in parte), Counter(suites))
        self.assertTrue(all(particiones))

    def test_balancea_costos_y_reserva_tiempo_para_los_gates_de_la_ultima(self):
        costos = {"a.gd": 100.0, "b.gd": 80.0, "c.gd": 50.0, "d.gd": 20.0}
        particiones = [
            seleccionar_suites(list(costos), ParticionTests(i, 2), costos) for i in range(2)
        ]
        self.assertEqual(particiones, [["a.gd", "c.gd"], ["b.gd", "d.gd"]])
        self.assertEqual(
            [sum(costos[ruta] for ruta in parte) for parte in particiones], [150.0, 100.0]
        )

    def test_asigna_las_suites_mas_costosas_primero(self):
        costos = {"a.gd": 1.0, "b.gd": 90.0, "c.gd": 100.0, "d.gd": 80.0}
        self.assertEqual(
            seleccionar_suites(list(costos), ParticionTests(0, 2), costos), ["c.gd", "d.gd"]
        )
        self.assertEqual(
            seleccionar_suites(list(costos), ParticionTests(1, 2), costos), ["a.gd", "b.gd"]
        )

    def test_desempata_por_ruta_y_por_indice_con_cualquier_total(self):
        costos = {f"{letra}.gd": 60.0 for letra in "fedcba"}
        particiones = [
            seleccionar_suites(list(costos), ParticionTests(i, 3), costos) for i in range(3)
        ]
        self.assertEqual(
            particiones, [["a.gd", "d.gd"], ["b.gd", "e.gd"], ["c.gd", "f.gd"]]
        )

    def test_una_suite_nueva_cuesta_un_segundo_y_una_borrada_no_se_ejecuta(self):
        suites = ["a.gd", "b.gd", "nueva.gd"]
        costos = {"a.gd": 100.0, "b.gd": 100.0, "borrada.gd": 1000.0}
        self.assertEqual(
            seleccionar_suites(suites, ParticionTests(0, 2), costos), ["a.gd", "nueva.gd"]
        )
        self.assertEqual(seleccionar_suites(suites, ParticionTests(1, 2), costos), ["b.gd"])
        self.assertEqual(
            seleccionar_suites(suites, ParticionTests(0, 2), {**costos, "nueva.gd": 1.0}),
            seleccionar_suites(suites, ParticionTests(0, 2), costos),
        )

    def test_el_orden_de_descubrimiento_no_cambia_la_asignacion(self):
        suites = [f"test/dominio/suite_{numero}_test.gd" for numero in range(100)]
        for indice in range(4):
            with self.subTest(indice=indice):
                particion = ParticionTests(indice, 4)
                self.assertEqual(
                    seleccionar_suites(suites, particion),
                    seleccionar_suites(list(reversed(suites)), particion),
                )

    def test_la_reserva_no_deja_un_runner_vacio_si_alcanzan_las_suites(self):
        suites = ["a.gd", "b.gd", "c.gd", "d.gd"]
        particiones = [
            seleccionar_suites(suites, ParticionTests(i, 4), {}) for i in range(4)
        ]
        self.assertEqual(particiones, [["a.gd"], ["b.gd"], ["c.gd"], ["d.gd"]])

    def test_normaliza_barras_y_puntos_antes_de_asignar(self):
        unix = [f"test/dominio/ejemplo_{numero}_test.gd" for numero in range(100)]
        windows = [".\\" + ruta.replace("/", "\\") for ruta in unix]
        costos = {ruta: float(numero + 1) for numero, ruta in enumerate(unix)}
        costos_windows = {".\\" + ruta.replace("/", "\\"): costo for ruta, costo in costos.items()}
        for indice in range(4):
            with self.subTest(indice=indice):
                particion = ParticionTests(indice, 4)
                self.assertEqual(
                    seleccionar_suites(windows, particion, costos_windows),
                    seleccionar_suites(unix, particion, costos),
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
                seleccionar_suites(suites, ParticionTests(1, 4))

    def test_la_reserva_no_excluye_suites_de_una_particion_unica(self):
        self.assertEqual(seleccionar_suites(["nueva.gd"], ParticionTests(0, 1)), ["nueva.gd"])

    def test_rechaza_costos_invalidos(self):
        for costo in (0, -1, float("nan"), float("inf"), float("-inf"), True, "1", None):
            with self.subTest(costo=costo), self.assertRaises(ValueError):
                seleccionar_suites(["a.gd"], ParticionTests(0, 1), {"a.gd": costo})

    def test_rechaza_estimaciones_duplicadas_despues_de_normalizar(self):
        with self.assertRaisesRegex(ValueError, "duplicadas"):
            seleccionar_suites(
                ["test/a.gd"], ParticionTests(0, 1), {"test/a.gd": 1.0, "test\\a.gd": 2.0}
            )

    def test_rechaza_duplicados_despues_de_normalizar(self):
        with self.assertRaisesRegex(ValueError, "duplicadas"):
            seleccionar_suites(["test/a.gd", "test\\a.gd"], ParticionTests(0, 1))

    def test_rechaza_rutas_que_no_son_relativas_al_checkout(self):
        for ruta in ("", ".", "/test/a.gd", "C:\\test\\a.gd", "test/../a.gd"):
            with self.subTest(ruta=ruta), self.assertRaises(ValueError):
                seleccionar_suites([ruta], ParticionTests(0, 1))


class EvidenciaDeEjecucion(unittest.TestCase):
    def test_la_union_rechaza_grupos_ausentes_y_suites_repetidas(self):
        for ejecutadas in (SUITES[:1], [*SUITES, SUITES[0]]):
            with self.subTest(ejecutadas=ejecutadas), self.assertRaises(ValueError):
                comprobar_cobertura(SUITES, ejecutadas)

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
    def _correr_suite(self, particion, xml=XML, codigo=0, suites=SUITES, repetido=False):
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
                contenido = xml.get(reportes.name) if isinstance(xml, dict) else xml
                if contenido is not None:
                    (reportes / "report_1").mkdir()
                    (reportes / "report_1" / "results.xml").write_text(
                        contenido, encoding="utf-8"
                    )
                    if repetido:
                        (reportes / "report_2").mkdir()
                        (reportes / "report_2" / "results.xml").write_text(
                            contenido, encoding="utf-8"
                        )
                retorno = codigo.get(reportes.name, 0) if isinstance(codigo, dict) else codigo
            else:
                retorno = 0
            return verificar.Resultado(
                nodo, retorno, "salida de gdUnit4", 0.1
            )

        with (
            patch.object(verificar, "RAIZ", self.raiz),
            patch.object(verificar, "scripts_gd", return_value=dict.fromkeys(suites, "")),
            patch.object(verificar, "resolver", return_value=("godot", None)),
            patch.object(verificar, "validar_motor", return_value={}),
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
        self.assertEqual(reportes.name, "normal")
        self.assertNotIn("--fixed-fps", comando)
        self.assertEqual(
            (reportes / "suites-esperadas.txt").read_text(encoding="utf-8").splitlines(), SUITES
        )
        self.assertEqual(
            (reportes / "salida-gdunit4.log").read_text(encoding="utf-8"), "salida de gdUnit4"
        )
        self.assertIn("2/2 suites", (reportes / "cobertura.txt").read_text(encoding="utf-8"))
        raiz_reportes = reportes.parent
        self.assertEqual(
            json.loads((raiz_reportes / "grupos.json").read_text(encoding="utf-8")),
            [{"nombre": "normal", "suites": SUITES, "fps_fijos": None}],
        )
        self.assertIn("2/2 suites", (raiz_reportes / "cobertura.txt").read_text(encoding="utf-8"))

    def test_sin_particion_exige_archivos_explicitos_y_reportes_nuevos(self):
        resultado = self._correr_suite(None)
        comando, _ = self.comandos[1]
        self.assertEqual(resultado.codigo, 0)
        self.assertEqual(
            [comando[i + 1] for i, valor in enumerate(comando) if valor == "-a"], SUITES
        )
        self.assertTrue(comando[comando.index("-rd") + 1].startswith("reports/suite-"))

    def test_ambos_modos_local_y_particionado_importan_una_vez_y_aislan_relojes(self):
        suites = [*SUITES, *FISICAS]
        xml = {"normal": XML, "fisica60": reporte(FISICAS)}
        for particion in (None, ParticionTests(0, 1)):
            with self.subTest(particion=particion):
                resultado = self._correr_suite(particion, xml, suites=suites)
                self.assertEqual(resultado.codigo, 0)
                self.assertAlmostEqual(resultado.segundos, 0.2)
                self.assertEqual(len(self.comandos), 3)
                self.assertIn("--import", self.comandos[0][0])
                normal, fisica = [comando for comando, _ in self.comandos[1:]]
                self.assertNotIn("--fixed-fps", normal)
                self.assertEqual(fisica[fisica.index("--fixed-fps") + 1], "60")
                self.assertEqual(
                    [fisica[i + 1] for i, valor in enumerate(fisica) if valor == "-a"], FISICAS
                )
                self.assertIn("4/4 suites", resultado.aviso)

    def test_un_grupo_ausente_no_se_rescata_con_el_reporte_del_otro(self):
        for faltante in ("normal", "fisica60"):
            xml = {"normal": XML, "fisica60": reporte(FISICAS), faltante: None}
            with self.subTest(faltante=faltante):
                resultado = self._correr_suite(None, xml, suites=[*SUITES, *FISICAS])
                self.assertEqual(resultado.codigo, 1)
                self.assertEqual(len(self.comandos), 3)
                self.assertIn("faltantes=", resultado.aviso)

    def test_un_solo_grupo_fisico_no_lanza_un_proceso_normal_vacio(self):
        resultado = self._correr_suite(None, reporte(FISICAS), suites=FISICAS)
        self.assertEqual(resultado.codigo, 0)
        self.assertEqual(len(self.comandos), 2)
        self.assertIn("--fixed-fps", self.comandos[1][0])

    def test_un_fallo_no_impide_el_otro_grupo_ni_se_oculta_con_su_exito(self):
        for fallido in ("normal", "fisica60"):
            with self.subTest(fallido=fallido):
                resultado = self._correr_suite(
                    None, {"normal": XML, "fisica60": reporte(FISICAS)},
                    codigo={fallido: 3}, suites=[*SUITES, *FISICAS],
                )
                self.assertEqual(resultado.codigo, 3)
                self.assertEqual(len(self.comandos), 3)

    def test_dos_xml_en_un_grupo_no_demuestran_una_ejecucion_unica(self):
        self.assertEqual(self._correr_suite(None, repetido=True).codigo, 1)

    def test_un_reporte_viejo_no_rescata_una_corrida_sin_suites(self):
        for particion in (None, ParticionTests(0, 1)):
            for xml in (None, "<testsuites />"):
                with self.subTest(particion=particion, xml=xml):
                    self.assertEqual(self._correr_suite(particion, xml).codigo, 1)

    def test_un_reporte_completo_no_oculta_el_codigo_de_fallo_del_motor(self):
        for xml in (XML, "<testsuites />"):
            with self.subTest(xml=xml):
                self.assertEqual(self._correr_suite(ParticionTests(0, 1), xml, codigo=3).codigo, 3)

    def test_un_fallo_de_importacion_no_lanza_los_tests(self):
        with (
            patch.object(verificar, "scripts_gd", return_value=dict.fromkeys(SUITES, "")),
            patch.object(verificar, "resolver", return_value=("godot", None)),
            patch.object(verificar, "validar_motor", return_value={}),
            patch.object(
                verificar, "_correr", return_value=verificar.Resultado("tests", 1, "", 0)
            ) as correr,
        ):
            self.assertEqual(verificar.nodo_tests(ParticionTests(0, 1)).codigo, 1)
            self.assertEqual(correr.call_count, 1)

    def test_motor_oficial_rechazado_no_lanza_importacion_ni_tests(self):
        with (
            patch.object(verificar, "scripts_gd", return_value=dict.fromkeys(SUITES, "")),
            patch.object(verificar, "resolver", return_value=("oficial", None)),
            patch.object(verificar, "validar_motor", side_effect=ValueError("sin parche")),
            patch.object(verificar, "_correr") as correr,
        ):
            resultado = verificar.nodo_tests()
        self.assertEqual(resultado.codigo, 1)
        self.assertIn("sin parche", resultado.salida)
        correr.assert_not_called()

    def test_copia_gestionada_con_manifiesto_incompleto_es_un_rojo_explicito(self):
        with (
            patch.object(verificar, "scripts_gd", return_value=dict.fromkeys(SUITES, "")),
            patch.object(verificar, "resolver", side_effect=KeyError("receta_sha256")),
            patch.object(verificar, "_correr") as correr,
        ):
            resultado = verificar.nodo_tests()
        self.assertEqual(resultado.codigo, 1)
        self.assertIn("Motor nativo no válido", resultado.salida)
        self.assertIn("preparar_godot_nativo.py preparar", resultado.salida)
        correr.assert_not_called()


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

    def test_solo_tests_conserva_el_mismo_nodo_con_o_sin_particion(self):
        self.assertEqual(self._invocar(["--solo", "tests"]), (0, [("tests", None)]))
        self.assertEqual(
            self._invocar(["--solo", "tests", "--particion-tests", "0/1"]),
            (0, [("tests", ParticionTests(0, 1))]),
        )

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
