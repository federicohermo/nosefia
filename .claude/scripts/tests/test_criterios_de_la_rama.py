"""El ancla anti-deuda: cada criterio del spec de la rama, citado por un test.

**Un spec `Implementado` cuyos criterios no verifica nadie es la deuda invisible.** El spec
dice que está hecho, el PR aterrizó, y lo que quedó sin hacer no figura en ninguna parte: no
hay casilla abierta que mirar, porque en este régimen no hay casillas.

## Por qué mira la RAMA y no los specs cerrados

La versión anterior de esta regla corría sobre los specs `Implementado` **hidratados en
disco**, y ahí tenía dos agujeros. El primero: `specs/[0-9]*/` es caché, así que dependía de
que alguien se acordara de traer treinta specs cerrados a cada worktree — y desde que los
cerrados no se hidratan más (`hidratar_specs.py`, 2026-09-05), de que se acordara de traerlos
uno por uno. El segundo es peor: llegaba **tarde**. Un spec pasa a `Implementado` cuando su
PR ya aterrizó, o sea que el rojo aparecía cuando el trabajo ya estaba en `staging` y lo único
que quedaba era abrir otra cosa para arreglarlo — que es exactamente la deuda que esto viene a
cerrar.

Sobre la rama llega a tiempo: el PR está abierto, el spec y sus tests están juntos, y el
criterio sin verificar todavía se puede escribir en vez de deber.

## Qué verifica y qué no

Verifica la **cita** —un `NNN-AC4` en el nombre de un test o en un comentario alcanza—, no que
el test ejerza el criterio. Es un piso y hay que decirlo: el techo, que el test falle de verdad
cuando el criterio no se cumple, no lo ve ninguna herramienta. Es el mismo piso que todo lo que
este repo verifica sin cobertura.

## Los tres salteos, y por qué cada uno se declara

Se saltea si la rama no nombra un spec, si no se puede leer el `spec.md` de ese spec —ni en
disco ni por `gh`— y si no hay `specs/mapa.json`. Los tres son estados normales; el que no es
normal es un gate que no pudo mirar y sale igual que uno que miró.
"""

import functools
import json
import os
import subprocess
import unittest

from lib.repo import RAIZ, REPO
from lib.specs import RAMA_DE_SPEC, acs_de, acs_sin_test, leer_mapa

SPECS = RAIZ / "specs"

#: Dónde se busca la cita. Son dos árboles porque este repo tiene dos suites: la de gdUnit4
#: sobre el juego y la de unittest sobre el harness, y un spec puede caer entero de cualquiera
#: de los dos lados.
ARBOLES_DE_TEST = (RAIZ / "test", RAIZ / ".claude" / "scripts" / "tests")


def rama_actual() -> str | None:
    """El nombre de la rama, con el caso del PR de la Action resuelto primero.

    **En un `pull_request` de GitHub Actions, `HEAD` no es la rama**: es el merge de prueba, y
    `git rev-parse --abbrev-ref HEAD` contesta `HEAD` pelado. Sin `GITHUB_HEAD_REF`, este gate
    se saltearía siempre y justo en el único lugar donde tiene que correr.
    """
    del_entorno = os.environ.get("GITHUB_HEAD_REF")
    if del_entorno:
        return del_entorno
    try:
        salida = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=RAIZ, capture_output=True, text=True, timeout=10, check=True,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return salida.stdout.strip()


@functools.lru_cache(maxsize=1)
def spec_de_la_rama() -> str | None:
    """El `NNN` que nombra la rama, o `None`.

    El patrón deja el prefijo abierto —`feature/`, pero también `fix/` o `chore/`— y vive en
    `lib/specs.py` porque lo comparten el derivador del mapa y este gate. Dos copias que se
    separen dan dos herramientas que no coinciden en de qué spec es una rama.
    """
    rama = rama_actual()
    if rama is None:
        return None
    m = RAMA_DE_SPEC.match(rama)
    return m.group(1) if m else None


@functools.lru_cache(maxsize=1)
def spec_md() -> tuple[str, str] | None:
    """El `spec.md` del spec de la rama y de dónde salió, o `None` si no se pudo leer.

    **El disco primero y la red después**, y no al revés: el `spec.md` local puede tener
    ediciones que todavía no se publicaron, y son las que el PR está implementando. Preguntarle
    a GitHub primero haría que este gate juzgara una versión anterior del spec.
    """
    numero = spec_de_la_rama()
    if numero is None:
        return None

    for carpeta in sorted(SPECS.glob(f"{numero}-*")):
        archivo = carpeta / "spec.md"
        if archivo.is_file():
            return archivo.read_text(encoding="utf-8"), f"{carpeta.name}/spec.md"

    try:
        mapa = leer_mapa((SPECS / "mapa.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    fila = mapa.get(numero)
    if fila is None:
        return None

    # `subprocess` pelado y no el `gh` de `lib/`: ése muere con un mensaje cuando no hay `gh`
    # ni sesión, y acá eso no es un error sino un salteo que se declara.
    try:
        salida = subprocess.run(
            ["gh", "issue", "view", str(fila["issue"]), "--repo", REPO, "--json", "body"],
            capture_output=True, text=True, encoding="utf-8", timeout=60,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if salida.returncode != 0:
        return None
    return json.loads(salida.stdout)["body"], f"el issue #{fila['issue']}"


def textos_de_test() -> list[str]:
    return [
        archivo.read_text(encoding="utf-8", errors="replace")
        for arbol in ARBOLES_DE_TEST
        if arbol.is_dir()
        for archivo in arbol.rglob("*")
        if archivo.is_file() and archivo.suffix in (".gd", ".py")
    ]


class CriteriosDeLaRama(unittest.TestCase):
    def setUp(self):
        self.numero = spec_de_la_rama()
        if self.numero is None:
            self.skipTest(
                f"la rama `{rama_actual()}` no nombra un spec: este gate NO miró nada. "
                "Corre sobre una rama `<prefijo>/<NNN>-<kebab>`."
            )
        leido = spec_md()
        if leido is None:
            self.skipTest(
                f"no se pudo leer el spec.md del {self.numero}: no está hidratado y `gh` no "
                f"contestó. Este gate NO miró nada. `hidratar_specs.py {self.numero}` lo trae."
            )
        self.texto, self.origen = leido

    def test_el_spec_de_la_rama_declara_criterios(self):
        # Cero criterios no es «este spec no necesita tests»: es un spec que no dice cuándo
        # está hecho, y de paso deja al gate de abajo sin nada que exigir — en verde.
        self.assertNotEqual(
            acs_de(self.texto),
            [],
            f"el spec {self.numero} ({self.origen}) no declara ningún `ACn`.",
        )

    def test_cada_criterio_esta_citado_por_un_test(self):
        acs = acs_de(self.texto)
        faltan = acs_sin_test(self.numero, acs, textos_de_test())
        self.assertEqual(
            faltan,
            [],
            f"el spec {self.numero} ({self.origen}) tiene {len(faltan)} de {len(acs)} "
            "criterios que ningún test cita: "
            f"{', '.join(f'{self.numero}-{ac}' for ac in faltan)}. "
            "Cada criterio se cita como `NNN-ACn` desde el test que lo verifica, en `test/` o "
            "en `.claude/scripts/tests/`. Si el criterio no se puede verificar con un test, el "
            "que está mal escrito es el criterio.",
        )


class Sondas(unittest.TestCase):
    """Las reglas puras, que no dependen de en qué rama corra esto.

    **El número de los ejemplos es `999` y eso importa**: este archivo es uno de los que el
    gate lee para buscar citas, así que un ejemplo escrito con el número de un spec real
    dejaría ese criterio cubierto sin que ningún test lo verifique. Un gate que se cumple a sí
    mismo con sus propios ejemplos es la falla exacta que la cita calificada vino a cerrar, y
    vale también para la prosa: la primera versión de este encabezado se autocubrió dos AC del
    spec 030 con dos ejemplos de un docstring.
    """

    def test_un_ac_sin_test_se_nombra(self):  # 029-AC3
        self.assertEqual(acs_sin_test("999", ["AC1", "AC2"], ["mira el 999-AC1"]), ["AC2"])

    def test_un_ac_no_lo_cubre_un_prefijo(self):  # 029-AC3
        # `AC1` no lo cubre un test que dice `AC12`: sin el límite de palabra, el criterio 1
        # quedaría cubierto por cualquier criterio de dos dígitos que empiece con 1.
        self.assertEqual(acs_sin_test("999", ["AC1"], ["verifica el 999-AC12"]), ["AC1"])

    def test_la_cita_lleva_el_numero_del_spec(self):  # 029-AC3
        # Sin el número, el primer test que escribiera `AC1` cubriría el `AC1` de todos los
        # specs que vengan después, para siempre.
        self.assertEqual(acs_sin_test("999", ["AC1"], ["verifica el AC1"]), ["AC1"])

    def test_los_criterios_salen_de_su_bloque_y_no_de_la_prosa(self):  # 029-AC3
        texto = (
            "# T\n\nel AC9 de otro spec\n\n"
            "## Criterios de aceptación\n\n- **AC2** — x\n- **AC1** — y\n"
        )
        self.assertEqual(acs_de(texto), ["AC2", "AC1"])
