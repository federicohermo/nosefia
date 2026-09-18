"""La exportación debe corresponder a la fuente y conservar sus recursos."""

import hashlib
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
        cls.glb = (RAIZ / "assets/SEPT_JUEGOS_PROTOTIPO.glb").read_bytes()
        longitud = struct.unpack_from("<I", cls.glb, 12)[0]
        cls.modelo = json.loads(cls.glb[20 : 20 + longitud])
        cls.bin_inicio = 20 + longitud + 8

    def test_el_glb_corresponde_al_blend_integrado(self):
        # Par medido al exportar con Blender 5.2.1 desde la fuente ya guardada. El par no se
        # puede mezclar entre versiones del exportador: dos versiones devuelven datos de
        # vértice distintos para la misma malla.
        #
        # Las opciones que reproducen el par, medidas reexportando hasta dar con los mismos
        # bytes: formato GLB, imágenes AUTO, `export_apply`, `use_visible` y `export_yup`,
        # sin cámaras ni luces. `use_visible` importa: sin él entran los objetos de la
        # colección oculta, que no son parte del juego.
        #
        # **Y la exportación va con los modificadores `Array` apagados**, que son Geometry
        # Nodes llamados `Array`, no modificadores de tipo `ARRAY`: apagar por tipo no apaga
        # ninguno y los productos salen multiplicados igual. Se apagan por nombre. Los productos
        # llevan un Geometry Nodes que llena el estante con una fila, y **Blender 5.0 no
        # realizaba esas instancias al exportar y 5.2 sí**, así que con el modificador activo
        # el producto sale multiplicado donde antes salía solo. El juego necesita **una
        # unidad**, porque `reposicion_manual.gd` toma la superficie 0 de cada grupo como el
        # modelo de una y apila `cupo()` copias separadas por su AABB; con la fila entera, dos
        # productos vecinos se pisan y el test de apoyos del modelo da rojo.
        blend = (RAIZ / "assets/SEPT_JUEGOS_PROTOTIPO.blend").read_bytes()
        self.assertEqual(
            hashlib.sha256(blend).hexdigest(),
            "d07b308d1daf75d151b7f407b7014c27bb8c7a021a27f97d308fd0233f4ffe0a",
        )
        self.assertEqual(
            hashlib.sha256(self.glb).hexdigest(),
            "f6bdb1afb621c2faf9de0cd34ad8e3b36b421a895aa5443e986660a94fb36ee9",
        )

    def test_las_mallas_conservan_uv_y_materiales(self):
        self.assertEqual(len(self.modelo["meshes"]), 67)
        self.assertEqual(len(self.modelo["materials"]), 42)
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

    def test_las_texturas_resuelven_dentro_del_glb(self):
        imagenes = self.modelo.get("images", [])
        self.assertEqual(len(imagenes), 35)
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
