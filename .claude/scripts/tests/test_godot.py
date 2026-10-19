"""Los tests de `lib/godot.py`: encontrar el ejecutable, o decir cómo se declara.

El lector del registro se inyecta, así que las tres fuentes —entorno, registro, PATH— se
ejercen en las tres plataformas y sin tocar el registro de la máquina que corre los tests.
"""

import unittest
import sys
import tempfile
from unittest.mock import Mock, patch

from pathlib import Path

from lib.godot import (
    ENTORNO,
    GESTIONADO,
    PATH,
    REGISTRO,
    aviso_de_entorno_viejo,
    como_declararlo,
    entorno_de_la_suite,
    resolver,
    motor_gestionado,
    validar_motor,
    WRAPPER_MEDICION,
)


def nada() -> None:
    """El doble de `del_registro`: no hay nada declarado en el registro."""
    return None


def nada_en_el_path(_nombre: str) -> None:
    """El doble de `en_el_path`. Toma un argumento: por eso no puede ser el mismo doble."""
    return None


class Resolver(unittest.TestCase):
    def setUp(self):
        gestionado = patch("lib.godot.motor_gestionado", return_value=None)
        gestionado.start()
        self.addCleanup(gestionado.stop)

    def test_el_entorno_gana_sobre_el_registro_y_el_path(self):
        # Es lo que alguien puso PARA ESTA CORRIDA: un `GODOT_BIN=… python verificar.py` para
        # probar otra versión tiene que ganarle a la declaración persistente.
        ruta, origen = resolver(
            {"GODOT_BIN": "/del/entorno/godot"},
            en_el_path=lambda n: "/del/path/godot",
            existe=lambda r: True,
            del_registro=lambda: "/del/registro/godot",
        )
        self.assertEqual((ruta, origen), ("/del/entorno/godot", ENTORNO))

    def test_sin_entorno_cae_al_registro(self):
        # ÉSTE es el caso que justifica el módulo entero. En Windows un proceso hereda el
        # entorno de su padre y no lo lee del registro, así que una terminal abierta antes de
        # declarar la variable no la ve NUNCA — ni ella ni nada de lo que lance.
        ruta, origen = resolver(
            {},
            en_el_path=lambda n: "/del/path/godot",
            existe=lambda r: True,
            del_registro=lambda: "/del/registro/godot",
        )
        self.assertEqual((ruta, origen), ("/del/registro/godot", REGISTRO))

    def test_sin_entorno_ni_registro_cae_al_path(self):
        ruta, origen = resolver(
            {},
            en_el_path=lambda n: "/del/path/godot" if n == "godot" else None,
            existe=lambda r: True,
            del_registro=nada,
        )
        self.assertEqual((ruta, origen), ("/del/path/godot", PATH))

    def test_un_valor_declarado_que_apunta_a_la_nada_no_cae_al_siguiente(self):
        # Es el caso de una ruta que se movió. Caer al PATH taparía el error y correría los
        # tests con OTRA versión de Godot que la declarada, en verde.
        self.assertEqual(
            resolver(
                {"GODOT_BIN": "/se/movio/godot"},
                en_el_path=lambda n: "/del/path/godot",
                existe=lambda r: False,
                del_registro=lambda: "/del/registro/godot",
            ),
            (None, None),
        )

    def test_un_registro_que_apunta_a_la_nada_tampoco(self):
        self.assertEqual(
            resolver({}, en_el_path=lambda n: "/del/path/godot", existe=lambda r: False,
                     del_registro=lambda: "/se/movio/godot"),
            (None, None),
        )

    def test_saca_las_comillas_y_los_espacios(self):
        # En Windows es normal que la variable quede guardada con comillas.
        ruta, _ = resolver({"GODOT_BIN": ' "/con/comillas/godot" '}, existe=lambda r: True,
                           del_registro=nada)
        self.assertEqual(ruta, "/con/comillas/godot")

    def test_una_variable_vacia_no_cuenta_como_declarada(self):
        # `GODOT_BIN=` en el entorno es lo mismo que no tenerla: sin esto se leería como una
        # ruta declarada que no existe, y el mensaje diría «se movió el ejecutable».
        ruta, origen = resolver({"GODOT_BIN": "   "}, en_el_path=nada_en_el_path, existe=lambda r: True,
                                del_registro=lambda: "/del/registro/godot")
        self.assertEqual((ruta, origen), ("/del/registro/godot", REGISTRO))

    def test_sin_nada_devuelve_none(self):
        self.assertEqual(
            resolver({}, en_el_path=nada_en_el_path, existe=lambda r: False, del_registro=nada), (None, None)
        )

    def test_copia_gestionada_validada_gana_al_registro(self):
        self.assertEqual(resolver(
            {}, gestionado=lambda: "/proyecto/build/godot", del_registro=lambda: "/oficial",
        ), ("/proyecto/build/godot", GESTIONADO))

    def test_copia_corrupta_no_cae_al_motor_oficial(self):
        with self.assertRaisesRegex(ValueError, "corrupto"):
            resolver({}, gestionado=Mock(side_effect=ValueError("corrupto")),
                     del_registro=lambda: "/oficial")


class IdentidadNativa(unittest.TestCase):
    DATOS = {"receta_sha256": "a" * 64, "binario_sha256": "b" * 64,
             "plataforma": "linux-x86_64", "archivos": {"Godot_v4": "b" * 64}}

    def test_copia_gestionada_se_valida_antes_de_devolver_la_ruta(self):
        with tempfile.TemporaryDirectory() as temporal:
            raiz = Path(temporal)
            carpeta = raiz / "build/godot-native/linux-x86_64"
            carpeta.mkdir(parents=True)
            preparador = Mock()
            preparador.plataforma_actual.return_value = "linux-x86_64"
            preparador.validar.return_value = {"binario": str(carpeta / "Godot_v4")}
            with patch("lib.godot.preparador_nativo", return_value=preparador):
                self.assertEqual(motor_gestionado(raiz), str(carpeta / "Godot_v4"))
            preparador.validar.assert_called_once_with(carpeta, raiz)

    def test_variable_real_aislada_no_evade_validacion_del_ejecutable(self):
        preparador = Mock()
        preparador.validar_binario.side_effect = ValueError("binario oficial sin parche")
        with patch("lib.godot.preparador_nativo", return_value=preparador):
            with self.assertRaisesRegex(ValueError, "sin parche"):
                validar_motor("/oficial", Path.cwd(), {"CI_GODOT_REAL": "/corregido"})
        preparador.validar_binario.assert_called_once_with(Path("/oficial").resolve(), Path.cwd())

    def test_wrapper_exacto_valida_el_motor_real(self):
        with tempfile.TemporaryDirectory() as temporal:
            raiz = Path(temporal)
            wrapper = raiz / "godot-medido"
            wrapper.write_text(WRAPPER_MEDICION, encoding="utf-8", newline="\n")
            entorno = {
                "RUNNER_TEMP": str(raiz), "CI_GODOT_REAL": str(raiz / "corregido"),
                "CI_BENCH_SCRIPT": str(raiz / ".github/scripts/medir_verificacion.py"),
                "CI_BENCH_PYTHON": sys.executable,
            }
            preparador = Mock()
            preparador.validar_binario.return_value = self.DATOS
            with patch("lib.godot.preparador_nativo", return_value=preparador):
                self.assertEqual(validar_motor(wrapper, raiz, entorno), self.DATOS)
            preparador.validar_binario.assert_called_once_with(raiz / "corregido", raiz)

    def test_wrapper_modificado_o_script_ajeno_no_evaden_el_preflight(self):
        with tempfile.TemporaryDirectory() as temporal:
            raiz = Path(temporal)
            wrapper = raiz / "godot-medido"
            for contenido, script in (
                ("#!/bin/sh\nexit 0\n", raiz / ".github/scripts/medir_verificacion.py"),
                (WRAPPER_MEDICION, raiz / "otro.py"),
            ):
                wrapper.write_text(contenido, encoding="utf-8", newline="\n")
                entorno = {
                    "RUNNER_TEMP": str(raiz), "CI_GODOT_REAL": str(raiz / "corregido"),
                    "CI_BENCH_SCRIPT": str(script), "CI_BENCH_PYTHON": sys.executable,
                }
                with self.subTest(script=script), patch(
                    "lib.godot.preparador_nativo"
                ) as cargar, self.assertRaisesRegex(ValueError, "wrapper"):
                    validar_motor(wrapper, raiz, entorno)
                cargar.assert_not_called()


class ComoDeclararlo(unittest.TestCase):
    def test_sin_la_variable_dice_como_declararla(self):
        mensaje = como_declararlo({}, del_registro=nada)
        self.assertIn("GODOT_BIN", mensaje)
        self.assertIn("preparar_godot_nativo.py", mensaje)

    def test_con_la_variable_rota_dice_que_se_movio(self):
        mensaje = como_declararlo({"GODOT_BIN": "/se/movio/godot"}, del_registro=nada)
        self.assertIn("/se/movio/godot", mensaje)
        self.assertIn("no existe", mensaje)

    def test_tambien_mira_el_registro_para_decidir_el_mensaje(self):
        # Si la declaración está sólo en el registro y apunta a la nada, el mensaje útil sigue
        # siendo «se movió», no «declarala».
        mensaje = como_declararlo({}, del_registro=lambda: "/se/movio/godot")
        self.assertIn("no existe", mensaje)

    def test_avisa_de_onedrive(self):
        # No es un detalle de color: es el estado en el que estaba la máquina donde se escribió
        # este harness. Un `.exe` que vive en OneDrive sin descargar se rechaza con «el proveedor
        # de archivos de nube no se está ejecutando», y ese mensaje no dice nada de Godot.
        self.assertIn("OneDrive", como_declararlo({}, del_registro=nada))


class AvisoDeEntornoViejo(unittest.TestCase):
    def test_avisa_cuando_salio_del_registro(self):
        aviso = aviso_de_entorno_viejo(REGISTRO)
        self.assertIn("no está en el entorno de esta terminal", aviso)

    def test_no_avisa_cuando_salio_del_entorno(self):
        # Un aviso que aparece siempre deja de leerse.
        self.assertIsNone(aviso_de_entorno_viejo(ENTORNO))

    def test_no_avisa_cuando_salio_del_path(self):
        self.assertIsNone(aviso_de_entorno_viejo(PATH))


if __name__ == "__main__":
    unittest.main()


class EntornoDeLaSuite(unittest.TestCase):
    """`user://` es una carpeta por proyecto, y la comparten todos los checkouts de la máquina.

    gdUnit4 borra `user://tmp` al terminar cada suite, así que dos corridas a la vez —dos
    worktrees de un batch— se borran la carpeta temporal una a la otra en medio de un caso.
    """

    RAIZ = Path("/un/checkout")

    def test_en_linux_el_usuario_de_godot_vive_adentro_del_checkout(self):
        entorno = entorno_de_la_suite({"HOME": "/home/x"}, self.RAIZ, "linux")
        self.assertEqual(entorno["XDG_DATA_HOME"], str(self.RAIZ / ".godot" / "usuario_de_los_tests"))
        self.assertEqual(entorno["HOME"], "/home/x")

    def test_en_windows_el_usuario_de_godot_vive_adentro_del_checkout(self):
        entorno = entorno_de_la_suite({"APPDATA": r"C:\Users\x\AppData\Roaming"}, self.RAIZ, "win32")
        self.assertEqual(entorno["APPDATA"], str(self.RAIZ / ".godot" / "usuario_de_los_tests"))

    def test_dos_checkouts_no_comparten_la_carpeta(self):
        uno = entorno_de_la_suite({}, Path("/a"), "linux")
        otro = entorno_de_la_suite({}, Path("/b"), "linux")
        self.assertNotEqual(uno["XDG_DATA_HOME"], otro["XDG_DATA_HOME"])

    def test_no_toca_el_entorno_que_recibe(self):
        original = {"XDG_DATA_HOME": "/del/usuario"}
        entorno_de_la_suite(original, self.RAIZ, "linux")
        self.assertEqual(original, {"XDG_DATA_HOME": "/del/usuario"})
