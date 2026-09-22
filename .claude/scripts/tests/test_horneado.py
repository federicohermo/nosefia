"""Los tests de `lib/horneado.py`: cómo se prende el plugin y qué cuenta como horneado."""

import unittest

from lib.horneado import PLUGIN, project_con_el_plugin, veredicto

PROJECT = (
    "config_version=5\n\n[editor_plugins]\n\n"
    'enabled=PackedStringArray("res://addons/gdUnit4/plugin.cfg", "res://addons/otro/plugin.cfg")\n\n'
    "[filesystem]\n\nimport/blender/enabled=false\n"
)


class ProjectConElPlugin(unittest.TestCase):
    def test_reemplaza_la_lista_por_el_plugin_solo(self):
        texto = project_con_el_plugin(PROJECT)
        self.assertIn('enabled=PackedStringArray("%s")' % PLUGIN, texto)
        self.assertNotIn("gdUnit4", texto)
        # El resto del archivo no se toca.
        self.assertIn("import/blender/enabled=false", texto)

    def test_sin_lista_previa_la_agrega(self):
        texto = project_con_el_plugin("config_version=5\n")
        self.assertIn("[editor_plugins]", texto)
        self.assertIn(PLUGIN, texto)


class Veredicto(unittest.TestCase):
    def test_un_editor_que_cerro_con_error_no_horneo(self):
        ok, motivo = veredicto(1, {"a.lmbake": True, "a.exr": True})
        self.assertFalse(ok)
        self.assertIn("código 1", motivo)

    def test_un_editor_que_cerro_bien_sin_escribir_tampoco(self):
        # Un editor cerrado a mano devuelve cero igual que uno que horneó.
        ok, motivo = veredicto(0, {"a.lmbake": True, "a.exr": False})
        self.assertFalse(ok)
        self.assertIn("a.exr", motivo)

    def test_las_dos_salidas_escritas_es_un_horneado(self):
        ok, _ = veredicto(0, {"a.lmbake": True, "a.exr": True})
        self.assertTrue(ok)
