"""El borrador de un issue sale del template y no se publica a medio llenar.

El skill que escribe issues decía «la forma es la del task-brief», con un link. Eso se lee como
una sugerencia: el 2026-09-22 un issue salió escrito de memoria, sin la sección «Contrato» y con
una sección inventada, y el formato lo notó una persona. Un script que copia el archivo y otro
que revisa el borrador antes de `gh issue create` no dependen de que la prosa se lea bien.

Los casos usan el template real y lo llenan con las mismas reglas que usa el script para leerlo.
Ninguno copia una línea ni un nombre de sección del template: si el template cambia, los casos
cambian con él, y un test que se rompe es un script que dejó de entenderlo.
"""

import contextlib
import importlib.util
import io
import re
import tempfile
import unittest
from pathlib import Path

from lib.repo import RAIZ

SCRIPT = RAIZ / ".claude" / "skills" / "to-issue" / "scripts" / "borrador.py"
TEMPLATE = RAIZ / ".github" / "ISSUE_TEMPLATE" / "task-brief.md"

_spec = importlib.util.spec_from_file_location("borrador", SCRIPT)
assert _spec is not None and _spec.loader is not None
borrador = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(borrador)

# El comentario va en un grupo para que `re.split` lo conserve en los índices impares.
_COMENTARIO = re.compile(r"(<!--.*?-->)", re.DOTALL)


def _campo_llenado(campo: str) -> str:
    return campo.split(":**")[0] + ":** llenado"


def _llenado(plantilla: str) -> str:
    """El template con cada campo y cada hueco llenado, afuera de los comentarios."""
    partes = _COMENTARIO.split(plantilla)
    for i in range(0, len(partes), 2):
        texto = borrador.CAMPO.sub(lambda m: _campo_llenado(m.group(0)), partes[i])
        partes[i] = borrador.HUECO.sub("llenado", texto)
    return "".join(partes)


class Borrador(unittest.TestCase):
    def setUp(self) -> None:
        self.crudo = TEMPLATE.read_text(encoding="utf-8")
        self.plantilla = borrador.sin_encabezado(self.crudo)
        self.secciones = borrador.SECCION.findall(self.plantilla)

    def test_el_borrador_nuevo_es_el_template_sin_su_encabezado(self):
        self.assertTrue(self.crudo.startswith("---"))
        self.assertFalse(self.plantilla.startswith("---"))
        self.assertTrue(self.crudo.endswith(self.plantilla))

    def test_el_hueco_del_numero_esta_en_el_template(self):
        # Si el template lo renombra, `numerar` deja de escribir el número sin decir nada.
        self.assertIn(borrador.NUMERO, self.plantilla)

    def test_un_borrador_llenado_no_tiene_problemas(self):
        self.assertEqual(borrador.problemas(_llenado(self.plantilla), self.plantilla), [])

    def test_el_template_sin_llenar_tiene_problemas(self):
        self.assertNotEqual(borrador.problemas(self.plantilla, self.plantilla), [])

    def test_falta_una_seccion(self):
        seccion = self.secciones[0]
        texto = _llenado(self.plantilla).replace(f"## {seccion}\n", "", 1)
        problemas = borrador.problemas(texto, self.plantilla)
        self.assertTrue(any(seccion in p for p in problemas), problemas)

    def test_sobra_una_seccion(self):
        texto = _llenado(self.plantilla) + "\n## Qué pasa hoy\n\nAlgo.\n"
        problemas = borrador.problemas(texto, self.plantilla)
        self.assertTrue(any("Qué pasa hoy" in p for p in problemas), problemas)

    def test_las_secciones_van_en_el_orden_del_template(self):
        texto = _llenado(self.plantilla)
        penultima = texto.index(f"## {self.secciones[-2]}")
        ultima = texto.index(f"## {self.secciones[-1]}")
        texto = texto[:penultima] + texto[ultima:] + "\n" + texto[penultima:ultima]
        problemas = borrador.problemas(texto, self.plantilla)
        self.assertTrue(any("orden" in p for p in problemas), problemas)

    def test_un_hueco_sin_llenar_se_nombra_con_su_linea(self):
        texto = _llenado(self.plantilla) + "- <sin llenar>\n"
        numero = len(texto.splitlines())
        problemas = borrador.problemas(texto, self.plantilla)
        self.assertIn(f"línea {numero}: queda el hueco <sin llenar>", "\n".join(problemas))

    def test_un_campo_del_contexto_copiado_tal_cual_es_un_hueco(self):
        campo = borrador.CAMPO.search(self.plantilla).group(0)
        texto = _llenado(self.plantilla).replace(_campo_llenado(campo), campo, 1)
        problemas = borrador.problemas(texto, self.plantilla)
        self.assertTrue(any(campo in p for p in problemas), problemas)

    def test_los_comentarios_del_template_no_cuentan_como_huecos(self):
        # Los comentarios traen huecos de ejemplo, y GitHub no los muestra: el borrador los
        # conserva y tiene que pasar igual.
        self.assertIn("<!--", _llenado(self.plantilla))
        self.assertEqual(borrador.problemas(_llenado(self.plantilla), self.plantilla), [])

    def test_el_numero_del_issue_puede_faltar_antes_de_publicar(self):
        # El número lo da GitHub al crear el issue: exigirlo antes haría imposible publicar.
        texto = _llenado(self.plantilla) + f"- `bugfix/{borrador.NUMERO}-la-caja`\n"
        self.assertEqual(borrador.problemas(texto, self.plantilla, publicado=False), [])
        self.assertNotEqual(borrador.problemas(texto, self.plantilla), [])

    def test_numerar_llena_el_numero_y_el_borrador_queda_listo(self):
        texto = _llenado(self.plantilla) + f"- `bugfix/{borrador.NUMERO}-la-caja`\n"
        numerado = borrador.numerar(texto, 155)
        self.assertIn("`bugfix/155-la-caja`", numerado)
        self.assertEqual(borrador.problemas(numerado, self.plantilla), [])

    def test_un_borrador_sin_titulo_tiene_problemas(self):
        texto = re.sub(r"^# .+\n", "", _llenado(self.plantilla), count=1, flags=re.MULTILINE)
        self.assertNotEqual(borrador.problemas(texto, self.plantilla), [])


class Consola(unittest.TestCase):
    """El script como lo corre el skill: el código de salida decide si se publica."""

    def setUp(self) -> None:
        # Una carpeta con espacios, como la ruta de este repo.
        self._dir = tempfile.TemporaryDirectory(prefix="borrador de issue ")
        self.archivo = Path(self._dir.name) / "el borrador.md"

    def tearDown(self) -> None:
        self._dir.cleanup()

    def _correr(self, *argumentos: str) -> tuple[int, str]:
        err = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            codigo = borrador.main(list(argumentos))
        return codigo, err.getvalue()

    def test_nuevo_no_pisa_un_borrador(self):
        self.assertEqual(self._correr("nuevo", str(self.archivo))[0], 0)
        self.archivo.write_bytes(b"llenado")
        self.assertEqual(self._correr("nuevo", str(self.archivo))[0], 1)
        self.assertEqual(self.archivo.read_bytes(), b"llenado")

    def test_un_borrador_con_crlf_se_lee_igual(self):
        # Un editor de Windows guarda con CRLF: eso no es un borrador mal formado.
        plantilla = borrador.sin_encabezado(TEMPLATE.read_text(encoding="utf-8"))
        self.archivo.write_bytes(_llenado(plantilla).replace("\n", "\r\n").encode("utf-8"))
        self.assertEqual(self._correr("revisar", str(self.archivo)), (0, ""))

    def test_un_borrador_mal_formado_sale_con_1_y_dice_que_falta(self):
        plantilla = borrador.sin_encabezado(TEMPLATE.read_text(encoding="utf-8"))
        seccion = borrador.SECCION.findall(plantilla)[0]
        texto = _llenado(plantilla).replace(f"## {seccion}\n", "", 1)
        self.archivo.write_bytes(texto.replace("\n", "\r\n").encode("utf-8"))
        codigo, err = self._correr("revisar", str(self.archivo))
        self.assertEqual(codigo, 1)
        self.assertIn(f"falta la sección «## {seccion}»", err)

    def test_un_uso_equivocado_sale_con_2(self):
        self.assertEqual(self._correr("numerar", str(self.archivo), "N")[0], 2)


if __name__ == "__main__":
    unittest.main()
