"""El nodo de convergencia: lo único que hay que correr antes de un PR.

    python .claude/scripts/verificar.py

Corre los seis nodos **en paralelo** y sale 1 si alguno falla. La CI llama a este script y
**no enumera los nodos**, a propósito: enumerarlos allá crearía un segundo lugar donde vive la
lista, y el día que alguien agregue un nodo acá, la CI seguiría corriendo la lista vieja — en
verde, que es el modo de falla que este archivo existe para no tener.

Los seis:

| Nodo      | Qué verifica                                                              |
|-----------|---------------------------------------------------------------------------|
| `lint`    | `gdlint` sobre `src/` y `test/`: nombres, orden de declaraciones, largo    |
| `formato` | `gdformat --check`: el formato es el que produce la herramienta, no una opinión |
| `capas`   | La dirección de dependencia entre las capas de `src/`                     |
| `tdd`     | El espejo de tests, que ninguno esté apagado y que ninguno corra sin afirmar |
| `harness` | Los tests de estas mismas herramientas (`unittest`)                       |
| `tests`   | La suite de gdUnit4 en Godot headless                                     |

## Los dos nodos que se saltean, y por qué lo dicen

Un nodo que no puede correr **no pasa callado**: declara que se salteó y por qué. Un repo
recién arrancado no tiene un solo `.gd`, y `lint` sobre cero archivos que dice «OK» es una
mentira chiquita que se vuelve grande el día que el walk se rompa y siga diciendo lo mismo.

Y `tests` es un salteo **con fecha de vencimiento**: mientras no haya un solo `*_test.gd` no
hay nada que correr y no hace falta Godot. En cuanto exista el primero, Godot pasa a ser
obligatorio y la falta de `GODOT_BIN` es un rojo — no un salteo.
"""

import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.archivos import scripts_gd  # noqa: E402
from lib.godot import aviso_de_entorno_viejo, como_declararlo, resolver  # noqa: E402
from lib.repo import RAIZ, REPORTES, TESTS  # noqa: E402
from lib.tdd import SUFIJO_DE_TEST  # noqa: E402

AQUI = Path(__file__).resolve().parent


@dataclass
class Resultado:
    nodo: str
    codigo: int
    salida: str
    segundos: float
    #: Un nodo salteado no es un nodo verde: se cuenta aparte y se dice por qué.
    salteado: bool = False
    #: Algo que hay que decir **aunque el nodo salga verde**. Es raro y por eso es opcional: la
    #: salida de un nodo en verde no se imprime, así que sin este campo un aviso se perdería.
    aviso: str | None = None


def _correr(nodo: str, comando: list[str], cwd: Path = RAIZ) -> Resultado:
    arranque = time.monotonic()
    try:
        proceso = subprocess.run(
            comando, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace"
        )
    except FileNotFoundError:
        return Resultado(
            nodo,
            1,
            f"no se encontró `{comando[0]}`.\n"
            "Las herramientas de GDScript se instalan con: pip install \"gdtoolkit==4.*\"",
            time.monotonic() - arranque,
        )
    salida = (proceso.stdout or "") + (proceso.stderr or "")
    return Resultado(nodo, proceso.returncode, salida, time.monotonic() - arranque)


def _saltear(nodo: str, motivo: str) -> Resultado:
    return Resultado(nodo, 0, motivo, 0.0, salteado=True)


def _fuentes() -> list[str]:
    """Los directorios de GDScript propio que existen y tienen algo adentro."""
    return [d for d in ("src", TESTS) if (RAIZ / d).is_dir() and any((RAIZ / d).rglob("*.gd"))]


def nodo_lint() -> Resultado:
    fuentes = _fuentes()
    if not fuentes:
        return _saltear("lint", "no hay un solo `.gd` propio todavía: nada que lintear.")
    return _correr("lint", ["gdlint", *fuentes])


def nodo_formato() -> Resultado:
    fuentes = _fuentes()
    if not fuentes:
        return _saltear("formato", "no hay un solo `.gd` propio todavía: nada que formatear.")
    return _correr("formato", ["gdformat", "--check", *fuentes])


def nodo_capas() -> Resultado:
    return _correr("capas", [sys.executable, str(AQUI / "gate_de_capas.py")])


def nodo_tdd() -> Resultado:
    return _correr("tdd", [sys.executable, str(AQUI / "gate_de_tests.py")])


def nodo_harness() -> Resultado:
    return _correr(
        "harness",
        [sys.executable, "-m", "unittest", "discover", "-s", str(AQUI / "tests"), "-t", str(AQUI)],
    )


def nodo_tests() -> Resultado:
    """La suite de gdUnit4, en Godot headless.

    El veredicto sale del **código de salida**, y eso hay que decirlo porque la alternativa
    tentadora —grepear la salida buscando «failed»— es la forma más corta conocida de declarar
    verde una corrida rota: un `grep` que no matchea devuelve 1 y se traga la salida entera.
    """
    tests = scripts_gd(RAIZ, TESTS)
    suites = [r for r in tests if r.endswith(SUFIJO_DE_TEST)]
    if not suites:
        return _saltear(
            "tests",
            f"no hay un solo `*{SUFIJO_DE_TEST}` todavía. En cuanto exista el primero, este nodo "
            "pasa a necesitar Godot y deja de saltearse.",
        )

    godot, origen = resolver(dict(os.environ))
    if godot is None:
        return Resultado("tests", 1, como_declararlo(dict(os.environ)), 0.0)

    # El aviso viaja en el resultado y lo imprime `main`, aunque el nodo salga verde: que el
    # entorno de la terminal esté viejo es un dato que hay que dar igual, porque va a morder en
    # la próxima herramienta que no tenga este rescate.
    aviso = aviso_de_entorno_viejo(origen)

    resultado = _correr(
        "tests",
        [
            godot,
            "--path", str(RAIZ),
            "--headless",
            "-s", "-d",
            # Sin esto, un error de parseo abre el debugger interactivo de Godot y el proceso
            # queda colgado para siempre en un prompt `debug>` que nadie va a contestar. El
            # puerto 0 no se liga nunca, así que la conexión siempre se rechaza.
            "--remote-debug", "tcp://127.0.0.1:0",
            "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
            "-a", TESTS,
            # Por defecto gdUnit4 corta en el primer fallo. Acá se corre todo: en una corrida de
            # CI, saber que fallan siete cosas y cuáles vale más que saber cuál fue la primera.
            "--continue",
            # gdUnit4 se niega a correr headless salvo que se lo declare, y correr headless es
            # justamente todo el punto: es lo que hace que la CI y esta máquina hagan lo mismo.
            "--ignoreHeadlessMode",
            "-rd", REPORTES,
        ],
    )
    resultado.aviso = aviso
    return resultado


NODOS = (nodo_lint, nodo_formato, nodo_capas, nodo_tdd, nodo_harness, nodo_tests)


def main() -> None:
    solo = None
    if "--solo" in sys.argv:
        solo = sys.argv[sys.argv.index("--solo") + 1]

    a_correr = [n for n in NODOS if solo is None or n.__name__ == f"nodo_{solo}"]
    if not a_correr:
        nombres = ", ".join(n.__name__.removeprefix("nodo_") for n in NODOS)
        print(f"no hay un nodo «{solo}». Los que hay: {nombres}", file=sys.stderr)
        sys.exit(1)

    arranque = time.monotonic()
    with ThreadPoolExecutor(max_workers=len(a_correr)) as pool:
        resultados = list(pool.map(lambda n: n(), a_correr))
    total = time.monotonic() - arranque

    for r in sorted(resultados, key=lambda r: r.nodo):
        if r.salteado:
            estado = "salteado"
        elif r.codigo == 0:
            estado = "ok"
        else:
            estado = "FALLA"
        print(f"  {estado:<9} {r.nodo:<9} {r.segundos:5.1f}s")

    fallaron = [r for r in resultados if r.codigo != 0]
    salteados = [r for r in resultados if r.salteado]

    # Los avisos van primero y salen igual con la corrida en verde: son cosas ciertas sobre la
    # máquina que no impidieron correr, pero que van a impedir otra cosa más adelante.
    for r in resultados:
        if r.aviso:
            print(f"\n{r.aviso}")

    for r in salteados:
        print(f"\n── {r.nodo}: salteado ──\n{r.salida}")

    for r in fallaron:
        print(f"\n── {r.nodo}: exit {r.codigo} ──\n{r.salida.rstrip()}")

    print(f"\n{len(resultados) - len(fallaron)}/{len(resultados)} nodos en verde, en {total:.1f}s.")
    sys.exit(1 if fallaron else 0)


if __name__ == "__main__":
    main()
