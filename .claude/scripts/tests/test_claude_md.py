"""Que `CLAUDE.md` siga siendo un índice y no se convierta en prosa.

Es el único archivo que se carga entero en cada sesión, así que cada línea que crece ahí la paga
todo el trabajo que viene después. La presión es constante y en una sola dirección: cada trampa
nueva llega con su explicación pegada, y explicarla ahí siempre parece la opción corta.

El techo es lo que la frena. El detalle va al lugar que corresponde —la regla de la capa, el
docstring del gate, el comentario que justifica la línea rara—, y acá queda la línea que la
nombra.
"""

import unittest

from lib.repo import RAIZ

#: Cuántas líneas puede medir una trampa. Es lo que mide hoy la más larga: el techo no es una
#: preferencia, es no dejarla crecer.
LINEAS_POR_TRAMPA = 6

#: El consejo que no alcanza. Una terminal nueva **no** ve una `GODOT_BIN` recién declarada si el
#: host es anterior al cambio, y dejar los dos consejos al lado es peor que cualquiera solo.
CONSEJO_QUE_NO_ALCANZA = "Después hay que abrir una terminal nueva."


def _items(texto: str, titulo: str) -> list[list[str]]:
    """Los ítems de la lista de una sección, cada uno con sus líneas de continuación."""
    cuerpo = texto.split(titulo, 1)[1].split("\n## ", 1)[0]
    items: list[list[str]] = []
    for linea in cuerpo.splitlines():
        if linea.startswith("- "):
            items.append([linea])
        elif items and linea.startswith("  "):
            items[-1].append(linea)
    return items


class LasTrampas(unittest.TestCase):
    def test_cada_trampa_sigue_siendo_una_sola(self):
        texto = (RAIZ / "CLAUDE.md").read_text(encoding="utf-8")
        items = _items(texto, "## Las trampas de este repo")
        self.assertTrue(items, "la sección de trampas no tiene ítems")
        for item in items:
            with self.subTest(trampa=item[0][:60]):
                self.assertLessEqual(
                    len(item),
                    LINEAS_POR_TRAMPA,
                    f"creció a prosa larga:\n{item[0]}\n"
                    "El detalle va donde vive el arreglo; acá va la línea que la nombra.",
                )

    def test_ningun_puntero_del_indice_apunta_a_un_archivo_que_no_esta(self):
        # Un índice con un enlace muerto es peor que uno incompleto: manda a buscar algo que no
        # existe, y quien lo sigue no sabe si se borró o si nunca estuvo.
        import re

        texto = (RAIZ / "CLAUDE.md").read_text(encoding="utf-8")
        for destino in re.findall(r"\]\(\.(/[^)#]+)", texto):
            with self.subTest(destino=destino):
                self.assertTrue((RAIZ / destino.lstrip("/")).exists(), "puntero muerto")


class ElQuickstart(unittest.TestCase):
    def test_no_repite_el_consejo_que_no_alcanza(self):
        texto = (RAIZ / "docs" / "guides" / "quickstart.md").read_text(encoding="utf-8")
        self.assertNotIn(
            CONSEJO_QUE_NO_ALCANZA,
            texto,
            "una terminal nueva no ve la variable si el host es anterior al cambio. Se corrige, "
            "no se complementa.",
        )


if __name__ == "__main__":
    unittest.main()
