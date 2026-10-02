"""Los tests de `lib/horneado.py`: cómo se prende el plugin y qué cuenta como horneado."""

import unittest

from lib.horneado import (
    PLUGIN,
    SALIDAS,
    project_con_el_plugin,
    reescritos_de_mas,
    sesion_bloqueada,
    tope_en_segundos,
    veredicto,
)

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


class SesionBloqueada(unittest.TestCase):
    # Con la sesión de Windows bloqueada el editor no dibuja, no aprieta el botón y el horneado
    # espera el tope entero sin decir por qué.
    def test_la_pantalla_de_bloqueo_corriendo_es_una_sesion_bloqueada(self):
        procesos = '"explorer.exe","1","Console"\n"LogonUI.exe","2","Console"\n'
        self.assertTrue(sesion_bloqueada(procesos))

    def test_sin_la_pantalla_de_bloqueo_la_sesion_esta_abierta(self):
        self.assertFalse(sesion_bloqueada('"explorer.exe","1","Console"\n'))


class ReescritosDeMas(unittest.TestCase):
    # El editor guarda la escena para escribir el horneado, y al guardar re-serializa más de lo
    # que el horneado cambió. Medido el 2026-09-29: además de las dos salidas, dejó `almacen.tscn`
    # con 94 overrides de `transform` iguales a los de la estructura, y reescritos `tema.tres` y
    # `caja_de_reposicion.tres`.
    def test_las_salidas_del_horneado_no_se_devuelven(self):
        self.assertEqual(reescritos_de_mas(list(SALIDAS)), [])

    def test_lo_que_el_editor_re_serializo_se_devuelve(self):
        escritos = [
            *SALIDAS,
            "src/escenas/almacen.tscn",
            "assets/ui/manada/tema.tres",
            "src/dominio/almacen/caja_de_reposicion.tres",
        ]
        self.assertEqual(
            reescritos_de_mas(escritos),
            [
                "assets/ui/manada/tema.tres",
                "src/dominio/almacen/caja_de_reposicion.tres",
                "src/escenas/almacen.tscn",
            ],
        )

    def test_project_godot_lo_devuelve_el_script_byte_por_byte(self):
        # Ya lo restaura `hornear.py` con el contenido de antes: devolverlo acá otra vez lo
        # pisaría con el de git, y un `project.godot` con cambios sin commitear los perdería.
        self.assertEqual(reescritos_de_mas(["project.godot"]), [])


class TopeDelHorneado(unittest.TestCase):
    # Con GPU el local se hornea en segundos; con el Vulkan por software de Mesa, medido el
    # 2026-09-29, en 9 minutos con la máquina libre y en 17,7 con otros procesos corriendo. Un
    # tope de 20 minutos confundía una máquina ocupada con un editor colgado.
    def test_con_gpu_el_tope_es_el_de_siempre(self):
        self.assertEqual(tope_en_segundos({}), 20 * 60)

    def test_con_vulkan_por_software_el_tope_se_estira(self):
        entorno = {"VK_ICD_FILENAMES": "/usr/share/vulkan/icd.d/lvp_icd.json"}
        self.assertGreater(tope_en_segundos(entorno), 2 * 17.7 * 60)

    def test_otro_driver_declarado_no_es_software(self):
        entorno = {"VK_ICD_FILENAMES": "/usr/share/vulkan/icd.d/radeon_icd.json"}
        self.assertEqual(tope_en_segundos(entorno), 20 * 60)
