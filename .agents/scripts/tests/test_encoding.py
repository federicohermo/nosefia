"""El gate del encoding: nada de este repo escribe ni lee texto con el ANSI de la máquina.

Es la trampa más barata de pisar y la más cara de diagnosticar, porque **el síntoma nunca nombra
la causa**. En Windows la salida a una tubería sale en cp1252, así que:

- un script que imprime un acento **se cae** con `UnicodeEncodeError`, y si es el mensaje de
  bloqueo del hook, el bloqueo se convierte en una caída;
- un `subprocess.run` que captura texto **decodifica con el ANSI**, así que una rama o una ruta
  con acento vuelve mal, y en el peor caso tira;
- un servidor de stdio manda su primera respuesta con acento en cp1252 y el cliente la descarta
  con un error de decodificación: se lee como «el servidor no conecta».

Los tres ya pasaron acá. Este módulo los cierra **descubriendo los archivos**, no enumerándolos:
un script nuevo entra al gate solo, que es lo único que hace que el gate siga sirviendo cuando el
repo crezca.
"""

import ast
import unittest
from pathlib import Path

from lib.repo import RAIZ

#: Los árboles de Python propios. `addons/` es vendorizado y no lo escribimos nosotros.
ARBOLES = (RAIZ / ".claude" / "scripts", RAIZ / "mcp-server")


def _modulos() -> list[Path]:
    return sorted(p for arbol in ARBOLES if arbol.is_dir() for p in arbol.rglob("*.py"))


def _es_ejecutable(arbol: ast.Module) -> bool:
    """Si el módulo se corre solo. Los de `lib/` no, y no imprimen: no necesitan configurar."""
    for nodo in arbol.body:
        if (
            isinstance(nodo, ast.If)
            and isinstance(nodo.test, ast.Compare)
            and isinstance(nodo.test.left, ast.Name)
            and nodo.test.left.id == "__name__"
        ):
            return True
    return False


def _configura_utf8(texto: str) -> bool:
    """Si el módulo pone sus flujos en UTF-8, por cualquiera de las dos vías legítimas.

    La normal es `configurar()` de `lib/consola.py`. El servidor MCP lo hace a mano porque
    además necesita `stdin` y un salto de línea fijo: su canal es el protocolo, no una consola.
    """
    return "configurar()" in texto or "reconfigure(encoding=" in texto


class TodoLoQueImprimeDeclaraSuEncoding(unittest.TestCase):
    def test_cada_script_ejecutable_configura_utf8(self):
        # **Los módulos de `tests/` quedan afuera, y no por comodidad.** Su `__main__` es un
        # atajo para correr uno suelto; quien los corre de verdad es `unittest discover` desde
        # `verificar.py`, que captura la salida con `encoding="utf-8"` — y eso lo cobra el caso
        # de abajo. Pedirles `configurar()` a los veinticinco sería ruido que nadie lee.
        for modulo in _modulos():
            if "tests" in modulo.relative_to(RAIZ).parts:
                continue
            texto = modulo.read_text(encoding="utf-8")
            if not _es_ejecutable(ast.parse(texto)):
                continue
            with self.subTest(modulo=modulo.relative_to(RAIZ).as_posix()):
                self.assertTrue(
                    _configura_utf8(texto),
                    "un script que se corre solo imprime, y en Windows su primer acento lo tira "
                    "abajo. Va `configurar()` de `lib/consola.py` antes de imprimir nada.",
                )

    def test_ningun_subprocess_captura_texto_sin_declarar_el_encoding(self):
        # `text=True` sin `encoding` decodifica con el ANSI de la máquina. Lo pisaron dos
        # llamadas de `gate_de_rama.py`, que leen el nombre de la rama con `git`.
        for modulo in _modulos():
            arbol = ast.parse(modulo.read_text(encoding="utf-8"))
            for nodo in ast.walk(arbol):
                if not (
                    isinstance(nodo, ast.Call)
                    and isinstance(nodo.func, ast.Attribute)
                    and nodo.func.attr == "run"
                ):
                    continue
                claves = {k.arg for k in nodo.keywords}
                if not ({"capture_output", "text"} & claves):
                    continue
                with self.subTest(
                    modulo=modulo.relative_to(RAIZ).as_posix(), linea=nodo.lineno
                ):
                    self.assertIn(
                        "encoding",
                        claves,
                        "captura texto de un subproceso sin declarar el encoding: pasale "
                        '`encoding="utf-8"`.',
                    )

    def test_todo_archivo_se_lee_y_se_escribe_en_utf8(self):
        # Un `read_text()` pelado usa el ANSI de la máquina. Acá los `.gd` y los `.md` llevan
        # acentos en casi todas las líneas, así que la falla es inmediata y no ambigua — salvo
        # en la CI, que corre en Linux y no la ve.
        for modulo in _modulos():
            arbol = ast.parse(modulo.read_text(encoding="utf-8"))
            for nodo in ast.walk(arbol):
                if not (
                    isinstance(nodo, ast.Call)
                    and isinstance(nodo.func, ast.Attribute)
                    and nodo.func.attr in ("read_text", "write_text")
                ):
                    continue
                with self.subTest(
                    modulo=modulo.relative_to(RAIZ).as_posix(), linea=nodo.lineno
                ):
                    self.assertIn(
                        "encoding",
                        {k.arg for k in nodo.keywords},
                        f"`{nodo.func.attr}()` sin `encoding=\"utf-8\"` usa el ANSI de la "
                        "máquina, y la CI corre en Linux: el rojo aparece sólo en Windows.",
                    )


if __name__ == "__main__":
    unittest.main()
