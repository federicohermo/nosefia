"""Los tests de `lib/blender.py`.

Se prueba que **no** esté Blender en una máquina que sí lo tiene, que es el caso que importa: el
mensaje de «no se encontró» es lo único que ve quien clona el repo, y un mensaje sin la salida
escrita produce el reflejo de buscar cómo saltear el paso.
"""

import json
import struct
import unittest
import zlib

from lib.blender import (
    EDIFICIO,
    FUENTES,
    LADO_MAXIMO,
    LADO_TOPE,
    MUEBLES,
    ORIGEN_DE_CADA_GRUPO,
    PRODUCTOS,
    SERIE,
    VARIABLE,
    achicada,
    como_declararlo,
    es_un_array,
    grupo_de,
    recomprimir_las_imagenes,
    recomprimir_png,
    resolver,
)


class Resolver(unittest.TestCase):
    def test_la_variable_gana_sobre_la_instalacion(self):
        # Quien la declaró eligió una versión. Que el instalador haya dejado otra en su lugar
        # de siempre no puede pisar esa elección.
        binario, origen = resolver(
            {VARIABLE: "C:/elegido/blender.exe"},
            existe=lambda ruta: True,
            ubicaciones=("C:/instalado/blender.exe",),
        )
        self.assertEqual((binario, origen), ("C:/elegido/blender.exe", VARIABLE))

    def test_sin_variable_cae_en_la_instalacion(self):
        binario, origen = resolver(
            {}, existe=lambda ruta: ruta == "C:/instalado/blender.exe",
            ubicaciones=("C:/otro/blender.exe", "C:/instalado/blender.exe"),
        )
        self.assertEqual((binario, origen), ("C:/instalado/blender.exe", "instalación"))

    def test_una_variable_que_apunta_a_la_nada_no_se_usa(self):
        binario, _ = resolver(
            {VARIABLE: "C:/borrado/blender.exe"}, existe=lambda ruta: False, ubicaciones=()
        )
        self.assertIsNone(binario)

    def test_sin_nada_contesta_que_no_hay(self):
        self.assertEqual(resolver({}, existe=lambda ruta: False, ubicaciones=()), (None, None))


class ElMensaje(unittest.TestCase):
    def test_sin_declarar_dice_como_declararlo_y_que_hay_que_abrir_otra_terminal(self):
        mensaje = como_declararlo({})
        self.assertIn(f"setx {VARIABLE}", mensaje)
        self.assertIn(SERIE, mensaje)
        # La trampa de Windows, que ya costó una tarde con `GODOT_BIN`.
        self.assertIn("terminal nueva", mensaje)

    def test_declarada_y_rota_lo_dice_con_la_ruta(self):
        mensaje = como_declararlo({VARIABLE: "C:/borrado/blender.exe"})
        self.assertIn("C:/borrado/blender.exe", mensaje)
        self.assertIn("no existe", mensaje)


class ElModificadorQueSeApaga(unittest.TestCase):
    """Qué nombre cuenta como uno de los que llenan el estante.

    La comparación exacta contra `Array` dejaba prendidos los 34 `Array.001` del `.blend`, y el
    producto salía al doble o al cuádruple de vértices. El síntoma no nombra ni a Blender ni al
    modificador: aparece como dos productos vecinos que se pisan.
    """

    def test_el_nombre_pelado_cuenta(self):
        self.assertTrue(es_un_array("Array"))

    def test_el_sufijo_que_agrega_blender_al_duplicar_tambien(self):
        for nombre in ("Array.001", "Array.002", "Array.014"):
            with self.subTest(nombre=nombre):
                self.assertTrue(es_un_array(nombre))

    def test_otro_modificador_que_empieza_igual_no_cuenta(self):
        # `Smooth by Angle` está en el mismo `.blend` y tiene que quedar prendido. Y un nombre
        # que apenas comparte el prefijo no es un duplicado: el sufijo de Blender lleva punto.
        for nombre in ("Smooth by Angle", "Arrayado", "ArrayDeVerdad"):
            with self.subTest(nombre=nombre):
                self.assertFalse(es_un_array(nombre))


class ElGrupoDeCadaImagen(unittest.TestCase):
    """De qué grupo es una imagen, por la ruta de su archivo adentro de `assets/source/`.

    El grupo decide el lado con el que viaja en el `.glb`, y el lado lo decide el usuario
    mirando capturas: una etiqueta de producto que cae en otro grupo cambia sin que nadie la
    haya mirado.
    """

    def test_las_etiquetas_de_las_carpetas_de_producto_son_productos(self):
        for ruta in (
            "products-textured/Cora cola/cora cola.png",
            "products-cam/NUEVOS 22-9/Oaaaa/oaaaa completo.png",
        ):
            with self.subTest(ruta=ruta):
                self.assertEqual(grupo_de(ruta), PRODUCTOS)

    def test_una_etiqueta_guardada_con_la_utileria_es_producto_y_la_utileria_no(self):
        # `textures/props/` mezcla la lata de Marranos y el alfajor Jorgillo con la caja
        # registradora y el portón: la carpeta sola no alcanza para saber qué es cada una.
        self.assertEqual(grupo_de("textures/props/jorgillata.png"), PRODUCTOS)
        self.assertEqual(grupo_de("textures/props/textura caja.png"), MUEBLES)

    def test_las_paredes_los_pisos_y_los_techos_son_edificio(self):
        self.assertEqual(grupo_de("third-party/128x128/Bricks/piso_baseColor.png"), EDIFICIO)

    def test_lo_demas_es_mueble(self):
        for ruta in (
            "textures/furniture/Puerta/puerta textura.png",
            "third-party/128x128/Wood/Wood_09-128x128.png",
            "third-party/psx_trash_can/textures/Material.001_baseColor.png",
        ):
            with self.subTest(ruta=ruta):
                self.assertEqual(grupo_de(ruta), MUEBLES)

    def test_una_imagen_que_no_sale_de_source_es_mueble(self):
        # Las empaquetadas con la ruta de otra máquina —la góndola, el inodoro— no tienen
        # carpeta que leer.
        self.assertEqual(grupo_de(None), MUEBLES)

    def test_un_nombre_que_apenas_empieza_igual_no_cuenta(self):
        self.assertEqual(grupo_de("products-camara/x.png"), MUEBLES)
        self.assertEqual(grupo_de("textures/props/jorgillata.png.bak"), MUEBLES)

    def test_el_mismo_acento_escrito_de_otra_forma_es_el_mismo_archivo(self):
        # «ó» puede llegar como un carácter o como «o» más el acento suelto, según quién
        # escribió la ruta. Para el disco es el mismo archivo.
        descompuesta = "textures/props/jabón liquido.png"
        self.assertEqual(grupo_de(descompuesta), PRODUCTOS)

    def test_cada_origen_de_la_tabla_existe(self):
        # Una entrada que no existe no clasifica nada, y el archivo que tenía que clasificar
        # cae en otro grupo sin que ningún test lo diga.
        for origen in ORIGEN_DE_CADA_GRUPO:
            with self.subTest(origen=origen):
                self.assertTrue((FUENTES / origen).exists(), FUENTES / origen)

    def test_cada_grupo_tiene_su_lado_y_ninguno_pasa_del_tope(self):
        self.assertEqual(set(ORIGEN_DE_CADA_GRUPO.values()) | {MUEBLES}, set(LADO_MAXIMO))
        for grupo, lado in LADO_MAXIMO.items():
            with self.subTest(grupo=grupo):
                self.assertGreaterEqual(lado, 1)
                self.assertLessEqual(lado, LADO_TOPE)


class ElTamanoConElQueViaja(unittest.TestCase):
    def test_una_imagen_que_entra_viaja_igual_y_la_chica_no_se_agranda(self):
        self.assertEqual(achicada(128, 128, 1024), (128, 128))
        self.assertEqual(achicada(1024, 1024, 1024), (1024, 1024))

    def test_la_que_no_entra_deja_su_lado_mayor_en_el_maximo(self):
        self.assertEqual(achicada(1254, 1254, 512), (512, 512))
        self.assertEqual(achicada(2048, 256, 1024), (1024, 128))

    def test_conserva_la_proporcion(self):
        # La puerta: 1024 x 1536.
        self.assertEqual(achicada(1024, 1536, 1024), (683, 1024))
        self.assertEqual(achicada(9937, 7270, 512), (512, 375))

    def test_un_lado_nunca_queda_en_cero(self):
        self.assertEqual(achicada(4096, 2, 512), (512, 1))


FIRMA_PNG = b"\x89PNG\r\n\x1a\n"


def _trozo(tipo: bytes, cuerpo: bytes) -> bytes:
    crc = zlib.crc32(tipo + cuerpo)
    return struct.pack(">I", len(cuerpo)) + tipo + cuerpo + struct.pack(">I", crc)


def _filas(ancho: int, alto: int) -> bytes:
    """Filas RGB ya filtradas (filtro 0), con un degradé que se deja comprimir."""
    return b"".join(b"\x00" + bytes((x + y) % 256 for x in range(ancho * 3)) for y in range(alto))


def _png(filas: bytes, nivel: int, partes: int = 1, ancho: int = 16, alto: int = 16) -> bytes:
    comprimido = zlib.compress(filas, nivel)
    corte = len(comprimido) // partes + 1
    idat = b"".join(
        _trozo(b"IDAT", comprimido[i : i + corte]) for i in range(0, len(comprimido), corte)
    )
    return (
        FIRMA_PNG
        + _trozo(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 2, 0, 0, 0))
        + _trozo(b"tEXt", b"Software\x00Blender")
        + idat
        + _trozo(b"IEND", b"")
    )


def _trozos(png: bytes) -> list[tuple[bytes, bytes]]:
    trozos, indice = [], len(FIRMA_PNG)
    while indice < len(png):
        largo = struct.unpack(">I", png[indice : indice + 4])[0]
        tipo, cuerpo = png[indice + 4 : indice + 8], png[indice + 8 : indice + 8 + largo]
        (crc,) = struct.unpack(">I", png[indice + 8 + largo : indice + 12 + largo])
        assert crc == zlib.crc32(tipo + cuerpo), f"CRC roto en {tipo!r}"
        trozos.append((tipo, cuerpo))
        indice += 12 + largo
    return trozos


def _pixeles(png: bytes) -> bytes:
    return zlib.decompress(b"".join(cuerpo for tipo, cuerpo in _trozos(png) if tipo == b"IDAT"))


class LaRecompresionDeUnPng(unittest.TestCase):
    """El exportador de glTF escribe cada imagen que achica con el zlib flojo de Blender.

    Recomprimir el mismo flujo con el nivel más alto no cambia un solo píxel: es la misma
    imagen, filtrada igual, empaquetada más chica.
    """

    def test_sale_mas_chico_con_los_mismos_pixeles_y_los_demas_trozos_en_su_lugar(self):
        filas = _filas(16, 16)
        flojo = _png(filas, 0)
        apretado = recomprimir_png(flojo)
        self.assertLess(len(apretado), len(flojo))
        self.assertEqual(_pixeles(apretado), filas)
        tipos = [tipo for tipo, _ in _trozos(apretado)]
        self.assertEqual(tipos, [b"IHDR", b"tEXt", b"IDAT", b"IEND"])
        self.assertEqual(_trozos(apretado)[0], _trozos(flojo)[0])

    def test_un_idat_partido_en_varios_trozos_se_une_en_uno(self):
        filas = _filas(16, 16)
        apretado = recomprimir_png(_png(filas, 0, partes=3))
        self.assertEqual([tipo for tipo, _ in _trozos(apretado)].count(b"IDAT"), 1)
        self.assertEqual(_pixeles(apretado), filas)

    def test_uno_que_ya_viene_apretado_no_crece(self):
        apretado = _png(_filas(16, 16), 9)
        self.assertLessEqual(len(recomprimir_png(apretado)), len(apretado))

    def test_lo_que_no_es_png_vuelve_como_llego(self):
        jpeg = b"\xff\xd8\xff\xe0" + b"\x00" * 32
        self.assertEqual(recomprimir_png(jpeg), jpeg)


def _glb(modelo: dict, binario: bytes) -> bytes:
    texto = json.dumps(modelo).encode()
    texto += b" " * (-len(texto) % 4)
    binario += b"\x00" * (-len(binario) % 4)
    total = 12 + 8 + len(texto) + 8 + len(binario)
    return (
        struct.pack("<4sII", b"glTF", 2, total)
        + struct.pack("<I4s", len(texto), b"JSON")
        + texto
        + struct.pack("<I4s", len(binario), b"BIN\x00")
        + binario
    )


def _partes(glb: bytes) -> tuple[dict, bytes]:
    magia, version, total = struct.unpack_from("<4sII", glb, 0)
    assert (magia, version, total) == (b"glTF", 2, len(glb)), "cabecera rota"
    largo, tipo = struct.unpack_from("<I4s", glb, 12)
    assert tipo == b"JSON" and largo % 4 == 0
    modelo = json.loads(glb[20 : 20 + largo])
    largo_bin, tipo_bin = struct.unpack_from("<I4s", glb, 20 + largo)
    assert tipo_bin == b"BIN\x00" and largo_bin % 4 == 0
    return modelo, glb[28 + largo : 28 + largo + largo_bin]


def _vista(modelo: dict, binario: bytes, indice: int) -> bytes:
    vista = modelo["bufferViews"][indice]
    inicio = vista.get("byteOffset", 0)
    return binario[inicio : inicio + vista["byteLength"]]


class LaRecompresionDelGlb(unittest.TestCase):
    """Las imágenes del `.glb` se recomprimen, y todo lo que viene después se corre."""

    def setUp(self):
        self.geometria = struct.pack("<3f", 1.0, 2.0, 3.0)
        self.filas = _filas(16, 16)
        self.imagen = _png(self.filas, 0)
        self.indices = struct.pack("<3H", 0, 1, 2) + b"\x00\x00"
        binario = self.geometria
        desde_imagen = len(binario)
        binario += self.imagen + b"\x00" * (-len(self.imagen) % 4)
        desde_indices = len(binario)
        binario += self.indices
        self.modelo = {
            "asset": {"version": "2.0"},
            "buffers": [{"byteLength": len(binario)}],
            "bufferViews": [
                {"buffer": 0, "byteOffset": 0, "byteLength": len(self.geometria)},
                {"buffer": 0, "byteOffset": desde_imagen, "byteLength": len(self.imagen)},
                {"buffer": 0, "byteOffset": desde_indices, "byteLength": 6},
            ],
            "accessors": [{"bufferView": 2, "byteOffset": 0, "componentType": 5123, "count": 3}],
            "images": [{"name": "etiqueta", "mimeType": "image/png", "bufferView": 1}],
        }
        self.glb = _glb(self.modelo, binario)

    def test_la_imagen_achica_y_la_geometria_llega_intacta(self):
        nuevo = recomprimir_las_imagenes(self.glb)
        self.assertLess(len(nuevo), len(self.glb))
        modelo, binario = _partes(nuevo)
        self.assertEqual(_vista(modelo, binario, 0), self.geometria)
        self.assertEqual(_pixeles(_vista(modelo, binario, 1)), self.filas)
        self.assertEqual(_vista(modelo, binario, 2), self.indices[:6])
        self.assertEqual(modelo["buffers"][0]["byteLength"], len(binario))

    def test_cada_vista_sigue_empezando_en_un_multiplo_de_cuatro(self):
        modelo, _ = _partes(recomprimir_las_imagenes(self.glb))
        for vista in modelo["bufferViews"]:
            self.assertEqual(vista.get("byteOffset", 0) % 4, 0)

    def test_lo_que_no_se_toca_del_json_queda_igual(self):
        modelo, _ = _partes(recomprimir_las_imagenes(self.glb))
        self.assertEqual(modelo["accessors"], self.modelo["accessors"])
        self.assertEqual(modelo["images"], self.modelo["images"])

    def test_un_glb_sin_imagenes_vuelve_con_la_geometria_intacta(self):
        sin = dict(self.modelo, images=[], bufferViews=self.modelo["bufferViews"][:1])
        sin["buffers"] = [{"byteLength": len(self.geometria)}]
        modelo, binario = _partes(recomprimir_las_imagenes(_glb(sin, self.geometria)))
        self.assertEqual(_vista(modelo, binario, 0), self.geometria)


if __name__ == "__main__":
    unittest.main()
