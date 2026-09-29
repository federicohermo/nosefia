"""Sube una carpeta de capturas a la rama huérfana `capturas/<N>`, sin abrir un worktree.

    python .claude/skills/implement-batch/scripts/capturas_a_rama.py <N> <carpeta> [--sin-push]

Se corre desde el worktree de la rama del issue. Las capturas que pide un issue no van en su
rama: van a `capturas/<N>`, que nunca se mergea, y el PR las muestra por su URL de
`raw.githubusercontent.com` (el repo es público).

## Por qué con plumbing y no con un worktree

**El guard del entorno rechaza `git -C <otro worktree>`**, con «redirects git to the shared
checkout via -C». La receta de abrir un worktree huérfano y commitear desde afuera no anda desde
el worktree de un carril: medido el 2026-09-29, en el carril de #267. Acá se arman los blobs, los
árboles —con subcarpetas— y un commit con `hash-object`, `mktree` y `commit-tree`, en el repo del
directorio actual, y se empuja el commit directo a la rama del remoto. Si la rama ya existe, el
commit nuevo va encima del anterior: cada corrida suma y ninguna pisa.
"""

import re
import subprocess
import sys
from pathlib import Path


def git(*argumentos: str, entrada: str | None = None) -> str:
    return subprocess.run(
        ["git", *argumentos],
        input=entrada,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=True,
    ).stdout.strip()


def arbol(carpeta: Path) -> str:
    """El hash del árbol de `carpeta`, con sus subcarpetas, escrito en el repo actual."""
    entradas = []
    for ruta in sorted(carpeta.iterdir()):
        if ruta.is_dir():
            entradas.append(f"040000 tree {arbol(ruta)}\t{ruta.name}")
        elif ruta.is_file():
            entradas.append(f"100644 blob {git('hash-object', '-w', str(ruta))}\t{ruta.name}")
    return git("mktree", entrada="\n".join(entradas) + "\n")


def base_cruda(url_del_remoto: str) -> str | None:
    """La base de `raw.githubusercontent.com` de un remoto de GitHub, o `None` si no lo es."""
    encontrado = re.search(r"github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?/?$", url_del_remoto)
    if encontrado is None:
        return None
    return f"https://raw.githubusercontent.com/{encontrado.group(1)}/{encontrado.group(2)}"


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    numero, carpeta = sys.argv[1], Path(sys.argv[2]).resolve()
    if not carpeta.is_dir():
        print(f"no es una carpeta: {carpeta}", file=sys.stderr)
        return 2
    rama = f"capturas/{numero}"
    arbol_nuevo = arbol(carpeta)
    padres: list[str] = []
    remoto = git("ls-remote", "origin", f"refs/heads/{rama}")
    if remoto:
        git("fetch", "-q", "origin", rama)
        padres = ["-p", remoto.split()[0]]
    commit = git("commit-tree", arbol_nuevo, *padres, "-m", f"capturas de #{numero}")
    print(git("ls-tree", "-r", "--name-only", commit))
    if "--sin-push" in sys.argv:
        print(f"commit {commit}, sin empujar")
        return 0
    git("push", "origin", f"{commit}:refs/heads/{rama}")
    base = base_cruda(git("remote", "get-url", "origin"))
    print(f"empujado a {rama}" + (f": {base}/{rama}/<archivo>" if base else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
