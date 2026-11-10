"""La caché y la exportación deben conservar la plantilla elegida, sin fallback oficial."""

import hashlib
import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
import urllib.error
import zipfile
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[3] / ".github/scripts/preparar_plantilla_web.py"
SPEC = importlib.util.spec_from_file_location("plantilla_web", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
plantilla = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(plantilla)


URL = "https://github.com/federicohermo/nosefia/releases/download/godot-web-1/web_release.zip"
WORKFLOW = "construir-plantilla-web.yml"


def sha(contenido):
    return hashlib.sha256(contenido).hexdigest()


class PlantillaWebTest(unittest.TestCase):
    def setUp(self):
        self.temporal = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporal.cleanup)
        self.raiz = Path(self.temporal.name)
        (self.raiz / ".godot-version").write_text("4.7.2-stable\n", encoding="utf-8")
        self.destino = self.raiz / "build/templates/web_release.zip"
        self.parche = self.raiz / "motor.patch"
        self._parche("parche medido")
        self.archivo = self.raiz / "motor.json"
        self.local = self.raiz / "local.zip"
        self.wasm = b"\0asm\x01\0\0\0"
        self.js = b"motor de prueba;var prevScissorTest=gl.isEnabled(3089);"
        self._zip(self.local)
        self.datos = {
            "version_del_motor": "4.7.2-stable",
            "commit_del_motor": "e" * 40,
            "fuente_zip_sha256": "a" * 64,
            "emsdk_zip_sha256": "b" * 64,
            "parche": self.parche.name,
            "emscripten": "4.0.11",
            "scons": "4.9.1",
            "opciones": list(plantilla.OPCIONES),
            "archivos": {
                "motor.cpp": {"original_sha256": "c" * 64, "modificado_sha256": "d" * 64},
            },
            "plantilla_publicada": {
                "url": URL, "zip_sha256": sha(self.local.read_bytes()),
                "wasm_sha256": sha(self.wasm),
            },
        }
        self._metadata()
        identidad = plantilla._identidad(self.archivo, self.raiz)[2]
        self.datos["plantilla_publicada"]["receta_sha256"] = plantilla.receta_sha256(identidad)
        self._metadata()
        self._preset()

    def _zip(self, ruta, wasm=None):
        with zipfile.ZipFile(ruta, "w", compression=zipfile.ZIP_STORED) as archivo:
            archivo.writestr("godot.wasm", self.wasm if wasm is None else wasm)
            archivo.writestr("godot.js", self.js)
            for nombre in (
                "godot.html", "godot.audio.worklet.js", "godot.audio.position.worklet.js",
                "godot.service.worker.js", "godot.offline.html",
            ):
                archivo.writestr(nombre, "contenido")

    def _parche(self, cambio, rutas=("motor.cpp",)):
        # En binario: en Windows, el modo texto escribe CRLF y `git apply` rechaza el parche.
        self.parche.write_bytes("".join(
            f"--- a/{ruta}\n+++ b/{ruta}\n@@ -1 +1 @@\n-antes\n+{cambio}\n" for ruta in rutas
        ).encode("utf-8"))

    def _metadata(self):
        self.archivo.write_text(json.dumps(self.datos), encoding="utf-8")

    def _preset(self, ruta="build/templates/web_release.zip", hilos=True, extensiones=False):
        (self.raiz / "export_presets.cfg").write_text(
            '[preset.0]\nplatform="Web"\n[preset.0.options]\n'
            f'custom_template/release="{ruta}"\n'
            f'variant/thread_support={str(hilos).lower()}\n'
            f'variant/extensions_support={str(extensiones).lower()}\n', encoding="utf-8",
        )

    def _preparar(self, **opciones):
        return plantilla.preparar(self.archivo, self.destino, raiz=self.raiz, **opciones)

    def _importar(self):
        resultado = self._preparar(desde=self.local)
        self.assertTrue(self.destino.exists(), "La importación no escribió la plantilla")
        return resultado

    def test_importa_zip_medido_y_reutiliza_cache_sin_construir(self):
        self._importar()
        self.assertEqual(self.local.read_bytes(), self.destino.read_bytes())
        with patch.object(plantilla, "construir") as construir:
            self._preparar(comprobar=True)
            self._preparar()
        construir.assert_not_called()
        self.assertTrue((self.raiz / "build/.gdignore").exists())
        manifiesto = json.loads(
            self.destino.with_suffix(".manifiesto.json").read_text(encoding="utf-8")
        )
        self.assertEqual(manifiesto["wasm_sha256"], sha(self.wasm))
        (self.raiz / "build/.gdignore").unlink()
        self._preparar(comprobar=True)
        self.assertTrue((self.raiz / "build/.gdignore").exists())

    def test_version_distinta_falla_antes_de_modificar_cache(self):
        (self.raiz / ".godot-version").write_text("4.8-stable\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "versi"):
            self._preparar(desde=self.local)
        self.assertFalse(self.destino.exists())

    def test_parche_cambiado_invalida_cache_aunque_zip_siga_sano(self):
        self._importar()
        self._parche("otro parche")
        with self.assertRaisesRegex(ValueError, "identidad|coincide"):
            self._preparar(comprobar=True)

    def test_metadata_fuente_sdk_o_opciones_cambiadas_invalidan_cache(self):
        self._importar()
        huellas = self.datos["archivos"]["motor.cpp"]
        for donde, campo in (
            (self.datos, "fuente_zip_sha256"), (self.datos, "emsdk_zip_sha256"),
            (huellas, "original_sha256"), (huellas, "modificado_sha256"),
        ):
            with self.subTest(campo=campo):
                original = donde[campo]
                donde[campo] = "f" * 64
                self._metadata()
                with self.assertRaisesRegex(ValueError, "identidad|coincide"):
                    self._preparar(comprobar=True)
                donde[campo] = original
        self.datos["opciones"][-1] = "lto=none"
        self._metadata()
        with self.assertRaises(ValueError):
            self._preparar(comprobar=True)

    def test_cache_zip_corrupto_no_pasa_comprobar(self):
        self._importar()
        self.destino.write_bytes(b"zip roto")
        with self.assertRaises(ValueError):
            self._preparar(comprobar=True)

    def test_importacion_incorrecta_conserva_cache_previa(self):
        self._importar()
        original = self.destino.read_bytes()
        self._zip(self.local, self.wasm + b"otro motor")
        with self.assertRaisesRegex(ValueError, "SHA"):
            self._preparar(desde=self.local)
        self.assertEqual(self.destino.read_bytes(), original)

    def test_publicacion_interrumpida_conserva_cache_y_limpia_temporales(self):
        self._importar()
        original = self.destino.read_bytes()
        manifiesto = self.destino.with_suffix(".manifiesto.json")
        original_manifiesto = manifiesto.read_bytes()
        archivos = set(self.destino.parent.iterdir())
        with patch.object(plantilla.os, "replace", side_effect=OSError("interrupción")):
            with self.assertRaises(OSError):
                self._preparar(desde=self.local)
        self.assertEqual(self.destino.read_bytes(), original)
        self.assertEqual(manifiesto.read_bytes(), original_manifiesto)
        self.assertEqual(set(self.destino.parent.iterdir()), archivos)

    def test_importar_zip_viejo_no_lo_reetiqueta_con_otra_receta(self):
        self._importar()
        original = self.destino.read_bytes()
        self._parche("parche nuevo")
        with self.assertRaisesRegex(ValueError, "receta"):
            self._preparar(desde=self.local)
        self.assertEqual(self.destino.read_bytes(), original)

    def test_rechaza_crc_roto_y_wasm_sin_cabecera(self):
        crudo = self.local.read_bytes()
        self.local.write_bytes(crudo.replace(self.js, b"X" + self.js[1:], 1))
        with self.assertRaisesRegex(ValueError, "CRC|ZIP"):
            plantilla.validar_zip(self.local)
        self._zip(self.local, b"no es wasm")
        with self.assertRaisesRegex(ValueError, "WASM|wasm"):
            plantilla.validar_zip(self.local)

    def test_rechaza_la_consulta_sincrona_de_recorte_en_cada_cuadro(self):
        self.js = b"var prevScissorTest=gl.getParameter(3089);"
        self._zip(self.local)
        with self.assertRaisesRegex(ValueError, "recorte"):
            plantilla.validar_zip(self.local)

    def test_corregir_el_recorte_conserva_el_motor_y_los_demas_archivos(self):
        self.js = b"var prevScissorTest=gl.getParameter(3089);"
        self._zip(self.local)
        with zipfile.ZipFile(self.local) as archivo:
            originales = {nombre: archivo.read(nombre) for nombre in archivo.namelist()}
        plantilla.corregir_recorte_zip(self.local)
        plantilla.validar_zip(self.local)
        with zipfile.ZipFile(self.local) as archivo:
            for nombre, contenido in originales.items():
                if nombre != "godot.js":
                    self.assertEqual(archivo.read(nombre), contenido)
        corregido = self.local.read_bytes()
        plantilla.corregir_recorte_zip(self.local)
        self.assertEqual(self.local.read_bytes(), corregido)

    def test_un_recorte_desconocido_no_reescribe_la_plantilla(self):
        self.js = b"otro SDK"
        self._zip(self.local)
        original = self.local.read_bytes()
        with self.assertRaisesRegex(ValueError, "recorte"):
            plantilla.corregir_recorte_zip(self.local)
        self.assertEqual(self.local.read_bytes(), original)

    def test_no_etiqueta_un_zip_desconocido_como_motor_parcheado(self):
        del self.datos["plantilla_publicada"]
        self._metadata()
        with self.assertRaisesRegex(ValueError, "plantilla_publicada"):
            self._preparar(desde=self.local)
        self.assertFalse(self.destino.exists())

    def test_cambio_de_preparador_invalida_cache_local(self):
        self._importar()
        otro_script = self.raiz / "preparador.py"
        otro_script.write_text("otra receta\n", encoding="utf-8")
        with patch.object(plantilla, "__file__", str(otro_script)):
            with self.assertRaisesRegex(ValueError, "identidad"):
                self._preparar(comprobar=True)

    def test_parche_real_no_hereda_autocrlf_ni_repositorio_padre(self):
        subprocess.run(["git", "init", "-q", str(self.raiz)], check=True)
        config = self.raiz / "global.gitconfig"
        config.write_text("[core]\n\tautocrlf = true\n", encoding="utf-8")
        motor = self.raiz / "build/engine"
        padre = self.raiz / "drivers/gles3/shader_gles3.cpp"
        padre.parent.mkdir(parents=True)
        padre.write_bytes(b"padre\n")
        cpp = motor / "drivers/gles3/shader_gles3.cpp"
        cpp.parent.mkdir(parents=True)
        cpp.write_bytes(b"antes\n")
        self.parche.write_bytes(
            b"--- a/drivers/gles3/shader_gles3.cpp\n"
            b"+++ b/drivers/gles3/shader_gles3.cpp\n"
            b"@@ -1 +1 @@\n-antes\n+despues\n"
        )
        datos = {"archivos": {"drivers/gles3/shader_gles3.cpp": {
            "original_sha256": sha(b"antes\n"), "modificado_sha256": sha(b"despues\n"),
        }}}
        with patch.dict(os.environ, {"GIT_CONFIG_GLOBAL": str(config)}):
            plantilla._aplicar_parche(datos, self.parche, motor, self.raiz / "parche.log")
        self.assertEqual(cpp.read_bytes(), b"despues\n")
        self.assertEqual(padre.read_bytes(), b"padre\n")

    def _motor_con_dos_archivos(self):
        motor = self.raiz / "build/engine"
        motor.mkdir(parents=True)
        for nombre in ("uno.cpp", "dos.h"):
            (motor / nombre).write_bytes(b"antes\n")
        self._parche("despues", ("uno.cpp", "dos.h"))
        huellas = {"original_sha256": sha(b"antes\n"), "modificado_sha256": sha(b"despues\n")}
        return motor, {"archivos": {"uno.cpp": dict(huellas), "dos.h": dict(huellas)}}

    def test_el_parche_comprueba_la_huella_de_cada_archivo_antes_y_despues(self):
        motor, datos = self._motor_con_dos_archivos()
        plantilla._aplicar_parche(datos, self.parche, motor, self.raiz / "parche.log")
        self.assertEqual((motor / "uno.cpp").read_bytes(), b"despues\n")
        self.assertEqual((motor / "dos.h").read_bytes(), b"despues\n")

    def test_un_archivo_distinto_del_medido_frena_el_parche_sin_aplicarlo(self):
        motor, datos = self._motor_con_dos_archivos()
        datos["archivos"]["dos.h"]["original_sha256"] = "f" * 64
        with self.assertRaisesRegex(ValueError, "original.*dos.h"):
            plantilla._aplicar_parche(datos, self.parche, motor, self.raiz / "parche.log")
        self.assertEqual((motor / "uno.cpp").read_bytes(), b"antes\n")

    def test_un_resultado_distinto_del_medido_falla_despues_de_aplicar(self):
        motor, datos = self._motor_con_dos_archivos()
        datos["archivos"]["dos.h"]["modificado_sha256"] = "f" * 64
        with self.assertRaisesRegex(ValueError, "modificado.*dos.h"):
            plantilla._aplicar_parche(datos, self.parche, motor, self.raiz / "parche.log")

    def test_la_receta_tiene_que_nombrar_cada_archivo_que_el_parche_toca(self):
        self._parche("parche medido", ("motor.cpp", "otro.h"))
        with self.assertRaisesRegex(ValueError, "otro.h"):
            self._preparar(comprobar=True)
        self._parche("parche medido", ())
        with self.assertRaisesRegex(ValueError, "motor.cpp"):
            self._preparar(comprobar=True)

    def test_la_receta_del_repo_cubre_el_parche_del_repo(self):
        datos, parche, _ = plantilla._identidad(plantilla.METADATA, plantilla.RAIZ)
        self.assertEqual(set(datos["archivos"]), plantilla.archivos_del_parche(parche))
        self.assertGreater(len(datos["archivos"]), 1)

    def test_cada_linea_que_el_parche_del_repo_agrega_queda_bajo_web_enabled(self):
        """El editor y la plantilla de debug compilan la misma fuente sin el parche activo."""
        parche = plantilla._identidad(plantilla.METADATA, plantilla.RAIZ)[1]
        bajo_web = False
        for numero, linea in enumerate(parche.read_text(encoding="utf-8").splitlines(), 1):
            if linea.startswith("@@"):
                bajo_web = False
            if not linea.startswith("+") or linea.startswith("+++"):
                continue
            agregado = linea[1:].strip()
            if agregado == "#ifdef WEB_ENABLED":
                bajo_web = True
            elif agregado.startswith(("#else", "#endif")):
                bajo_web = False
            elif agregado:
                self.assertTrue(bajo_web, f"línea {numero} fuera de WEB_ENABLED: {linea}")

    def test_comprobar_rechaza_template_oficial_hilos_o_extensiones(self):
        self._importar()
        for ruta, hilos, extensiones in (
            ("", True, False), ("build/templates/otro.zip", True, False),
            ("build/templates/web_release.zip", False, False),
            ("build/templates/web_release.zip", True, True),
        ):
            with self.subTest(ruta=ruta, hilos=hilos, extensiones=extensiones):
                self._preset(ruta, hilos, extensiones)
                with self.assertRaisesRegex(ValueError, "preset|hilos|extensions"):
                    self._preparar(comprobar=True)

    def test_exportacion_compara_wasm_y_js_y_rechaza_fallback(self):
        exportacion = self.raiz / "export/web"
        exportacion.mkdir(parents=True)
        (exportacion / "index.wasm").write_bytes(self.wasm)
        (exportacion / "index.js").write_bytes(self.js)
        plantilla.verificar_export(exportacion, self.local)
        for nombre in ("index.wasm", "index.js"):
            with self.subTest(nombre=nombre):
                archivo = exportacion / nombre
                original = archivo.read_bytes()
                archivo.write_bytes(original + b"oficial")
                with self.assertRaisesRegex(ValueError, "export|coincide"):
                    plantilla.verificar_export(exportacion, self.local)
                archivo.write_bytes(original)

    def test_construccion_host_distinto_no_exige_sha_windows(self):
        otro = self.raiz / "linux.zip"
        self._zip(otro, self.wasm + b"host distinto")
        with patch.object(plantilla, "construir", return_value=otro) as construir:
            self._preparar(jobs=2)
        self.assertTrue(self.destino.exists())
        construir.assert_called_once()
        self._preparar(comprobar=True)

    def _servir(self, contenido):
        """Un `urlopen` que entrega `contenido` y anota qué se le pidió."""
        pedidos = []

        def abrir(url, timeout):
            pedidos.append(url)
            return io.BytesIO(contenido)

        abrir.pedidos = pedidos
        return abrir

    def _descargar(self, abrir):
        return plantilla.descargar_plantilla(self.archivo, self.destino, self.raiz, abrir)

    def test_descargar_importa_la_plantilla_publicada_y_no_compila(self):
        abrir = self._servir(self.local.read_bytes())
        with patch.object(plantilla, "construir") as construir:
            self._descargar(abrir)
            self._preparar(comprobar=True)
        construir.assert_not_called()
        self.assertEqual(abrir.pedidos, [URL])
        self.assertEqual(self.destino.read_bytes(), self.local.read_bytes())

    def test_dos_descargas_seguidas_dejan_la_misma_plantilla(self):
        abrir = self._servir(self.local.read_bytes())
        self._descargar(abrir)
        primera = self.destino.read_bytes()
        self._descargar(abrir)
        self.assertEqual(len(abrir.pedidos), 2)
        self.assertEqual(self.destino.read_bytes(), primera)

    def test_un_zip_con_otra_huella_no_se_extrae_ni_se_publica(self):
        abrir = self._servir(b"no es la plantilla publicada")
        with patch.object(plantilla, "validar_zip") as validar:
            with self.assertRaisesRegex(ValueError, f"zip_sha256.*{WORKFLOW}"):
                self._descargar(abrir)
        validar.assert_not_called()
        self.assertFalse(self.destino.exists())

    def test_un_zip_con_otro_wasm_sale_rojo_por_su_huella(self):
        self.datos["plantilla_publicada"]["wasm_sha256"] = sha(b"otro wasm")
        self._metadata()
        with self.assertRaisesRegex(ValueError, f"wasm_sha256.*{WORKFLOW}"):
            self._descargar(self._servir(self.local.read_bytes()))
        self.assertFalse(self.destino.exists())

    def test_una_receta_cambiada_falla_sin_bajar_nada(self):
        self._parche("parche nuevo")
        abrir = self._servir(self.local.read_bytes())
        with self.assertRaisesRegex(ValueError, f"receta.*{WORKFLOW}"):
            self._descargar(abrir)
        self.assertEqual(abrir.pedidos, [])

    def test_sin_plantilla_publicada_falla_y_nombra_el_workflow(self):
        del self.datos["plantilla_publicada"]
        self._metadata()
        abrir = self._servir(b"")
        with self.assertRaisesRegex(ValueError, f"plantilla_publicada.*{WORKFLOW}"):
            self._descargar(abrir)
        self.assertEqual(abrir.pedidos, [])

    def test_una_url_que_no_responde_se_nombra_y_conserva_la_cache(self):
        self._descargar(self._servir(self.local.read_bytes()))
        original = self.destino.read_bytes()

        def abrir(url, timeout):
            raise urllib.error.HTTPError(url, 404, "Not Found", {}, None)

        with self.assertRaisesRegex(ValueError, f"{URL}.*{WORKFLOW}"):
            self._descargar(abrir)
        self.assertEqual(self.destino.read_bytes(), original)
        self._preparar(comprobar=True)

    def test_descargar_no_se_combina_con_desde_ni_con_comprobar(self):
        for otro in (["--desde", "x.zip"], ["--comprobar"]):
            with self.subTest(otro=otro):
                with patch.object(sys, "argv", ["preparar", "--descargar", *otro]):
                    with patch.object(plantilla, "preparar") as preparar:
                        with self.assertRaises(SystemExit):
                            plantilla.main()
                preparar.assert_not_called()

    def test_la_receta_del_repo_declara_una_sola_plantilla_publicada(self):
        datos = json.loads(plantilla.METADATA.read_text(encoding="utf-8"))
        self.assertNotIn("plantilla_local", datos)
        publicada = datos["plantilla_publicada"]
        self.assertRegex(publicada["url"], r"^https://github\.com/federicohermo/nosefia/releases/")
        for campo in ("receta_sha256", "zip_sha256", "wasm_sha256"):
            self.assertRegex(publicada[campo], r"^[0-9a-f]{64}$", campo)


if __name__ == "__main__":
    unittest.main()
