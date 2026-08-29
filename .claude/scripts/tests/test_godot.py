"""Los tests de `lib/godot.py`: encontrar el ejecutable, o decir cómo se declara.

El lector del registro se inyecta, así que las tres fuentes —entorno, registro, PATH— se
ejercen en las tres plataformas y sin tocar el registro de la máquina que corre los tests.
"""

import unittest

from lib.godot import ENTORNO, PATH, REGISTRO, aviso_de_entorno_viejo, como_declararlo, resolver


def nada() -> None:
    """El doble de `del_registro`: no hay nada declarado en el registro."""
    return None


def nada_en_el_path(_nombre: str) -> None:
    """El doble de `en_el_path`. Toma un argumento: por eso no puede ser el mismo doble."""
    return None


class Resolver(unittest.TestCase):
    def test_el_entorno_gana_sobre_el_registro_y_el_path(self):
        # Es lo que alguien puso PARA ESTA CORRIDA: un `GODOT_BIN=… python verificar.py` para
        # probar otra versión tiene que ganarle a la declaración persistente.
        ruta, origen = resolver(
            {"GODOT_BIN": "/del/entorno/godot"},
            en_el_path=lambda n: "/del/path/godot",
            existe=lambda r: True,
            del_registro=lambda: "/del/registro/godot",
        )
        self.assertEqual((ruta, origen), ("/del/entorno/godot", ENTORNO))

    def test_sin_entorno_cae_al_registro(self):
        # ÉSTE es el caso que justifica el módulo entero. En Windows un proceso hereda el
        # entorno de su padre y no lo lee del registro, así que una terminal abierta antes de
        # declarar la variable no la ve NUNCA — ni ella ni nada de lo que lance.
        ruta, origen = resolver(
            {},
            en_el_path=lambda n: "/del/path/godot",
            existe=lambda r: True,
            del_registro=lambda: "/del/registro/godot",
        )
        self.assertEqual((ruta, origen), ("/del/registro/godot", REGISTRO))

    def test_sin_entorno_ni_registro_cae_al_path(self):
        ruta, origen = resolver(
            {},
            en_el_path=lambda n: "/del/path/godot" if n == "godot" else None,
            existe=lambda r: True,
            del_registro=nada,
        )
        self.assertEqual((ruta, origen), ("/del/path/godot", PATH))

    def test_un_valor_declarado_que_apunta_a_la_nada_no_cae_al_siguiente(self):
        # Es el caso de una ruta que se movió. Caer al PATH taparía el error y correría los
        # tests con OTRA versión de Godot que la declarada, en verde.
        self.assertEqual(
            resolver(
                {"GODOT_BIN": "/se/movio/godot"},
                en_el_path=lambda n: "/del/path/godot",
                existe=lambda r: False,
                del_registro=lambda: "/del/registro/godot",
            ),
            (None, None),
        )

    def test_un_registro_que_apunta_a_la_nada_tampoco(self):
        self.assertEqual(
            resolver({}, en_el_path=lambda n: "/del/path/godot", existe=lambda r: False,
                     del_registro=lambda: "/se/movio/godot"),
            (None, None),
        )

    def test_saca_las_comillas_y_los_espacios(self):
        # En Windows es normal que la variable quede guardada con comillas.
        ruta, _ = resolver({"GODOT_BIN": ' "/con/comillas/godot" '}, existe=lambda r: True,
                           del_registro=nada)
        self.assertEqual(ruta, "/con/comillas/godot")

    def test_una_variable_vacia_no_cuenta_como_declarada(self):
        # `GODOT_BIN=` en el entorno es lo mismo que no tenerla: sin esto se leería como una
        # ruta declarada que no existe, y el mensaje diría «se movió el ejecutable».
        ruta, origen = resolver({"GODOT_BIN": "   "}, en_el_path=nada_en_el_path, existe=lambda r: True,
                                del_registro=lambda: "/del/registro/godot")
        self.assertEqual((ruta, origen), ("/del/registro/godot", REGISTRO))

    def test_sin_nada_devuelve_none(self):
        self.assertEqual(
            resolver({}, en_el_path=nada_en_el_path, existe=lambda r: False, del_registro=nada), (None, None)
        )


class ComoDeclararlo(unittest.TestCase):
    def test_sin_la_variable_dice_como_declararla(self):
        mensaje = como_declararlo({}, del_registro=nada)
        self.assertIn("GODOT_BIN", mensaje)
        self.assertIn("SetEnvironmentVariable", mensaje)

    def test_con_la_variable_rota_dice_que_se_movio(self):
        mensaje = como_declararlo({"GODOT_BIN": "/se/movio/godot"}, del_registro=nada)
        self.assertIn("/se/movio/godot", mensaje)
        self.assertIn("no existe", mensaje)

    def test_tambien_mira_el_registro_para_decidir_el_mensaje(self):
        # Si la declaración está sólo en el registro y apunta a la nada, el mensaje útil sigue
        # siendo «se movió», no «declarala».
        mensaje = como_declararlo({}, del_registro=lambda: "/se/movio/godot")
        self.assertIn("no existe", mensaje)

    def test_avisa_de_onedrive(self):
        # No es un detalle de color: es el estado en el que estaba la máquina donde se escribió
        # este harness. Un `.exe` que vive en OneDrive sin descargar se rechaza con «el proveedor
        # de archivos de nube no se está ejecutando», y ese mensaje no dice nada de Godot.
        self.assertIn("OneDrive", como_declararlo({}, del_registro=nada))


class AvisoDeEntornoViejo(unittest.TestCase):
    def test_avisa_cuando_salio_del_registro(self):
        aviso = aviso_de_entorno_viejo(REGISTRO)
        self.assertIn("no está en el entorno de esta terminal", aviso)

    def test_no_avisa_cuando_salio_del_entorno(self):
        # Un aviso que aparece siempre deja de leerse.
        self.assertIsNone(aviso_de_entorno_viejo(ENTORNO))

    def test_no_avisa_cuando_salio_del_path(self):
        self.assertIsNone(aviso_de_entorno_viejo(PATH))


if __name__ == "__main__":
    unittest.main()
