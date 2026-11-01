"""Los tests de `lib/atlas.py`: el reparto y el desfasaje contra las fuentes.

Un atlas desactualizado no da ningún error: la etiqueta de un producto sale con el dibujo de
otro. Por eso el desfasaje frente a las fuentes es lo que más pesa acá.
"""

import hashlib
import unittest

from lib.atlas import (
    BC1,
    BC3,
    BLOQUE,
    BORDE,
    TOPE,
    Entrada,
    a_manifiesto,
    acomodar,
    carpeta_del_atlas,
    desfasaje,
    reparto_de_las_cajas,
    uv_en_el_atlas,
)


def entrada(ruta, ancho=512, alto=512, formato=BC1, huella="h"):
    return Entrada(ruta, ancho, alto, formato, huella)


def png(ancho, alto, extra=b""):
    cabecera = b"\x89PNG\r\n\x1a\n\0\0\0\rIHDR"
    return cabecera + ancho.to_bytes(4, "big") + alto.to_bytes(4, "big") + extra


def manifiesto_de(entradas):
    atlas = acomodar(entradas, "t")
    archivos = {a.archivo: png(a.ancho, a.alto) for a in atlas}
    huellas = {k: hashlib.sha256(v).hexdigest() for k, v in archivos.items()}
    return a_manifiesto({"t": atlas}, huellas), archivos


class Acomodar(unittest.TestCase):
    def test_cada_celda_empieza_en_un_multiplo_del_bloque(self):
        entradas = [entrada(f"{i}.png", 100 + 3 * i, 90 + i) for i in range(12)]
        for atlas in acomodar(entradas, "t"):
            for c in atlas.colocadas:
                self.assertEqual((c.x - BORDE) % BLOQUE, 0)
                self.assertEqual((c.y - BORDE) % BLOQUE, 0)

    def test_dos_texturas_no_se_pisan_ni_se_tocan_sus_bordes(self):
        entradas = [entrada(f"{i}.png", 200 + 7 * i, 150 + 5 * i) for i in range(10)]
        (atlas,) = acomodar(entradas, "t")
        cajas = [
            (c.x - BORDE, c.y - BORDE, c.x + c.entrada.ancho + BORDE, c.y + c.entrada.alto + BORDE)
            for c in atlas.colocadas
        ]
        for i, a in enumerate(cajas):
            for b in cajas[i + 1 :]:
                separadas = a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1]
                self.assertTrue(separadas, f"{a} se pisa con {b}")

    def test_nada_pasa_del_tope(self):
        entradas = [entrada(f"{i}.png") for i in range(80)]
        atlas = acomodar(entradas, "t")
        self.assertGreater(len(atlas), 1)
        for a in atlas:
            self.assertLessEqual(max(a.ancho, a.alto), TOPE)
            for c in a.colocadas:
                self.assertLessEqual(c.x + c.entrada.ancho + BORDE, a.ancho)
                self.assertLessEqual(c.y + c.entrada.alto + BORDE, a.alto)

    def test_todas_las_entradas_quedan_colocadas_una_sola_vez(self):
        entradas = [entrada(f"{i}.png") for i in range(80)]
        puestas = [c.entrada.ruta for a in acomodar(entradas, "t") for c in a.colocadas]
        self.assertEqual(sorted(puestas), sorted(e.ruta for e in entradas))

    def test_es_determinista(self):
        entradas = [entrada(f"{i}.png", 300 + i, 200 + 2 * i) for i in range(9)]
        self.assertEqual(acomodar(entradas, "t"), acomodar(list(reversed(entradas)), "t"))

    def test_un_atlas_no_mezcla_formatos(self):
        with self.assertRaises(ValueError):
            acomodar([entrada("a.png"), entrada("b.png", formato=BC3)], "t")

    def test_una_textura_que_no_entra_en_el_tope_falla(self):
        with self.assertRaises(ValueError):
            acomodar([entrada("a.png", TOPE, 64)], "t")

    def test_con_un_solo_atlas_el_archivo_no_lleva_numero(self):
        (atlas,) = acomodar([entrada("a.png")], "etiquetas_bc1")
        self.assertEqual(atlas.archivo, "etiquetas_bc1.png")


class Cajas(unittest.TestCase):
    def test_el_atlas_de_las_cajas_vive_junto_a_las_cajas_y_el_de_etiquetas_no(self):
        self.assertEqual(carpeta_del_atlas("atlas_cajas_bc1.png").name, "boxes")
        self.assertEqual(carpeta_del_atlas("etiquetas_bc1.png").name, "atlas")

    def test_el_reparto_de_cada_caja_sale_del_nombre_de_su_png(self):
        entradas = [entrada("boxes/actroncito.png"), entrada("boxes/fernet_god.png")]
        atlas = acomodar(entradas, "atlas_cajas_bc1")
        manifiesto = a_manifiesto({"cajas": atlas}, {})
        reparto = reparto_de_las_cajas(manifiesto)
        self.assertEqual(sorted(reparto["cajas"]), ["actroncito", "fernet_god"])
        colocada = atlas[0].colocadas[0]
        rect = reparto["cajas"][colocada.entrada.ruta.split("/")[-1][:-4]]["rect"]
        self.assertEqual(rect, [colocada.x, colocada.y, 512, 512])

    def test_las_etiquetas_no_entran_al_reparto_de_las_cajas(self):
        atlas = acomodar([entrada("source/x.png")], "etiquetas_bc1")
        self.assertEqual(reparto_de_las_cajas(a_manifiesto({"e": atlas}, {}))["cajas"], {})


class UV(unittest.TestCase):
    def test_las_esquinas_de_la_textura_caen_en_su_celda(self):
        (atlas,) = acomodar([entrada("a.png", 256, 128), entrada("b.png", 128, 64)], "t")
        for c in atlas.colocadas:
            u0, v_abajo = uv_en_el_atlas(c, atlas, 0.0, 0.0)
            u1, v_arriba = uv_en_el_atlas(c, atlas, 1.0, 1.0)
            self.assertAlmostEqual(u0 * atlas.ancho, c.x)
            self.assertAlmostEqual(u1 * atlas.ancho, c.x + c.entrada.ancho)
            self.assertAlmostEqual((1 - v_arriba) * atlas.alto, c.y)
            self.assertAlmostEqual((1 - v_abajo) * atlas.alto, c.y + c.entrada.alto)


class Desfasaje(unittest.TestCase):
    def setUp(self):
        self.entradas = [entrada("a.png", huella="1"), entrada("b.png", 256, 128, huella="2")]
        self.manifiesto, self.archivos = manifiesto_de(self.entradas)
        self.fuentes = {e.ruta: e for e in self.entradas}

    def motivos(self, fuentes=None, archivos=None):
        return desfasaje(
            self.manifiesto,
            self.fuentes if fuentes is None else fuentes,
            self.archivos if archivos is None else archivos,
        )

    def test_un_atlas_al_dia_no_tiene_motivos(self):
        self.assertEqual(self.motivos(), [])

    def test_una_textura_cambiada_frena_el_atlas(self):
        fuentes = dict(self.fuentes, **{"a.png": entrada("a.png", huella="otra")})
        (motivo,) = self.motivos(fuentes)
        self.assertIn("a.png", motivo)

    def test_una_textura_de_otro_tamano_frena_el_atlas(self):
        fuentes = dict(self.fuentes, **{"b.png": entrada("b.png", 512, 512, huella="2")})
        (motivo,) = self.motivos(fuentes)
        self.assertIn("512x512", motivo)

    def test_una_textura_que_cambia_de_formato_frena_el_atlas(self):
        fuentes = dict(self.fuentes, **{"a.png": entrada("a.png", formato=BC3, huella="1")})
        (motivo,) = self.motivos(fuentes)
        self.assertIn("bc3", motivo)

    def test_una_fuente_nueva_o_borrada_frena_el_atlas(self):
        nueva = dict(self.fuentes, **{"c.png": entrada("c.png")})
        self.assertTrue(any("nueva" in m for m in self.motivos(nueva)))
        borrada = {k: v for k, v in self.fuentes.items() if k != "a.png"}
        self.assertTrue(any("ya no existe" in m for m in self.motivos(borrada)))

    def test_un_atlas_sin_su_png_frena(self):
        self.assertTrue(any("falta" in m for m in self.motivos(archivos={})))

    def test_un_png_reemplazado_frena(self):
        ((nombre, datos),) = self.archivos.items()
        self.assertTrue(any("selló" in m for m in self.motivos(archivos={nombre: datos + b"x"})))

    def test_un_png_de_otro_tamano_frena(self):
        (nombre,) = self.archivos
        self.assertTrue(any("no mide" in m for m in self.motivos(archivos={nombre: png(8, 8)})))


if __name__ == "__main__":
    unittest.main()
