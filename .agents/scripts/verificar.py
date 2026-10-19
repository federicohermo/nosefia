"""El nodo de convergencia: lo único que hay que correr antes de un PR.

    python .claude/scripts/verificar.py

Corre los siete nodos **en paralelo** y sale 1 si alguno falla. La CI llama a este script y
**no enumera los nodos**, a propósito: enumerarlos allá crearía un segundo lugar donde vive la
lista, y el día que alguien agregue un nodo acá, la CI seguiría corriendo la lista vieja — en
verde, que es el modo de falla que este archivo existe para no tener.

Los siete:

| Nodo      | Qué verifica                                                              |
|-----------|---------------------------------------------------------------------------|
| `lint`    | `gdlint` sobre `src/` y `test/`: nombres, orden de declaraciones, largo    |
| `formato` | `gdformat --check`: el formato es el que produce la herramienta, no una opinión |
| `capas`   | Qué es cada capa de `src/`: su dirección, sus subcarpetas y la pureza del dominio |
| `tdd`     | El espejo de tests, que ninguno esté apagado y que ninguno corra sin afirmar |
| `specs`   | La forma de los contratos de capacidad, y que cada criterio ratificado tenga test |
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

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.archivos import scripts_gd  # noqa: E402
from lib.godot import (  # noqa: E402
    aviso_de_entorno_viejo,
    como_declararlo,
    entorno_de_la_suite,
    resolver,
    validar_motor,
)
from lib.particiones_de_tests import (  # noqa: E402
    GrupoTests,
    ParticionTests,
    agrupar_suites,
    comprobar_cobertura,
    comprobar_reporte,
    seleccionar_suites,
)
from lib.repo import RAIZ, REPORTES, TESTS  # noqa: E402
from lib.tdd import SUFIJO_DE_TEST  # noqa: E402
from lib.verificacion import resumen  # noqa: E402

AQUI = Path(__file__).resolve().parent


def _preparar_cache_gdtoolkit() -> None:
    """El creador de gdtoolkit no tolera que otro nodo cree la carpeta entre sus dos pasos."""
    try:
        from importlib.metadata import version

        from gdtoolkit.parser.parser import get_cache_directory

        cache = Path(get_cache_directory()) / "gdtoolkit" / version("gdtoolkit")
    except ImportError:
        # Sin la herramienta instalada, _correr conserva su diagnóstico habitual.
        return
    cache.mkdir(parents=True, exist_ok=True)


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


def _correr(
    nodo: str, comando: list[str], cwd: Path = RAIZ, entorno: dict[str, str] | None = None
) -> Resultado:
    arranque = time.monotonic()
    try:
        if comando[0] in ("gdlint", "gdformat"):
            _preparar_cache_gdtoolkit()
        proceso = subprocess.run(
            comando,
            cwd=cwd,
            env=entorno,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
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


def nodo_specs() -> Resultado:
    return _correr("specs", [sys.executable, str(AQUI / "gate_de_specs.py")])


def nodo_harness() -> Resultado:
    return _correr(
        "harness",
        [sys.executable, "-m", "unittest", "discover", "-s", str(AQUI / "tests"), "-t", str(AQUI)],
    )


def nodo_tests(particion: ParticionTests | None = None) -> Resultado:
    """La suite de gdUnit4, en Godot headless.

    El veredicto sale del **código de salida**, y eso hay que decirlo porque la alternativa
    tentadora —grepear la salida buscando «failed»— es la forma más corta conocida de declarar
    verde una corrida rota: un `grep` que no matchea devuelve 1 y se traga la salida entera.
    """
    tests = scripts_gd(RAIZ, TESTS)
    suites = [r for r in tests if r.endswith(SUFIJO_DE_TEST)]
    if particion is not None:
        try:
            suites = seleccionar_suites(suites, particion)
        except ValueError as error:
            return Resultado("tests", 1, str(error), 0.0)
    if not suites:
        return _saltear(
            "tests",
            f"no hay un solo `*{SUFIJO_DE_TEST}` todavía. En cuanto exista el primero, este nodo "
            "pasa a necesitar Godot y deja de saltearse.",
        )

    try:
        godot, origen = resolver(dict(os.environ))
        if godot is not None:
            validar_motor(godot, RAIZ)
    except (OSError, ValueError, ImportError, RuntimeError, KeyError, TypeError) as error:
        return Resultado(
            "tests", 1,
            f"Motor nativo no válido: {error}\n"
            "Preparalo con python .github/scripts/preparar_godot_nativo.py preparar.",
            0.0,
        )
    if godot is None:
        return Resultado("tests", 1, como_declararlo(dict(os.environ)), 0.0)

    # El aviso viaja en el resultado y lo imprime `main`, aunque el nodo salga verde: que el
    # entorno de la terminal esté viejo es un dato que hay que dar igual, porque va a morder en
    # la próxima herramienta que no tenga este rescate.
    aviso = aviso_de_entorno_viejo(origen)

    # **Importar primero, y siempre.** Godot no tiene el registro de clases globales hasta que
    # corre esto, y sin registro gdUnit4 no resuelve ni sus propios `class_name`: el rojo dice
    # `Could not find type "GdUnitTestCIRunner"`, que manda a revisar el addon. Pasa en todo
    # worktree recién creado —`.godot/` está en el `.gitignore`— y otra vez con **cada
    # `class_name` nuevo**, donde el mensaje es `Identifier "X" not declared` con el archivo ya
    # en disco, idéntico al del archivo que todavía no existe.
    #
    # Es incondicional porque la alternativa es adivinar cuándo hace falta, y equivocarse
    # devuelve justo esos dos rojos. Incremental cuesta 6 s contra los ~180 s de la suite.
    importacion = _correr(
        "tests", [godot, "--headless", "--path", str(RAIZ), "--import", "--quit"]
    )
    if importacion.codigo != 0:
        importacion.aviso = aviso
        return importacion

    grupos = agrupar_suites(suites)
    base_reportes = RAIZ / REPORTES.removeprefix("res://")
    base_reportes.mkdir(parents=True, exist_ok=True)
    prefijo = (
        f"particion-{particion.indice}-de-{particion.total}-" if particion else "suite-"
    )
    reportes = Path(tempfile.mkdtemp(prefix=prefijo, dir=base_reportes))
    (reportes / "suites-esperadas.txt").write_text("\n".join(suites) + "\n", encoding="utf-8")
    (reportes / "grupos.json").write_text(
        json.dumps([
            {"nombre": grupo.nombre, "suites": grupo.suites, "fps_fijos": grupo.fps_fijos}
            for grupo in grupos
        ], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    entorno = entorno_de_la_suite(dict(os.environ), RAIZ, sys.platform)
    resultado = Resultado("tests", 0, "", 0.0)
    ejecutadas: list[str] = []
    for grupo in grupos:
        carpeta = reportes / grupo.nombre
        carpeta.mkdir()
        parcial, comprobadas = _ejecutar_grupo(godot, grupo, carpeta, entorno)
        resultado.codigo = resultado.codigo or parcial.codigo
        resultado.segundos += parcial.segundos
        resultado.salida += f"\nGrupo {grupo.nombre}:\n{parcial.salida}\n"
        ejecutadas.extend(comprobadas)
    (reportes / "salida-gdunit4.log").write_text(resultado.salida, encoding="utf-8")
    try:
        comprobar_cobertura(suites, ejecutadas)
        cobertura = f"{len(ejecutadas)}/{len(suites)} suites verificadas por ruta en JUnit"
    except ValueError as error:
        resultado.codigo = resultado.codigo or 1
        cobertura = str(error)
    alcance = f"Partición {particion.indice}/{particion.total}" if particion else "Suite completa"
    detalle = f"{alcance}: {cobertura}"
    (reportes / "cobertura.txt").write_text(detalle + "\n", encoding="utf-8")
    resultado.salida += "\n" + detalle
    resultado.aviso = "\n".join(texto for texto in (aviso, detalle) if texto)
    return resultado


def _ejecutar_grupo(
    godot: str, grupo: GrupoTests, reportes: Path, entorno: dict[str, str]
) -> tuple[Resultado, list[str]]:
    (reportes / "suites-esperadas.txt").write_text(
        "\n".join(grupo.suites) + "\n", encoding="utf-8"
    )
    resultado = _correr(
        "tests",
        [
            godot,
            *(["--fixed-fps", str(grupo.fps_fijos)] if grupo.fps_fijos else []),
            "--path", str(RAIZ),
            "--headless",
            "-s", "-d",
            # Sin esto, un error de parseo abre el debugger interactivo de Godot y el proceso
            # queda colgado para siempre en un prompt `debug>` que nadie va a contestar. El
            # puerto 0 no se liga nunca, así que la conexión siempre se rechaza.
            "--remote-debug", "tcp://127.0.0.1:0",
            "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
            *(argumento for suite in grupo.suites for argumento in ("-a", suite)),
            # Por defecto gdUnit4 corta en el primer fallo. Acá se corre todo: en una corrida de
            # CI, saber que fallan siete cosas y cuáles vale más que saber cuál fue la primera.
            "--continue",
            # gdUnit4 se niega a correr headless salvo que se lo declare, y correr headless es
            # justamente todo el punto: es lo que hace que la CI y esta máquina hagan lo mismo.
            "--ignoreHeadlessMode",
            "-rd", reportes.relative_to(RAIZ).as_posix(),
        ],
        # `user://` adentro del checkout: si no, dos corridas a la vez se borran `user://tmp`.
        entorno=entorno,
    )
    (reportes / "salida-gdunit4.log").write_text(resultado.salida, encoding="utf-8")
    ejecutadas: list[str] = []
    try:
        archivos = list(reportes.rglob("results.xml"))
        if len(archivos) != 1:
            raise ValueError(
                f"se esperaba un reporte JUnit nuevo, se encontraron {len(archivos)}"
            )
        ejecutadas = comprobar_reporte(list(grupo.suites), archivos[0].read_text(encoding="utf-8"))
        cobertura = f"{len(ejecutadas)}/{len(grupo.suites)} suites verificadas por ruta en JUnit"
    except (OSError, ValueError) as error:
        resultado.codigo = resultado.codigo or 1
        cobertura = str(error)
    detalle = f"Grupo {grupo.nombre}: {cobertura}"
    (reportes / "cobertura.txt").write_text(detalle + "\n", encoding="utf-8")
    resultado.salida += "\n" + detalle
    return resultado, ejecutadas


NODOS = (nodo_lint, nodo_formato, nodo_capas, nodo_tdd, nodo_specs, nodo_harness, nodo_tests)


def main(argumentos: list[str] | None = None) -> None:
    nodos = {n.__name__.removeprefix("nodo_"): n for n in NODOS}
    parser = argparse.ArgumentParser(
        description="Verifica todos los nodos o uno solo.", allow_abbrev=False
    )
    parser.add_argument("--solo", choices=nodos, help="corre un único nodo, sin comas")
    parser.add_argument(
        "--particion-tests",
        type=ParticionTests.desde_texto,
        metavar="ÍNDICE/TOTAL",
        help="reparte las suites; la última partición también corre los demás nodos",
    )
    opciones = parser.parse_args(argumentos)
    particion = opciones.particion_tests
    if particion is not None and opciones.solo not in (None, "tests"):
        parser.error("--particion-tests sólo admite --solo tests o la verificación completa")
    a_correr = [nodos[opciones.solo]] if opciones.solo is not None else list(NODOS)
    tests = nodos.get("tests")
    if particion is not None and particion.indice != particion.total - 1:
        a_correr = [n for n in a_correr if n is tests]

    arranque = time.monotonic()
    with ThreadPoolExecutor(max_workers=len(a_correr)) as pool:
        resultados = list(
            pool.map(lambda n: n(particion) if n is tests and particion else n(), a_correr)
        )
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

    # El conteo vive en `lib/verificacion.py` y no acá. Hasta el 2026-09-02 esta línea decía
    # `len(resultados) - len(fallaron)`, y un salteado —que devuelve 0— no está entre los que
    # fallaron: sumaba al numerador. Una corrida sin `GODOT_BIN` imprimía `6/6 nodos en verde`
    # con la suite del juego sin correr, tres líneas debajo del bloque que decía que no corrió.
    print(f"\n{resumen(resultados, total)}")
    sys.exit(1 if fallaron else 0)


if __name__ == "__main__":
    main()
