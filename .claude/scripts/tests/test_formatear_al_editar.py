"""El hook que deja formateado cada `.gd` que se edita.

Lo puro se ejerce directo. El hook entero se lanza como subproceso con un payload por stdin,
que es como lo lanza Claude Code, y contra el `gdformat` de verdad.
"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import formatear_al_editar
from lib.formato import formatear, ruta_a_formatear

SCRIPT = Path(formatear_al_editar.__file__)

SIN_FORMATO = "func f()->void:\n  var x=1\n"
CON_FORMATO = "func f() -> void:\n\tvar x = 1\n"


def _payload(ruta: str, herramienta: str = "Edit", cwd: str = "") -> dict:
    return {
        "hook_event_name": "PostToolUse",
        "tool_name": herramienta,
        "tool_input": {"file_path": ruta},
        "cwd": cwd,
    }


class QueArchivoFormatea(unittest.TestCase):
    def test_las_tres_herramientas_que_escriben_formatean_un_gd(self) -> None:
        for herramienta in ("Edit", "Write", "MultiEdit"):
            with self.subTest(herramienta=herramienta):
                ruta = ruta_a_formatear(_payload("/repo/src/dominio/turno.gd", herramienta))
                self.assertEqual(ruta, "/repo/src/dominio/turno.gd")

    def test_otra_herramienta_no_formatea(self) -> None:
        self.assertIsNone(ruta_a_formatear(_payload("/repo/src/x.gd", "Read")))

    def test_un_archivo_que_no_es_gd_no_se_toca(self) -> None:
        for ruta in ("/repo/escena.tscn", "/repo/docs/x.md", "/repo/x.gdshader"):
            with self.subTest(ruta=ruta):
                self.assertIsNone(ruta_a_formatear(_payload(ruta)))

    def test_un_gd_de_addons_no_se_toca(self) -> None:
        for ruta in ("/repo/addons/gdUnit4/x.gd", r"C:\repo\addons\gdUnit4\x.gd"):
            with self.subTest(ruta=ruta):
                self.assertIsNone(ruta_a_formatear(_payload(ruta)))

    def test_una_ruta_de_windows_con_barras_invertidas_se_formatea(self) -> None:
        ruta = r"C:\repo\src\dominio\turno.gd"
        self.assertEqual(ruta_a_formatear(_payload(ruta)), ruta)

    def test_una_ruta_relativa_se_resuelve_contra_el_cwd_del_payload(self) -> None:
        ruta = ruta_a_formatear(_payload("src/x.gd", cwd="/repo"))
        self.assertEqual(Path(ruta), Path("/repo/src/x.gd"))

    def test_un_payload_sin_ruta_no_formatea(self) -> None:
        self.assertIsNone(ruta_a_formatear({"tool_name": "Edit", "tool_input": {}}))
        self.assertIsNone(ruta_a_formatear({}))


class CuandoGdformatNoPuede(unittest.TestCase):
    def test_sin_gdformat_instalado_lo_dice(self) -> None:
        def no_existe(*_args: object, **_kwargs: object) -> None:
            raise FileNotFoundError("gdformat")

        self.assertIn("no está instalado", formatear("x.gd", no_existe))

    def test_si_gdformat_sale_con_error_lo_dice_con_su_salida(self) -> None:
        def falla(argv: list[str], **_kwargs: object) -> subprocess.CompletedProcess:
            return subprocess.CompletedProcess(argv, 1, "", "Unexpected token")

        motivo = formatear("x.gd", falla)
        self.assertIn("x.gd", motivo)
        self.assertIn("Unexpected token", motivo)

    def test_si_gdformat_formatea_no_hay_nada_que_decir(self) -> None:
        def bien(argv: list[str], **_kwargs: object) -> subprocess.CompletedProcess:
            return subprocess.CompletedProcess(argv, 0, "", "")

        self.assertIsNone(formatear("x.gd", bien))


class ElHookEntero(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _correr(self, payload: dict) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(SCRIPT)],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            encoding="utf-8",
        )

    def _archivo(self, nombre: str, texto: str) -> Path:
        ruta = self.dir / nombre
        ruta.parent.mkdir(parents=True, exist_ok=True)
        ruta.write_bytes(texto.encode("utf-8"))
        return ruta

    def test_un_gd_editado_queda_como_lo_deja_gdformat(self) -> None:
        ruta = self._archivo("turno.gd", SIN_FORMATO)
        proceso = self._correr(_payload(str(ruta)))
        self.assertEqual(proceso.returncode, 0, proceso.stderr)
        self.assertEqual(ruta.read_bytes().decode("utf-8"), CON_FORMATO)

    def test_un_gd_nuevo_de_un_write_se_formatea_igual(self) -> None:
        ruta = self._archivo("nuevo.gd", SIN_FORMATO)
        self.assertEqual(self._correr(_payload(str(ruta), "Write")).returncode, 0)
        self.assertEqual(ruta.read_bytes().decode("utf-8"), CON_FORMATO)

    def test_un_gd_de_addons_queda_como_estaba(self) -> None:
        ruta = self._archivo("addons/plugin/x.gd", SIN_FORMATO)
        self.assertEqual(self._correr(_payload(str(ruta))).returncode, 0)
        self.assertEqual(ruta.read_bytes().decode("utf-8"), SIN_FORMATO)

    def test_un_gd_con_error_de_sintaxis_lo_dice_y_queda_como_estaba(self) -> None:
        roto = "func f( :\n  pass\n"
        ruta = self._archivo("roto.gd", roto)
        proceso = self._correr(_payload(str(ruta)))
        self.assertEqual(proceso.returncode, 0, "el hook no frena la edición")
        contexto = json.loads(proceso.stdout)["hookSpecificOutput"]["additionalContext"]
        self.assertIn("roto.gd", contexto)
        self.assertEqual(ruta.read_bytes().decode("utf-8"), roto)

    def test_un_payload_ilegible_no_frena_la_edicion(self) -> None:
        proceso = subprocess.run(
            [sys.executable, str(SCRIPT)],
            input="esto no es json",
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        self.assertEqual(proceso.returncode, 0)
        self.assertIn("formatear_al_editar", proceso.stdout + proceso.stderr)


if __name__ == "__main__":
    unittest.main()
