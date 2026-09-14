"""La exportación debe corresponder a la fuente y conservar sus recursos."""

import hashlib
import json
import struct
import unittest

from lib.repo import RAIZ


class ModeloActualizado(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.glb = (RAIZ / "assets/SEPT_JUEGOS_PROTOTIPO.glb").read_bytes()
        longitud = struct.unpack_from("<I", cls.glb, 12)[0]
        cls.modelo = json.loads(cls.glb[20 : 20 + longitud])
        cls.bin_inicio = 20 + longitud + 8

    def test_el_glb_corresponde_al_blend_integrado(self):  # 041-AC7
        # Par medido al exportar c852fc2 con Blender 5.0, sin guardar la fuente.
        blend = (RAIZ / "assets/SEPT_JUEGOS_PROTOTIPO.blend").read_bytes()
        self.assertEqual(
            hashlib.sha256(blend).hexdigest(),
            "95520fe035e670127905dde3dee006ca1487e68fa3e00c4e9e33971ebd1e7d00",
        )
        self.assertEqual(
            hashlib.sha256(self.glb).hexdigest(),
            "99f217eb45d020223edff3fa69c9b5ddee53dcd4f6b4f60ee2d599847be1bafd",
        )

    def test_las_mallas_conservan_uv_y_materiales(self):  # 041-AC7
        self.assertEqual(len(self.modelo["meshes"]), 61)
        self.assertEqual(len(self.modelo["materials"]), 36)
        for malla in self.modelo["meshes"]:
            for parte in malla["primitives"]:
                with self.subTest(malla=malla["name"]):
                    atributos = parte["attributes"]
                    uv = self.modelo["accessors"][atributos["TEXCOORD_0"]]
                    vertices = self.modelo["accessors"][atributos["POSITION"]]
                    self.assertEqual(uv["count"], vertices["count"])
                    self.assertGreater(uv["count"], 0)
                    if "material" in parte:
                        self.assertLess(parte["material"], len(self.modelo["materials"]))

    def test_las_texturas_resuelven_dentro_del_glb(self):  # 041-AC7
        imagenes = self.modelo.get("images", [])
        self.assertEqual(len(imagenes), 26)
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
                self.assertEqual(self.glb[inicio : inicio + 8], b"\x89PNG\r\n\x1a\n")
