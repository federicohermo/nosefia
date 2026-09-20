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
        cls.glb = (RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.glb").read_bytes()
        longitud = struct.unpack_from("<I", cls.glb, 12)[0]
        cls.modelo = json.loads(cls.glb[20 : 20 + longitud])
        cls.bin_inicio = 20 + longitud + 8

    def test_el_glb_corresponde_al_blend_integrado(self):
        # Par medido al exportar con Blender 5.2.1 desde la fuente ya guardada. El par no se
        # puede mezclar entre versiones del exportador: dos versiones devuelven datos de
        # vertice distintos para la misma malla.
        #
        # Las opciones que reproducen el par: formato GLB, imagenes AUTO, `export_apply`,
        # `use_visible` y `export_yup`, sin camaras ni luces.
        #
        # **Y la exportacion va con los `Array` apagados y la coleccion `guia` excluida.** Las
        # dos cosas por el mismo motivo: el juego dibuja la gondola con un `MultiMesh`, asi que
        # el `.glb` tiene que traer **una unidad** de cada producto y ninguna de sus copias. Si
        # las copias viajan, cada producto se dibuja dos veces —una horneada y otra por el
        # grupo— y el estante queda con el doble de mercaderia que el inventario dice.
        #
        # Los `Array` son Geometry Nodes llamados `Array`, no modificadores de tipo `ARRAY`:
        # apagar por tipo no apaga ninguno. Se apagan por nombre, con su sufijo.
        #
        # **El 2026-09-19 entro el modelo nuevo**, con la gondola llena: 177 copias linkeadas
        # pasaron a la coleccion `guia`, que no se exporta y que
        # `src/escenas/puestos/disposicion_de_la_gondola.tres` reproduce copia por copia. Ese
        # mismo dia entraron los seis productos que tenian textura y no tenian modelo, armados
        # del troquel de su propia textura: tres cajas, dos bolsas y un cilindro.
        blend = (RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend").read_bytes()
        self.assertEqual(
            hashlib.sha256(blend).hexdigest(),
            "3ea268168afc70942f08be0bfbdc47f80bf29c3bfc2c6ea7b615d0a90d14ba72",
        )
        self.assertEqual(
            hashlib.sha256(self.glb).hexdigest(),
            "374bbff8cb9704a5ed66683f18802a7bd4c323607d311f2ff54f3f3320a800e9",
        )

    def test_las_mallas_conservan_uv_y_materiales(self):
        self.assertEqual(len(self.modelo["meshes"]), 65)
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
        self.assertEqual(len(imagenes), 36)
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
