import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


RUTA = Path(__file__).resolve().parents[1] / "preparar_godot_nativo.py"
SPEC = importlib.util.spec_from_file_location("toolchain_godot_nativo", RUTA)
motor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(motor)
PAQUETE = "g++-mingw-w64-x86-64-posix"


class ToolchainTests(unittest.TestCase):
    def setUp(self):
        temporal = tempfile.TemporaryDirectory()
        self.addCleanup(temporal.cleanup)
        self.compilador = Path(temporal.name) / "x86_64-w64-mingw32-g++-posix"
        self.compilador.write_bytes(b"compilador del paquete")
        self.datos = {
            "scons": "4.9.1",
            "plataformas": {
                "windows-x86_64": {
                    "compilador": "x86_64-w64-mingw32-g++", "version_compilador": "13.2.0",
                },
                "linux-x86_64": {"compilador": "g++", "version_compilador": "13.3.0"},
            },
        }

    def comprobar(self, reportada="13-posix", host="Linux", plataforma="windows-x86_64",
                  propietario=None, version_paquete="13.2.0-6ubuntu1+26.1", salida="",
                  error="", codigo=0, localizado=True):
        respuestas = [
            reportada + "\n",
            propietario if propietario is not None else f"{PAQUETE}: {self.compilador.resolve()}\n",
            version_paquete,
        ]
        verificacion = subprocess.CompletedProcess(["dpkg"], codigo, salida, error)
        fallo = subprocess.CalledProcessError(codigo, ["dpkg"], output=salida, stderr=error)
        with patch.object(motor.platform, "system", return_value=host), \
                patch.object(motor.shutil, "which", return_value=str(self.compilador) if localizado else None), \
                patch.object(motor.subprocess, "check_output", side_effect=respuestas) as consultar, \
                patch.object(motor.subprocess, "run", side_effect=fallo if codigo else None,
                             return_value=verificacion) as verificar:
            resultado = motor._toolchain(self.datos, plataforma)
        return resultado, consultar.call_args_list, verificar.call_args_list

    def test_semver_linux_exacta_no_consulta_paquetes(self):
        resultado, consultas, verificaciones = self.comprobar(
            reportada="13.3.0", plataforma="linux-x86_64"
        )
        self.assertEqual(resultado["version_compilador"], "13.3.0")
        self.assertEqual(len(consultas), 1)
        self.assertEqual(verificaciones, [])

    def test_mingw_major_posix_obtiene_version_del_paquete_verificado(self):
        resultado, consultas, verificaciones = self.comprobar()
        self.assertEqual(resultado["version_compilador"], "13.2.0")
        self.assertEqual(resultado["version_reportada"], "13-posix")
        self.assertEqual(resultado["paquete_compilador"], {
            "nombre": PAQUETE, "version": "13.2.0-6ubuntu1+26.1",
            "archivo": str(self.compilador.resolve()),
        })
        self.assertEqual(consultas[1].args[0], ["dpkg-query", "-S", str(self.compilador.resolve())])
        self.assertEqual(consultas[2].args[0], ["dpkg-query", "-W", "-f=${Version}", PAQUETE])
        self.assertEqual(verificaciones[0].args[0], ["dpkg", "--verify", PAQUETE])
        self.assertTrue(verificaciones[0].kwargs["check"])

    def test_version_de_paquete_diferente_no_se_disfraza_como_la_esperada(self):
        for version in ("13.3.0-1", "13.2.01-1", "13.2.0", "1:13.2.0-1"):
            with self.subTest(version=version), self.assertRaisesRegex(ValueError, "paquete MinGW"):
                self.comprobar(version_paquete=version)

    def test_propietario_debe_ser_unico_y_del_archivo_resuelto(self):
        for propietario in (
            "otro-paquete: " + str(self.compilador.resolve()) + "\n",
            f"{PAQUETE}: /usr/bin/otro\n",
            f"{PAQUETE}: {self.compilador.resolve()}\n{PAQUETE}: /otro\n",
            "",
        ):
            with self.subTest(propietario=propietario), self.assertRaisesRegex(ValueError, "propietario"):
                self.comprobar(propietario=propietario)

    def test_archivos_de_paquete_modificados_o_no_verificables_fallan(self):
        for salida, error in (("??5?????? /usr/bin/g++\n", ""), ("", "aviso de verificación")):
            with self.subTest(salida=salida), self.assertRaisesRegex(ValueError, "modificados"):
                self.comprobar(salida=salida, error=error)
        with self.assertRaises(subprocess.CalledProcessError):
            self.comprobar(codigo=1)

    def test_fallback_no_admite_otros_hosts_banners_o_plataformas(self):
        for parametros in (
            {"host": "Windows"}, {"host": "Darwin"}, {"reportada": "13.0.0"},
            {"reportada": "14-posix"}, {"reportada": "13"},
            {"reportada": "13-posix", "plataforma": "linux-x86_64"},
        ):
            with self.subTest(parametros=parametros), self.assertRaisesRegex(ValueError, "compilador no compatible"):
                self.comprobar(**parametros)

    def test_ejecutable_sin_resolver_falla(self):
        with self.assertRaisesRegex(ValueError, "resolver el compilador"):
            self.comprobar(localizado=False)


if __name__ == "__main__":
    unittest.main()
