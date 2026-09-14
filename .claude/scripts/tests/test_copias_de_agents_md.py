"""El gate de los `AGENTS.md`: cada copia sigue siendo su regla, letra por letra.

Cada directorio con reglas propias lleva un `AGENTS.md` que es la copia íntegra de un archivo de
`.claude/rules/`. La duplicación es deliberada y tiene el mismo motivo que la de los skills: los
`AGENTS.md` los lee un agente que no carga `.claude/rules/`, así que un puntero no le sirve —
necesita el texto adelante.

**El precio es el mismo y hasta hoy nadie lo cobraba.** Ocho copias, novecientas líneas, y editar
la regla sin propagarla no rompía nada: el agente seguía leyendo el método viejo, en verde. Es el
peor modo de falla de este repo, y es exactamente el que `test_copias_de_skills.py` cierra del
otro lado.

**La declaración no se escribe acá: la trae cada copia en su encabezado.** La línea 3 nombra su
canónico, así que agregar una copia la mete al gate sola. Una tabla en este archivo sería el
segundo lugar donde vive la lista, y la que se pudre.
"""

import re
import unittest
from pathlib import Path

from lib.repo import RAIZ

#: El encabezado que cada copia antepone a su canónico, y de dónde arranca el texto copiado.
#:
#: Son las seis líneas de contexto que el canónico no puede traer —dice que es una copia, a qué
#: alcance aplica y desde dónde se resuelven sus enlaces—. La séptima ya es del canónico.
LINEAS_DEL_ENCABEZADO = 6

#: La línea 3 del encabezado, que nombra el canónico. Es la declaración.
DECLARACION = re.compile(r"^Copia íntegra de `(\.claude/rules/[^`]+\.md)`\.$")

#: El `AGENTS.md` de la raíz no es una copia: manda a leer `CLAUDE.md` y no duplica nada.
RAIZ_NO_COPIA = RAIZ / "AGENTS.md"


def _relativa(p: Path) -> str:
    return p.relative_to(RAIZ).as_posix()


def _copias() -> list[Path]:
    # Se descubren en disco y no se enumeran: una copia nueva entra al gate sin tocar este
    # archivo, que es la única forma de que el gate no se afloje solo.
    return sorted(
        p
        for p in RAIZ.rglob("AGENTS.md")
        if p != RAIZ_NO_COPIA and ".claude/worktrees" not in _relativa(p) and "addons" not in p.parts
    )


class CopiasDeAgentsMd(unittest.TestCase):
    def test_hay_copias_que_mirar(self):
        # Sin esto, un rglob que deja de encontrar archivos —una carpeta renombrada, un filtro de
        # más— deja el gate entero en verde sin mirar nada.
        self.assertGreater(len(_copias()), 0, "no se encontró un solo AGENTS.md de directorio")

    def test_cada_copia_declara_su_canonico(self):
        for copia in _copias():
            lineas = copia.read_text(encoding="utf-8").splitlines()
            self.assertGreaterEqual(
                len(lineas),
                LINEAS_DEL_ENCABEZADO,
                f"{_relativa(copia)} es más corto que su encabezado",
            )
            self.assertRegex(
                lineas[2],
                DECLARACION,
                f"{_relativa(copia)}:3 no nombra su canónico. La línea es "
                "'Copia íntegra de `.claude/rules/<archivo>.md`.'",
            )

    def test_cada_copia_es_identica_a_su_canonico(self):
        for copia in _copias():
            texto = copia.read_text(encoding="utf-8")
            declarado = DECLARACION.match(texto.splitlines()[2])
            if declarado is None:
                continue  # Lo cobra el caso de arriba; acá sería el mismo rojo dos veces.
            canonico = RAIZ / declarado.group(1)
            self.assertTrue(
                canonico.is_file(),
                f"{_relativa(copia)} declara {declarado.group(1)}, que no existe",
            )
            cuerpo = "".join(texto.splitlines(keepends=True)[LINEAS_DEL_ENCABEZADO:])
            self.assertEqual(
                cuerpo,
                canonico.read_text(encoding="utf-8"),
                f"{_relativa(copia)} se separó de {declarado.group(1)}. Se edita la regla y se "
                f"propaga: el cuerpo de la copia es ese archivo entero, sin tocar una coma.",
            )


if __name__ == "__main__":
    unittest.main()
