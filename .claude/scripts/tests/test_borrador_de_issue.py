"""El borrador de un issue sale del template y no se publica a medio llenar.

El skill que escribe issues decía «la forma es la del task-brief», con un link. Eso se lee como
una sugerencia: el 2026-09-22 un issue salió escrito de memoria, sin la sección «Contrato» y con
una sección inventada, y el formato lo notó una persona. Un script que copia el archivo y otro
que revisa el borrador antes de `gh issue create` no dependen de que la prosa se lea bien.

Los casos usan el template real y no uno de juguete: si el template cambia, lo que se afirma
cambia con él.
"""

import importlib.util
import unittest

from lib.repo import RAIZ

SCRIPT = RAIZ / ".claude" / "skills" / "to-issue" / "scripts" / "borrador.py"
TEMPLATE = RAIZ / ".github" / "ISSUE_TEMPLATE" / "task-brief.md"

_spec = importlib.util.spec_from_file_location("borrador", SCRIPT)
assert _spec is not None and _spec.loader is not None
borrador = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(borrador)


def _llenado(plantilla: str) -> str:
    """Un borrador con cada hueco del template llenado, que es lo que tiene que pasar."""
    reemplazos = {
        "# <Qué cambia, no qué área toca>": "# La caja vuelve al centro",
        "- **Objetivo:** una oración. Qué problema resuelve.": "- **Objetivo:** que vuelva.",
        "- **Tipo:** `feature` | `bugfix` | `refactor` | `improvement`": "- **Tipo:** `bugfix`",
        "- **Spec:** ninguno | crea | modifica | borra — `specs/<capability>/<capability>.md`": (
            "- **Spec:** ninguno"
        ),
        "- **Rama:** `<tipo>/<issue>-<kebab>`, o `harness/` o `docs/` si no toca `src/`": (
            "- **Rama:** `bugfix/155-la-caja-vuelve`"
        ),
        "- [ ] <...>": "- [ ] La caja vuelve al punto de la caja.",
        "| **Se escribe** | <...> |": "| **Se escribe** | `src/sistemas/marco/agarre.gd` |",
        "| **Sólo lectura** | <...> |": "| **Sólo lectura** | `src/escenas/jugador.gd` |",
        "| **No se toca** | <...> |": "| **No se toca** | `specs/` |",
        "2. <...>": "2. Examinar una caja en el juego.",
        "- <...>": "- Cerrar con el clic.",
    }
    texto = plantilla
    for viejo, nuevo in reemplazos.items():
        assert viejo in texto, f"el template ya no trae «{viejo}»: actualizar este fixture"
        texto = texto.replace(viejo, nuevo)
    return texto


class Borrador(unittest.TestCase):
    def setUp(self) -> None:
        self.plantilla = borrador.sin_encabezado(TEMPLATE.read_text(encoding="utf-8"))

    def test_el_borrador_nuevo_es_el_template_sin_su_encabezado(self):
        self.assertNotIn("name: Task brief", self.plantilla)
        self.assertIn("## Criterios de aceptación", self.plantilla)
        self.assertFalse(self.plantilla.startswith("---"))

    def test_un_borrador_llenado_no_tiene_problemas(self):
        self.assertEqual(borrador.problemas(_llenado(self.plantilla), self.plantilla), [])

    def test_el_template_sin_llenar_tiene_problemas(self):
        self.assertNotEqual(borrador.problemas(self.plantilla, self.plantilla), [])

    def test_falta_una_seccion(self):
        texto = _llenado(self.plantilla).replace("## Contrato\n", "")
        problemas = borrador.problemas(texto, self.plantilla)
        self.assertTrue(any("Contrato" in p for p in problemas), problemas)

    def test_sobra_una_seccion(self):
        texto = _llenado(self.plantilla).replace("## Bordes", "## Qué pasa hoy\n\nAlgo.\n\n## Bordes")
        problemas = borrador.problemas(texto, self.plantilla)
        self.assertTrue(any("Qué pasa hoy" in p for p in problemas), problemas)

    def test_las_secciones_van_en_el_orden_del_template(self):
        texto = _llenado(self.plantilla)
        verificacion, bordes = texto.index("## Verificación"), texto.index("## Bordes")
        texto = (
            texto[:verificacion]
            + texto[bordes:]
            + "\n"
            + texto[verificacion:bordes]
        )
        self.assertNotEqual(borrador.problemas(texto, self.plantilla), [])

    def test_un_hueco_sin_llenar_se_nombra_con_su_linea(self):
        texto = _llenado(self.plantilla).replace(
            "- **Rama:** `bugfix/155-la-caja-vuelve`", "- **Rama:** `bugfix/<issue>-la-caja-vuelve`"
        )
        problemas = borrador.problemas(texto, self.plantilla)
        numero = next(
            n for n, linea in enumerate(texto.splitlines(), 1) if "<issue>" in linea
        )
        self.assertIn(f"línea {numero}: queda el hueco <issue>", "\n".join(problemas))

    def test_un_campo_del_contexto_copiado_tal_cual_es_un_hueco(self):
        texto = _llenado(self.plantilla).replace(
            "- **Objetivo:** que vuelva.", "- **Objetivo:** una oración. Qué problema resuelve."
        )
        problemas = borrador.problemas(texto, self.plantilla)
        self.assertTrue(any("Objetivo" in p for p in problemas), problemas)

    def test_los_comentarios_del_template_no_cuentan_como_huecos(self):
        # Los comentarios traen `<COD>` y `<tipo>` de ejemplo, y GitHub no los muestra: el
        # borrador los conserva y tiene que pasar igual.
        self.assertIn("<!--", _llenado(self.plantilla))
        self.assertEqual(borrador.problemas(_llenado(self.plantilla), self.plantilla), [])

    def test_el_numero_del_issue_puede_faltar_antes_de_publicar(self):
        # El número lo da GitHub al crear el issue: exigirlo antes haría imposible publicar.
        texto = _llenado(self.plantilla).replace(
            "`bugfix/155-la-caja-vuelve`", "`bugfix/<issue>-la-caja-vuelve`"
        )
        self.assertEqual(borrador.problemas(texto, self.plantilla, publicado=False), [])

    def test_numerar_llena_el_numero_y_el_borrador_queda_listo(self):
        texto = _llenado(self.plantilla).replace(
            "`bugfix/155-la-caja-vuelve`", "`bugfix/<issue>-la-caja-vuelve`"
        )
        numerado = borrador.numerar(texto, 155)
        self.assertIn("`bugfix/155-la-caja-vuelve`", numerado)
        self.assertEqual(borrador.problemas(numerado, self.plantilla), [])

    def test_un_borrador_sin_titulo_tiene_problemas(self):
        texto = _llenado(self.plantilla).replace("# La caja vuelve al centro\n", "")
        self.assertNotEqual(borrador.problemas(texto, self.plantilla), [])


if __name__ == "__main__":
    unittest.main()
