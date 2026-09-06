"""El gate de la enumeración: un doc dice la regla, no la lista.

El árbol de `docs/architecture/directory-structure.md` describe cada directorio por lo que **no
se puede averiguar mirándolo** —`dominio/` dice «test OBLIGATORIO», no qué archivos tiene
adentro—. Una entrada que en vez de eso enumera su contenido caduca sola, y la de los skills
caducó cuatro veces en tres intentos. Ninguna la atajó: hasta hoy nada del harness leía el
**contenido** de `docs/`, sólo sus rutas, así que la línea podía decir tres de ocho con
`verificar.py` en 6/6 verde.

Este gate lee ese contenido y **es angosto a propósito**. «Ningún doc nombra un skill» marcaría
seis líneas de hoy y **cinco son correctas**: prosa que manda al lector a un skill por su
nombre. Un gate con cinco falsos positivos de seis se apaga en una semana. Lo que distingue al
defecto es la **enumeración**, así que el umbral son tres nombres distintos en una misma línea:
la prosa que contrasta dos pasa.

Camina `CLAUDE.md` y `docs/**/*.md`, y nada más. `specs/` queda afuera porque un spec enumera
para argumentar —el que estrenó este gate nacería rojo sobre sí mismo— y `.claude/skills/`
porque ahí los nombres **son** los directorios.

Y los nombres salen de listar ese directorio, nunca de una constante escrita: un gate contra
enumeraciones que enumera es el mismo defecto adentro del arreglo. El anteúltimo test es el que
cobra esa regla — todo nombre que figure escrito en este archivo cae adentro de
`LINEAS_DE_PRUEBA`, que son fixtures y no una lista de la que el gate dependa.
"""

import re
import unittest
from pathlib import Path

from lib.repo import RAIZ

#: Dónde viven los skills. De acá salen los nombres, con `iterdir()`.
SKILLS = RAIZ / ".claude" / "skills"

#: Cuántos nombres distintos en una misma línea dejan de ser una cita y pasan a ser una lista.
#:
#: Tres y no dos: «para dos o más, el otro» es la forma normal de mandar a la variante en lote, y
#: nombra dos. Tres nombres ya no contrastan nada — describen un contenido.
UMBRAL = 3

#: El único doc del repo cuyo trabajo es describir directorios, y donde nombrar un skill nunca
#: es una cita: es la enumeración que este gate vino a cerrar.
ARBOL = RAIZ / "docs" / "architecture" / "directory-structure.md"

#: Las líneas con las que se ejerce el conteo, y cuántos nombres nombra cada una.
#:
#: **Es el único lugar de este archivo donde se escribe el nombre de un skill**, y el test de
#: más abajo lo cobra. La primera es la enumeración que estrenó el gate, conservada acá para que
#: el gate siga demostrando que la ve después de que el doc dejó de tenerla. Las cinco del medio
#: son las citas legítimas que el repo tenía al implementar —cuatro de `CLAUDE.md` y una de
#: `quickstart.md`—, copiadas **por texto y no por número de línea**, que se corre solo. Las dos
#: últimas son sintéticas: el contraste de dos, y el nombre largo que cuenta uno.
LINEAS_DE_PRUEBA: tuple[tuple[str, int], ...] = (
    ("│   ├── skills/             spec-create, spec-revise, spec-implement", 3),
    (
        "| Convención de specs | [specs/README.md](./specs/README.md) | El mapa, los cuatro "
        "estados y los techos. El flujo es de `spec-create`; la forma, de `specs/plantilla/` |",
        1,
    ),
    (
        "[issue](https://github.com/federicohermo/nosefia/issues) y `spec-create` lo drena "
        "hacia specs",
        1,
    ),
    (
        "[sin-deuda.md](./.claude/skills/spec-create/sin-deuda.md) es la copia canónica.",
        1,
    ),
    (
        "flujo entero y **qué NO necesita spec**, en "
        "[spec-create](./.claude/skills/spec-create/SKILL.md).",
        1,
    ),
    ("El camino entero está en el skill `/spec-create`, y en corto es:", 1),
    ("Para dos o más specs de una, spec-revise-batch. Para uno solo, spec-revise.", 2),
    ("Para dos o más, spec-create-batch.", 1),
)


def nombres_de_skill() -> tuple[str, ...]:
    return tuple(sorted(d.name for d in SKILLS.iterdir() if d.is_dir()))


def nombres_en(linea: str, nombres: tuple[str, ...]) -> set[str]:
    """Los nombres que la línea nombra, contados por palabra y una sola vez cada uno.

    El límite trata al guión como parte del nombre, y no es un detalle: con un `in` pelado, un
    nombre que es prefijo de otro se cuenta dos veces —el largo, y el corto adentro del largo—,
    así que dos citas a variantes en lote alcanzarían el umbral sin enumerar nada.
    """
    return {n for n in nombres if re.search(rf"(?<![\w-]){re.escape(n)}(?![\w-])", linea)}


def documentos() -> list[Path]:
    """Lo que el gate camina: `CLAUDE.md` y `docs/`. Nada más."""
    return [RAIZ / "CLAUDE.md", *sorted((RAIZ / "docs").rglob("*.md"))]


def _relativa(p: Path) -> str:
    return p.relative_to(RAIZ).as_posix()


def _lineas_fuera_de_los_fixtures(fuente: str) -> list[tuple[int, str]]:
    """Las líneas del propio archivo que no son el bloque de fixtures."""
    afuera: list[tuple[int, str]] = []
    adentro = False
    for numero, linea in enumerate(fuente.splitlines(), 1):
        if linea.startswith("LINEAS_DE_PRUEBA"):
            adentro = True
            continue
        if adentro:
            adentro = linea != ")"
            continue
        afuera.append((numero, linea))
    return afuera


class DocsNoEnumeranSkills(unittest.TestCase):
    def setUp(self):
        self.nombres = nombres_de_skill()

    def test_ninguna_linea_de_los_docs_enumera_skills(self):
        hallazgos = []
        for doc in documentos():
            for numero, linea in enumerate(
                doc.read_text(encoding="utf-8").splitlines(), 1
            ):
                encontrados = nombres_en(linea, self.nombres)
                if len(encontrados) >= UMBRAL:
                    hallazgos.append(
                        f"{_relativa(doc)}:{numero} nombra {len(encontrados)} skills "
                        f"({', '.join(sorted(encontrados))}): eso es una lista, y una lista "
                        "caduca la próxima vez que se agregue uno. Decí la regla."
                    )
        self.assertEqual(hallazgos, [], "\n".join(hallazgos))

    def test_el_arbol_de_directorios_no_nombra_ningun_skill(self):  # 010-AC1
        # El doc que describe directorios se mide más duro que el resto: ahí un nombre no es
        # una cita para el lector, es el contenido del directorio escrito a mano.
        texto = ARBOL.read_text(encoding="utf-8")
        for numero, linea in enumerate(texto.splitlines(), 1):
            self.assertEqual(
                nombres_en(linea, self.nombres),
                set(),
                f"{_relativa(ARBOL)}:{numero} nombra un skill. Este doc dice qué hay en cada "
                "directorio por lo que no se ve mirándolo, y un nombre ahí es la lista.",
            )

    def test_la_entrada_de_skills_dice_la_regla(self):  # 010-AC2
        lineas = [
            linea
            for linea in ARBOL.read_text(encoding="utf-8").splitlines()
            if "skills/" in linea and "├──" in linea
        ]
        self.assertEqual(len(lineas), 1, "la entrada `skills/` del árbol no está, o está dos veces")
        entrada = lineas[0]
        self.assertIn("specs", entrada, f"la entrada no dice de qué es el flujo: {entrada}")
        self.assertIn("lote", entrada, f"la entrada no dice que cada uno tiene su lote: {entrada}")

    def test_la_tabla_dice_donde_va_un_skill_nuevo(self):  # 010-AC3
        filas = [
            linea
            for linea in ARBOL.read_text(encoding="utf-8").splitlines()
            if linea.startswith("|") and "`.claude/skills/`" in linea
        ]
        self.assertEqual(len(filas), 1, "la tabla «Dónde crear cada cosa» no tiene su fila")
        fila = filas[0]
        self.assertIn("autocontenido", fila, f"la fila no dice la primera condición: {fila}")
        self.assertIn(
            "test_copias_de_skills.py", fila, f"la fila no dice dónde se declara una copia: {fila}"
        )

    def test_el_gate_ve_la_enumeracion_que_lo_estreno(self):  # 010-AC4
        # Corrido antes de tocar los docs, este módulo falló nombrando
        # `docs/architecture/directory-structure.md:67` y su enumeración de tres — la evidencia
        # de que sabe ver el defecto. Ese archivo ya está arreglado, así que el defecto vive
        # ahora en el primer fixture: sin esto, el gate quedaría demostrando nada.
        linea, cuantos = LINEAS_DE_PRUEBA[0]
        self.assertEqual(len(nombres_en(linea, self.nombres)), cuantos)
        self.assertGreaterEqual(cuantos, UMBRAL)

    def test_las_citas_legitimas_no_llegan_al_umbral(self):  # 010-AC5
        for linea, cuantos in LINEAS_DE_PRUEBA[1:]:
            with self.subTest(linea=linea):
                self.assertEqual(
                    len(nombres_en(linea, self.nombres)),
                    cuantos,
                    "el conteo no da lo medido: esta línea es prosa que cita, no una lista",
                )
                self.assertLess(cuantos, UMBRAL, "una cita legítima no puede dar rojo")

    def test_un_nombre_con_sufijo_cuenta_uno(self):  # 010-AC7
        # La variante en lote es UN nombre. Contarla como dos —el largo y el corto adentro—
        # bastaría para que dos citas seguidas alcanzaran el umbral sin enumerar nada.
        linea, cuantos = LINEAS_DE_PRUEBA[-1]
        self.assertEqual(len(nombres_en(linea, self.nombres)), cuantos)

    def test_los_nombres_solo_figuran_en_las_lineas_de_prueba(self):  # 010-AC6
        # El falsificador de «los nombres salen de `iterdir()`»: si alguno estuviera escrito
        # afuera de los fixtures, sería una constante, y este gate enumeraría lo mismo que
        # prohíbe.
        fuente = Path(__file__).read_text(encoding="utf-8")
        for numero, linea in _lineas_fuera_de_los_fixtures(fuente):
            self.assertEqual(
                nombres_en(linea, self.nombres),
                set(),
                f"la línea {numero} de este archivo escribe el nombre de un skill fuera de "
                "`LINEAS_DE_PRUEBA`: los nombres se listan, no se escriben.",
            )


# 010-AC8 — `verificar.py` en 6/6 sin salteos, con `harness` corriendo estos tests de más que el
# baseline: se verifica corriéndolo, no desde acá; ningún test puede verificarse a sí mismo
# contando cuántos hay.
# 010-AC9 — los dos `Closes` del PR —el del issue de este spec y el `#7` del origen— se
# verifican leyendo el cuerpo del PR abierto: no hay nada en el árbol que los contenga.

if __name__ == "__main__":
    unittest.main()
