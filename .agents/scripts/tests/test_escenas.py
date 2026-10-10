"""El gate del `@export` que llega en `null`.

La falla que cierra es la única conocida acá que **deja los siete nodos en verde y mata el juego
en el primer cuadro**: `Invalid call. Nonexistent function 'x' in base 'Nil'`, un mensaje que no
nombra ni al `.tscn` ni al `@export`.

El editor de Godot escribe la lista `node_paths` solo. Una escena editada a mano, no — y este
repo edita escenas a mano, porque un `.tscn` no se mergea y hay que mirarlas de todos modos.
"""

import unittest

from lib.archivos import scripts_gd
from lib.escenas import exports_sin_declarar
from lib.repo import RAIZ

ESCENAS = "src"

SCRIPT = """extends Node3D
@export var _hud: Hud
@export var _ruta: NodePath
"""

SIN_LISTA = """[gd_scene format=3]
[ext_resource type="Script" path="res://src/escenas/x.gd" id="1"]
[node name="Raiz" type="Node3D"]
script = ExtResource("1")
_hud = NodePath("Interfaz/Hud")
"""

CON_LISTA = SIN_LISTA.replace(
    '[node name="Raiz" type="Node3D"]',
    '[node name="Raiz" type="Node3D" node_paths=PackedStringArray("_hud")]',
)

FUENTES = {"src/escenas/x.gd": SCRIPT}


class LaDeteccion(unittest.TestCase):
    def test_un_nodepath_asignado_sin_la_lista_es_un_hallazgo(self):
        self.assertEqual(
            exports_sin_declarar({"src/escenas/x.tscn": SIN_LISTA}, FUENTES),
            [("src/escenas/x.tscn", "Raiz", "_hud")],
        )

    def test_con_la_lista_no_hay_nada(self):
        self.assertEqual(exports_sin_declarar({"src/escenas/x.tscn": CON_LISTA}, FUENTES), [])

    def test_un_export_declarado_nodepath_no_necesita_la_lista(self):
        # Ahí la ruta **es** el valor: no hay nada que resolver, y pedirle la lista sería un
        # falso positivo que enseña a ignorar el gate.
        escena = SIN_LISTA.replace(
            '_hud = NodePath("Interfaz/Hud")', '_ruta = NodePath("Interfaz/Hud")'
        )
        self.assertEqual(exports_sin_declarar({"src/escenas/x.tscn": escena}, FUENTES), [])

    def test_una_propiedad_que_la_escena_no_asigna_no_se_reclama(self):
        # Se resuelve por código, y exigirla obligaría a listar exports que la escena no usa.
        escena = SIN_LISTA.replace('_hud = NodePath("Interfaz/Hud")\n', "")
        self.assertEqual(exports_sin_declarar({"src/escenas/x.tscn": escena}, FUENTES), [])

    def test_un_nodo_sin_script_no_se_mira(self):
        escena = SIN_LISTA.replace('script = ExtResource("1")\n', "")
        self.assertEqual(exports_sin_declarar({"src/escenas/x.tscn": escena}, FUENTES), [])


class ElRepo(unittest.TestCase):
    def test_ninguna_escena_deja_un_export_sin_resolver(self):
        escenas = {
            p.relative_to(RAIZ).as_posix(): p.read_text(encoding="utf-8")
            for p in (RAIZ / ESCENAS).rglob("*.tscn")
        }
        if not escenas:
            self.skipTest("no hay `.tscn`")
        hallazgos = exports_sin_declarar(escenas, scripts_gd(RAIZ, ESCENAS))
        self.assertEqual(
            hallazgos,
            [],
            "el `@export` va a llegar en `null` y el juego muere en el primer cuadro. Va la "
            'lista en el `[node]`: `node_paths=PackedStringArray("_x", "_y")`.',
        )


if __name__ == "__main__":
    unittest.main()
