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
        #
        # **Y la heladera recupero el mapa de sus caras gemelas.** El modelo trae la chapa dos
        # veces -la cara de adentro y su gemela unos centimetros detras-, y la gemela tenia el
        # UV colapsado: sampleaba una linea de la textura y se dibujaba como un degrade de
        # bandas. Con el material a doble cara, esa gemela es la que se ve.
        #
        # **El 2026-09-20 se acomodo el local.** Todo lo que el jugador repone quedo en una
        # bandeja del medio o en la heladera, las dos gondolas del fondo se llenaron y los seis
        # productos nuevos entraron al catalogo. El `.glb` gano siete objetos y ninguna malla:
        # las tandas duplicadas y las de relleno comparten la malla de la que salieron.
        #
        # **Y ese mismo dia se llenaron las caras que quedaban apagadas.** Las dos cabeceras del
        # fondo, el lado de la gondola del medio que da al pasillo de atras y siete de las ocho
        # bandejas de las dos heladeras no tenian nada, que no se lee como un estante a medio
        # reponer sino como un mueble roto. Son diecisiete tandas de guia mas.
        #
        # **Y despues, ninguna bandeja de un lado quedo con un solo producto.** Diez estantes
        # mostraban una marca sola repetida hasta el borde, alguno con cuarenta unidades: eso no
        # se lee como un almacen sino como el deposito. Ahora cada uno lleva entre dos y cuatro.
        # Las cabeceras si llevan uno solo, que es como se arma una punta de verdad, y cuatro
        # productos viven nada mas que ahi: Malbardo, Durextra, Laysntt y Chisitos son la compra
        # por impulso del que ya va a la caja, y estar en un solo lugar es lo que los distingue.

        #
        # **Coracola se repone una bandeja mas arriba**, a 1,29 y no a 0,79.
        #
        # **Y despues se junto todo.** Entre dos productos distintos habia diez centimetros y
        # entre dos unidades del mismo, uno: en el estante eso no se lee como dos marcas sino
        # como mercaderia faltante. Ahora la separacion es una sola, y las tandas de los
        # extremos se estiran hasta el borde de la chapa. Quedan 5,65 m de chapa libre en
        # treinta bandejas, repartidos en las dos puntas de cada una: menos de lo que mide un
        # producto, que es lo mas lleno que se puede dejar sin inventar una unidad partida.
        #
        # **Y la heladera se achico.** Medía casi un metro mas que la gondola de al lado: no se
        # leia como otro mueble sino como otra escala. Ahora tiene el mismo fondo que la
        # gondola, se apoya en el mismo plano de pared y queda apenas mas alta, que es la
        # proporcion que tienen de verdad. Las latas se reacomodaron solas: la chapa da menos
        # largo y menos fondo, asi que el mueble lleva una columna menos por bandeja.

        # Los seis productos armados del troquel entraron chicos —el troquel da la proporcion y
        # no el tamano— y se agrandaron un cuarto, salvo las Macumbas que ya venian agrandadas.
        blend = (RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend").read_bytes()
        self.assertEqual(
            hashlib.sha256(blend).hexdigest(),
            "aa6ff5f7dc2e479175a4924b30f3f009d165fcc5432ec78577ef1cb23fc614c2",
        )
        self.assertEqual(
            hashlib.sha256(self.glb).hexdigest(),
            "53a87f5aed5f15af07a227cfdb244226f7a1488b1d245477e2d8395dbd60e010",
        )

    def test_las_mallas_conservan_uv_y_materiales(self):
        # Son mas que las mallas de Blender, y no es un error: con `export_apply` el exportador
        # de glTF evalua los modificadores objeto por objeto, asi que una tanda copiada de un
        # objeto que tiene modificadores no comparte la malla con su original. Son mallas
        # repetidas, cien kilobytes sobre treinta y cuatro megas.
        self.assertEqual(len(self.modelo["meshes"]), 80)




        self.assertEqual(len(self.modelo["materials"]), 45)
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
        self.assertEqual(len(imagenes), 39)
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
