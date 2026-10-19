"""El tope de la carga web frena un PR que suma programas de shader o agranda el motor."""

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

TOPES = {"programas_con_paralelo": 103, "programas_sin_paralelo": 97, "wasm_bytes": 1000}


def medicion(programas, sin_enlace_en_paralelo, enlace_visto=None):
    if enlace_visto is None:
        enlace_visto = not sin_enlace_en_paralelo
    return {
        "corridas": [{"programas": p, "enlace_en_paralelo": enlace_visto} for p in programas],
        "condiciones": {"sinEnlaceEnParalelo": sin_enlace_en_paralelo},
    }


class TopeDeCargaTest(unittest.TestCase):
    def setUp(self):
        self.temporal = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporal.cleanup)
        self.raiz = Path(self.temporal.name)
        self.con = medicion([101, 100, 101], False)
        self.sin = medicion([95, 94, 95], True)
        self.topes = dict(TOPES)
        self.wasm = 1000

    def correr(self):
        rutas = []
        for nombre, datos in (("topes", self.topes), ("con", self.con), ("sin", self.sin)):
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

    def test_todo_en_su_tope_o_por_debajo_pasa_e_informa_lo_medido(self):
        self.con = medicion([103, 100, 101], False)
        self.sin = medicion([97, 94, 95], True)
        codigo, salida = self.correr()
        self.assertEqual(codigo, 0, salida)
        for dato in ("103", "97", "1000"):
            self.assertIn(dato, salida)

    def test_un_programa_de_mas_en_una_sola_corrida_falla_y_nombra_el_camino(self):
        self.con = medicion([101, 104, 101], False)
        codigo, salida = self.correr()
        self.assertEqual(codigo, 1)
        self.assertIn("con enlace en paralelo", salida)
        self.assertIn("104", salida)
        self.assertIn("103", salida)

    def test_el_camino_sin_enlace_en_paralelo_tiene_su_propio_tope(self):
        self.sin = medicion([95, 98, 95], True)
        codigo, salida = self.correr()
        self.assertEqual(codigo, 1)
        self.assertIn("sin enlace en paralelo", salida)

    def test_un_byte_de_mas_en_el_motor_falla(self):
        self.wasm = 1001
        codigo, salida = self.correr()
        self.assertEqual(codigo, 1)
        self.assertIn("index.wasm", salida)

    def test_un_conteo_de_cero_falla_porque_el_contador_no_vio_la_carga(self):
        self.sin = medicion([95, 0, 95], True)
        self.assertEqual(self.correr()[0], 1)

    def test_falla_si_la_medicion_con_enlace_en_paralelo_no_vio_la_extension(self):
        self.con = medicion([101, 100, 101], False, enlace_visto=False)
        codigo, salida = self.correr()
        self.assertEqual(codigo, 1)
        self.assertIn("KHR_parallel_shader_compile", salida)

    def test_falla_si_la_medicion_sin_enlace_en_paralelo_igual_vio_la_extension(self):
        self.sin = medicion([95, 94, 95], True, enlace_visto=True)
        self.assertEqual(self.correr()[0], 1)

    def test_bajar_un_conteo_pasa_sin_tocar_los_topes(self):
        self.con = medicion([80, 80, 80], False)
        antes = json.dumps(self.topes)
        self.assertEqual(self.correr()[0], 0)
        self.assertEqual((self.raiz / "topes.json").read_text(encoding="utf-8"), antes)

    def test_las_mediciones_invertidas_no_se_comparan(self):
        self.con, self.sin = self.sin, self.con
        self.assertEqual(self.correr()[0], 2)

    def test_menos_de_tres_corridas_es_un_dato_incompleto(self):
        self.con = medicion([101, 100], False)
        self.assertEqual(self.correr()[0], 2)

    def test_un_tope_que_falta_es_un_dato_incompleto(self):
        del self.topes["wasm_bytes"]
        self.assertEqual(self.correr()[0], 2)

    def test_un_archivo_que_falta_es_un_dato_incompleto(self):
        self.sin = None
        self.assertEqual(self.correr()[0], 2)
        self.sin = medicion([95, 94, 95], True)
        self.wasm = None
        self.assertEqual(self.correr()[0], 2)

    def test_un_conteo_que_no_es_entero_es_un_dato_incompleto(self):
        self.con["corridas"][1]["programas"] = "101"
        self.assertEqual(self.correr()[0], 2)

    def test_los_topes_del_repo_declaran_los_tres_valores(self):
        topes = json.loads(tope.TOPES.read_text(encoding="utf-8"))
        self.assertEqual(set(topes), set(TOPES))
        self.assertEqual(topes["wasm_bytes"], 30 * 1024 * 1024)


if __name__ == "__main__":
    unittest.main()
