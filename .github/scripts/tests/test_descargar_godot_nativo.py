import hashlib
import importlib.util
import io
import json
from pathlib import Path
import stat
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile

import test_preparar_godot_nativo as fixtures


RUTA = Path(__file__).resolve().parents[1] / "descargar_godot_nativo.py"
SPEC = importlib.util.spec_from_file_location("descargar_godot_nativo", RUTA)
descarga = importlib.util.module_from_spec(SPEC)
with patch.object(sys, "path", [str(RUTA.parent), *sys.path]):
    SPEC.loader.exec_module(descarga)


class DescargarMotorTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.MotorNativoTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.raiz = self.fixture.raiz
        self.origen, self.manifiesto = self.fixture.artefacto()
        self.destino = self.raiz / "descargado"
        self.zip = self.empaquetar()
        self.lock = self.raiz / descarga.LOCK
        self.escribir_lock()

    def empaquetar(self, extras=()):
        salida = io.BytesIO()
        with zipfile.ZipFile(salida, "w") as archivo:
            for ruta in self.origen.rglob("*"):
                if ruta.is_file():
                    archivo.writestr(ruta.relative_to(self.origen).as_posix(), ruta.read_bytes())
            for nombre, datos in extras:
                archivo.writestr(nombre, datos)
        return salida.getvalue()

    def escribir_lock(self):
        self.artefacto = {
            "receta_sha256": self.manifiesto["receta_sha256"],
            "url": "https://github.com/federicohermo/nosefia/releases/download/native-1/linux.zip",
            "archivo_sha256": hashlib.sha256(self.zip).hexdigest(),
            "manifiesto_sha256": descarga.constructor.sha256(self.origen / "manifiesto.json"),
        }
        self.guardar_lock()

    def guardar_lock(self):
        self.lock.write_text(json.dumps({
            "formato": 1, "plataformas": {"linux-x86_64": self.artefacto},
        }), encoding="utf-8")

    def obtener(self):
        with patch.object(descarga.urllib.request, "urlopen", return_value=io.BytesIO(self.zip)):
            return descarga.descargar(self.raiz, "linux-x86_64", self.destino)

    def test_frio_descarga_y_caliente_reutiliza_sin_compilar_ni_ejecutar(self):
        with patch.object(descarga.constructor, "preparar", side_effect=AssertionError("no compilar")), \
                patch.object(descarga.constructor.subprocess, "run", side_effect=AssertionError("no ejecutar")):
            frio = self.obtener()
            with patch.object(descarga.urllib.request, "urlopen", side_effect=AssertionError("sin red")):
                caliente = descarga.descargar(self.raiz, "linux-x86_64", self.destino)
        self.assertEqual(frio, caliente)
        self.assertEqual(Path(frio["binario"]).read_bytes(), fixtures.elf())
        self.assertFalse(list(self.raiz.glob(".godot-descarga-*")))
        self.assertFalse(list(self.raiz.glob("*.anterior")))

    def test_identidad_no_necesita_red_ni_cache(self):
        with patch.object(descarga.urllib.request, "urlopen", side_effect=AssertionError("sin red")):
            resultado = descarga.identidad(self.raiz, "linux-x86_64")
        self.assertEqual(resultado["archivo_sha256"], self.artefacto["archivo_sha256"])
        self.assertEqual(resultado["receta_sha256"], self.manifiesto["receta_sha256"])
        self.assertFalse(self.destino.exists())

    def test_cache_corrupta_se_recupera_sin_reconstruir(self):
        self.obtener()
        (self.destino / self.manifiesto["entrypoint"]).write_bytes(b"corrupto")
        with patch.object(descarga.constructor, "preparar", side_effect=AssertionError("no compilar")):
            resultado = self.obtener()
        self.assertEqual(Path(resultado["binario"]).read_bytes(), fixtures.elf())

    def test_manifest_autoconsistente_modificado_no_autoriza_otro_binario(self):
        self.obtener()
        otro = fixtures.elf() + b"alterado"
        entrada = self.manifiesto["entrypoint"]
        (self.destino / entrada).write_bytes(otro)
        modificado = dict(self.manifiesto, archivos={entrada: fixtures.digest(otro)},
                          binario_sha256=fixtures.digest(otro))
        (self.destino / "manifiesto.json").write_text(json.dumps(modificado))
        descarga.constructor.validar(self.destino, self.raiz, "linux-x86_64")
        with self.assertRaisesRegex(ValueError, "manifiesto.*lock"):
            descarga.comprobar(self.raiz, "linux-x86_64", self.destino)
        self.obtener()
        self.assertEqual((self.destino / entrada).read_bytes(), fixtures.elf())

    def test_hash_del_zip_se_comprueba_antes_de_parsear(self):
        self.zip = b"zip corrupto"
        with patch.object(descarga.zipfile, "ZipFile", side_effect=AssertionError("no parsear")):
            with self.assertRaisesRegex(ValueError, "archivo descargado.*lock"):
                self.obtener()
        self.assertFalse(self.destino.exists())

    def test_zip_fijado_pero_invalido_no_se_instala(self):
        self.zip = b"esto no es zip"
        self.escribir_lock()
        with self.assertRaises(zipfile.BadZipFile):
            self.obtener()
        self.assertFalse(self.destino.exists())

    def test_zip_con_rutas_ajenas_traversal_duplicados_y_enlaces_no_se_instala(self):
        enlace = zipfile.ZipInfo("enlace")
        enlace.external_attr = (stat.S_IFLNK | 0o777) << 16
        for nombre in ("../escape", "/escape", "C:/escape", "otra.dll", "manifiesto.json", enlace):
            with self.subTest(nombre=str(nombre)):
                self.zip = self.empaquetar(((nombre, b"alterado"),))
                self.escribir_lock()
                with self.assertRaises(ValueError):
                    self.obtener()
                self.assertFalse(self.destino.exists())
                self.assertFalse((self.raiz / "escape").exists())

    def test_manifiesto_del_zip_debe_coincidir_con_lock(self):
        self.artefacto["manifiesto_sha256"] = "0" * 64
        self.guardar_lock()
        with self.assertRaisesRegex(ValueError, "manifiesto descargado.*lock"):
            self.obtener()
        self.assertFalse(self.destino.exists())

    def test_archivos_ajenos_en_cache_se_conservan(self):
        self.obtener()
        ajeno = self.destino / "datos_usuario.txt"
        ajeno.write_text("conservar")
        with self.assertRaisesRegex(ValueError, "archivos ajenos"):
            self.obtener()
        self.assertEqual(ajeno.read_text(), "conservar")
        self.assertTrue((self.destino / self.manifiesto["entrypoint"]).exists())

    def test_destino_y_padres_enlazados_no_se_siguen(self):
        original = Path.is_symlink
        with patch.object(Path, "is_symlink", lambda ruta: ruta == self.destino.parent or original(ruta)):
            with self.assertRaisesRegex(ValueError, "padres no pueden ser enlaces"):
                self.obtener()
        self.assertFalse(self.destino.exists())

    def test_junction_windows_se_rechaza_sin_api_de_python312(self):
        original = Path.lstat
        falso = SimpleNamespace(st_mode=stat.S_IFDIR, st_file_attributes=0x400)
        with patch.object(Path, "lstat", lambda ruta: falso if ruta == self.destino else original(ruta)):
            with self.assertRaisesRegex(ValueError, "padres no pueden ser enlaces"):
                self.obtener()
        self.assertFalse(self.destino.exists())

    def test_nueva_aprobacion_con_otro_nombre_conserva_distribucion_anterior(self):
        anterior = self.obtener()
        nombre = self.manifiesto["entrypoint"]
        nuevo = nombre + ".nuevo"
        (self.origen / nombre).rename(self.origen / nuevo)
        self.manifiesto["entrypoint"] = nuevo
        self.manifiesto["archivos"] = {nuevo: self.manifiesto["binario_sha256"]}
        (self.origen / "manifiesto.json").write_text(json.dumps(self.manifiesto))
        self.zip = self.empaquetar()
        self.escribir_lock()
        with self.assertRaisesRegex(ValueError, "otro destino vacío"):
            self.obtener()
        self.assertEqual(Path(anterior["binario"]).read_bytes(), fixtures.elf())

    def test_error_de_red_conserva_cache_y_no_compila(self):
        self.obtener()
        entrada = self.destino / self.manifiesto["entrypoint"]
        entrada.write_bytes(b"cache corrupta")
        with patch.object(descarga.urllib.request, "urlopen", side_effect=OSError("sin red")), \
                patch.object(descarga.constructor, "preparar", side_effect=AssertionError("no compilar")):
            with self.assertRaisesRegex(OSError, "sin red"):
                descarga.descargar(self.raiz, "linux-x86_64", self.destino)
        self.assertEqual(entrada.read_bytes(), b"cache corrupta")

    def test_promocion_fallida_restaura_directorio_anterior(self):
        self.obtener()
        entrada = self.destino / self.manifiesto["entrypoint"]
        entrada.write_bytes(b"anterior")
        reemplazar = descarga.os.replace

        def fallo(origen, destino):
            if Path(origen).name == "motor":
                raise OSError("promoción interrumpida")
            reemplazar(origen, destino)

        with patch.object(descarga.os, "replace", side_effect=fallo):
            with self.assertRaisesRegex(OSError, "promoción interrumpida"):
                self.obtener()
        self.assertEqual(entrada.read_bytes(), b"anterior")

    def test_windows_descarga_consola_motor_y_dll_sin_ejecutarlos(self):
        self.origen.rename(self.raiz / "linux-anterior")
        self.origen, self.manifiesto = self.fixture.artefacto("windows-x86_64")
        self.zip = self.empaquetar()
        self.escribir_lock()
        self.lock.write_text(json.dumps({
            "formato": 1, "plataformas": {"windows-x86_64": self.artefacto},
        }), encoding="utf-8")
        with patch.object(descarga.urllib.request, "urlopen", return_value=io.BytesIO(self.zip)), \
                patch.object(descarga.constructor.subprocess, "run", side_effect=AssertionError("no ejecutar PE")):
            resultado = descarga.descargar(self.raiz, "windows-x86_64", self.destino)
        self.assertTrue(resultado["binario"].endswith(".console.exe"))
        self.assertEqual((self.destino / "D3D12/D3D12Core.dll").read_bytes(), b"dependencia")

    def test_url_externa_http_o_ambigua_y_receta_distinta_se_rechazan(self):
        for url in (
            "http://github.com/federicohermo/nosefia/releases/download/native-1/linux.zip",
            "https://otro.example/motor.zip",
            self.artefacto["url"] + "?token=secreto",
            self.artefacto["url"].replace("nosefia", "otro"),
        ):
            with self.subTest(url=url):
                self.artefacto["url"] = url
                self.guardar_lock()
                with self.assertRaisesRegex(ValueError, "release pública"):
                    descarga.identidad(self.raiz, "linux-x86_64")
        self.escribir_lock()
        self.artefacto["receta_sha256"] = "0" * 64
        self.guardar_lock()
        with self.assertRaisesRegex(ValueError, "receta nativa"):
            descarga.identidad(self.raiz, "linux-x86_64")


if __name__ == "__main__":
    unittest.main()
