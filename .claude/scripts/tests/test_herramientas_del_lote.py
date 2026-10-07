"""Lo que deciden las herramientas de un lote: quién pasa, cuántas suites corrieron, qué se exporta.

Las tres son cableado alrededor de una decisión chica. Los casos ejercen la decisión, sin
levantar Godot ni un navegador.
"""

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import ModuleType

from lib.repo import RAIZ

LOTE = RAIZ / ".claude" / "skills" / "implement-batch" / "scripts"


def _cargar(ruta: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location(ruta.stem, ruta)
    assert spec is not None and spec.loader is not None
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


turno = _cargar(LOTE / "turno.py")
conteo = _cargar(LOTE / "conteo.py")
escenario = _cargar(RAIZ / ".github" / "scripts" / "exportar_escenario.py")

PROYECTO = (
    '[application]\n\nrun/main_scene="res://src/escenas/menu_de_inicio.tscn"\n\n'
    '[autoload]\n\nServicio="*res://addons/x/servicio.gd"\n\n[debug]\n\nalgo=2\n'
)


class ElTurnoEsUnaCola(unittest.TestCase):
    def test_pasa_el_boleto_mas_viejo_y_no_el_que_reintenta_antes(self):
        boletos = ["00000000000000000030-7.json", "00000000000000000010-9.json"]
        self.assertEqual(turno.el_que_pasa(boletos, set(boletos)), "00000000000000000010-9.json")

    def test_un_boleto_cuyo_dueno_murio_no_frena_la_cola(self):
        boletos = ["00000000000000000010-9.json", "00000000000000000030-7.json"]
        self.assertEqual(
            turno.el_que_pasa(boletos, {"00000000000000000030-7.json"}),
            "00000000000000000030-7.json",
        )

    def test_sin_boletos_vivos_no_pasa_nadie(self):
        self.assertIsNone(turno.el_que_pasa(["00000000000000000010-9.json"], set()))

    def test_el_segundo_en_llegar_espera_y_entra_cuando_el_primero_sale(self):
        with tempfile.TemporaryDirectory() as carpeta:
            cola = Path(carpeta)
            primero = turno.esperar(cola, "primero")
            # El proceso del test es dueño de los dos boletos: los dos están vivos.
            segundo = cola / f"{int(primero.name.split('-')[0]) + 1:020d}-{turno.os.getpid()}.json"
            segundo.write_text("{}", encoding="utf-8")
            self.assertEqual(turno._primero(cola), primero.name)
            primero.unlink()
            self.assertEqual(turno._primero(cola), segundo.name)

    def test_el_boleto_de_un_proceso_que_termino_sale_de_la_cola(self):
        with tempfile.TemporaryDirectory() as carpeta:
            cola = Path(carpeta)
            muerto = subprocess.Popen([sys.executable, "-c", "pass"])
            muerto.wait()
            huerfano = cola / f"{1:020d}-{muerto.pid}.json"
            huerfano.write_text("{}", encoding="utf-8")
            self.assertIsNone(turno._primero(cola))
            self.assertFalse(huerfano.exists())


class ElConteoSaleDelReporte(unittest.TestCase):
    def test_cuenta_las_suites_y_no_los_casos(self):
        xml = '<testsuites><testsuite name="a"><testcase/></testsuite><testsuite name="b"/>'
        self.assertEqual(conteo.suites_corridas(xml), 2)

    def test_toma_el_reporte_de_numero_mas_alto_y_no_el_ultimo_por_nombre(self):
        with tempfile.TemporaryDirectory() as carpeta:
            reportes = Path(carpeta)
            for numero in (2, 10):
                (reportes / f"report_{numero}").mkdir()
                (reportes / f"report_{numero}" / "results.xml").write_text("", encoding="utf-8")
            (reportes / "report_11").mkdir()
            self.assertEqual(conteo.ultimo_reporte(reportes), reportes / "report_10")

    def test_sin_reportes_no_inventa_uno(self):
        with tempfile.TemporaryDirectory() as carpeta:
            self.assertIsNone(conteo.ultimo_reporte(Path(carpeta)))


class LaCopiaDelEscenario(unittest.TestCase):
    def test_el_escenario_es_la_escena_principal_y_el_usuario_es_propio(self):
        ajustado = escenario.ajustar_proyecto(PROYECTO, "res://test/performance/x.tscn", "medicion")
        self.assertIn('run/main_scene="res://test/performance/x.tscn"', ajustado)
        self.assertIn("config/use_custom_user_dir=true", ajustado)
        self.assertIn('config/custom_user_dir_name="medicion"', ajustado)

    def test_la_copia_no_lleva_autoloads_y_conserva_la_seccion_siguiente(self):
        ajustado = escenario.ajustar_proyecto(PROYECTO, "res://x.tscn", "medicion")
        self.assertNotIn("[autoload]", ajustado)
        self.assertNotIn("Servicio=", ajustado)
        self.assertIn("[debug]\n\nalgo=2", ajustado)

    def test_un_proyecto_sin_escena_principal_se_rechaza(self):
        with self.assertRaises(ValueError):
            escenario.ajustar_proyecto("[application]\n", "res://x.tscn", "medicion")

    def test_los_tests_entran_al_export_y_el_resto_de_la_exclusion_queda(self):
        presets = 'exclude_filter="reports/*,test/*,addons/gdUnit4/*"\n'
        self.assertEqual(
            escenario.ajustar_presets(presets), 'exclude_filter="reports/*,addons/gdUnit4/*"\n'
        )

    def test_un_preset_que_ya_no_excluye_los_tests_se_rechaza(self):
        with self.assertRaises(ValueError):
            escenario.ajustar_presets('exclude_filter="reports/*"\n')

    def test_los_ajustes_valen_sobre_los_archivos_del_repo(self):
        proyecto = (RAIZ / "project.godot").read_text(encoding="utf-8")
        ajustado = escenario.ajustar_proyecto(proyecto, "res://x.tscn", "medicion")
        self.assertEqual(ajustado.count('run/main_scene="res://x.tscn"'), 1)
        presets = (RAIZ / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertNotIn("test/*", escenario.ajustar_presets(presets))


if __name__ == "__main__":
    unittest.main()
