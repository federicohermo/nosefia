"""Los tests de `lib/derivacion.py`: las cuatro salidas del derivador.

La que más importa es la tercera —lista truncada— porque es la única que no se puede
reproducir contra el repo real: pediría mil issues.
"""

import json
import unittest

from lib.derivacion import EntornoDerivacion, derivar_y_guardar

MAPA = {
    "001": {
        "issue": 7,
        "carpeta": "001-la-ventanilla",
        "fecha": "2026-08-28",
        "estado": "Propuesto",
        "titulo": "Spec 001 — La ventanilla",
    }
}


def entorno(issues=(), prs=(), mapa=None, limite=1000, verificar=False):
    guardado = {"texto": None}
    lineas = []
    ent = EntornoDerivacion(
        issues=lambda: list(issues),
        prs=lambda: list(prs),
        leer_texto=lambda: json.dumps(mapa if mapa is not None else MAPA),
        guardar=lambda t: guardado.update(texto=t),
        informar=lineas.append,
        limite=limite,
        verificar=verificar,
    )
    return ent, guardado, lineas


class SinCambios(unittest.TestCase):
    def test_no_toca_el_archivo_y_lo_dice(self):
        ent, guardado, lineas = entorno()
        self.assertEqual(derivar_y_guardar(ent), 0)
        self.assertIsNone(guardado["texto"])
        self.assertIn("sin cambios", lineas[0])


class ConCambios(unittest.TestCase):
    def test_escribe_e_imprime_cada_correccion(self):
        prs = [{"number": 3, "headRefName": "feature/001-la-ventanilla", "state": "MERGED"}]
        ent, guardado, lineas = entorno(prs=prs)
        self.assertEqual(derivar_y_guardar(ent), 0)
        self.assertIn("Implementado", guardado["texto"])
        self.assertIn('estado: "Propuesto" → "Implementado"', lineas[0])


class ListaTruncada(unittest.TestCase):
    def test_no_escribe_nada_y_sale_1(self):
        # En una lista cortada, «este spec no tiene PR» y «su PR no entró en la página» no se
        # distinguen, y son respuestas opuestas. Derivar sobre eso pondría en `Propuesto` a
        # todo spec que quedó afuera: el derivador, que existe para arreglar el registro,
        # sería el único capaz de romperlo entero de una vez.
        ent, guardado, lineas = entorno(issues=[{"number": 1}] * 3, limite=3)
        self.assertEqual(derivar_y_guardar(ent), 1)
        self.assertIsNone(guardado["texto"])
        self.assertIn("truncada", lineas[0])

    def test_alcanza_con_que_una_de_las_dos_este_truncada(self):
        # No hay media derivación.
        ent, _, lineas = entorno(prs=[{"number": 1, "headRefName": "x", "state": "OPEN"}] * 3,
                                 limite=3)
        self.assertEqual(derivar_y_guardar(ent), 1)
        self.assertIn("PR (3)", lineas[0])

    def test_una_lista_que_no_llega_al_limite_deriva_normal(self):
        ent, _, _ = entorno(issues=[{"number": 7, "state": "OPEN", "title": MAPA["001"]["titulo"]}],
                            limite=3)
        self.assertEqual(derivar_y_guardar(ent), 0)


class Verificar(unittest.TestCase):
    def test_no_escribe_pero_sale_1(self):
        prs = [{"number": 3, "headRefName": "feature/001-la-ventanilla", "state": "MERGED"}]
        ent, guardado, lineas = entorno(prs=prs, verificar=True)
        self.assertEqual(derivar_y_guardar(ent), 1)
        self.assertIsNone(guardado["texto"])
        self.assertIn("sin aplicar", lineas[-1])

    def test_sin_correcciones_sale_0(self):
        ent, _, _ = entorno(verificar=True)
        self.assertEqual(derivar_y_guardar(ent), 0)


if __name__ == "__main__":
    unittest.main()
