"""Los tests del gate de specs: el ancla AC↔test y las citas rotas.

Lo que se ejerce acá son las dos funciones puras del gate. El veredicto entero corre sobre el
árbol de verdad y no se puede fabricar sin escribir specs de mentira adentro de `specs/`.
"""

import unittest
from pathlib import Path

from gate_de_specs import problemas_de_los_ids, problemas_del_ancla
from lib.specs import Spec


def spec(nombre: str, codigo: str, estado: str, criterios: dict, reglas: list) -> Spec:
    """Un spec armado a mano. La ruta no se lee: el gate ya no vuelve al disco por estos casos."""
    armado = Spec(Path("specs") / nombre / f"{nombre}.md")
    armado.codigo = codigo
    armado.estado = estado
    armado.reglas = reglas
    armado.criterios = criterios
    return armado


class ElAncla(unittest.TestCase):
    def test_un_ratified_con_un_criterio_sin_test_es_rojo(self):
        uno = spec("demo", "DEM", "ratified", {"AC-DEM-001": [], "AC-DEM-002": []}, [])
        hallazgos, informe = problemas_del_ancla([uno], {"AC-DEM-001"})
        self.assertEqual(len(hallazgos), 1)
        self.assertIn("AC-DEM-002", hallazgos[0])
        # Y dice las dos salidas, porque bloquear sin decir cómo salir empuja a saltear.
        self.assertIn("draft", hallazgos[0])
        self.assertEqual(informe, [])

    def test_un_ratified_completo_pasa(self):
        uno = spec("demo", "DEM", "ratified", {"AC-DEM-001": []}, [])
        hallazgos, _ = problemas_del_ancla([uno], {"AC-DEM-001"})
        self.assertEqual(hallazgos, [])

    def test_un_draft_no_es_rojo_pero_se_cuenta(self):
        # La frontera es deliberada: cobrarle a todo spec escrito convierte escribir el contrato
        # de una capacidad que todavía no existe en un rojo inmediato, y ahí nadie lo escribe.
        uno = spec("demo", "DEM", "draft", {"AC-DEM-001": [], "AC-DEM-002": []}, [])
        hallazgos, informe = problemas_del_ancla([uno], {"AC-DEM-001"})
        self.assertEqual(hallazgos, [])
        self.assertIn("1/2", informe[0])

    def test_un_draft_completo_se_declara_ratificable(self):
        uno = spec("demo", "DEM", "draft", {"AC-DEM-001": []}, [])
        _, informe = problemas_del_ancla([uno], {"AC-DEM-001"})
        self.assertIn("ratificable", informe[0])

    def test_un_superseded_no_se_cobra_ni_se_cuenta(self):
        uno = spec("demo", "DEM", "superseded", {"AC-DEM-001": []}, [])
        hallazgos, informe = problemas_del_ancla([uno], set())
        self.assertEqual((hallazgos, informe), ([], []))


class LosIds(unittest.TestCase):
    def _leible(self, spec_armado: Spec, texto: str) -> Spec:
        # `problemas_de_los_ids` relee el archivo para cazar los problemas de forma, así que el
        # caso tiene que existir en disco. Se escribe en el temporal de la clase.
        spec_armado.ruta.parent.mkdir(parents=True, exist_ok=True)
        spec_armado.ruta.write_text(texto, encoding="utf-8")
        return spec_armado

    def test_dos_capacidades_con_el_mismo_codigo(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            texto = "---\nschema_version: 1\ncapability_id: CAP-DEM\nstatus: draft\n---\n"
            uno = Spec(base / "uno" / "uno.md")
            uno.codigo, uno.estado, uno.criterios = "DEM", "draft", {"AC-DEM-001": []}
            otro = Spec(base / "otro" / "otro.md")
            otro.codigo, otro.estado, otro.criterios = "DEM", "draft", {"AC-DEM-002": []}
            for s in (uno, otro):
                self._leible(s, texto)
            hallazgos = problemas_de_los_ids([uno, otro])
            self.assertTrue(any("ya es de" in h for h in hallazgos))

    def test_un_criterio_que_verifica_una_regla_inexistente(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            uno = Spec(Path(tmp) / "uno" / "uno.md")
            uno.codigo, uno.estado = "DEM", "draft"
            uno.reglas = ["BR-DEM-001"]
            uno.criterios = {"AC-DEM-001": ["BR-DEM-009"]}
            self._leible(uno, "---\nschema_version: 1\ncapability_id: CAP-DEM\nstatus: draft\n---\n")
            hallazgos = problemas_de_los_ids([uno])
            # Es la cita rota que aparece cuando una regla se borra y el criterio se queda.
            self.assertTrue(any("BR-DEM-009" in h and "no declara" in h for h in hallazgos))

    def test_un_criterio_que_no_nombra_ninguna_regla(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            uno = Spec(Path(tmp) / "uno" / "uno.md")
            uno.codigo, uno.estado, uno.reglas = "DEM", "draft", ["BR-DEM-001"]
            uno.criterios = {"AC-DEM-001": []}
            self._leible(uno, "---\nschema_version: 1\ncapability_id: CAP-DEM\nstatus: draft\n---\n")
            hallazgos = problemas_de_los_ids([uno])
            self.assertTrue(any("no nombra qué regla" in h for h in hallazgos))


if __name__ == "__main__":
    unittest.main()
