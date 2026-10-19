import hashlib
import importlib.util
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
import zipfile


RUTA = Path(__file__).resolve().parents[1] / "preparar_godot_nativo.py"
SPEC = importlib.util.spec_from_file_location("preparar_godot_nativo", RUTA)
motor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(motor)
MARCA = "nosefia_classdb_1"


def digest(datos):
    return hashlib.sha256(datos).hexdigest()


def elf(marca=MARCA):
    datos = bytearray(80)
    datos[:6] = b"\x7fELF\x02\x01"
    datos[18:20] = (62).to_bytes(2, "little")
    return bytes(datos) + marca.encode("ascii")


def pe(marca=MARCA):
    datos = bytearray(80)
    datos[:2] = b"MZ"
    datos[60:64] = (64).to_bytes(4, "little")
    datos[64:70] = b"PE\0\0\x64\x86"
    return bytes(datos) + marca.encode("ascii")


class MotorNativoTests(unittest.TestCase):
    def setUp(self):
        self.temporal = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporal.cleanup)
        self.raiz = Path(self.temporal.name)
        (self.raiz / ".godot-version").write_text("4.7.2-stable\n")
        self.metadata = self.raiz / motor.METADATA
        self.metadata.parent.mkdir(parents=True)
        parche = b"+++ b/core/object/class_db.cpp\n+lock\n"
        (self.metadata.parent / "fix.patch").write_bytes(parche)
        docker = self.raiz / motor.DOCKERFILE
        docker.parent.mkdir(parents=True)
        docker.write_text("FROM ubuntu:24.04\n")
        self.receta = {
            "formato": 1, "version_del_motor": "4.7.2-stable",
            "commit_del_motor": "a" * 40, "fuente_zip_sha256": "b" * 64,
            "parche": "fix.patch", "parche_sha256": digest(parche),
            "build_name": MARCA, "scons": "4.9.1",
            "source_date_epoch": 1787069548,
            "opciones_comunes": ["target=editor", "arch=x86_64"],
            "archivos": {"core/object/class_db.cpp": {
                "original_sha256": digest(b"antes"), "modificado_sha256": digest(b"despues"),
            }},
            "plataformas": {
                "linux-x86_64": {
                    "opciones": ["platform=linuxbsd"],
                    "compilador": "g++", "version_compilador": "13.3.0",
                },
                "windows-x86_64": {
                    "opciones": ["platform=windows", "use_mingw=yes"],
                    "compilador": "x86_64-w64-mingw32-g++", "version_compilador": "13.2.0",
                },
            },
        }
        self.escribir_receta()

    def escribir_receta(self):
        self.metadata.write_text(json.dumps(self.receta), encoding="utf-8")

    def artefacto(self, plataforma="linux-x86_64", contenido=None):
        carpeta = self.raiz / "preparado"
        carpeta.mkdir(exist_ok=True)
        identidad = motor.identidad(self.raiz, plataforma)
        if plataforma == "linux-x86_64":
            archivos = {"Godot_v4.7.2-stable_nosefia_classdb_linux.x86_64": contenido or elf()}
        else:
            archivos = {
                "godot.windows.editor.x86_64.console.exe": pe("consola"),
                "godot.windows.editor.x86_64.exe": pe(),
                "D3D12/D3D12Core.dll": b"dependencia",
            }
        for nombre, datos in archivos.items():
            ruta = carpeta / nombre
            ruta.parent.mkdir(parents=True, exist_ok=True)
            ruta.write_bytes(datos)
        entrada = next(iter(archivos))
        manifiesto = {
            "formato": 1, "receta_sha256": identidad["receta_sha256"],
            "plataforma": plataforma, "entrypoint": entrada,
            "archivos": {nombre: digest(datos) for nombre, datos in archivos.items()},
            "binario_sha256": digest(archivos[entrada]),
            "version": "4.7.2.stable." + MARCA,
            "toolchain": identidad["toolchain"],
        }
        motor._guardar(carpeta / motor.MANIFIESTO, manifiesto)
        return carpeta, manifiesto

    def fuente_compilada(self, plataforma="linux-x86_64"):
        fuente = self.raiz / "fuente"
        cpp = fuente / "core/object/class_db.cpp"
        cpp.parent.mkdir(parents=True)
        cpp.write_bytes(b"despues")
        (fuente / "otra.cpp").write_bytes(b"fuente original")
        archivo = fuente.parent / "godot.zip"
        with zipfile.ZipFile(archivo, "w") as salida:
            salida.writestr("godot/core/object/class_db.cpp", b"antes")
            salida.writestr("godot/otra.cpp", b"fuente original")
        self.receta["fuente_zip_sha256"] = digest(archivo.read_bytes())
        self.escribir_receta()
        cabecera = fuente / "core/version_generated.gen.h"
        cabecera.write_text(
            '#define GODOT_VERSION_MAJOR 4\n#define GODOT_VERSION_MINOR 7\n'
            '#define GODOT_VERSION_PATCH 2\n#define GODOT_VERSION_STATUS "stable"\n'
            '#define GODOT_VERSION_BUILD "nosefia_classdb_1"\n'
        )
        binarios = fuente / "bin"
        binarios.mkdir()
        if plataforma == "linux-x86_64":
            (binarios / "godot.linuxbsd.editor.x86_64").write_bytes(elf())
        else:
            (binarios / "godot.windows.editor.x86_64.console.exe").write_bytes(pe("consola"))
            (binarios / "godot.windows.editor.x86_64.exe").write_bytes(pe())
            (binarios / "dxil.dll").write_bytes(b"dll")
        return fuente

    def test_identidad_depende_de_receta_parche_builder_y_plataforma(self):
        inicial = motor.identidad(self.raiz, "linux-x86_64")["receta_sha256"]
        windows = motor.identidad(self.raiz, "windows-x86_64")["receta_sha256"]
        self.assertNotEqual(inicial, windows)
        docker = self.raiz / motor.DOCKERFILE
        docker.write_text(docker.read_text() + "RUN true\n")
        self.assertNotEqual(inicial, motor.identidad(self.raiz, "linux-x86_64")["receta_sha256"])
        docker.write_text("FROM ubuntu:24.04\n")
        self.receta["opciones_comunes"].append("lto=none")
        self.escribir_receta()
        self.assertNotEqual(inicial, motor.identidad(self.raiz, "linux-x86_64")["receta_sha256"])

    def test_crlf_no_cambia_identidad_entre_checkout_windows_y_linux(self):
        inicial = motor.identidad(self.raiz, "linux-x86_64")
        for ruta in (self.metadata, self.metadata.parent / "fix.patch",
                     self.raiz / motor.DOCKERFILE):
            ruta.write_bytes(motor._texto_lf(ruta).replace(b"\n", b"\r\n"))
        self.assertEqual(inicial, motor.identidad(self.raiz, "linux-x86_64"))

    def test_version_base_divergente_falla(self):
        (self.raiz / ".godot-version").write_text("4.8-stable")
        with self.assertRaisesRegex(ValueError, "godot-version"):
            motor.identidad(self.raiz, "linux-x86_64")

    def test_parche_con_hash_incorrecto_falla(self):
        (self.metadata.parent / "fix.patch").write_text("cambiado")
        with self.assertRaisesRegex(ValueError, "hash del parche"):
            motor.identidad(self.raiz, "linux-x86_64")

    def test_epoch_no_admite_booleano_ni_negativo(self):
        for epoch in (-1, True, "1787069548"):
            self.receta["source_date_epoch"] = epoch
            self.escribir_receta()
            with self.subTest(epoch=epoch), self.assertRaisesRegex(ValueError, "SOURCE_DATE_EPOCH"):
                motor.identidad(self.raiz, "linux-x86_64")

    def test_descarga_existente_corrupta_falla_sin_aceptarla(self):
        archivo = self.raiz / "fuente.zip"
        archivo.write_bytes(b"corrupto")
        with patch.object(motor.urllib.request, "urlopen") as descargar:
            with self.assertRaisesRegex(ValueError, "SHA256"):
                motor._descargar("https://example.invalid", archivo, "0" * 64)
        descargar.assert_not_called()

    def test_arbol_incremental_alterado_falla_antes_de_scons(self):
        trabajo = self.raiz / "trabajo"
        trabajo.mkdir()
        archivo = trabajo / "godot.zip"
        with zipfile.ZipFile(archivo, "w") as salida:
            salida.writestr("godot/core/object/class_db.cpp", b"antes")
            salida.writestr("godot/otra.cpp", b"fuente original")
        datos = dict(self.receta, fuente_zip_sha256=digest(archivo.read_bytes()))
        fuente = trabajo / "source"
        (fuente / "core/object").mkdir(parents=True)
        (fuente / "core/object/class_db.cpp").write_bytes(b"despues")
        (fuente / "otra.cpp").write_bytes(b"fuente alterada")
        motor._guardar(trabajo / "fuentes.json", {
            clave: datos[clave]
            for clave in ("commit_del_motor", "fuente_zip_sha256", "parche_sha256")
        })
        with self.assertRaisesRegex(ValueError, "árbol incremental"):
            motor._fuentes(datos, self.metadata.parent / "fix.patch", trabajo, trabajo / "log")

    def test_valida_artefacto_sin_ejecutar_motor(self):
        carpeta, manifiesto = self.artefacto()
        with patch.object(motor.subprocess, "run", side_effect=AssertionError("no ejecutar")):
            resultado = motor.validar(carpeta, self.raiz, "linux-x86_64")
        self.assertEqual(resultado["binario"], str((carpeta / manifiesto["entrypoint"]).resolve()))

    def test_binario_corrupto_es_rojo(self):
        carpeta, manifiesto = self.artefacto()
        (carpeta / manifiesto["entrypoint"]).write_bytes(b"corrupto")
        with self.assertRaisesRegex(ValueError, "SHA256"):
            motor.validar(carpeta, self.raiz, "linux-x86_64")

    def test_binario_oficial_reetiquetado_es_rojo(self):
        carpeta, _ = self.artefacto(contenido=elf("official"))
        with self.assertRaisesRegex(ValueError, "identidad del build"):
            motor.validar(carpeta, self.raiz, "linux-x86_64")

    def test_receta_preparada_distinta_es_roja(self):
        carpeta, manifiesto = self.artefacto()
        manifiesto["receta_sha256"] = "0" * 64
        motor._guardar(carpeta / motor.MANIFIESTO, manifiesto)
        with self.assertRaisesRegex(ValueError, "receta del motor"):
            motor.validar(carpeta, self.raiz, "linux-x86_64")

    def test_plataforma_incompatible_es_roja(self):
        carpeta, manifiesto = self.artefacto()
        manifiesto["plataforma"] = "windows-x86_64"
        motor._guardar(carpeta / motor.MANIFIESTO, manifiesto)
        with self.assertRaisesRegex(ValueError, "plataforma del motor"):
            motor.validar(carpeta, self.raiz, "linux-x86_64")

    def test_dll_fuera_de_manifiesto_es_roja(self):
        carpeta, _ = self.artefacto()
        (carpeta / "otra.dll").write_bytes(b"extra")
        with self.assertRaisesRegex(ValueError, "fuera del manifiesto"):
            motor.validar(carpeta, self.raiz, "linux-x86_64")

    def test_manifest_no_admite_traversal(self):
        carpeta, manifiesto = self.artefacto()
        manifiesto["archivos"]["../afuera"] = "0" * 64
        motor._guardar(carpeta / motor.MANIFIESTO, manifiesto)
        with self.assertRaisesRegex(ValueError, "ruta de artefacto"):
            motor.validar(carpeta, self.raiz, "linux-x86_64")

    def test_windows_valida_consola_motor_y_dll(self):
        carpeta, _ = self.artefacto("windows-x86_64")
        resultado = motor.validar(carpeta, self.raiz, "windows-x86_64")
        self.assertTrue(resultado["entrypoint"].endswith(".console.exe"))
        (carpeta / "D3D12/D3D12Core.dll").write_bytes(b"otra dependencia")
        with self.assertRaisesRegex(ValueError, "SHA256"):
            motor.validar(carpeta, self.raiz, "windows-x86_64")

    def test_validar_binario_rechaza_exe_real_si_entrypoint_es_consola(self):
        carpeta, _ = self.artefacto("windows-x86_64")
        real = carpeta / "godot.windows.editor.x86_64.exe"
        with patch.object(motor, "plataforma_actual", return_value="windows-x86_64"):
            with self.assertRaisesRegex(ValueError, "entrypoint"):
                motor.validar_binario(real, self.raiz)

    def test_zip_hostil_no_escribe_fuera_ni_acepta_enlaces(self):
        for indice, nombre in enumerate(("root/../escape", "/root/escape", "root/escape")):
            with self.subTest(nombre=nombre):
                archivo = self.raiz / f"malo-{indice}.zip"
                with zipfile.ZipFile(archivo, "w") as salida:
                    salida.writestr(nombre, b"x")
                if indice == 2:
                    archivo.write_bytes(
                        archivo.read_bytes().replace(b"root/escape", b"root\\escape")
                    )
                with self.assertRaises(ValueError):
                    motor._extraer(archivo, self.raiz / f"extraido-{indice}")
        archivo = self.raiz / "enlace.zip"
        with zipfile.ZipFile(archivo, "w") as salida:
            info = zipfile.ZipInfo("root/enlace")
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            salida.writestr(info, b"/tmp/otro")
        with self.assertRaisesRegex(ValueError, "enlaces"):
            motor._extraer(archivo, self.raiz / "enlace-extraido")

    def test_zip_valido_preserva_archivos_y_no_requiere_raiz_explicita(self):
        archivo = self.raiz / "fuente.zip"
        with zipfile.ZipFile(archivo, "w") as salida:
            salida.writestr("root/carpeta/archivo", b"fuente")
        destino = self.raiz / "extraido"
        motor._extraer(archivo, destino)
        self.assertEqual((destino / "carpeta/archivo").read_bytes(), b"fuente")

    def test_publicar_adopta_build_existente_sin_compilar_ni_ejecutar_pe(self):
        fuente = self.fuente_compilada("windows-x86_64")
        toolchain = motor.identidad(self.raiz, "windows-x86_64")["toolchain"]
        with patch.object(motor, "_ejecutar", side_effect=AssertionError("no compilar")):
            resultado = motor.publicar(
                fuente, self.raiz / "publicado", self.raiz, "windows-x86_64", toolchain
            )
        self.assertEqual(resultado["version_origen"], "cabecera-generada")
        self.assertEqual(len(resultado["archivos"]), 3)

    def test_publicar_rechaza_fuente_sin_parche(self):
        fuente = self.fuente_compilada()
        (fuente / "core/object/class_db.cpp").write_bytes(b"antes")
        toolchain = motor.identidad(self.raiz, "linux-x86_64")["toolchain"]
        with self.assertRaisesRegex(ValueError, "fuente sin parche"):
            motor.publicar(fuente, self.raiz / "publicado", self.raiz, "linux-x86_64", toolchain)

    def test_publicar_rechaza_otra_fuente_original_modificada(self):
        fuente = self.fuente_compilada()
        (fuente / "otra.cpp").write_bytes(b"alterada")
        toolchain = motor.identidad(self.raiz, "linux-x86_64")["toolchain"]
        with self.assertRaisesRegex(ValueError, "árbol incremental"):
            motor.publicar(fuente, self.raiz / "publicado", self.raiz, "linux-x86_64", toolchain)

    def test_publicar_no_borra_datos_ajenos_del_destino(self):
        fuente = self.fuente_compilada()
        destino = self.raiz / "publicado"
        destino.mkdir()
        ajeno = destino / "datos_usuario.txt"
        ajeno.write_text("conservar")
        toolchain = motor.identidad(self.raiz, "linux-x86_64")["toolchain"]
        with self.assertRaisesRegex(ValueError, "archivos ajenos"):
            motor.publicar(fuente, destino, self.raiz, "linux-x86_64", toolchain)
        self.assertEqual(ajeno.read_text(), "conservar")
        self.assertEqual(list(destino.iterdir()), [ajeno])

    def test_publicar_rechaza_destino_enlazado_antes_de_resolver(self):
        destino = self.raiz / "enlace"
        fuente = self.fuente_compilada()
        toolchain = motor.identidad(self.raiz, "linux-x86_64")["toolchain"]
        original = Path.is_symlink
        with patch.object(Path, "is_symlink", lambda ruta: ruta == destino or original(ruta)):
            with self.assertRaisesRegex(ValueError, "padres no pueden ser enlaces"):
                motor.publicar(fuente, destino, self.raiz, "linux-x86_64", toolchain)
        self.assertFalse(destino.exists())

    def test_publicar_reconstruye_corrupto_y_elimina_solo_obsoletos_declarados(self):
        fuente = self.fuente_compilada()
        carpeta, manifiesto = self.artefacto()
        obsoleto = carpeta / "obsoleto.dll"
        obsoleto.write_bytes(b"anterior")
        manifiesto["archivos"]["obsoleto.dll"] = digest(b"anterior")
        motor._guardar(carpeta / motor.MANIFIESTO, manifiesto)
        (carpeta / manifiesto["entrypoint"]).write_bytes(b"corrupto")
        toolchain = motor.identidad(self.raiz, "linux-x86_64")["toolchain"]
        resultado = motor.publicar(fuente, carpeta, self.raiz, "linux-x86_64", toolchain)
        self.assertFalse(obsoleto.exists())
        self.assertEqual(len(resultado["archivos"]), 1)

    def test_hit_no_compila_y_corrupcion_solicita_reconstruccion(self):
        carpeta, manifiesto = self.artefacto()
        with patch.object(motor, "_toolchain", side_effect=AssertionError("no compilar")):
            self.assertEqual(
                motor.preparar(self.raiz, "linux-x86_64", carpeta)["entrypoint"],
                manifiesto["entrypoint"],
            )
        (carpeta / manifiesto["entrypoint"]).write_bytes(b"corrupto")
        with patch.object(motor, "_toolchain", side_effect=RuntimeError("reconstruccion")):
            with self.assertRaisesRegex(RuntimeError, "reconstruccion"):
                motor.preparar(self.raiz, "linux-x86_64", carpeta)

    def test_cache_invalida_no_admite_fallback_oficial(self):
        carpeta, _ = self.artefacto(contenido=elf("official"))
        with patch.object(motor, "RAIZ", self.raiz):
            codigo = motor.main([
                "comprobar", "--plataforma", "linux-x86_64", "--destino", str(carpeta),
            ])
        self.assertEqual(codigo, 1)


if __name__ == "__main__":
    unittest.main()
