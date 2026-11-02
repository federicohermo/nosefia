"""La receta del motor WebGPU y el exportador no pueden separarse de lo que el motor hace."""

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[3]


def cargar(nombre: str, ruta: str):
    spec = importlib.util.spec_from_file_location(nombre, RAIZ / ruta)
    assert spec is not None and spec.loader is not None
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


preparador = cargar("preparar_motor_webgpu", ".github/scripts/preparar_motor_webgpu.py")
exportador = cargar("exportar_webgpu", ".github/scripts/exportar_webgpu.py")
RECETA = RAIZ / ".github/patches/godot-webgpu-compilacion.json"

PROYECTO = '[autoload]\n\nA="*res://a.gd"\n\n[rendering]\n\nrenderer/rendering_method="gl_compatibility"\nreflections/x=1\n'
PRESETS = (
    '[preset.0.options]\n\ncustom_template/release="res://build/templates/web_release.zip"\n'
    "variant/extensions_support=false\nvariant/thread_support=true\n"
)


class RecetaTest(unittest.TestCase):
    def test_la_receta_se_lee_y_el_parche_coincide_con_sus_huellas(self):
        datos, parches, identidad = preparador.identidad(RECETA)
        self.assertEqual(preparador.archivos_del_parche(parches), set(datos["archivos"]))
        self.assertEqual(identidad["commit_del_motor"], datos["commit_del_motor"])

    def test_un_parche_con_un_archivo_de_mas_frena_la_preparacion(self):
        with tempfile.TemporaryDirectory() as carpeta:
            copia = Path(carpeta)
            datos = json.loads(RECETA.read_text(encoding="utf-8"))
            (copia / datos["parches"][0]).write_text(
                (RECETA.parent / datos["parches"][0]).read_text(encoding="utf-8") + "+++ b/otro.cpp\n",
                encoding="utf-8",
            )
            (copia / RECETA.name).write_text(json.dumps(datos), encoding="utf-8")
            with self.assertRaises(ValueError):
                preparador.identidad(copia / RECETA.name)

    def test_unas_opciones_distintas_frenan_la_preparacion(self):
        with tempfile.TemporaryDirectory() as carpeta:
            copia = Path(carpeta)
            datos = json.loads(RECETA.read_text(encoding="utf-8"))
            datos["opciones"] = [*datos["opciones"], "threads=yes"]
            (copia / datos["parches"][0]).write_bytes((RECETA.parent / datos["parches"][0]).read_bytes())
            (copia / RECETA.name).write_text(json.dumps(datos), encoding="utf-8")
            with self.assertRaises(ValueError):
                preparador.identidad(copia / RECETA.name)

    def test_la_plantilla_es_webgpu_y_no_cambia_el_renderizador_de_la_web_actual(self):
        self.assertIn("webgpu=yes", preparador.OPCIONES)
        self.assertIn("opengl3=no", preparador.OPCIONES)


class ExportadorTest(unittest.TestCase):
    def test_el_renderizador_pedido_reemplaza_al_del_proyecto(self):
        ajustado = exportador.ajustar_proyecto(PROYECTO, "mobile", None)
        self.assertIn('renderer/rendering_method="mobile"', ajustado)
        self.assertNotIn("gl_compatibility", ajustado)

    def test_el_renderizador_se_escribe_aunque_el_editor_haya_borrado_su_linea(self):
        sin_linea = PROYECTO.replace('renderer/rendering_method="gl_compatibility"\n', "")
        self.assertIn('renderer/rendering_method="forward_plus"', exportador.ajustar_proyecto(sin_linea, "forward_plus", None))

    def test_un_proyecto_sin_seccion_de_render_no_se_exporta_a_ciegas(self):
        with self.assertRaises(ValueError):
            exportador.ajustar_proyecto("[autoload]\n\n", "mobile", None)

    def test_el_autoload_de_prueba_entra_sin_tocar_los_demas(self):
        ajustado = exportador.ajustar_proyecto(PROYECTO, "mobile", "res://depuracion/x.gd")
        self.assertIn('JornadaDirecta="*res://depuracion/x.gd"', ajustado)
        self.assertIn('A="*res://a.gd"', ajustado)

    def test_el_preset_usa_la_plantilla_webgpu_con_o_sin_hilo_de_render(self):
        con = exportador.ajustar_presets(PRESETS, "res://build/templates/webgpu_release.zip", True, True)
        sin = exportador.ajustar_presets(PRESETS, "res://build/templates/webgpu_release.zip", True, False)
        self.assertIn('custom_template/release="res://build/templates/webgpu_release.zip"', con)
        self.assertIn("variant/separate_render_thread=true", con)
        self.assertIn("variant/separate_render_thread=false", sin)
        self.assertEqual(sin.count("separate_render_thread"), 1)

    def test_un_preset_sin_plantilla_no_se_ajusta_a_ciegas(self):
        with self.assertRaises(ValueError):
            exportador.ajustar_presets("[preset.0.options]\n", "x.zip", False, False)


if __name__ == "__main__":
    unittest.main()
