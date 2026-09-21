"""Los tests de `lib/specs.py`: leer un spec de capacidad sin tocar disco.

`leer_spec` recibe el texto y no la ruta justamente para esto — un parser que abriera el
archivo sólo se podría ejercer escribiendo specs de mentira en el árbol de verdad, y los casos
que importan acá son los malformados, que nadie quiere ver commiteados.
"""

import unittest
from pathlib import Path

from lib.specs import ESTADOS, leer_spec

RUTA = Path("specs/demo/demo.md")

CABECERA = """---
schema_version: 1
capability_id: CAP-DEM
status: draft
---

# Capacidad: demo
"""


def spec(cuerpo: str = "", cabecera: str = CABECERA):
    leido = leer_spec(RUTA, cabecera + cuerpo)
    return leido, leido.problemas


class ElFrontmatter(unittest.TestCase):
    def test_el_codigo_sale_del_capability_id(self):
        leido, problemas = spec()
        self.assertEqual(leido.codigo, "DEM")
        self.assertEqual(leido.estado, "draft")

    def test_sin_frontmatter_es_un_problema_y_no_una_excepcion(self):
        # Un spec ilegible tiene que salir en el reporte junto a los demás, no llevarse puesta
        # la corrida: el gate mira nueve archivos y un `raise` deja ocho sin mirar.
        _, problemas = spec(cabecera="# Capacidad: demo\n")
        self.assertEqual(len(problemas), 1)
        self.assertIn("frontmatter", problemas[0])

    def test_un_capability_id_que_no_es_CAP_XXX(self):
        _, problemas = spec(cabecera=CABECERA.replace("CAP-DEM", "demo"))
        self.assertTrue(any("capability_id" in p for p in problemas))

    def test_un_estado_fuera_del_conjunto(self):
        _, problemas = spec(cabecera=CABECERA.replace("status: draft", "status: Propuesto"))
        self.assertTrue(any("status" in p for p in problemas))
        # Y el mensaje ofrece los tres: bloquear sin decir cuáles son manda a abrir el módulo.
        self.assertTrue(all(e in problemas[0] for e in ESTADOS))

    def test_el_comentario_de_la_plantilla_no_se_cuela_en_el_valor(self):
        # La plantilla explica el ciclo de vida al lado del campo, así que cortar el `#` es
        # parte de leerlo. Sin eso, el spec copiado de la plantilla nace inválido.
        leido, problemas = spec(cabecera=CABECERA.replace("status: draft", "status: draft  # ojo"))
        self.assertEqual(leido.estado, "draft")
        self.assertEqual(problemas, [])


class LosIdentificadores(unittest.TestCase):
    def test_las_reglas_y_los_criterios_se_separan(self):
        leido, problemas = spec(
            "### BR-DEM-001 — una regla\n\n### AC-DEM-001 — un criterio *(verifica BR-DEM-001)*\n"
        )
        self.assertEqual(leido.reglas, ["BR-DEM-001"])
        self.assertEqual(leido.criterios, {"AC-DEM-001": ["BR-DEM-001"]})
        self.assertEqual(problemas, [])

    def test_un_criterio_puede_verificar_varias_reglas(self):
        leido, _ = spec(
            "### BR-DEM-001 — a\n\n### BR-DEM-002 — b\n\n"
            "### AC-DEM-001 — c *(verifica BR-DEM-001, BR-DEM-002)*\n"
        )
        self.assertEqual(leido.criterios["AC-DEM-001"], ["BR-DEM-001", "BR-DEM-002"])

    def test_un_id_repetido_es_un_problema(self):
        _, problemas = spec("### BR-DEM-001 — a\n\n### BR-DEM-001 — b\n")
        self.assertTrue(any("dos veces" in p for p in problemas))

    def test_un_id_con_el_codigo_de_otra_capacidad(self):
        # El modo de falla real: un spec copiado de otro se queda con el código del original, y
        # sus criterios apuntan a reglas que sí existen — en el otro archivo.
        _, problemas = spec("### BR-OTR-001 — de otra capacidad\n")
        self.assertTrue(any("código de la capacidad" in p for p in problemas))

    def test_un_encabezado_que_no_es_un_id_no_cuenta(self):
        leido, problemas = spec("### Propósito\n\n### BR-DEM-001 — una regla\n")
        self.assertEqual(leido.reglas, ["BR-DEM-001"])
        self.assertEqual(problemas, [])


if __name__ == "__main__":
    unittest.main()
