"""El tope de la carga web frena un despliegue que suma programas de shader o agranda el motor."""

import contextlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[3] / ".github/scripts/tope_de_carga.py"
SPEC = importlib.util.spec_from_file_location("tope_de_carga", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
tope = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(tope)

TOPES = {"programas": 89, "wasm_bytes": 1000}


def medicion(*programas):
    return {"corridas": [{"programas": p} for p in programas]}


class TopeDeCargaTest(unittest.TestCase):
    def setUp(self):
        self.temporal = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporal.cleanup)
        self.raiz = Path(self.temporal.name)
        self.medida = medicion(87)
        self.topes = dict(TOPES)
        self.wasm = 1000

    def correr(self):
        rutas = []
        for nombre, datos in (("topes", self.topes), ("carga", self.medida)):
            ruta = self.raiz / f"{nombre}.json"
            ruta.unlink(missing_ok=True)
            if datos is not None:
                ruta.write_text(json.dumps(datos), encoding="utf-8")
            rutas.append(str(ruta))
        wasm = self.raiz / "index.wasm"
        wasm.unlink(missing_ok=True)
        if self.wasm is not None:
            wasm.write_bytes(b"\0" * self.wasm)
        salida = io.StringIO()
        with contextlib.redirect_stdout(salida), contextlib.redirect_stderr(salida):
            codigo = tope.main([*rutas, str(wasm)])
        return codigo, salida.getvalue()

    def test_todo_en_su_tope_pasa_e_informa_lo_medido(self):
        self.medida = medicion(89)
        codigo, salida = self.correr()
        self.assertEqual(codigo, 0, salida)
        for dato in ("89", "1000"):
            self.assertIn(dato, salida)

    def test_un_programa_de_mas_falla_y_nombra_lo_medido_y_el_tope(self):
        self.medida = medicion(90)
        codigo, salida = self.correr()
        self.assertEqual(codigo, 1)
        self.assertIn("90 programas, tope 89", salida)

    def test_cada_corrida_se_compara_sola(self):
        self.medida = medicion(87, 90, 87)
        self.assertEqual(self.correr()[0], 1)

    def test_un_byte_de_mas_en_el_motor_falla(self):
        self.wasm = 1001
        codigo, salida = self.correr()
        self.assertEqual(codigo, 1)
        self.assertIn("index.wasm: 1001 bytes, tope 1000", salida)

    def test_un_conteo_de_cero_falla_porque_no_se_conto_la_carga(self):
        self.medida = medicion(0)
        self.assertEqual(self.correr()[0], 1)

    def test_bajar_un_conteo_pasa_sin_tocar_los_topes(self):
        self.medida = medicion(60)
        antes = json.dumps(self.topes)
        self.assertEqual(self.correr()[0], 0)
        self.assertEqual((self.raiz / "topes.json").read_text(encoding="utf-8"), antes)

    def test_una_medicion_sin_corridas_es_un_dato_incompleto(self):
        self.medida = medicion()
        self.assertEqual(self.correr()[0], 2)

    def test_un_tope_que_falta_o_sobra_es_un_dato_incompleto(self):
        del self.topes["wasm_bytes"]
        self.assertEqual(self.correr()[0], 2)
        self.topes = dict(TOPES, programas_con_paralelo=1)
        self.assertEqual(self.correr()[0], 2)

    def test_un_archivo_que_falta_es_un_dato_incompleto(self):
        self.medida = None
        self.assertEqual(self.correr()[0], 2)
        self.medida = medicion(87)
        self.wasm = None
        self.assertEqual(self.correr()[0], 2)

    def test_un_conteo_que_no_es_entero_es_un_dato_incompleto(self):
        self.medida = medicion("87")
        self.assertEqual(self.correr()[0], 2)

    def test_los_topes_del_repo_declaran_los_dos_valores(self):
        topes = json.loads(tope.TOPES.read_text(encoding="utf-8"))
        self.assertEqual(set(topes), set(TOPES))
        self.assertEqual(topes["wasm_bytes"], 30 * 1024 * 1024)


if __name__ == "__main__":
    unittest.main()
