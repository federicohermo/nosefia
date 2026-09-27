"""El limpiador sólo borra bajo `.claude/worktrees/`, que es el único lugar donde se abre uno."""

import unittest

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


if __name__ == "__main__":
    unittest.main()
