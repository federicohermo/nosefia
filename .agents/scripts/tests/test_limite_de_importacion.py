"""El límite de lado de una textura extraída sale de su grupo y no se pisa si alguien lo decidió."""

import unittest

from lib import atlas
from lib.blender import LADO_TOPE
from lib.limite_de_importacion import (
    con_el_limite,
    es_una_textura,
    limite_declarado,
    limite_de,
)

NACE_SIN_LIMITE = (
    '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'
    "compress/mode=2\nprocess/size_limit=0\ndetect_3d/compress_to=0\n"
)


class LaCuenta(unittest.TestCase):
    def test_una_textura_que_nace_sin_limite_recibe_el_del_grupo(self):
        texto = con_el_limite(NACE_SIN_LIMITE, LADO_TOPE)
        self.assertEqual(limite_declarado(texto), LADO_TOPE)

    def test_cambia_solo_esa_linea(self):
        texto = con_el_limite(NACE_SIN_LIMITE, LADO_TOPE)
        self.assertEqual(texto.replace(f"={LADO_TOPE}", "=0"), NACE_SIN_LIMITE)

    def test_un_limite_ya_decidido_no_se_pisa(self):
        decidido = NACE_SIN_LIMITE.replace("size_limit=0", "size_limit=256")
        self.assertEqual(con_el_limite(decidido, LADO_TOPE), decidido)

    def test_correrlo_dos_veces_da_lo_mismo(self):
        una = con_el_limite(NACE_SIN_LIMITE, LADO_TOPE)
        self.assertEqual(con_el_limite(una, LADO_TOPE), una)

    def test_un_import_sin_limite_declarado_no_es_de_una_textura(self):
        with self.assertRaises(ValueError):
            con_el_limite("[remap]\nimporter=\"scene\"\n", LADO_TOPE)

    def test_reconoce_las_texturas(self):
        self.assertTrue(es_una_textura(NACE_SIN_LIMITE))
        self.assertFalse(es_una_textura('[remap]\nimporter="scene"\n'))


class ElTopeDelGrupo(unittest.TestCase):
    def test_una_textura_suelta_lleva_el_tope_del_modelo(self):
        self.assertEqual(limite_de("oremos_paquete", {"etiquetas_bc3"}), LADO_TOPE)

    def test_un_atlas_lleva_el_tope_de_los_atlas(self):
        self.assertEqual(limite_de("etiquetas_bc3", {"etiquetas_bc3"}), atlas.TOPE)


if __name__ == "__main__":
    unittest.main()
