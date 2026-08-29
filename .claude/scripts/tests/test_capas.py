"""Los tests de `lib/capas.py`: la dirección de dependencia entre las capas de `src/`.

Los archivos se escriben a mano acá adentro. Recibir `ruta → texto` en vez de leer el disco
es lo que permite que los casos que importan —una referencia adentro de un comentario, un
`class_name` que además es una palabra común— entren en cuatro líneas.
"""

import ntpath
import unittest

from lib.capas import capa_de, indice_de_class_names, violaciones

CAPAS = (
    ("src/dominio", ()),
    ("src/sistemas", ("src/dominio",)),
    ("src/ui", ("src/dominio", "src/sistemas")),
)


class CapaDe(unittest.TestCase):
    def test_reconoce_la_capa(self):
        self.assertEqual(capa_de("src/dominio/turno.gd", CAPAS), "src/dominio")

    def test_lo_que_no_esta_en_ninguna_capa_es_none(self):
        self.assertIsNone(capa_de("addons/gdUnit4/plugin.gd", CAPAS))

    def test_normaliza_las_barras_de_windows(self):
        # Sin normalizar, en Windows NINGUNA ruta cae en ninguna capa y el gate pasa siempre,
        # en verde. Es el bug más caro que puede tener un gate: el que no se ve.
        self.assertEqual(capa_de(ntpath.join("src", "dominio", "turno.gd"), CAPAS), "src/dominio")


class PorRuta(unittest.TestCase):
    def test_el_dominio_no_puede_preloadear_la_ui(self):
        archivos = {
            "src/dominio/turno.gd": 'const Hud = preload("res://src/ui/hud.gd")\n',
            "src/ui/hud.gd": "extends Control\n",
        }
        hallazgos = violaciones(archivos, CAPAS)
        self.assertEqual(len(hallazgos), 1)
        ruta, linea, origen, destino, _ = hallazgos[0]
        self.assertEqual((ruta, linea, origen, destino), ("src/dominio/turno.gd", 1, "src/dominio",
                                                          "src/ui"))

    def test_la_ui_si_puede_preloadear_el_dominio(self):
        archivos = {
            "src/ui/hud.gd": 'const Turno = preload("res://src/dominio/turno.gd")\n',
            "src/dominio/turno.gd": "extends RefCounted\n",
        }
        self.assertEqual(violaciones(archivos, CAPAS), [])

    def test_tambien_mira_load(self):
        archivos = {"src/dominio/turno.gd": 'var h = load("res://src/ui/hud.gd")\n'}
        self.assertEqual(len(violaciones(archivos, CAPAS)), 1)

    def test_tambien_mira_extends_por_ruta(self):
        archivos = {"src/dominio/turno.gd": 'extends "res://src/ui/hud.gd"\n'}
        self.assertEqual(len(violaciones(archivos, CAPAS)), 1)

    def test_una_referencia_dentro_de_la_misma_capa_no_es_violacion(self):
        archivos = {"src/dominio/turno.gd": 'const T = preload("res://src/dominio/tarea.gd")\n'}
        self.assertEqual(violaciones(archivos, CAPAS), [])

    def test_una_referencia_a_algo_que_no_es_capa_se_ignora(self):
        # `addons/` y los recursos no participan de la regla.
        archivos = {"src/dominio/turno.gd": 'const X = preload("res://addons/gdUnit4/src/X.gd")\n'}
        self.assertEqual(violaciones(archivos, CAPAS), [])


class PorClassName(unittest.TestCase):
    def test_indexa_los_class_name_de_src(self):
        archivos = {"src/ui/hud.gd": "class_name Hud\nextends Control\n"}
        self.assertEqual(indice_de_class_names(archivos, CAPAS), {"Hud": "src/ui"})

    def test_no_indexa_los_de_afuera_de_src(self):
        archivos = {"test/dominio/turno_test.gd": "class_name TurnoTest\n"}
        self.assertEqual(indice_de_class_names(archivos, CAPAS), {})

    def test_el_dominio_no_puede_nombrar_una_clase_de_la_ui(self):
        # Ésta es la puerta que ningún análisis de imports encuentra: no hay una sola ruta
        # escrita, y en Godot es la forma NORMAL de escribir código.
        archivos = {
            "src/ui/hud.gd": "class_name Hud\nextends Control\n",
            "src/dominio/turno.gd": "extends RefCounted\n\nfunc pintar(h: Hud) -> void:\n\tpass\n",
        }
        hallazgos = violaciones(archivos, CAPAS)
        self.assertEqual(len(hallazgos), 1)
        self.assertEqual(hallazgos[0][3], "src/ui")

    def test_un_class_name_nombrado_en_un_comentario_no_cuenta(self):
        # Un gate con falsos positivos se apaga: la única salida que le queda a quien lo sufre
        # es sacarlo del `verify`.
        archivos = {
            "src/ui/hud.gd": "class_name Hud\n",
            "src/dominio/turno.gd": "# esto lo va a pintar Hud, algún día\nextends RefCounted\n",
        }
        self.assertEqual(violaciones(archivos, CAPAS), [])

    def test_un_class_name_adentro_de_un_string_no_cuenta(self):
        archivos = {
            "src/ui/hud.gd": "class_name Hud\n",
            "src/dominio/turno.gd": 'var etiqueta := "Hud"\n',
        }
        self.assertEqual(violaciones(archivos, CAPAS), [])

    def test_un_nombre_que_es_prefijo_de_otro_no_cuenta(self):
        # `\\b` de los dos lados: `Hud` no matchea adentro de `HudViejo`.
        archivos = {
            "src/ui/hud.gd": "class_name Hud\n",
            "src/dominio/turno.gd": "var x := HudViejo.new()\n",
        }
        self.assertEqual(violaciones(archivos, CAPAS), [])

    def test_declarar_el_propio_class_name_no_es_referenciarse(self):
        archivos = {"src/dominio/turno.gd": "class_name Turno\nextends RefCounted\n"}
        self.assertEqual(violaciones(archivos, CAPAS), [])

    def test_la_linea_del_hallazgo_es_la_del_archivo(self):
        # Los strings y comentarios se reemplazan por espacios y no se borran, justamente para
        # que el número de línea siga siendo el de verdad.
        archivos = {
            "src/ui/hud.gd": "class_name Hud\n",
            "src/dominio/turno.gd": '# comentario\nvar s := "texto"\n\nvar h: Hud\n',
        }
        self.assertEqual(violaciones(archivos, CAPAS)[0][1], 4)


if __name__ == "__main__":
    unittest.main()
