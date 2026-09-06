"""Las reglas puras de `lib/rama.py`: qué cuenta como violar una ruta declarada.

Lo de I/O —git, `gh`— no se sondea acá: se ejerce en los dos gates que lo usan, y ahí un
salteo se declara. Lo que sí tiene que estar cubierto es lo que decide el rojo, porque un
`viola()` demasiado laxo pone en rojo un PR correcto y uno demasiado estricto deja pasar
justo lo que el plan prohibía.
"""

import unittest

from lib.rama import rutas_violadas, viola


class Viola(unittest.TestCase):
    def test_un_directorio_matchea_lo_que_tiene_adentro(self):
        self.assertTrue(viola("src/", "src/dominio/reglas.gd"))
        self.assertFalse(viola("src/", "docs/guides/tdd.md"))

    def test_un_directorio_no_matchea_un_nombre_que_lo_tiene_de_prefijo(self):
        # Sin la barra, `src` matchearía `srcnuevo/x.gd`. Con ella, no.
        self.assertFalse(viola("src/", "srcnuevo/x.gd"))

    def test_una_ruta_con_barra_es_exacta(self):
        self.assertTrue(viola("src/dominio/reglas.gd", "src/dominio/reglas.gd"))
        self.assertFalse(viola("src/dominio/reglas.gd", "src/ui/reglas.gd"))

    def test_un_nombre_pelado_matchea_en_cualquier_carpeta(self):
        # Es la forma que usan el 006, el 008, el 016, el 017 y el 033. Leerla como ruta
        # exacta las volvería inofensivas sin decirlo.
        self.assertTrue(viola("reglas.gd", "src/dominio/reglas.gd"))
        self.assertTrue(viola("almacen.tscn", "src/escenas/almacen.tscn"))

    def test_un_nombre_pelado_no_matchea_un_sufijo_de_otro_nombre(self):
        # `reglas.gd` no puede cazar a `reglas_del_jugador.gd`: son dos archivos distintos y
        # el plan del 006 los nombra por separado.
        self.assertFalse(viola("reglas.gd", "src/dominio/reglas_del_jugador.gd"))

    def test_las_barras_de_windows_no_cambian_el_veredicto(self):
        self.assertTrue(viola("src/", "src\\dominio\\reglas.gd"))


class RutasVioladas(unittest.TestCase):
    def test_devuelve_el_par_para_que_el_rojo_sea_accionable(self):
        self.assertEqual(
            rutas_violadas(["src/"], ["src/dominio/reglas.gd", "docs/x.md"]),
            [("src/dominio/reglas.gd", "src/")],
        )

    def test_sin_rutas_declaradas_no_hay_violacion(self):
        # 11 de los 24 specs abiertos sólo declaran invariantes: una lista vacía es un estado
        # normal, no un spec mal escrito.
        self.assertEqual(rutas_violadas([], ["src/dominio/reglas.gd"]), [])

    def test_un_archivo_puede_violar_dos_rutas_y_las_dos_se_nombran(self):
        self.assertEqual(
            rutas_violadas(["src/", "reglas.gd"], ["src/dominio/reglas.gd"]),
            [("src/dominio/reglas.gd", "src/"), ("src/dominio/reglas.gd", "reglas.gd")],
        )
