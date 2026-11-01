"""Los tests de `lib/union_de_mallas.py`: qué se une y qué se queda afuera.

Lo que importa es el fallo caro: unir una malla que el juego busca por su nombre, o que se
mueve, o que cruza de un ambiente a otro.
"""

import unittest

from lib.repo import RAIZ
from lib.union_de_mallas import (
    PREFIJOS_DE_LUZ_DINAMICA,
    Candidata,
    agrupar,
    ambiente_de,
    de_blender_a_godot,
    es_fijo,
    esta_citado,
    leer_ambientes,
    nombre_de_godot,
    nombre_de_la_union,
    nombres_citados,
)

ESCENA = """
local = Array[AABB]([AABB(0.0, 0.0, 0.0, 10.0, 3.0, 10.0)])
deposito = Array[AABB]([AABB(0.0, 0.0, -20.0, 10.0, 3.0, 10.0)])
bano = Array[AABB]([AABB(20.0, 0.0, 0.0, 5.0, 3.0, 5.0)])
cuartito = Array[AABB]([AABB(20.0, 0.0, -20.0, 5.0, 3.0, 5.0)])
"""


def cajas():
    return leer_ambientes(ESCENA)


def pieza(nombre, centro=(1.0, -1.0, 1.0), material="acero", **resto):
    return Candidata(nombre=nombre, centro=centro, material=material, **resto)


class Citados(unittest.TestCase):
    def test_un_nombre_entre_comillas_esta_citado(self):
        citados = nombres_citados(['var m = get_node("tapa_del_tacho")'])
        self.assertTrue(esta_citado("tapa_del_tacho", citados))

    def test_el_destino_de_un_camino_cuenta_y_los_tramos_de_paso_no(self):
        citados = nombres_citados(['[node name="Volumen" parent="techo/chapa/Cuerpo"]'])
        self.assertTrue(esta_citado("Cuerpo", citados))
        self.assertFalse(esta_citado("techo", citados))
        self.assertFalse(esta_citado("chapa", citados))

    def test_el_nombre_que_deja_godot_cambia_el_punto_por_un_guion_bajo(self):
        citados = nombres_citados(['"gondola_001"'])
        self.assertTrue(esta_citado("gondola.001", citados))
        self.assertEqual(nombre_de_godot("a.b:c"), "a_b_c")

    def test_el_destino_de_un_dolar_esta_citado(self):
        self.assertIn("Hora", nombres_citados(["$Reloj/Hora"]))


class Fijos(unittest.TestCase):
    def test_lo_que_se_mueve_no_es_fijo(self):
        for nombre in ("puerta_del_local", "hoja_derecha", "tapa_contenedor", "vidrio_sur"):
            self.assertFalse(es_fijo(nombre), nombre)

    def test_lo_que_el_importador_interpreta_por_su_sufijo_no_es_fijo(self):
        for nombre in ("estante-col", "mesa-convcol.001", "x-noimp", "y-colonly"):
            self.assertFalse(es_fijo(nombre), nombre)

    def test_lo_que_pasa_a_luz_dinamica_no_es_fijo(self):
        for prefijo in PREFIJOS_DE_LUZ_DINAMICA:
            self.assertFalse(es_fijo(prefijo + "_1"), prefijo)

    def test_los_prefijos_son_los_de_importar_modelo(self):
        texto = (RAIZ / "assets/models/importar_modelo.gd").read_text(encoding="utf-8")
        for prefijo in PREFIJOS_DE_LUZ_DINAMICA:
            self.assertIn(f'"{prefijo}"', texto, f"{prefijo} ya no está en importar_modelo.gd")

    def test_una_viga_es_fija(self):
        self.assertTrue(es_fijo("deposito_techo_cercha_01"))


class Ambientes(unittest.TestCase):
    def test_blender_y_godot_cambian_de_eje(self):
        self.assertEqual(de_blender_a_godot((1.0, 2.0, 3.0)), (1.0, 3.0, -2.0))

    def test_un_punto_cae_en_su_ambiente(self):
        self.assertEqual(ambiente_de((5.0, 1.0, 5.0), cajas()), "local")
        self.assertEqual(ambiente_de((5.0, 1.0, -15.0), cajas()), "deposito")
        self.assertEqual(ambiente_de((22.0, 1.0, 2.0), cajas()), "bano")
        self.assertEqual(ambiente_de((100.0, 0.0, 0.0), cajas()), "fuera")

    def test_una_escena_sin_las_cajas_de_un_ambiente_falla(self):
        with self.assertRaises(ValueError):
            leer_ambientes("local = Array[AABB]([])\n")


class Agrupar(unittest.TestCase):
    def test_dos_piezas_del_mismo_ambiente_y_material_se_unen(self):
        grupos = agrupar([pieza("a"), pieza("b")], set(), cajas())
        self.assertEqual(list(grupos.values()), [["a", "b"]])

    def test_una_pieza_sola_no_se_une(self):
        self.assertEqual(agrupar([pieza("a")], set(), cajas()), {})

    def test_no_se_une_a_traves_de_ambientes(self):
        local = pieza("a", centro=(5.0, -5.0, 1.0))
        deposito = pieza("b", centro=(5.0, 15.0, 1.0))
        self.assertEqual(agrupar([local, deposito], set(), cajas()), {})

    def test_no_se_unen_materiales_distintos(self):
        self.assertEqual(agrupar([pieza("a"), pieza("b", material="madera")], set(), cajas()), {})

    def test_no_se_une_lo_que_el_juego_nombra(self):
        grupos = agrupar([pieza("a"), pieza("b"), pieza("c")], {"b"}, cajas())
        self.assertEqual(list(grupos.values()), [["a", "c"]])

    def test_lo_que_cuelga_de_algo_que_se_mueve_se_queda(self):
        hijas = [pieza("a", ancestros=("puerta_1",)), pieza("b", ancestros=("puerta_1",))]
        self.assertEqual(agrupar(hijas, set(), cajas()), {})

    def test_no_se_une_con_capas_de_uv_distintas(self):
        mezcla = [pieza("a", capas="uv1|"), pieza("b", capas="uv2|")]
        self.assertEqual(agrupar(mezcla, set(), cajas()), {})

    def test_el_vidrio_no_se_une_por_su_material(self):
        vidrio = [pieza("a", material="local_vidrio"), pieza("b", material="local_vidrio")]
        self.assertEqual(agrupar(vidrio, set(), cajas()), {})

    def test_el_nombre_de_la_union_no_lleva_nada_que_el_importador_interprete(self):
        nombre = nombre_de_la_union("deposito", "CONTENEDOR | Paneles negros")
        self.assertTrue(es_fijo(nombre))
        self.assertTrue(nombre.replace("_", "").isalnum())


if __name__ == "__main__":
    unittest.main()
