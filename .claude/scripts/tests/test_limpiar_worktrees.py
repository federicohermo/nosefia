"""El limpiador sólo borra bajo `.claude/worktrees/`, que es el único lugar donde se abre uno."""

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import limpiar_worktrees
from lib.repo import RAIZ

LOTE = RAIZ / ".claude" / "worktrees"


class DelLote(unittest.TestCase):
    def test_un_worktree_bajo_la_carpeta_es_del_lote(self) -> None:
        self.assertTrue(limpiar_worktrees.del_lote(LOTE / "agent-abc"))

    def test_el_checkout_principal_no_es_del_lote(self) -> None:
        self.assertFalse(limpiar_worktrees.del_lote(RAIZ))

    def test_un_worktree_al_lado_del_repo_no_es_del_lote(self) -> None:
        self.assertFalse(limpiar_worktrees.del_lote(RAIZ.parent / f"{RAIZ.name}-42"))

    def test_una_carpeta_de_nombre_parecido_no_es_del_lote(self) -> None:
        self.assertFalse(limpiar_worktrees.del_lote(RAIZ / ".claude" / "worktrees-otro" / "x"))


class SinCommitear(unittest.TestCase):
    """Un worktree con cambios sin commitear puede ser de otra sesión que todavía trabaja."""

    def test_un_arbol_limpio_se_puede_borrar(self) -> None:
        self.assertFalse(limpiar_worktrees.sin_commitear(""))

    def test_un_archivo_modificado_frena_el_borrado(self) -> None:
        self.assertTrue(limpiar_worktrees.sin_commitear(" M test/dominio/x_test.gd\n"))

    def test_un_archivo_nuevo_frena_el_borrado(self) -> None:
        self.assertTrue(limpiar_worktrees.sin_commitear("?? test/dominio/nuevo_test.gd\n"))


class NoBorraTrabajoAjeno(unittest.TestCase):
    """El script entero, sobre un repo de juguete: la guarda vive en `main()`, no en una función.

    El script resuelve su raíz desde su propia ubicación, así que se copia adentro del repo de
    juguete y nunca ve los worktrees del repo real.
    """

    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp(prefix="limpiar_")).resolve()
        self.addCleanup(shutil.rmtree, self.repo, True)
        scripts = self.repo / ".claude" / "scripts"
        (scripts / "lib").mkdir(parents=True)
        shutil.copy(RAIZ / ".claude" / "scripts" / "limpiar_worktrees.py", scripts)
        for nombre in ("__init__.py", "consola.py"):
            shutil.copy(RAIZ / ".claude" / "scripts" / "lib" / nombre, scripts / "lib")
        (self.repo / ".gitignore").write_text(".claude/\n", encoding="utf-8")
        (self.repo / "x.txt").write_text("x\n", encoding="utf-8")
        self._git("init", "-q")
        self._git("add", ".")
        self._git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "x")
        self.wt = self.repo / ".claude" / "worktrees" / "carril"
        self._git("worktree", "add", "-q", "-b", "carril", str(self.wt))

    def _git(self, *args: str) -> None:
        subprocess.run(
            ["git", *args], cwd=self.repo, check=True, capture_output=True, encoding="utf-8"
        )

    def _limpiar(self) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(self.repo / ".claude" / "scripts" / "limpiar_worktrees.py"),
             str(self.wt)],
            cwd=self.repo, capture_output=True, text=True, encoding="utf-8", errors="replace",
        )

    def test_un_worktree_limpio_se_borra(self) -> None:
        hecho = self._limpiar()
        self.assertEqual(hecho.returncode, 0, hecho.stderr)
        self.assertFalse(self.wt.exists())

    def test_un_worktree_con_cambios_sin_commitear_queda_y_el_script_falla(self) -> None:
        (self.wt / "x.txt").write_text("trabajo\n", encoding="utf-8")
        hecho = self._limpiar()
        self.assertEqual(hecho.returncode, 1)
        self.assertIn("sin commitear", hecho.stderr)
        self.assertTrue((self.wt / "x.txt").exists())

    def test_un_git_status_que_falla_no_se_lee_como_arbol_limpio(self) -> None:
        # Un índice roto hace salir a `git status` con error y sin nada en stdout: leído como
        # «limpio», el worktree se borraba con lo que tuviera adentro.
        indice = self.repo / ".git" / "worktrees" / "carril" / "index"
        indice.write_bytes(b"roto")
        hecho = self._limpiar()
        self.assertEqual(hecho.returncode, 1)
        self.assertTrue((self.wt / "x.txt").exists())


class RamasDeLosCarriles(NoBorraTrabajoAjeno):
    """Las ramas `worktree-agent-…` con que arranca cada carril, y cuáles se barren.

    Los carriles arrancan en `origin/main`, que no es ancestro de `staging`: `branch -d` se
    niega aunque la rama no tenga un solo commit propio. Medido el 2026-09-30 cerrando el lote
    #262–#267, donde las nueve quedaron como ANOMALIA. Acá `main` diverge de `HEAD` igual.
    """

    def setUp(self) -> None:
        super().setUp()
        remoto = Path(tempfile.mkdtemp(prefix="remoto_")).resolve()
        self.addCleanup(shutil.rmtree, remoto, True)
        self._git("init", "-q", "--bare", str(remoto))
        self._git("remote", "add", "origin", str(remoto))
        self._git("checkout", "-q", "-b", "main")
        self._commit("en main")
        self._git("push", "-q", "origin", "main")
        self._git("checkout", "-q", "-")
        self._git("branch", "-D", "main")

    def _commit(self, mensaje: str) -> None:
        self._git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty",
                  "-m", mensaje)

    def _ramas(self) -> list[str]:
        salida = subprocess.run(
            ["git", "branch", "--format=%(refname:short)"], cwd=self.repo, check=True,
            capture_output=True, encoding="utf-8",
        ).stdout
        return salida.split()

    def test_la_rama_que_esta_entera_en_un_remoto_se_barre(self) -> None:
        # Sin upstream, como las de los carriles: con él, `-d` la aceptaría por estar en él.
        self._git("branch", "--no-track", "worktree-agent-a1", "origin/main")
        hecho = self._limpiar()
        self.assertEqual(hecho.returncode, 0, hecho.stderr)
        self.assertNotIn("worktree-agent-a1", self._ramas())
        self.assertNotIn("ANOMALIA", hecho.stderr)

    def test_la_rama_con_un_commit_que_no_esta_en_ningun_remoto_queda(self) -> None:
        self._git("checkout", "-q", "--no-track", "-b", "worktree-agent-a2", "origin/main")
        self._commit("trabajo propio")
        self._git("checkout", "-q", "-")
        hecho = self._limpiar()
        self.assertIn("worktree-agent-a2", self._ramas())
        self.assertIn("ANOMALIA: la rama worktree-agent-a2", hecho.stderr)


if __name__ == "__main__":
    unittest.main()
