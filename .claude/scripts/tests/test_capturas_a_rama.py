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


def _git(*argumentos: str) -> str:
    return subprocess.run(
        ["git", *argumentos],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=True,
    ).stdout.strip()


def _commit(arbol: str) -> str:
    return _git("commit-tree", arbol, "-m", "una corrida anterior")


def _listado(arbol: str) -> list[str]:
    return _git("ls-tree", "-r", "--name-only", arbol).split()


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

    def test_suma_sobre_el_arbol_del_padre_y_reemplaza_la_misma_ruta(self):
        with tempfile.TemporaryDirectory() as antes, tempfile.TemporaryDirectory() as ahora:
            (Path(antes) / "a.png").write_bytes(b"viejo")
            (Path(antes) / "giro").mkdir()
            (Path(antes) / "giro" / "c.png").write_bytes(b"\x89PNG de la otra corrida")
            (Path(ahora) / "a.png").write_bytes(b"nuevo")
            (Path(ahora) / "b.png").write_bytes(b"\x89PNG que se suma")
            padre = _commit(capturas.arbol(Path(antes)))
            arbol = capturas.arbol(Path(ahora), padre)
        self.assertEqual(_listado(arbol), ["a.png", "b.png", "giro/c.png"])
        self.assertEqual(_git("cat-file", "-p", f"{arbol}:a.png"), "nuevo")

    def test_sin_push_suma_sobre_la_cabeza_de_la_rama_del_remoto(self):
        # El remoto es el mismo repo temporal: la rama que `ls-remote` encuentra es la de acá.
        with tempfile.TemporaryDirectory() as antes, tempfile.TemporaryDirectory() as ahora:
            (Path(antes) / "de_la_primera.png").write_bytes(b"\x89PNG")
            _git("update-ref", "refs/heads/capturas/999", _commit(capturas.arbol(Path(antes))))
            (Path(ahora) / "de_la_segunda.png").write_bytes(b"\x89PNG")
            subprocess.run(["git", "remote", "add", "origin", self._repo.name], check=True)
            argv = sys.argv
            sys.argv = ["capturas_a_rama.py", "999", ahora, "--sin-push"]
            try:
                with contextlib.redirect_stdout(io.StringIO()) as salida:
                    codigo = capturas.main()
            finally:
                sys.argv = argv
        self.assertEqual(codigo, 0)
        self.assertIn("de_la_primera.png", salida.getvalue())
        self.assertIn("de_la_segunda.png", salida.getvalue())

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
