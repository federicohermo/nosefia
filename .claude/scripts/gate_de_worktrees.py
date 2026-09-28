"""El gate: un worktree de este repo se abre sólo en `.claude/worktrees/` del checkout principal.

Corre como hook `PreToolUse` sobre `Bash|PowerShell`. Recibe el payload del hook por stdin y,
si el comando abre un worktree de este repo en otro lado, contesta `deny` por stdout.

## Por qué existe

`limpiar_worktrees.py` sólo borra bajo `.claude/worktrees/`. Un worktree abierto en otro lado
queda fuera de toda limpieza, o peor: el 2026-09-22 un limpiador que tomaba todo lo registrado
se llevó un worktree abierto al lado del repo, con lo que tuviera sin commitear. La regla de
dónde se abre tiene que ser ejecutable, igual que la de dónde se borra.

## Tres decisiones que no son obvias

1. **El lugar sale del checkout principal, no del `cwd`, y es un hijo directo.** Un agente
   parado adentro de un worktree que abre `.claude/worktrees/x` lo abre anidado en el suyo, y
   el limpiador lo borra junto con el padre. Por eso el destino se compara contra el
   `--git-common-dir`, que es el mismo desde cualquier worktree del repo, y tiene que colgar
   directo de `.claude/worktrees/`: es también lo único que el limpiador barre en disco.

2. **Se mira el repo al que apunta el comando, no desde dónde se corre.** `git -C <repo>` y un
   `cd <repo> &&` previo cambian el repo destino. Un comando sobre otro repo pasa: este gate
   no tiene opinión sobre él.

3. **Falla abierto, como `gate_de_rama.py`.** Si no puede leer el payload o `git` no contesta,
   deja pasar y lo dice. Lo que protege es una convención, no un secreto.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.worktrees import DIR_DE_WORKTREES, worktrees_que_abre  # noqa: E402

def checkout_principal(directorio: Path) -> Path | None:
    """El checkout principal del repo que contiene a `directorio`, o `None` si no hay repo."""
    hecho = subprocess.run(
        ["git", "-C", str(directorio), "rev-parse", "--path-format=absolute", "--git-common-dir"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if hecho.returncode != 0:
        return None
    return Path(hecho.stdout.strip()).resolve().parent


def veredicto(comando: str, cwd: Path) -> str | None:
    """El motivo del bloqueo, o `None` si el comando no abre un worktree de este repo afuera."""
    este_repo = checkout_principal(Path(__file__).resolve().parent)
    for dir_git, ruta in worktrees_que_abre(comando, cwd):
        principal = checkout_principal(dir_git)
        if principal is None or principal != este_repo:
            continue
        permitido = principal / DIR_DE_WORKTREES
        if ruta.resolve().parent != permitido.resolve():
            return (
                f"Un worktree de este repo se abre sólo como hijo directo de `{permitido.as_posix()}/`, y "
                f"`{ruta.as_posix()}` queda afuera. El limpiador sólo borra ahí. Usá "
                f"`git worktree add {permitido.as_posix()}/<nombre> ...`, o `EnterWorktree`, "
                "o un `Agent` con `isolation: worktree`, que ya lo abren ahí."
            )
    return None


def _responder(decision: str, motivo: str) -> None:
    salida = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": motivo,
        }
    }
    print(json.dumps(salida, ensure_ascii=False))
    sys.exit(0)


def main() -> None:
    try:
        payload = json.loads(sys.stdin.read())
        comando = payload.get("tool_input", {}).get("command") or ""
        cwd = Path(payload.get("cwd") or os.getcwd())
        motivo = veredicto(comando, cwd)
    except Exception as error:  # noqa: BLE001 — falla abierto, y lo dice
        _responder("allow", f"gate_de_worktrees no pudo correr y dejó pasar: {error}")
        return
    if motivo:
        _responder("deny", motivo)
    # Sin opinión: no se imprime nada, y la decisión queda en manos de los permisos.
    sys.exit(0)


if __name__ == "__main__":
    main()
