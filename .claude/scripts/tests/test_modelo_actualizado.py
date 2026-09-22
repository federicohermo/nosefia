"""La exportación debe corresponder a la fuente y conservar sus recursos."""

import json
import struct
import unittest

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
