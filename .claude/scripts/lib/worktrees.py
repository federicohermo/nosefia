"""Leer de un comando de shell qué worktrees abre. Puro: no corre `git` ni toca el disco.

Lo usa `gate_de_worktrees.py`. No es un parser de shell: mira `git [opciones] worktree add`,
con `-C` y con un `cd` previo en la misma línea, que son las formas en que un agente lo escribe.
"""

import os
import re
import shlex
from pathlib import Path

#: Dónde se abre un worktree, relativo al checkout principal.
DIR_DE_WORKTREES = Path(".claude") / "worktrees"

#: Las opciones de `git` que consumen el token siguiente.
OPCIONES_DE_GIT_CON_VALOR = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}

#: Las opciones de `git worktree add` que consumen el token siguiente.
OPCIONES_DE_ADD_CON_VALOR = {"-b", "-B", "--reason"}

#: Los comandos que cambian el `cwd` de lo que sigue en la misma línea.
CAMBIOS_DE_DIRECTORIO = {"cd", "pushd", "set-location", "sl", "push-location"}


def _tokens(segmento: str) -> list[str]:
    # `posix=False` conserva las `\` de una ruta de Windows; las comillas se sacan a mano.
    try:
        crudos = shlex.split(segmento, posix=False)
    except ValueError:
        return []
    return [t[1:-1] if len(t) >= 2 and t[0] == t[-1] and t[0] in "\"'" else t for t in crudos]


def _ruta(base: Path, token: str) -> Path:
    # Git Bash escribe `D:\x` como `/d/x`, y `Path` lo leería como `D:\d\x`.
    msys = re.match(r"^/([a-zA-Z])(/|$)", token)
    if msys and os.name == "nt":
        token = f"{msys.group(1)}:/{token[3:]}"
    return base / token


def _ruta_de_add(args: list[str]) -> str | None:
    """El primer argumento posicional de `git worktree add`, que es la ruta."""
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--":
            return args[i + 1] if i + 1 < len(args) else None
        if arg in OPCIONES_DE_ADD_CON_VALOR:
            i += 2
            continue
        if not arg.startswith("-"):
            return arg
        i += 1
    return None


def worktrees_que_abre(comando: str, cwd: Path) -> list[tuple[Path, Path]]:
    """Cada `git worktree add` del comando, como (directorio donde corre git, ruta destino)."""
    abiertos: list[tuple[Path, Path]] = []
    for segmento in re.split(r"&&|\|\||[;|\n]", comando):
        tokens = _tokens(segmento.strip())
        if not tokens:
            continue
        if tokens[0].lower() in CAMBIOS_DE_DIRECTORIO and len(tokens) > 1:
            cwd = _ruta(cwd, tokens[1])
            continue
        if Path(tokens[0]).stem.lower() != "git":
            continue
        dir_git = cwd
        i = 1
        while i < len(tokens) and tokens[i].startswith("-"):
            if tokens[i] == "-C" and i + 1 < len(tokens):
                dir_git = _ruta(dir_git, tokens[i + 1])
            i += 2 if tokens[i] in OPCIONES_DE_GIT_CON_VALOR else 1
        if tokens[i : i + 2] != ["worktree", "add"]:
            continue
        ruta = _ruta_de_add(tokens[i + 2 :])
        if ruta is not None:
            abiertos.append((dir_git, _ruta(dir_git, ruta)))
    return abiertos
