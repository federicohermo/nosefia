"""El limpiador sólo borra bajo `.claude/worktrees/`, que es el único lugar donde se abre uno."""

import unittest
from pathlib import Path

import limpiar_worktrees
from lib.repo import RAIZ

LOTE = RAIZ / ".claude" / "worktrees"


class DelLote(unittest.TestCase):
    def test_un_worktree_bajo_la_carpeta_es_del_lote(self) -> None:
        self.assertTrue(limpiar_worktrees.del_lote(LOTE / "agent-abc"))

    def test_la_ruta_con_barras_de_windows_es_del_lote(self) -> None:
        self.assertTrue(limpiar_worktrees.del_lote(Path(str(LOTE / "x").replace("/", "\\"))))

    def test_el_checkout_principal_no_es_del_lote(self) -> None:
        self.assertFalse(limpiar_worktrees.del_lote(RAIZ))

    def test_un_worktree_al_lado_del_repo_no_es_del_lote(self) -> None:
        self.assertFalse(limpiar_worktrees.del_lote(RAIZ.parent / f"{RAIZ.name}-42"))

    def test_una_carpeta_de_nombre_parecido_no_es_del_lote(self) -> None:
        self.assertFalse(limpiar_worktrees.del_lote(RAIZ / ".claude" / "worktrees-otro" / "x"))


if __name__ == "__main__":
    unittest.main()
