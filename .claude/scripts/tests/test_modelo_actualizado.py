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
        # Par medido al exportar con Blender 5.2.1 desde la fuente ya guardada. El anterior
        # salía de c852fc2 con Blender 5.0: los dos exportadores devuelven datos de vértice
        # distintos para la misma malla, así que el par no se puede mezclar entre versiones.
        #
        # **Y la exportación va con los modificadores `Array` apagados.** Siete productos
        # —`durextra`, `Zucarachas`, `Zucarachas2`, `Zucarachas2.001`, `snackpapas1`,
        # `malbardocig` y `alfajorescaja`— llevan un Geometry Nodes llamado `Array` que llena
        # el estante con una fila. Blender 5.0 no realizaba esas instancias al exportar y 5.2
        # sí, así que exportar con el modificador activo multiplica el producto por cuatro o
        # por seis: medido, `durextra` pasa de 0,268 m a 1,105 m y `Zucarachas` de 0,282 m a
        # 1,667 m. El juego necesita **una unidad**, porque `reposicion_manual.gd` toma la
        # superficie 0 de cada grupo como el modelo de una y apila `cupo()` copias separadas
        # por su AABB; con la fila entera, dos productos vecinos se pisan y el 042-AC2 da
        # rojo. Apagados, los nueve productos salen byte a byte iguales al `.glb` de c852fc2.
        blend = (RAIZ / "assets/SEPT_JUEGOS_PROTOTIPO.blend").read_bytes()
        self.assertEqual(
            hashlib.sha256(blend).hexdigest(),
            "7dfef7a3b561ea7beb9238e563308740cbd073e26fdc5d5a0e1cc610561e7f70",
        )
        self.assertEqual(
            hashlib.sha256(self.glb).hexdigest(),
            "d40fb7b9e8e2a15ea7f9d65309344faa4731090f3e0721a0592b8369fc1d5dee",
        )

    def test_las_mallas_conservan_uv_y_materiales(self):  # 041-AC7
        self.assertEqual(len(self.modelo["meshes"]), 60)
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
