"""Ninguna textura del modelo pasa de `LADO_TOPE`: ni las que viajan en el `.glb` ni las que
Godot extrae de él.

**Son dos redes, y hacen falta las dos.** La exportación achica cada imagen al lado de su grupo,
y eso es lo que deja el `.glb` liviano. Pero Godot importa por su cuenta cada textura que extrae,
y una que llega sin `process/size_limit` sube a la placa de video con el lado que traiga. Medido
el 2026-09-29: de las sesenta texturas de `assets/models/`, la del techo tenía el límite en 0
—que para Godot es «sin límite»— y era la única.
"""

import json
import struct
import unittest

from lib.blender import LADO_TOPE
from lib.repo import RAIZ

MODELOS = RAIZ / "assets/models"
GLB = MODELOS / "SEPT_JUEGOS_PROTOTIPO.glb"

PNG = b"\x89PNG\r\n\x1a\n"
JPEG = b"\xff\xd8\xff"

#: Los marcadores de JPEG que abren un cuadro y traen el lado: SOF0 a SOF15, menos DHT (C4),
#: JPG (C8) y DAC (CC), que comparten el rango y son otra cosa.
CUADROS_JPEG = frozenset(range(0xC0, 0xD0)) - {0xC4, 0xC8, 0xCC}


def parametros_de_importacion(texto: str) -> dict[str, str]:
    """Las claves de la sección `[params]` de un `.import`, con el valor como texto."""
    parametros: dict[str, str] = {}
    seccion = ""
    for linea in texto.splitlines():
        linea = linea.strip()
        if linea.startswith("[") and linea.endswith("]"):
            seccion = linea[1:-1]
        elif seccion == "params" and "=" in linea:
            clave, valor = linea.split("=", 1)
            parametros[clave] = valor
    return parametros


def lado_de_la_imagen(datos: bytes) -> tuple[int, int]:
    """El ancho y el alto de una imagen PNG o JPEG, leídos de su cabecera."""
    if datos.startswith(PNG):
        return struct.unpack(">II", datos[16:24])
    if datos.startswith(JPEG):
        indice = 2
        while indice + 9 <= len(datos):
            if datos[indice] != 0xFF:
                indice += 1
                continue
            marcador = datos[indice + 1]
            if marcador in CUADROS_JPEG:
                alto, ancho = struct.unpack(">HH", datos[indice + 5 : indice + 9])
                return ancho, alto
            if marcador == 0xFF:
                # Relleno: el marcador empieza en el 0xFF siguiente, no dos bytes más allá.
                indice += 1
                continue
            if 0xD0 <= marcador <= 0xD9 or marcador == 0x01:
                indice += 2
                continue
            indice += 2 + struct.unpack(">H", datos[indice + 2 : indice + 4])[0]
    raise ValueError("no es un PNG ni un JPEG con cabecera legible")


def imagenes_del_glb(glb: bytes) -> list[tuple[str, bytes]]:
    """Cada imagen embebida en un `.glb`, con su nombre."""
    largo = struct.unpack_from("<I", glb, 12)[0]
    modelo = json.loads(glb[20 : 20 + largo])
    binario = 20 + largo + 8
    imagenes = []
    for imagen in modelo.get("images", []):
        vista = modelo["bufferViews"][imagen["bufferView"]]
        inicio = binario + vista.get("byteOffset", 0)
        imagenes.append((imagen.get("name", "?"), glb[inicio : inicio + vista["byteLength"]]))
    return imagenes


class LoQueGodotExtrae(unittest.TestCase):
    def test_cada_textura_se_importa_con_un_limite_de_lado(self) -> None:
        texturas = [
            ruta
            for ruta in sorted(MODELOS.glob("*.import"))
            if 'importer="texture"' in ruta.read_text(encoding="utf-8")
        ]
        # Sin esto, una carpeta vacía o un filtro roto dejarían el test verde sin mirar nada.
        self.assertGreater(len(texturas), 0)
        for ruta in texturas:
            with self.subTest(textura=ruta.name):
                parametros = parametros_de_importacion(ruta.read_text(encoding="utf-8"))
                limite = parametros.get("process/size_limit")
                self.assertIsNotNone(limite, "sin `process/size_limit`")
                self.assertGreaterEqual(int(limite), 1, "0 es «sin límite» para Godot")
                self.assertLessEqual(int(limite), LADO_TOPE)


class LoQueViajaEnElGlb(unittest.TestCase):
    def test_ninguna_imagen_del_glb_pasa_del_tope(self) -> None:
        imagenes = imagenes_del_glb(GLB.read_bytes())
        self.assertGreater(len(imagenes), 0)
        for nombre, datos in imagenes:
            with self.subTest(imagen=nombre):
                ancho, alto = lado_de_la_imagen(datos)
                self.assertGreater(min(ancho, alto), 0)
                self.assertLessEqual(max(ancho, alto), LADO_TOPE, f"{ancho} x {alto}")


class LaLecturaDeLasCabeceras(unittest.TestCase):
    """Las dos lecturas de arriba, contra datos armados a mano: si leyeran mal, el test del
    `.glb` daría verde sin haber medido nada."""

    def test_el_lado_de_un_png_sale_de_su_ihdr(self) -> None:
        cabecera = PNG + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 1536, 1024)
        self.assertEqual(lado_de_la_imagen(cabecera + b"\x08\x06\x00\x00\x00"), (1536, 1024))

    def test_el_lado_de_un_jpeg_sale_de_su_cuadro_y_no_de_lo_que_viene_antes(self) -> None:
        app0 = b"\xff\xe0" + struct.pack(">H", 16) + b"JFIF\x00" + b"\x00" * 9
        dht = b"\xff\xc4" + struct.pack(">H", 5) + b"\x00\x00\x00"
        sof0 = b"\xff\xc0" + struct.pack(">HBHH", 11, 8, 1536, 1024) + b"\x03\x00\x00"
        self.assertEqual(lado_de_la_imagen(JPEG[:2] + app0 + dht + sof0), (1024, 1536))

    def test_un_byte_de_relleno_antes_del_cuadro_no_lo_esconde(self) -> None:
        # JPEG deja poner cualquier cantidad de 0xFF antes de un marcador. Saltear el relleno de
        # a dos pisa el primer byte del marcador, y el cuadro que trae el lado no se lee nunca.
        sof0 = b"\xff\xc0" + struct.pack(">HBHH", 11, 8, 1536, 1024) + b"\x03\x00\x00"
        self.assertEqual(lado_de_la_imagen(JPEG[:2] + b"\xff" + sof0), (1024, 1536))

    def test_lo_que_no_es_png_ni_jpeg_no_se_lee_como_si_lo_fuera(self) -> None:
        with self.assertRaises(ValueError):
            lado_de_la_imagen(b"RIFF\x00\x00\x00\x00WEBP")

    def test_de_un_import_se_leen_los_parametros_y_no_el_remap(self) -> None:
        texto = (
            '[remap]\n\nimporter="texture"\npath="res://x.ctex"\n\n'
            "[params]\n\ncompress/mode=2\nprocess/size_limit=1024\n"
        )
        parametros = parametros_de_importacion(texto)
        self.assertEqual(parametros["process/size_limit"], "1024")
        self.assertNotIn("importer", parametros)


if __name__ == "__main__":
    unittest.main()
