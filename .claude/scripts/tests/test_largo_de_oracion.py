"""El largo de oración de la directriz de lenguaje, cobrado por un test y no por la revisión.

La directriz vive en `docs/guides/conventions.md` y dice el techo en palabras. Era prosa, y la
prosa no frena a nadie: una oración larga pasaba todos los nodos en verde. Un número fijo va en
un script, y éste es ese script.

Camina `CLAUDE.md`, `docs/**/*.md` y `.claude/rules/*.md`. Quedan afuera `specs/` y
`.claude/skills/`, que tienen su propia forma, y `docs/architecture/decisions/`: un ADR es
registro histórico y no se reescribe.

El techo para instrucciones es más bajo, y queda para la revisión: distinguir una instrucción de
una descripción no es mecánico. No hay lista de excepciones: una oración larga se parte.
"""

import unittest
from pathlib import Path

from lib.oraciones import largas, oraciones
from lib.repo import RAIZ

#: El techo de palabras por oración. Sale de la directriz de lenguaje de
#: `docs/guides/conventions.md`, que lo dice como regla. En el código vive sólo acá.
TECHO = 25

#: Un ADR se escribe una vez y queda: reescribirlo borra lo que registra.
DECISIONES = RAIZ / "docs" / "architecture" / "decisions"


def documentos() -> list[Path]:
    docs = [p for p in sorted((RAIZ / "docs").rglob("*.md")) if DECISIONES not in p.parents]
    reglas = sorted((RAIZ / ".claude" / "rules").glob("*.md"))
    return [RAIZ / "CLAUDE.md", *docs, *reglas]


def _palabras(n: int) -> str:
    return " ".join(["palabra"] * n)


class ElConteo(unittest.TestCase):
    def test_el_techo_pasa_y_una_palabra_mas_no(self):
        self.assertEqual(largas(f"{_palabras(TECHO)}.\n", TECHO), [])
        [larga] = largas(f"{_palabras(TECHO + 1)}.\n", TECHO)
        self.assertEqual(larga.palabras, TECHO + 1)

    def test_una_oracion_que_sigue_en_la_linea_siguiente_cuenta_entera(self):
        mitad = TECHO // 2 + 1
        texto = f"Intro.\n\n{_palabras(mitad)}\n{_palabras(mitad)}.\n"
        [larga] = largas(texto, TECHO)
        self.assertEqual((larga.linea, larga.palabras), (3, 2 * mitad))

    def test_la_linea_es_la_de_la_oracion_y_no_la_del_parrafo(self):
        texto = f"Corta.\nOtra corta.\nUna {_palabras(TECHO)}.\n"
        self.assertEqual([o.linea for o in largas(texto, TECHO)], [3])

    def test_un_item_de_lista_es_una_oracion_aparte(self):
        # Cada parte entra en el techo; juntas, no.
        parte = _palabras(TECHO - 1)
        texto = f"{parte}:\n\n- {parte}.\n- {parte}.\n"
        self.assertEqual(largas(texto, TECHO), [])
        self.assertEqual(len(oraciones(texto)), 3)

    def test_una_abreviatura_con_punto_no_corta(self):
        # La abreviatura cuenta como una palabra, y la mayúscula que la sigue no corta.
        texto = f"{_palabras(12)}, p. ej. Una {_palabras(12)}.\n"
        self.assertEqual([o.palabras for o in oraciones(texto)], [26])

    def test_un_punto_seguido_de_mayuscula_corta(self):
        texto = f"{_palabras(20)}. Otra {_palabras(20)}.\n"
        self.assertEqual([o.palabras for o in oraciones(texto)], [20, 21])

    def test_un_etc_seguido_de_mayuscula_corta(self):
        # «etc.» cierra la oración cuando lo sigue una mayúscula; seguido de minúscula ya no corta.
        self.assertEqual([o.palabras for o in oraciones("Uno, dos, etc. Tres cuatro.\n")], [3, 2])

    def test_el_codigo_en_linea_cuenta_como_una_palabra(self):
        texto = "Correr `python .claude/scripts/verificar.py --solo harness` antes del PR.\n"
        self.assertEqual([o.palabras for o in oraciones(texto)], [5])

    def test_un_enlace_cuenta_por_su_texto(self):
        texto = "Ver [la guía de tests](../../docs/guides/tdd.md), que lo explica.\n"
        self.assertEqual([o.palabras for o in oraciones(texto)], [8])

    def test_no_cuenta_codigo_tablas_titulos_ni_frontmatter(self):
        texto = (
            f"---\npaths: {_palabras(30)}\n---\n\n# {_palabras(30)}\n\n"
            f"```text\n{_palabras(30)}.\n```\n\n| {_palabras(30)} |\n|---|\n"
        )
        self.assertEqual(oraciones(texto), [])


class LosDocs(unittest.TestCase):
    def test_hay_documentos_que_mirar(self):
        # Sin esto, un glob que deja de encontrar archivos deja el test en verde sin leer nada.
        self.assertGreater(len(documentos()), 1)
        self.assertNotIn(DECISIONES, [p.parent for p in documentos()])

    def test_ninguna_oracion_pasa_del_techo(self):
        hallazgos = [
            f"{doc.relative_to(RAIZ).as_posix()}:{o.linea}: {o.palabras} palabras — {o.texto[:80]}"
            for doc in documentos()
            for o in largas(doc.read_text(encoding="utf-8"), TECHO)
        ]
        self.assertEqual(
            hallazgos,
            [],
            f"\n{len(hallazgos)} oraciones pasan de {TECHO} palabras. Se parten; no hay "
            "excepciones.\n" + "\n".join(hallazgos),
        )


if __name__ == "__main__":
    unittest.main()
