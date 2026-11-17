"""El atlas del árbol frente a sus fuentes.

Un atlas viejo no da ningún error en el juego: la etiqueta de un producto sale con el dibujo
de otro, o una caja con la de la vecina. Estos casos lo frenan antes del PR.

Sin manifiesto no hay atlas, y no hay nada que comparar: los casos que lo necesitan se saltean
diciéndolo. Con manifiesto, cada diferencia con las fuentes es un rojo con su motivo.
"""

import unittest
import unicodedata

from lib import atlas
from lib.atlas import MANIFIESTO, es_caja


class FuentesDelAtlas(unittest.TestCase):
    def test_cada_textura_de_la_tabla_existe(self):
        faltan = [r for r in atlas.ETIQUETAS if not (atlas.ASSETS / r).is_file()]
        self.assertEqual(faltan, [], "una textura de ETIQUETAS ya no está en assets/source/")

    def test_ninguna_textura_esta_dos_veces(self):
        normalizadas = [unicodedata.normalize("NFC", r) for r in atlas.ETIQUETAS]
        self.assertEqual(len(normalizadas), len(set(normalizadas)))


@unittest.skipUnless(MANIFIESTO.is_file(), f"todavía no hay atlas: falta {MANIFIESTO.name}")
class AtlasAlDia(unittest.TestCase):
    def test_el_atlas_corresponde_a_sus_fuentes(self):
        motivos = atlas.desfasaje_con_el_disco(atlas.leer())
        self.assertEqual(
            motivos, [], "corré python .claude/scripts/armar_atlas.py\n" + "\n".join(motivos)
        )

    def test_el_reparto_guardado_es_el_que_saldria_hoy(self):
        manifiesto = atlas.leer()
        guardado = {e["ruta"]: (e["x"], e["y"]) for a in manifiesto["atlas"] for e in a["entradas"]}
        hoy = {}
        fuentes = atlas.fuentes_del_disco(manifiesto)
        for formato in (atlas.BC1, atlas.BC3):
            for caja in (False, True):
                grupo = [
                    e for e in fuentes.values()
                    if e.formato == formato and es_caja(e.ruta) == caja
                ]
                for hoja in atlas.acomodar(grupo, "x"):
                    hoy.update({c.entrada.ruta: (c.x, c.y) for c in hoja.colocadas})
        self.assertEqual(hoy, guardado)

    def test_el_reparto_de_las_cajas_es_el_del_manifiesto(self):
        manifiesto = atlas.leer()
        if not atlas.reparto_de_las_cajas(manifiesto)["cajas"]:
            self.skipTest("el manifiesto todavía no trae cajas")
        self.assertEqual(atlas.leer(atlas.REPARTO_DE_LAS_CAJAS), atlas.reparto_de_las_cajas(manifiesto))

    def test_ninguna_hoja_pasa_del_tope(self):
        for hoja in atlas.leer()["atlas"]:
            self.assertLessEqual(max(hoja["ancho"], hoja["alto"]), atlas.TOPE, hoja["archivo"])


if __name__ == "__main__":
    unittest.main()
