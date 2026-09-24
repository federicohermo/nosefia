"""El recordatorio del índice."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import recordatorio_del_indice
from lib.recordatorio import explora_el_codigo
from lib.repo import RAIZ

SCRIPT = Path(recordatorio_del_indice.__file__)


def _pre(herramienta: str, entrada: dict, sesion: str = "s1") -> dict:
    return {
        "hook_event_name": "PreToolUse",
        "session_id": sesion,
        "tool_name": herramienta,
        "tool_input": entrada,
    }


class QueExploraElCodigo(unittest.TestCase):
    def test_grep_sobre_src_o_sobre_la_raiz_explora(self) -> None:
        self.assertTrue(explora_el_codigo("Grep", {"path": str(RAIZ / "src")}, RAIZ))
        self.assertTrue(explora_el_codigo("Grep", {"pattern": "Comprador"}, RAIZ))

    def test_grep_sobre_docs_no_explora(self) -> None:
        self.assertFalse(explora_el_codigo("Grep", {"path": str(RAIZ / "docs")}, RAIZ))

    def test_glob_con_la_carpeta_en_el_patron_explora(self) -> None:
        self.assertTrue(explora_el_codigo("Glob", {"pattern": "src/**/*.gd"}, RAIZ))
        self.assertTrue(explora_el_codigo("Glob", {"pattern": "**/*_test.gd"}, RAIZ))
        self.assertFalse(explora_el_codigo("Glob", {"pattern": "docs/**/*.md"}, RAIZ))

    def test_read_de_un_script_del_juego_explora(self) -> None:
        ruta = str(RAIZ / "src" / "dominio" / "reglas.gd")
        self.assertTrue(explora_el_codigo("Read", {"file_path": ruta}, RAIZ))
        self.assertFalse(explora_el_codigo("Read", {"file_path": str(RAIZ / "CLAUDE.md")}, RAIZ))

    def test_una_ruta_de_otro_repo_no_explora(self) -> None:
        self.assertFalse(explora_el_codigo("Read", {"file_path": "/otro/src/x.gd"}, RAIZ))

    def test_grep_por_bash_sobre_src_explora(self) -> None:
        comando = "grep -rli comprador src/dominio"
        self.assertTrue(explora_el_codigo("Bash", {"command": comando}, RAIZ))
        self.assertTrue(explora_el_codigo("Bash", {"command": f"cat {RAIZ}/src/x.gd"}, RAIZ))

    def test_bash_que_nombra_src_sin_explorar_no_cuenta(self) -> None:
        self.assertFalse(explora_el_codigo("Bash", {"command": "gdformat src test"}, RAIZ))
        self.assertFalse(explora_el_codigo("Bash", {"command": "git add src/x.gd"}, RAIZ))

    def test_bash_que_explora_otra_carpeta_no_cuenta(self) -> None:
        self.assertFalse(explora_el_codigo("Bash", {"command": "grep -rn hooks docs/"}, RAIZ))


class LaMarcaDeLaSesion(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name) / "marcas"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _contexto(self, payload: dict) -> str | None:
        return recordatorio_del_indice.contexto(payload, self.dir, RAIZ)

    def test_sin_consultar_el_indice_avisa(self) -> None:
        texto = self._contexto(_pre("Grep", {"path": "src"}))
        self.assertIsNotNone(texto)
        self.assertIn("mapa_del_sistema", texto)

    def test_despues_de_consultar_el_indice_no_avisa(self) -> None:
        self.assertIsNone(self._contexto(_pre("mcp__nosefia-index__mapa_del_sistema", {})))
        self.assertIsNone(self._contexto(_pre("Grep", {"path": "src"})))

    def test_la_marca_es_de_una_sesion_sola(self) -> None:
        self._contexto(_pre("mcp__nosefia-index__quien_usa", {}, sesion="s1"))
        self.assertIsNotNone(self._contexto(_pre("Grep", {"path": "src"}, sesion="s2")))

    def test_un_id_con_barras_no_escribe_afuera_de_la_carpeta(self) -> None:
        self._contexto(_pre("mcp__nosefia-index__quien_usa", {}, sesion="../../afuera"))
        self.assertEqual([p.parent for p in self.dir.parent.rglob("*") if p.is_file()], [self.dir])

    def test_al_arrancar_la_sesion_nombra_el_indice(self) -> None:
        texto = self._contexto({"hook_event_name": "SessionStart", "session_id": "s1"})
        self.assertIn("nosefia-index", texto)


class ElHook(unittest.TestCase):
    def _correr(self, entrada: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(SCRIPT)],
            input=entrada,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )

    def test_nunca_decide_un_permiso(self) -> None:
        payload = _pre("Bash", {"command": "grep -r x src/"}, sesion="test-sin-marca-nunca")
        hecho = self._correr(json.dumps(payload))
        self.assertEqual(hecho.returncode, 0)
        salida = json.loads(hecho.stdout)["hookSpecificOutput"]
        self.assertNotIn("permissionDecision", salida)
        self.assertIn("additionalContext", salida)

    def test_un_payload_roto_deja_pasar_y_dice_el_error(self) -> None:
        hecho = self._correr("esto no es json")
        self.assertEqual((hecho.returncode, hecho.stdout), (0, ""))
        self.assertIn("no pudo correr", hecho.stderr)


class LaConfiguracion(unittest.TestCase):
    def setUp(self) -> None:
        self.hooks = json.loads((RAIZ / ".claude" / "settings.json").read_text(encoding="utf-8"))[
            "hooks"
        ]

    def _matchers_con_el_recordatorio(self, evento: str) -> set[str]:
        return {
            h
            for entrada in self.hooks.get(evento, [])
            for hook in entrada["hooks"]
            if "recordatorio_del_indice.py" in hook["command"]
            for h in entrada.get("matcher", "*").split("|")
        }

    def test_mira_las_herramientas_que_exploran_y_las_del_indice(self) -> None:
        mirados = self._matchers_con_el_recordatorio("PreToolUse")
        for herramienta in ("Grep", "Glob", "Read", "Bash", "PowerShell", "mcp__nosefia-index__.*"):
            with self.subTest(herramienta=herramienta):
                self.assertIn(herramienta, mirados)

    def test_corre_al_arrancar_la_sesion(self) -> None:
        self.assertTrue(self._matchers_con_el_recordatorio("SessionStart"))


if __name__ == "__main__":
    unittest.main()
