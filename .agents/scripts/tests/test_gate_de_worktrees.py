"""El gate de los worktrees: uno de este repo se abre sólo en `.claude/worktrees/` del principal.

Lo puro —leer el comando— se ejerce sobre rutas inventadas. El veredicto se ejerce contra este
mismo repo, porque lo que decide es qué repo contesta `git` desde el destino.
"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import gate_de_worktrees
from gate_de_worktrees import veredicto
from lib.worktrees import worktrees_que_abre
from lib.repo import RAIZ

PRINCIPAL = gate_de_worktrees.checkout_principal(RAIZ)
PERMITIDO = PRINCIPAL / ".claude" / "worktrees"


class LeerElComando(unittest.TestCase):
    def test_la_ruta_es_el_primer_posicional_despues_de_las_opciones(self) -> None:
        base = Path("/repo")
        abiertos = worktrees_que_abre("git worktree add -b feature/x --lock ../otro staging", base)
        self.assertEqual(abiertos, [(base, base / "../otro")])

    def test_git_C_cambia_el_repo_y_la_base_de_la_ruta(self) -> None:
        abiertos = worktrees_que_abre("git -C /repo worktree add x", Path("/afuera"))
        self.assertEqual(abiertos, [(Path("/repo"), Path("/repo/x"))])

    def test_un_cd_previo_cambia_la_base(self) -> None:
        abiertos = worktrees_que_abre('cd "/repo" && git worktree add x', Path("/afuera"))
        self.assertEqual(abiertos, [(Path("/repo"), Path("/repo/x"))])

    def test_otro_subcomando_de_worktree_no_cuenta(self) -> None:
        self.assertEqual(worktrees_que_abre("git worktree list; git worktree remove x", Path(".")), [])


class ElVeredicto(unittest.TestCase):
    def test_bajo_la_carpeta_del_principal_pasa(self) -> None:
        self.assertIsNone(veredicto(f'git worktree add "{PERMITIDO / "x"}" -b y', RAIZ))

    def test_al_lado_del_repo_se_bloquea(self) -> None:
        self.assertIsNotNone(veredicto("git worktree add ../nosefia-42 -b y", PRINCIPAL))

    def test_desde_afuera_con_git_C_se_bloquea(self) -> None:
        with tempfile.TemporaryDirectory() as afuera:
            comando = f'git -C "{PRINCIPAL}" worktree add "{afuera}/x"'
            self.assertIsNotNone(veredicto(comando, Path(afuera)))

    def test_relativo_a_otra_carpeta_se_bloquea(self) -> None:
        # Desde un worktree o una subcarpeta, `.claude/worktrees/x` no cae en la del principal.
        desde = PRINCIPAL / ".claude" / "scripts"
        self.assertIsNotNone(veredicto("git worktree add .claude/worktrees/x", desde))

    def test_otro_repo_pasa(self) -> None:
        with tempfile.TemporaryDirectory() as otro:
            subprocess.run(["git", "init", "-q", otro], check=True)
            self.assertIsNone(veredicto("git worktree add ../lejos", Path(otro)))


class ElHook(unittest.TestCase):
    def test_contesta_deny_por_stdout(self) -> None:
        payload = {"tool_input": {"command": "git worktree add ../x"}, "cwd": str(PRINCIPAL)}
        hecho = subprocess.run(
            [sys.executable, gate_de_worktrees.__file__],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        self.assertEqual(hecho.returncode, 0)
        salida = json.loads(hecho.stdout)["hookSpecificOutput"]
        self.assertEqual(salida["permissionDecision"], "deny")


if __name__ == "__main__":
    unittest.main()
