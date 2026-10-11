"""La exportación debe corresponder a la fuente y conservar sus recursos."""

import json
import struct
import tempfile
import unittest
from pathlib import Path

from exportar_modelo import FUENTE, HUELLA, desfasaje, escribir_huella
from lib.repo import RAIZ

# Firmas de archivo. El test sólo necesita saber que la imagen viaja adentro del `.glb`, y
# el formato lo decide la fuente: el exportador ofrece AUTO, JPEG, WEBP o NONE, y no hay
# opción de forzar todo a PNG.
PNG = b"\x89PNG\r\n\x1a\n"
JPEG = b"\xff\xd8\xff"


class ModeloActualizado(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.glb = (RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.glb").read_bytes()
        longitud = struct.unpack_from("<I", cls.glb, 12)[0]
        cls.modelo = json.loads(cls.glb[20 : 20 + longitud])
        cls.bin_inicio = 20 + longitud + 8

    def test_el_glb_salio_del_blend_del_arbol(self) -> None:
        self.assertIsNone(desfasaje(FUENTE, HUELLA))

    def test_las_mallas_conservan_uv_y_materiales(self):
        # Son mas que las mallas de Blender, y no es un error: con `export_apply` el exportador
        # de glTF evalua los modificadores objeto por objeto, asi que una tanda copiada de un
        # objeto que tiene modificadores no comparte la malla con su original. Son mallas
        # repetidas, cien kilobytes sobre treinta y cuatro megas.
        for malla in self.modelo["meshes"]:
            for parte in malla["primitives"]:
                with self.subTest(malla=malla["name"]):
                    atributos = parte["attributes"]
                    # Una malla de color plano, sin textura, no trae UV, y no le hace falta.
                    if "TEXCOORD_0" not in atributos:
                        continue
                    uv = self.modelo["accessors"][atributos["TEXCOORD_0"]]
                    vertices = self.modelo["accessors"][atributos["POSITION"]]
                    self.assertEqual(uv["count"], vertices["count"])
                    self.assertGreater(uv["count"], 0)
                    if "material" in parte:
                        self.assertLess(parte["material"], len(self.modelo["materials"]))

    def test_las_texturas_resuelven_dentro_del_glb(self):
        imagenes = self.modelo.get("images", [])
        for textura in self.modelo["textures"]:
            self.assertLess(textura["source"], len(imagenes))
        for imagen in imagenes:
            with self.subTest(imagen=imagen["name"]):
                self.assertNotIn("uri", imagen)
                vista = self.modelo["bufferViews"][imagen["bufferView"]]
                inicio = self.bin_inicio + vista.get("byteOffset", 0)
                fin = inicio + vista["byteLength"]
                self.assertEqual(vista["buffer"], 0)
                self.assertLessEqual(fin, len(self.glb))
                self.assertGreater(vista["byteLength"], 8)
                cabecera = self.glb[inicio : inicio + 8]
                self.assertTrue(
                    cabecera.startswith(PNG) or cabecera.startswith(JPEG),
                    "la imagen no empieza por una firma PNG ni JPEG",
                )


class ElCicloDeLaHuella(unittest.TestCase):
    """`escribir_huella` es lo que corre el exportador después de Blender: acá hace de exportar."""

    def setUp(self) -> None:
        carpeta = tempfile.TemporaryDirectory()
        self.addCleanup(carpeta.cleanup)
        self.fuente = Path(carpeta.name) / "modelo.blend"
        self.huella = Path(carpeta.name) / "modelo.glb.fuente"
        self.fuente.write_bytes(b"fuente uno")

    def test_tocar_la_fuente_sin_exportar_da_rojo_y_exportar_la_vuelve_verde(self) -> None:
        escribir_huella(self.fuente, self.huella)
        self.assertIsNone(desfasaje(self.fuente, self.huella))
        self.fuente.write_bytes(b"fuente dos")
        self.assertIn("exportar_modelo.py", desfasaje(self.fuente, self.huella))
        escribir_huella(self.fuente, self.huella)
        self.assertIsNone(desfasaje(self.fuente, self.huella))

    def test_reemplazar_la_fuente_por_otra_da_rojo(self) -> None:
        escribir_huella(self.fuente, self.huella)
        self.assertIsNone(desfasaje(self.fuente, self.huella))
        otra = self.fuente.with_name("otra.blend")
        otra.write_bytes(b"fuente dos")
        otra.replace(self.fuente)
        self.assertIsNotNone(desfasaje(self.fuente, self.huella))

    def test_sin_huella_el_rojo_dice_que_hay_que_correr_el_exportador(self) -> None:
        self.assertIn("exportar_modelo.py", desfasaje(self.fuente, self.huella))
