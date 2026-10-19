import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


REPO = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("cache_importaciones", REPO / ".github/scripts/cache_importaciones.py")
cache = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = cache
SPEC.loader.exec_module(cache)


class CacheImportacionesTests(unittest.TestCase):
    def setUp(self):
        temporal = tempfile.TemporaryDirectory()
        self.addCleanup(temporal.cleanup)
        self.raiz = Path(temporal.name)
        self.nombres = []
        for nombre in cache.IMPORTADORES:
            self.escribir(nombre, (REPO / nombre).read_text(encoding="utf-8"))
        self.escribir(cache.MATERIAL, (REPO / cache.MATERIAL).read_text(encoding="utf-8"))
        for nombre in (
            ".godot-version", "project.godot", "assets/models/modelo.glb",
            "assets/environments/vidrio_marcas.png",
            "src/escenas/puestos/vidrio_del_local.gdshader", "src/escenas/almacen.exr",
            "icon.svg", "addons/plugin/plugin.gd", "src/dominio/regla.gd",
            "test/dominio/regla_test.gd", "docs/guia.md", "src/dominio/regla.gd.uid",
        ):
            self.escribir(nombre, "original")
        self.inventario = patch.object(cache, "archivos_versionados", side_effect=lambda _: sorted(self.nombres))
        self.inventario.start()
        self.addCleanup(self.inventario.stop)

    def escribir(self, nombre, contenido):
        ruta = self.raiz / nombre
        ruta.parent.mkdir(parents=True, exist_ok=True)
        ruta.write_text(contenido, encoding="utf-8")
        if nombre not in self.nombres:
            self.nombres.append(nombre)

    def identidad(self, sistema="Linux-Ubuntu24", arquitectura="X64"):
        return cache.identidad(self.raiz, sistema, arquitectura)

    def test_codigo_tests_clases_uid_y_documentacion_conservan_clave(self):
        original = self.identidad()
        self.assertTrue(original.cacheable)
        for nombre in ("src/dominio/regla.gd", "test/dominio/regla_test.gd", "src/dominio/regla.gd.uid", "docs/guia.md"):
            self.escribir(nombre, "cambiado")
        self.escribir("src/dominio/nueva_clase.gd", "class_name NuevaClase")
        self.escribir("test/dominio/nueva_clase_test.gd", "extends GdUnitTestSuite")
        self.assertEqual(original.key, self.identidad().key)

    def test_recursos_opciones_motor_y_addons_invalidan_por_contenido(self):
        for nombre in (
            "assets/models/modelo.glb", cache.MATERIAL, "src/escenas/puestos/vidrio_del_local.gdshader",
            "src/escenas/almacen.exr", "icon.svg", "addons/plugin/plugin.gd", ".godot-version",
        ):
            with self.subTest(nombre=nombre):
                original = self.identidad()
                ruta = self.raiz / nombre
                anterior = ruta.read_text(encoding="utf-8")
                self.escribir(nombre, anterior + "\ncambio")
                self.assertNotEqual(original.key, self.identidad().key)
                self.escribir(nombre, anterior)
        self.escribir("assets/models/modelo.glb.import", 'import_script/path="res://assets/models/importar_modelo.gd"\n')
        original = self.identidad()
        self.escribir("assets/models/modelo.glb.import", 'import_script/path="res://assets/models/importar_modelo.gd"\nmeshes/generate_lods=false\n')
        self.assertNotEqual(original.key, self.identidad().key)

    def test_plataforma_altas_bajas_y_renombres_invalidan(self):
        original = self.identidad()
        self.assertNotEqual(original.key, self.identidad(sistema="Linux-Ubuntu26").key)
        self.assertNotEqual(original.key, self.identidad(arquitectura="ARM64").key)
        self.escribir("src/escenas/nuevo.webp", "nuevo")
        self.assertNotEqual(original.key, self.identidad().key)
        self.nombres.remove("src/escenas/nuevo.webp")
        self.assertEqual(original.key, self.identidad().key)
        self.nombres.remove("icon.svg")
        self.escribir("otro_icono.svg", "original")
        self.assertNotEqual(original.key, self.identidad().key)

    def test_importadores_nuevos_cambiados_y_plugins_desactivan(self):
        self.escribir("assets/models/importar_modelo.gd", "modificado")
        self.assertFalse(self.identidad().cacheable)
        self.escribir("assets/models/importar_modelo.gd", (REPO / "assets/models/importar_modelo.gd").read_text(encoding="utf-8"))
        self.escribir("assets/models/modelo.glb.import", 'import_script/path="res://otro.gd"\n')
        self.assertFalse(self.identidad().cacheable)
        self.escribir("assets/models/modelo.glb.import", 'import_script/path=""\n')
        self.escribir("addons/plugin/importador.gd", "extends EditorImportPlugin")
        self.assertFalse(self.identidad().cacheable)

    def test_material_importado_con_script_o_recurso_no_auditado_desactiva(self):
        for contenido in (
            '[ext_resource type="Script" path="res://src/externo.gd"]',
            '[ext_resource type="Material" path="res://assets/otro.tres"]',
            '[sub_resource type="GDScript" id="incrustado"]',
            '[ext_resource type="Shader" path="res://docs/fuera.gdshader"]',
        ):
            self.escribir(cache.MATERIAL, contenido)
            self.assertFalse(self.identidad().cacheable)
        self.escribir(cache.MATERIAL, "[resource]")
        self.escribir("src/dominio/runtime.tres", '[ext_resource type="Script" path="res://src/dominio/regla.gd"]')
        self.assertTrue(self.identidad().cacheable)

    def test_caja_sin_destinos_desactiva_cache_y_verifica_en_frio(self):
        self.preparar_importados()
        self.escribir("assets/models/caja_registradora.glb.import", 'import_script/path="res://assets/models/importar_caja.gd"\ndest_files=[]\n')
        resultado = self.identidad()
        self.assertFalse(resultado.cacheable)
        cache.preparar_verificacion(self.raiz, False)
        self.assertFalse((self.raiz / ".godot/imported").exists())

    @unittest.skipUnless(hasattr(os, "symlink"), "requiere enlaces")
    def test_enlace_roto_desactiva_sin_intentar_hashear_su_destino(self):
        ruta = self.raiz / "assets/enlace.png"
        try:
            ruta.symlink_to(self.raiz / "inexistente.png")
        except OSError:
            self.skipTest("el sistema no permite crear enlaces")
        self.nombres.append("assets/enlace.png")
        self.assertFalse(self.identidad().cacheable)

    def preparar_importados(self):
        for caja in cache.CAJAS:
            destino = f"res://.godot/imported/{caja}.glb-hash.scn"
            self.escribir(f"assets/models/{caja}.glb.import", f'import_script/path="res://assets/models/importar_caja.gd"\ndest_files=["{destino}"]\n')
            self.escribir(f".godot/imported/{caja}.glb-hash.scn", "escena vieja")
            self.escribir(f".godot/imported/{caja}.glb-hash.md5", "huella vieja")
            self.escribir(f"assets/models/{caja}.res", "versionado actual")
        self.escribir(".godot/imported/SEPT.glb-hash.scn", "almacén")
        self.escribir(".godot/uid_cache.bin", "índice privado actual")
        self.escribir("reports/results.xml", "resultado actual")

    def test_hit_purga_solo_salidas_de_tres_cajas_y_preserva_checkout(self):
        self.preparar_importados()
        eliminados = cache.preparar_verificacion(self.raiz, True)
        self.assertEqual(len(eliminados), 6)
        for caja in cache.CAJAS:
            self.assertEqual((self.raiz / f"assets/models/{caja}.res").read_text(encoding="utf-8"), "versionado actual")
        for nombre in (".godot/imported/SEPT.glb-hash.scn", ".godot/uid_cache.bin", "reports/results.xml"):
            self.assertTrue((self.raiz / nombre).exists())

    def test_miss_o_restauracion_parcial_limpia_solo_imported(self):
        self.preparar_importados()
        cache.preparar_verificacion(self.raiz, False)
        self.assertFalse((self.raiz / ".godot/imported").exists())
        self.assertTrue((self.raiz / ".godot/uid_cache.bin").exists())
        self.assertTrue((self.raiz / "reports/results.xml").exists())

    def test_rechaza_traversal_y_destinos_externos(self):
        for destino in (
            "res://assets/models/caja.res", "res://.godot/imported/../uid_cache.bin",
            "res://.godot/imported/sub/caja.scn", "res://.godot/imported/..\\afuera",
        ):
            with self.subTest(destino=destino), self.assertRaises(ValueError):
                cache.destino_privado(self.raiz, destino)

    def test_rechaza_directorio_privado_enlazado_fuera_del_checkout(self):
        with tempfile.TemporaryDirectory() as afuera:
            carpeta = self.raiz / ".godot"
            carpeta.mkdir()
            try:
                (carpeta / "imported").symlink_to(afuera, target_is_directory=True)
            except OSError:
                self.skipTest("el sistema no permite crear enlaces")
            centinela = Path(afuera) / "preservado"
            centinela.write_text("fuera", encoding="utf-8")
            with self.assertRaises(ValueError):
                cache.preparar_verificacion(self.raiz, False)
            self.assertTrue(centinela.exists())

    def test_cli_exige_hit_exacto_y_registra_identidad_sin_userdata(self):
        self.preparar_importados()
        reporte = self.raiz / "reports/cache-importaciones.json"
        reporte.write_text(json.dumps({"cacheable": True, "key": "correcta", "entradas": 1, "motivo": "auditado"}), encoding="utf-8")
        with patch.object(sys, "argv", ["cache", "preparar", "--raiz", str(self.raiz)]), patch.dict(
            os.environ, {"CACHE_HIT": "true", "CACHE_RESULTADO": "success", "CACHE_CLAVE_RESTAURADA": "parcial"}, clear=True
        ):
            cache.main()
        datos = json.loads(reporte.read_text(encoding="utf-8"))
        self.assertFalse(datos["hit"])
        self.assertFalse((self.raiz / ".godot/imported").exists())
        self.assertNotIn("user", datos)


class CheckoutActualTests(unittest.TestCase):
    def test_recursos_actuales_son_elegibles_y_clase_nueva_conserva_clave(self):
        original = cache.identidad(REPO, "Linux-Ubuntu24", "X64")
        self.assertTrue(original.cacheable, original.motivo)
        nombres = cache.archivos_versionados(REPO)
        with patch.object(cache, "archivos_versionados", return_value=nombres + [
            "src/dominio/clase_nueva.gd", "test/dominio/clase_nueva_test.gd",
        ]):
            actual = cache.identidad(REPO, "Linux-Ubuntu24", "X64")
        self.assertEqual(original.key, actual.key)


if __name__ == "__main__":
    unittest.main()
