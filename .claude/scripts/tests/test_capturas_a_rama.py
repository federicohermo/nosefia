"""Las capturas de un issue suben a su rama huérfana sin abrir un worktree.

El guard del entorno rechaza `git -C <otro worktree>`, así que la receta de un worktree huérfano
no anda desde el worktree de un carril (medido el 2026-09-29, en el carril de #267). El script
arma el commit con plumbing en el repo del directorio actual. Los casos lo corren sobre un repo
temporal y sin empujar: lo que se verifica es el árbol, con sus subcarpetas, y la URL cruda.
"""

import contextlib
import importlib.util
import io
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from lib.repo import RAIZ

SCRIPT = RAIZ / ".claude" / "skills" / "implement-batch" / "scripts" / "capturas_a_rama.py"

_spec = importlib.util.spec_from_file_location("capturas_a_rama", SCRIPT)
assert _spec is not None and _spec.loader is not None
capturas = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(capturas)


class ElArbol(unittest.TestCase):
    def setUp(self):
        self._previo = Path.cwd()
        self._repo = tempfile.TemporaryDirectory()
        os.chdir(self._repo.name)
        subprocess.run(["git", "init", "-q"], check=True)

    def tearDown(self):
        os.chdir(self._previo)
        self._repo.cleanup()

    def test_arma_el_arbol_con_sus_subcarpetas(self):
        with tempfile.TemporaryDirectory() as carpeta:
            base = Path(carpeta)
            (base / "salon.png").write_bytes(b"\x89PNG antes")
            (base / "comparacion").mkdir()
            (base / "comparacion" / "salon_lado_a_lado.png").write_bytes(b"\x89PNG los dos")
            arbol = capturas.arbol(base)
            listado = subprocess.run(
                ["git", "ls-tree", "-r", "--name-only", arbol],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                check=True,
            ).stdout.split()
        self.assertEqual(listado, ["comparacion/salon_lado_a_lado.png", "salon.png"])

    def test_sin_push_no_toca_ningun_remoto(self):
        # El repo temporal no tiene remoto: si el script intentara empujar, `git push` fallaría.
        with tempfile.TemporaryDirectory() as carpeta:
            (Path(carpeta) / "a.png").write_bytes(b"\x89PNG")
            subprocess.run(["git", "remote", "add", "origin", self._repo.name], check=True)
            argv = sys.argv
            sys.argv = ["capturas_a_rama.py", "999", carpeta, "--sin-push"]
            try:
                with contextlib.redirect_stdout(io.StringIO()) as salida:
                    codigo = capturas.main()
            finally:
                sys.argv = argv
        self.assertEqual(codigo, 0)
        self.assertIn("sin empujar", salida.getvalue())


class LaUrlCruda(unittest.TestCase):
    def test_sale_del_remoto_de_github_por_https_o_ssh(self):
        esperada = "https://raw.githubusercontent.com/federicohermo/nosefia"
        self.assertEqual(capturas.base_cruda("https://github.com/federicohermo/nosefia.git"), esperada)
        self.assertEqual(capturas.base_cruda("git@github.com:federicohermo/nosefia.git"), esperada)
        self.assertEqual(capturas.base_cruda("https://github.com/federicohermo/nosefia"), esperada)

    def test_un_remoto_que_no_es_github_no_inventa_una_url(self):
        self.assertIsNone(capturas.base_cruda("/tmp/un/repo/local"))
