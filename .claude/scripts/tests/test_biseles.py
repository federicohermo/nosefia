"""La capa de biseles de una etiqueta: cómo se suma y cuándo el atlas queda viejo.

La capa la hornea Blender sobre la malla real, y eso no se prueba acá: depende del modelo. Lo
que se prueba es lo que decide `lib/biseles.py` y `lib/atlas.py`, sin Blender.
"""

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from lib import atlas, biseles


class SumarLaCapa(unittest.TestCase):
    def test_una_capa_vacia_deja_el_color_como_estaba(self):
        for canal in (0.0, 0.2, 0.5, 1.0):
            self.assertAlmostEqual(biseles.componer(canal, 1.0, 0.0), canal)

    def test_la_banda_oscura_oscurece(self):
        self.assertLess(biseles.componer(0.8, 0.7, 0.0), 0.8)

    def test_el_brillo_aclara_un_color_oscuro_y_uno_claro(self):
        for canal in (0.1, 0.5, 0.9):
            self.assertGreater(biseles.componer(canal, 1.0, 0.3), canal)

    def test_el_resultado_nunca_pasa_de_blanco(self):
        pasos = [i / 10 for i in range(11)]
        mayor = max(biseles.componer(c, luz, b) for c in pasos for luz in pasos for b in pasos)
        self.assertLessEqual(mayor, 1.0)

    def test_el_negro_con_brillo_se_ve_un_gris_y_sin_brillo_sigue_negro(self):
        self.assertEqual(biseles.componer(0.0, 0.7, 0.0), 0.0)
        self.assertGreater(biseles.componer(0.0, 0.7, 0.3), 0.0)


class ElRadioDelBisel(unittest.TestCase):
    def test_una_etiqueta_mas_densa_lleva_un_bisel_mas_angosto_en_metros(self):
        rala = biseles.radio_en_metros(3.0, 300.0)
        densa = biseles.radio_en_metros(3.0, 1500.0)
        self.assertLess(densa, rala)

    def test_el_bisel_ocupa_los_texeles_pedidos_cuando_no_toca_un_limite(self):
        densidad = 600.0
        radio = biseles.radio_en_metros(4.0, densidad)
        self.assertAlmostEqual(radio * densidad, 4.0)

    def test_una_densidad_extrema_no_da_un_bisel_invisible_ni_una_esquina_de_goma(self):
        self.assertEqual(biseles.radio_en_metros(3.0, 1e9), biseles.RADIO_MINIMO)
        self.assertEqual(biseles.radio_en_metros(3.0, 1.0), biseles.RADIO_MAXIMO)


class FormasCurvas(unittest.TestCase):
    def test_una_caja_y_un_cilindro_duro_llevan_bisel(self):
        self.assertFalse(biseles.es_forma_curva([90.0] * 12))
        self.assertFalse(biseles.es_forma_curva([11.2] * 32 + [90.0] * 64))

    def test_un_quiebre_suave_deja_la_malla_sin_bisel(self):
        self.assertTrue(biseles.es_forma_curva([90.0, 90.0, 28.5, 76.0]))
        self.assertTrue(biseles.es_forma_curva([45.0]))

    def test_una_malla_sin_aristas_compartidas_no_es_curva(self):
        self.assertFalse(biseles.es_forma_curva([]))


class DondeVive(unittest.TestCase):
    def test_la_capa_de_una_etiqueta_lleva_su_misma_ruta(self):
        ruta = biseles.ruta_de_la_capa("source/products-cam/petisas/petisas completo.png")
        self.assertEqual(
            ruta, biseles.CARPETA / "products-cam" / "petisas" / "petisas completo.png"
        )

    def test_toda_etiqueta_de_la_tabla_tiene_su_capa(self):
        faltan = [c for c in atlas.ETIQUETAS if not biseles.ruta_de_la_capa(c).is_file()]
        self.assertEqual(
            faltan, [], "corré python .claude/scripts/hornear_biseles.py\n" + "\n".join(faltan)
        )


class ElAtlasSabeSiLaCapaCambio(unittest.TestCase):
    def _fuente(self, base: Path) -> str:
        clave = "source/products-cam/caja/etiqueta.png"
        (base / "source" / "products-cam" / "caja").mkdir(parents=True)
        (base / clave).write_bytes(b"dibujo")
        return clave

    def test_cambiar_o_agregar_la_capa_cambia_la_huella(self):
        with tempfile.TemporaryDirectory() as carpeta:
            base = Path(carpeta)
            clave = self._fuente(base)
            with mock.patch.object(atlas, "ASSETS", base), mock.patch.object(
                biseles, "CARPETA", base / "capas"
            ):
                sin_capa = atlas.huella_de_la_fuente(clave)
                capa = biseles.ruta_de_la_capa(clave)
                capa.parent.mkdir(parents=True)
                capa.write_bytes(b"capa uno")
                con_capa = atlas.huella_de_la_fuente(clave)
                capa.write_bytes(b"capa dos")
                otra_capa = atlas.huella_de_la_fuente(clave)
        self.assertEqual(len({sin_capa, con_capa, otra_capa}), 3)

    def test_sin_capa_la_huella_es_la_de_siempre(self):
        with tempfile.TemporaryDirectory() as carpeta:
            base = Path(carpeta)
            clave = self._fuente(base)
            with mock.patch.object(atlas, "ASSETS", base), mock.patch.object(
                biseles, "CARPETA", base / "capas"
            ):
                self.assertEqual(atlas.huella_de_la_fuente(clave), atlas.huella_de(base / clave))


if __name__ == "__main__":
    unittest.main()
