"""Una base virtual debe excluir todos los padres que la cabeza ya contiene."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from lib.repo import RAIZ

SCRIPT = RAIZ / ".claude/skills/pr-review/scripts/diff_pr.py"


class BaseMultiple(unittest.TestCase):
    def setUp(self):
        self.temporal = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporal.cleanup)
        self.repo = Path(self.temporal.name)
        self.entorno = dict(os.environ)
        self.entorno.update({
            "GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "test@example.com",
            "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "test@example.com",
        })
        self.git("init", "-b", "base")
        self.commit("base.txt")
        self.git("checkout", "-b", "a")
        self.commit("a.txt")
        self.git("checkout", "-b", "b", "base")
        self.commit("b.txt")
        self.git("checkout", "-b", "cabeza", "a")
        self.git("merge", "--no-edit", "b")
        self.commit("propio.txt")
        tree = self.git("merge-tree", "--write-tree", "a", "b").strip()
        self.virtual = self.git("commit-tree", tree, "-p", "a", "-p", "b", "-m", "Virtual").strip()

    def git(self, *args):
        return subprocess.run(
            ["git", *args], cwd=self.repo, env=self.entorno, check=True,
            capture_output=True, text=True, encoding="utf-8",
        ).stdout

    def commit(self, nombre):
        (self.repo / nombre).write_text(nombre, encoding="utf-8")
        self.git("add", nombre)
        self.git("commit", "-m", nombre)

    def diff(self, base, *opciones):
        salida = self.repo / "salida"
        hecho = subprocess.run(
            [sys.executable, str(SCRIPT), base, str(salida), *opciones],
            cwd=self.repo, env=self.entorno, capture_output=True, text=True, encoding="utf-8",
        )
        self.assertEqual(hecho.returncode, 0, hecho.stdout + hecho.stderr)
        return set((salida / "pr.files").read_text(encoding="utf-8").splitlines())

    def test_base_virtual_excluye_ambos_padres_con_head_implicito(self):
        self.assertEqual(self.diff(self.virtual, "--base-exacta"), {"propio.txt"})

    def test_base_virtual_excluye_ambos_padres_con_head_explicito(self):
        self.assertEqual(self.diff(self.virtual, "cabeza", "--base-exacta"), {"propio.txt"})

    def test_sin_flag_conserva_el_diff_desde_el_ancestro_comun(self):
        self.assertEqual(self.diff("b"), {"a.txt", "propio.txt"})


if __name__ == "__main__":
    unittest.main()
