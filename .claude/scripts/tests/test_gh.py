"""Los tests de `lib/gh.py`.

Los tres caminos —lo encuentra en el PATH, lo rescata de una ubicación conocida, no lo
encuentra— se ejercen con el entorno inyectado, sin tocar el PATH del que corre los tests y
sin depender de si esta máquina tiene `gh`.
"""

import subprocess
import unittest

from lib.gh import UBICACIONES_WINDOWS, crear_gh, mensaje_sin_gh, mensaje_sin_sesion


class Muerte(Exception):
    """Lo que tira el doble de `morir`, que en producción es un `sys.exit`."""


def doble(existentes=(), plataforma="win32", falla_con=None, falla_siempre=False):
    """Un entorno de mentira. Devuelve `(gh, registro)`."""
    registro = {"llamadas": [], "avisos": [], "muerte": None}

    def ejecutar(binario, args, entrada):
        registro["llamadas"].append(binario)
        if falla_con is not None and len(registro["llamadas"]) == 1:
            raise falla_con
        if binario == "gh" or falla_siempre:
            raise FileNotFoundError(2, "no such file", binario)
        return "salida"

    def morir(mensaje):
        registro["muerte"] = mensaje
        raise Muerte(mensaje)

    gh = crear_gh(
        ejecutar=ejecutar,
        existe=lambda ruta: ruta in existentes,
        plataforma=plataforma,
        avisar=registro["avisos"].append,
        morir=morir,
    )
    return gh, registro


class CuandoEstaEnElPath(unittest.TestCase):
    def test_usa_gh_a_secas(self):
        registro = {"llamadas": []}

        def ejecutar(binario, args, entrada):
            registro["llamadas"].append(binario)
            return "ok"

        gh = crear_gh(ejecutar, lambda r: True, "win32", print, print)
        self.assertEqual(gh(["issue", "list"]), "ok")
        # El PATH gana: resolver por adelantado invertiría la preferencia y podría elegir una
        # instalación vieja del disco por sobre la que el PATH declara.
        self.assertEqual(registro["llamadas"], ["gh"])


class CuandoNoEstaEnElPath(unittest.TestCase):
    def test_lo_rescata_de_la_ubicacion_conocida(self):
        gh, registro = doble(existentes={UBICACIONES_WINDOWS[0]})
        self.assertEqual(gh(["issue", "list"]), "salida")
        self.assertEqual(registro["llamadas"], ["gh", UBICACIONES_WINDOWS[0]])

    def test_avisa_del_rescate(self):
        # Un aviso y no un silencio: la solución de fondo es agregarlo al PATH, y eso arregla
        # todas las otras herramientas también.
        gh, registro = doble(existentes={UBICACIONES_WINDOWS[0]})
        gh(["issue", "list"])
        self.assertIn("no está en el PATH", registro["avisos"][0])

    def test_no_busca_ubicaciones_de_windows_en_posix(self):
        gh, registro = doble(existentes=set(UBICACIONES_WINDOWS), plataforma="linux")
        with self.assertRaises(Muerte):
            gh(["issue", "list"])
        self.assertIn("cli.github.com", registro["muerte"])

    def test_si_tampoco_esta_ahi_muere_diciendo_como_salir(self):
        gh, registro = doble(existentes=set())
        with self.assertRaises(Muerte):
            gh(["issue", "list"])
        self.assertIn("gh auth login", registro["muerte"])

    def test_el_reintento_esta_protegido(self):
        # Un archivo que existe pero no se puede ejecutar —otra arquitectura, un enlace roto—
        # vuelve a dar `FileNotFoundError` en el reintento. Sin el `try` de adentro se escapa
        # crudo, que es exactamente el error que este módulo existe para no dejar salir. El
        # guardia de `rescatado` no alcanza: recién corre en la llamada SIGUIENTE.
        gh, registro = doble(existentes={UBICACIONES_WINDOWS[0]}, falla_siempre=True)
        with self.assertRaises(Muerte):
            gh(["issue", "list"])
        self.assertIn("No se encontró `gh`", registro["muerte"])


class CuandoNoHaySesion(unittest.TestCase):
    def test_lo_dice_en_vez_de_mostrar_un_traceback(self):
        error = subprocess.CalledProcessError(1, "gh")
        error.stderr = "gh: To get started with GitHub CLI, please run: gh auth login"
        gh, registro = doble(falla_con=error)
        with self.assertRaises(Muerte):
            gh(["issue", "list"])
        self.assertIn("gh auth login", registro["muerte"])

    def test_un_fallo_que_no_es_de_sesion_sube_tal_cual(self):
        # Inventarle una explicación a un fallo que no se reconoce es peor que mostrar el
        # original.
        error = subprocess.CalledProcessError(1, "gh")
        error.stderr = "could not resolve to a Repository"
        gh, registro = doble(falla_con=error)
        with self.assertRaises(subprocess.CalledProcessError):
            gh(["issue", "list"])
        self.assertIsNone(registro["muerte"])


class Mensajes(unittest.TestCase):
    def test_en_windows_nombra_las_ubicaciones(self):
        mensaje = mensaje_sin_gh("win32")
        for ubicacion in UBICACIONES_WINDOWS:
            self.assertIn(ubicacion, mensaje)

    def test_en_posix_no_las_nombra(self):
        # Allá el gestor de paquetes ya lo pone en el PATH y la línea sería ruido.
        self.assertNotIn("Program Files", mensaje_sin_gh("linux"))

    def test_el_de_sesion_muestra_lo_que_contesto_gh(self):
        self.assertIn("not logged in", mensaje_sin_sesion("  not logged in  "))


if __name__ == "__main__":
    unittest.main()
