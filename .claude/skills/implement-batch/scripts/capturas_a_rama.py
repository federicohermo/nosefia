"""Sube una carpeta de capturas a la rama huérfana `capturas/<N>`, sin abrir un worktree.

    python .claude/skills/implement-batch/scripts/capturas_a_rama.py <N> <carpeta> [--sin-push]

Se corre desde el worktree de la rama del issue. Las capturas que pide un issue no van en su
rama: van a `capturas/<N>`, que nunca se mergea, y el PR las muestra por su URL de
`raw.githubusercontent.com` (el repo es público).

## Por qué con plumbing y no con un worktree

**El guard del entorno rechaza `git -C <otro worktree>`**, con «redirects git to the shared
checkout via -C». La receta de abrir un worktree huérfano y commitear desde afuera no anda desde
el worktree de un carril: medido el 2026-09-29, en el carril de #267. Acá se arman los blobs y
un árbol con subcarpetas en un índice temporal, y un commit con `commit-tree`, en el repo del
directorio actual. El commit se empuja directo a la rama del remoto.

## Cada corrida suma y ninguna pisa

**Si la rama ya existe, el árbol nuevo parte del de su cabeza**, y los archivos de la carpeta van
encima: lo que ya estaba queda, y un archivo con la misma ruta se reemplaza. Sin eso, la cabeza
de la rama tenía sólo la carpeta de la última corrida, y cada URL de una corrida anterior daba
404 aunque el PR la siguiera mostrando. Lo encontró el carril de #263, el 2026-09-29.
"""

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def git(*argumentos: str, entrada: str | None = None, indice: Path | None = None) -> str:
    entorno = None if indice is None else {**os.environ, "GIT_INDEX_FILE": str(indice)}
    return subprocess.run(
        ["git", *argumentos],
        input=entrada,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        env=entorno,
        check=True,
    ).stdout.strip()


def arbol(carpeta: Path, padre: str | None = None) -> str:
    """El hash del árbol de `carpeta`, con sus subcarpetas, sobre el árbol del commit `padre`."""
    with tempfile.TemporaryDirectory() as temporal:
        indice = Path(temporal) / "index"
        if padre is not None:
            git("read-tree", padre, indice=indice)
        for ruta in sorted(p for p in carpeta.rglob("*") if p.is_file()):
            blob = git("hash-object", "-w", str(ruta))
            relativa = ruta.relative_to(carpeta).as_posix()
            git("update-index", "--add", "--cacheinfo", f"100644,{blob},{relativa}", indice=indice)
        return git("write-tree", indice=indice)


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
    padre: str | None = None
    remoto = git("ls-remote", "origin", f"refs/heads/{rama}")
    if remoto:
        git("fetch", "-q", "origin", rama)
        padre = remoto.split()[0]
    arbol_nuevo = arbol(carpeta, padre)
    padres = [] if padre is None else ["-p", padre]
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
