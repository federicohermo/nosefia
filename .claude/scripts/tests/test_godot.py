"""Los tests de `lib/godot.py`: encontrar el ejecutable, o decir cómo se declara."""

import unittest

from lib.godot import como_declararlo, resolver


class Resolver(unittest.TestCase):
    def test_godot_bin_gana_sobre_el_path(self):
        # En una máquina con varias versiones bajadas, la que vale es la que el repo declara y
        # no la que quedó primera en el PATH.
        elegido = resolver(
            {"GODOT_BIN": "/declarado/godot"},
            en_el_path=lambda n: "/del/path/godot",
            existe=lambda r: True,
        )
        self.assertEqual(elegido, "/declarado/godot")

    def test_cae_al_path_si_no_esta_declarado(self):
        elegido = resolver({}, en_el_path=lambda n: "/del/path/godot" if n == "godot" else None,
                           existe=lambda r: True)
        self.assertEqual(elegido, "/del/path/godot")

    def test_un_godot_bin_que_apunta_a_la_nada_no_cae_al_path(self):
        # Es el caso de una ruta que se movió. Confundirlo con «no está declarado» manda a
        # escribir de nuevo lo que ya estaba escrito, y el mensaje lo distingue.
        elegido = resolver(
            {"GODOT_BIN": "/se/movio/godot"},
            en_el_path=lambda n: "/del/path/godot",
            existe=lambda r: False,
        )
        self.assertIsNone(elegido)

    def test_saca_las_comillas_de_la_variable(self):
        # En Windows es normal que la variable quede guardada con comillas.
        elegido = resolver({"GODOT_BIN": '"/con/comillas/godot"'}, existe=lambda r: True)
        self.assertEqual(elegido, "/con/comillas/godot")

    def test_sin_nada_devuelve_none(self):
        self.assertIsNone(resolver({}, en_el_path=lambda n: None, existe=lambda r: False))


class ComoDeclararlo(unittest.TestCase):
    def test_sin_la_variable_dice_como_declararla(self):
        mensaje = como_declararlo({})
        self.assertIn("GODOT_BIN", mensaje)
        self.assertIn("SetEnvironmentVariable", mensaje)

    def test_con_la_variable_rota_dice_que_se_movio(self):
        mensaje = como_declararlo({"GODOT_BIN": "/se/movio/godot"})
        self.assertIn("/se/movio/godot", mensaje)
        self.assertIn("no existe", mensaje)

    def test_avisa_de_onedrive(self):
        # No es un detalle de color: es el estado en el que está la máquina donde se escribió
        # este harness. Un `.exe` que vive en OneDrive sin descargar se rechaza con «el
        # proveedor de archivos de nube no se está ejecutando», y ese mensaje no dice nada de
        # Godot ni de los tests.
        self.assertIn("OneDrive", como_declararlo({}))


if __name__ == "__main__":
    unittest.main()
