"""Los tests del servidor MCP.

Lo que hay que cuidar de un servidor de stdio es que **no se caiga y no ensucie el canal**: un
`raise` mata la sesión entera del cliente, y cualquier cosa que no sea un mensaje en `stdout`
rompe el protocolo. El síntoma de los dos es el mismo y no nombra la causa: «el servidor no
conecta».
"""

import io
import json
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from lib.repo import RAIZ

sys.path.insert(0, str(RAIZ / "mcp-server"))

import herramientas  # noqa: E402
import servidor  # noqa: E402


class ElProtocolo(unittest.TestCase):
    def test_initialize_contesta_la_version_y_sus_capacidades(self):
        r = servidor.responder({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
        self.assertEqual(r["result"]["protocolVersion"], servidor.VERSION_DEL_PROTOCOLO)
        self.assertIn("tools", r["result"]["capabilities"])
        self.assertEqual(r["result"]["serverInfo"]["name"], servidor.NOMBRE)

    def test_una_notificacion_no_lleva_respuesta(self):
        # Sin `id` no hay a qué contestar, y contestar igual le mete ruido al canal.
        self.assertIsNone(servidor.responder({"jsonrpc": "2.0", "method": "notifications/initialized"}))

    def test_un_metodo_desconocido_contesta_error_y_no_revienta(self):
        r = servidor.responder({"jsonrpc": "2.0", "id": 9, "method": "vuela"})
        self.assertEqual(r["error"]["code"], -32601)
        self.assertIn("vuela", r["error"]["message"])

    def test_tools_list_publica_todas_y_sin_el_cableado(self):
        r = servidor.responder({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        publicadas = r["result"]["tools"]
        self.assertEqual(len(publicadas), len(servidor.TOOLS))
        for tool in publicadas:
            # `fn` es nuestro y no se serializa: un callable adentro del JSON lo rompe.
            self.assertNotIn("fn", tool)

    def test_una_herramienta_que_falla_se_contesta_y_no_propaga(self):
        # Un `raise` acá mata el servidor y se lleva la sesión del cliente.
        servidor._POR_NOMBRE["explota"] = {"name": "explota", "fn": lambda a: 1 / 0}
        try:
            texto, fallo = servidor.ejecutar("explota", {})
        finally:
            del servidor._POR_NOMBRE["explota"]
        self.assertTrue(fallo)
        self.assertIn("ZeroDivisionError", texto)

    def test_una_herramienta_que_no_existe_nombra_las_que_si(self):
        texto, fallo = servidor.ejecutar("inventada", {})
        self.assertTrue(fallo)
        self.assertIn("mapa_del_sistema", texto)

    def test_responder_no_escribe_en_stdout(self):
        # `stdout` es sólo del protocolo, y el bucle es el único que escribe ahí.
        salida = io.StringIO()
        with redirect_stdout(salida):
            servidor.responder(
                {
                    "jsonrpc": "2.0",
                    "id": 3,
                    "method": "tools/call",
                    "params": {"name": "mapa_del_sistema", "arguments": {}},
                }
            )
        self.assertEqual(salida.getvalue(), "")


class LosEsquemas(unittest.TestCase):
    def test_cada_tool_declara_nombre_descripcion_y_esquema(self):
        for tool in servidor.TOOLS:
            with self.subTest(tool=tool.get("name")):
                self.assertTrue(tool["name"])
                self.assertGreater(len(tool["description"]), 40, "la descripción no dice nada")
                self.assertEqual(tool["inputSchema"]["type"], "object")

    def test_todo_campo_requerido_esta_declarado_en_properties(self):
        # Un `required` que nombra algo que no está en `properties` hace que el cliente arme una
        # llamada que la herramienta no puede leer.
        for tool in servidor.TOOLS:
            esquema = tool["inputSchema"]
            for campo in esquema.get("required", []):
                with self.subTest(tool=tool["name"], campo=campo):
                    self.assertIn(campo, esquema["properties"])

    def test_el_json_de_las_tools_es_serializable(self):
        json.dumps(servidor._publicas())


class LasMenciones(unittest.TestCase):
    def test_un_comentario_no_es_un_uso(self):
        archivos = {"x.gd": "## Lo llama `Turno`\nvar a := 1\n"}
        self.assertEqual(herramientas._menciones("Turno", archivos), [])

    def test_pero_una_cita_de_criterio_vive_en_un_comentario(self):
        # El primer humo de este servidor contestó «ningún test lo cita» sobre un criterio citado.
        archivos = {"x_test.gd": "func test_algo() -> void:  # AC-EMP-004\n"}
        self.assertEqual(herramientas._menciones("AC-EMP-004", archivos), [])
        self.assertEqual(
            herramientas._menciones("AC-EMP-004", archivos, limpiar=False), [("x_test.gd", 1)]
        )

    def test_un_nombre_que_es_prefijo_de_otro_no_matchea(self):
        archivos = {"x.gd": "var t: TareaDeAtender\n"}
        self.assertEqual(herramientas._menciones("Tarea", archivos), [])


class LaLecturaDeEscenas(unittest.TestCase):
    ESCENA = (
        '[gd_scene format=3]\n'
        '[ext_resource type="Script" path="res://src/escenas/x.gd" id="1"]\n'
        '[ext_resource type="PackedScene" path="res://src/escenas/y.tscn" id="2"]\n'
        '[node name="Raiz" type="Node3D" node_paths=PackedStringArray("_hud", "_reloj")]\n'
    )

    def test_saca_scripts_instancias_y_node_paths(self):
        recursos = herramientas._EXT_RESOURCE.findall(self.ESCENA)
        self.assertIn(("Script", "res://src/escenas/x.gd"), recursos)
        self.assertIn(("PackedScene", "res://src/escenas/y.tscn"), recursos)
        crudo = herramientas._NODE_PATHS.findall(self.ESCENA)[0]
        nombres = [n.strip().strip('"') for n in crudo.split(",")]
        self.assertEqual(nombres, ["_hud", "_reloj"])

    def test_las_escenas_llegan_con_su_contenido(self):
        # `escenas_tscn()` las devuelve con el texto vacío a propósito; este servidor las relee.
        escenas = herramientas._escenas()
        if not escenas:
            self.skipTest("no hay `.tscn` en `src/`")
        self.assertTrue(any(texto.strip() for texto in escenas.values()))


class LasRespuestasVacias(unittest.TestCase):
    def test_un_simbolo_inexistente_lo_dice_y_no_miente(self):
        self.assertIn("no existe", herramientas.quien_usa("EsteSimboloNoExiste"))

    def test_una_ruta_inexistente_lo_dice(self):
        self.assertIn("No hay", herramientas.contexto_de_archivo("src/dominio/inventado.gd"))

    def test_un_criterio_inexistente_dice_la_forma_del_id(self):
        self.assertIn("AC-<COD>-###", herramientas.criterio("AC-ZZZ-999"))


if __name__ == "__main__":
    unittest.main()
