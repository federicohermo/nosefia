"""Los tests de `lib/blender.py`.

Se prueba que **no** esté Blender en una máquina que sí lo tiene, que es el caso que importa: el
mensaje de «no se encontró» es lo único que ve quien clona el repo, y un mensaje sin la salida
escrita produce el reflejo de buscar cómo saltear el paso.
"""

import unittest

from lib.blender import SERIE, VARIABLE, como_declararlo, es_un_array, resolver


class Resolver(unittest.TestCase):
    def test_la_variable_gana_sobre_la_instalacion(self):
        # Quien la declaró eligió una versión. Que el instalador haya dejado otra en su lugar
        # de siempre no puede pisar esa elección.
        binario, origen = resolver(
            {VARIABLE: "C:/elegido/blender.exe"},
            existe=lambda ruta: True,
            ubicaciones=("C:/instalado/blender.exe",),
        )
        self.assertEqual((binario, origen), ("C:/elegido/blender.exe", VARIABLE))

    def test_sin_variable_cae_en_la_instalacion(self):
        binario, origen = resolver(
            {}, existe=lambda ruta: ruta == "C:/instalado/blender.exe",
            ubicaciones=("C:/otro/blender.exe", "C:/instalado/blender.exe"),
        )
        self.assertEqual((binario, origen), ("C:/instalado/blender.exe", "instalación"))

    def test_una_variable_que_apunta_a_la_nada_no_se_usa(self):
        binario, _ = resolver(
            {VARIABLE: "C:/borrado/blender.exe"}, existe=lambda ruta: False, ubicaciones=()
        )
        self.assertIsNone(binario)

    def test_sin_nada_contesta_que_no_hay(self):
        self.assertEqual(resolver({}, existe=lambda ruta: False, ubicaciones=()), (None, None))


class ElMensaje(unittest.TestCase):
    def test_sin_declarar_dice_como_declararlo_y_que_hay_que_abrir_otra_terminal(self):
        mensaje = como_declararlo({})
        self.assertIn(f"setx {VARIABLE}", mensaje)
        self.assertIn(SERIE, mensaje)
        # La trampa de Windows, que ya costó una tarde con `GODOT_BIN`.
        self.assertIn("terminal nueva", mensaje)

    def test_declarada_y_rota_lo_dice_con_la_ruta(self):
        mensaje = como_declararlo({VARIABLE: "C:/borrado/blender.exe"})
        self.assertIn("C:/borrado/blender.exe", mensaje)
        self.assertIn("no existe", mensaje)


class ElModificadorQueSeApaga(unittest.TestCase):
    """Qué nombre cuenta como uno de los que llenan el estante.

    La comparación exacta contra `Array` dejaba prendidos los 34 `Array.001` del `.blend`, y el
    producto salía al doble o al cuádruple de vértices. El síntoma no nombra ni a Blender ni al
    modificador: aparece como dos productos vecinos que se pisan.
    """

    def test_el_nombre_pelado_cuenta(self):
        self.assertTrue(es_un_array("Array"))

    def test_el_sufijo_que_agrega_blender_al_duplicar_tambien(self):
        for nombre in ("Array.001", "Array.002", "Array.014"):
            with self.subTest(nombre=nombre):
                self.assertTrue(es_un_array(nombre))

    def test_otro_modificador_que_empieza_igual_no_cuenta(self):
        # `Smooth by Angle` está en el mismo `.blend` y tiene que quedar prendido. Y un nombre
        # que apenas comparte el prefijo no es un duplicado: el sufijo de Blender lleva punto.
        for nombre in ("Smooth by Angle", "Arrayado", "ArrayDeVerdad"):
            with self.subTest(nombre=nombre):
                self.assertFalse(es_un_array(nombre))


if __name__ == "__main__":
    unittest.main()
