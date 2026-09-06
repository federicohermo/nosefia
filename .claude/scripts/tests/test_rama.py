"""Las reglas puras de `lib/rama.py`: qué cuenta como violar una ruta declarada.

Lo de I/O —git, `gh`— no se sondea acá: se ejerce en los dos gates que lo usan, y ahí un
salteo se declara. Lo que sí tiene que estar cubierto es lo que decide el rojo, porque un
`viola()` demasiado laxo pone en rojo un PR correcto y uno demasiado estricto deja pasar
justo lo que el plan prohibía.
"""

import os
import unittest

from lib.rama import rama_actual, rutas_violadas, spec_de_la_rama, viola


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

    def test_un_directorio_sin_la_barra_igual_protege(self):
        # Es el caso que se apagaba callado: `src` leído como nombre de archivo no matchea
        # NADA —ningún archivo se llama `src`— así que la restricción existía en el plan y no
        # protegía nada, sin decirlo. Lo que separa un directorio de un nombre es la
        # extensión, no la barra: la barra es la forma canónica, no la única que se escribe.
        self.assertTrue(viola("src", "src/dominio/reglas.gd"))
        self.assertFalse(viola("src", "srcnuevo/x.gd"))
        self.assertTrue(viola("src/dominio", "src/dominio/reglas.gd"))

    def test_un_nombre_con_extension_sigue_siendo_un_nombre(self):
        # La contracara: `reglas.gd` NO se vuelve directorio, o dejaría de matchear en
        # cualquier carpeta, que es la forma que usan el 006, el 008, el 016, el 017 y el 033.
        self.assertTrue(viola("reglas.gd", "src/dominio/reglas.gd"))
        self.assertFalse(viola("reglas.gd", "reglas.gd/x.py"))

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


class QueSpecNombraLaRama(unittest.TestCase):
    """Lo que decide si los dos gates miran o se saltean, sobre el camino que sí se puede fijar.

    **Es la mitad que faltaba.** Los dos gates que usan esto se saltean enteros cuando la rama
    no nombra un spec —una `chore/` o una `fix/`—, así que en un PR de ésos ninguno de los dos
    llega a ejercer nada y los tres casos salen `skipped`. Medido en el PR 59, que es el que
    los trajo: sus tres casos se saltearon y el I/O de `lib/rama.py` no lo corrió nadie.

    `GITHUB_HEAD_REF` es la rendija por la que se puede sondear sin fabricar un repo: es el
    mismo camino que la Action usa, y tiene prioridad sobre `git` a propósito —en un
    `pull_request`, `HEAD` es el merge de prueba y `rev-parse` contesta `HEAD` pelado—.
    """

    def setUp(self):
        self.previo = os.environ.get("GITHUB_HEAD_REF")
        self.addCleanup(self._restaurar)

    def _restaurar(self):
        if self.previo is None:
            os.environ.pop("GITHUB_HEAD_REF", None)
        else:
            os.environ["GITHUB_HEAD_REF"] = self.previo
        spec_de_la_rama.cache_clear()

    def _sobre(self, rama: str):
        os.environ["GITHUB_HEAD_REF"] = rama
        # El `lru_cache` es de la corrida real, donde la rama no cambia. Acá sí cambia, y sin
        # limpiarlo el segundo caso mediría el primero — en verde.
        spec_de_la_rama.cache_clear()
        return spec_de_la_rama()

    def test_el_prefijo_esta_abierto(self):
        # `fix/` y `chore/` también nombran un spec: el gate no es sólo de las features.
        self.assertEqual(self._sobre("feature/031-la-jornada-dura-diez-minutos"), "031")
        self.assertEqual(self._sobre("fix/007-el-reloj-atrasa"), "007")
        self.assertEqual(self._sobre("chore/012-la-pureza"), "012")

    def test_una_rama_que_no_nombra_un_spec_saltea_los_dos_gates(self):
        # Devolver `None` es lo que dispara el salteo declarado. Que sea `None` y no `""`
        # importa: un `""` cae en el `if` de `archivo_del_spec` y saldría a buscar el spec 0.
        self.assertIsNone(self._sobre("chore/el-regimen-de-specs-se-unifica"))
        self.assertIsNone(self._sobre("staging"))

    def test_el_entorno_de_la_action_le_gana_a_git(self):
        # En un `pull_request` de GitHub Actions `HEAD` es el merge de prueba y `rev-parse`
        # contesta `HEAD` pelado. Sin esta prioridad los dos gates se saltearían siempre, y
        # justo en el único lugar donde tienen que correr.
        os.environ["GITHUB_HEAD_REF"] = "feature/033-la-caja-de-traslado"
        self.assertEqual(rama_actual(), "feature/033-la-caja-de-traslado")
        del os.environ["GITHUB_HEAD_REF"]
        self.assertNotEqual(rama_actual(), "feature/033-la-caja-de-traslado")

    def test_el_numero_sale_del_prefijo_y_no_de_cualquier_parte_del_nombre(self):
        # `feature/la-caja-lleva-008-productos` no es el spec 008.
        self.assertIsNone(self._sobre("feature/la-caja-lleva-008-productos"))
