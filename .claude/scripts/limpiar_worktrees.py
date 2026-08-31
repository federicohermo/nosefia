"""Destruye los worktrees del lote al cerrar `pr-review-batch`.

Uso, desde la raíz del repo:

    python .claude/scripts/limpiar_worktrees.py --todos
    python .claude/scripts/limpiar_worktrees.py <ruta> [<ruta> ...]

Ésta es la copia canónica. **Los dos batch que abren worktrees —`pr-review-batch` y
`spec-implement-batch`— traen la suya en `scripts/`**, porque un skill trae su implementación
completa y uno que dependa de `.claude/scripts/` deja de funcionar apenas viaja solo. Que las tres
copias no se separen lo verifica `test_copias_de_skills.py`, no la disciplina de nadie.

## Por qué no alcanza `git worktree remove`

`.godot/` y `reportes/` están en el `.gitignore`, así que `remove` borra lo trackeado y el
`.git` pero **el directorio no queda vacío** y el borrado final tira `Directory not empty`.
`--force` no ayuda: no es un problema de cambios sin commitear. Y le pasa a **todo worktree que
haya corrido `verificar.py`**, o sea a todos — el nodo `tests` levanta Godot headless, y Godot
escribe su caché de importación en `.godot/` la primera vez que abre el proyecto.

Git igual saca la metadata, así que el worktree queda desregistrado y basta un borrado común.

## Y por qué `--todos` no puede salir de `git worktree list`

Porque **el peor worktree es justamente el que git ya no registra**. Un carril que muere a
mitad —o cualquiera que haya pasado por un `git worktree prune`— deja el directorio en disco
y desaparece de la lista. Un `--todos` que salga sólo de ahí no lo ve, **y no falla**:
reporta que limpió todo y deja la carpeta. Y si los huérfanos son todos, contesta «no hay
worktrees para limpiar», que es la versión más convincente de la misma mentira.

Medido en el lote 001/002/004/007: el carril que se colgó dejó su carpeta, el script dijo
ok, y el que lo vio fue el usuario mirando el árbol de archivos.

Por eso `--todos` es la **unión** de lo que git registra y lo que hay en disco bajo
`.claude/worktrees/`, y no lo primero.

## Las ramas también quedan

`git worktree remove` borra el árbol y **deja la rama** que el harness le puso. Un lote de N
carriles deja N ramas que no son de nadie. Se barren con `git branch -d` y **nunca con
`-D`**: el `-d` se niega a borrar una rama con commits que no estén en ningún otro lado, así
que quien decide qué es descartable es git y no una heurística de este script. Una rama que
se niega a morir tiene algo adentro, y se reporta en vez de forzarla.
## Y por qué además hay que matar procesos

Acá **el review sí levanta Godot**: `verificar.py` corre la suite en headless. Un Godot colgado
—un test que espera un `await` que no llega, un diálogo de error del motor— se queda con un
handle sobre `.godot/` y el borrado falla sin decir por qué.

Tres cosas que NO se tocan sin volver a medir, heredadas del script del que sale éste y las tres
descubiertas fallando en verde:

  - El filtro matchea la **ruta del worktree**, nunca el nombre del proceso. Un filtro por
    `godot.exe` se llevaría puesto el editor que el usuario tiene abierto con el checkout
    principal, que es exactamente el proceso que no hay que matar.
  - Matchea también por `ExecutablePath` y no sólo por línea de comando.
  - Excluye el propio árbol de procesos: la línea de comando del intérprete que corre este
    script contiene la ruta del worktree, así que sin eso el script se mata solo.

Ninguna conversión de ruta del lado del shell: la hace PowerShell con `.Replace()`.
"""

import subprocess
import sys
import time
from pathlib import Path
from typing import Callable

# La raíz sale de buscar `.claude/scripts/lib` hacia arriba, y NO de un `parents[N]` fijo: este
# archivo vive además copiado adentro de cada skill que lo usa —que es la regla: un skill trae su
# propia implementación—, y ahí la profundidad es otra. Un índice fijo lo ata a una ubicación y
# rompe la copia con un `ModuleNotFoundError` que no nombra ni al skill ni a la copia.
RAIZ = next(
    p for p in Path(__file__).resolve().parents if (p / ".claude" / "scripts" / "lib").is_dir()
)
sys.path.insert(0, str(RAIZ / ".claude" / "scripts"))

from lib.consola import configurar  # noqa: E402

configurar()

# Nada de no-ASCII adentro del -Command: la cadena cruza a powershell.exe por la codepage de la
# consola. Los comentarios viven acá, en Python, que no cruza.
PS = """
$ErrorActionPreference='SilentlyContinue'
$a = '{ruta}'
$pats = @($a, $a.Replace('/','\\'))
$todos = Get-CimInstance Win32_Process
$mios = @(); $p = $PID
while ($p -and ($mios -notcontains $p)) {{
  $mios += $p
  $pr = $todos | Where-Object {{ $_.ProcessId -eq $p }}
  if (-not $pr) {{ break }}
  $p = $pr.ParentProcessId
}}
$todos |
  Where-Object {{ $mios -notcontains $_.ProcessId }} |
  Where-Object {{
    $c = $_.CommandLine; $e = $_.ExecutablePath
    ($c -and ($pats | Where-Object {{ $c.Contains($_) }})) -or
    ($e -and ($pats | Where-Object {{ $e.StartsWith($_) }}))
  }} |
  ForEach-Object {{
    Write-Output ($_.ProcessId.ToString() + ' ' + $_.Name)
    Stop-Process -Id $_.ProcessId -Force
  }}
"""


#: Dónde nacen los worktrees de un lote. Se mira ADEMÁS de lo que git registra, nunca en vez.
DIR_DE_WORKTREES = (".claude", "worktrees")

#: El prefijo que el harness le pone a la rama de cada worktree.
RAMA_DE_WORKTREE = "worktree-agent-"


def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args], capture_output=True, text=True, encoding="utf-8", errors="replace"
    )


def borrar_arbol(ruta: Path) -> None:
    # `shutil.rmtree` se cae con los de sólo lectura que git deja en `.git`; `rm -rf` por shell
    # no está garantizado en Windows fuera de Git Bash. Se hace a mano y sin gritar.
    import shutil

    def forzar(func: Callable[[str], None], camino: str, _exc: object) -> None:
        import os
        import stat

        try:
            os.chmod(camino, stat.S_IWRITE)
            func(camino)
        except OSError:
            pass

    shutil.rmtree(ruta, onerror=forzar)


def huerfanos(directorio: Path, ya_estan: list[Path], principal: Path) -> list[Path]:
    """Los worktrees que quedaron en disco y que git ya no registra."""
    if not directorio.is_dir():
        return []
    return [
        hijo.resolve()
        for hijo in sorted(directorio.iterdir())
        if hijo.is_dir() and hijo.resolve() not in ya_estan and hijo.resolve() != principal
    ]


def barrer_ramas() -> tuple[list[str], list[str]]:
    """Borra las ramas de worktree sin trabajo propio. El `-d` es el que pone el límite."""
    salida = git(
        "branch", "--list", f"{RAMA_DE_WORKTREE}*", "--format=%(refname:short)"
    ).stdout
    borradas: list[str] = []
    quedaron: list[str] = []
    for rama in (r.strip() for r in salida.splitlines() if r.strip()):
        if git("branch", "-d", rama).returncode == 0:
            borradas.append(rama)
        else:
            quedaron.append(rama)
    return borradas, quedaron


def main() -> None:
    args = sys.argv[1:]
    if not args:
        print(
            "uso: limpiar_worktrees.py --todos | <ruta-del-worktree> [...]",
            file=sys.stderr,
        )
        sys.exit(2)

    hecho = git("rev-parse", "--show-toplevel")
    if hecho.returncode != 0:
        print("ABORT: no es un repo git", file=sys.stderr)
        sys.exit(1)
    principal = Path(hecho.stdout.strip()).resolve()

    if args == ["--todos"]:
        registrados = [
            Path(l[len("worktree ") :]).resolve()
            for l in git("worktree", "list", "--porcelain").stdout.splitlines()
            if l.startswith("worktree ")
        ]
        objetivos = [w for w in registrados if w != principal]
        objetivos += huerfanos(RAIZ.joinpath(*DIR_DE_WORKTREES), objetivos, principal)
        if not objetivos:
            print("no hay worktrees del lote para limpiar")
    else:
        objetivos = [Path(a).resolve() for a in args]

    # Sin objetivos igual se sigue: quedan el `prune` y las ramas, que no dependen de que
    # haya quedado un árbol en disco.
    padre = objetivos[0].parent if objetivos else RAIZ.joinpath(*DIR_DE_WORKTREES)
    fallo = False
    matados = False

    for wt in objetivos:
        print(f"== {wt}")
        if not wt.exists():
            print("   no existe: nada que hacer")
            continue
        if wt == principal:
            print("   SALTEADO: es el checkout principal", file=sys.stderr)
            fallo = True
            continue

        if git("worktree", "remove", "--force", str(wt)).returncode == 0:
            print("   git worktree remove: ok")
        else:
            print("   git worktree remove: fallo (esperado, corrio verificar.py) - sigo")

        if not wt.exists():
            print("   borrado")
            continue

        salida = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command",
             PS.format(ruta=str(wt).replace("\\", "/"))],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        ).stdout.strip()

        if salida:
            for linea in salida.splitlines():
                print(f"   ANOMALIA: habia un proceso vivo - {linea}")
            matados = True
            # `Stop-Process` vuelve enseguida, pero Windows tarda en soltar el handle. Sin esta
            # espera el borrado corre contra un archivo todavía bloqueado y falla — y el script
            # termina culpando al IDE de algo que era timing.
            time.sleep(1)

        borrar_arbol(wt)
        if wt.exists():
            time.sleep(2)
            borrar_arbol(wt)

        if wt.exists():
            print(
                "   SIGUE AHI. Algo tiene un handle abierto que el filtro no ve - tipicamente el\n"
                "   editor de Godot o el IDE con la carpeta abierta. Lo cierra el usuario.",
                file=sys.stderr,
            )
            fallo = True
        else:
            print("   borrado")

    # El padre vacío también se va: una carpeta vacía sigue apareciendo en el IDE, que es la
    # única señal que ve el usuario. `rmdir` falla solo si quedó algo, así que no hace falta
    # preguntar. Se calculó ANTES del loop a propósito.
    try:
        padre.rmdir()
    except OSError:
        pass

    print()
    print(git("worktree", "prune", "-v").stdout, end="")
    print()
    borradas, quedaron = barrer_ramas()
    if borradas:
        print(f"-- ramas de worktree borradas: {', '.join(borradas)}")
    for rama in quedaron:
        print(
            f"   ANOMALIA: la rama {rama} tiene commits que no estan en ningun otro lado, "
            "asi que NO se borro. Miralos antes de forzarla.",
            file=sys.stderr,
        )

    print("-- quedan registrados --")
    print(git("worktree", "list").stdout, end="")

    if matados:
        print()
        print("REPORTAR: `verificar.py` levanta Godot headless, pero deberia haber terminado.")
        print("Un proceso vivo adentro de un worktree al limpiar es un Godot colgado, y eso va")
        print("al reporte del Paso 8 con el nombre del test que lo dejo asi.")

    sys.exit(1 if fallo else 0)


if __name__ == "__main__":
    main()
