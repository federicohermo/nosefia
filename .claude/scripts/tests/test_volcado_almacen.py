"""El volcado del almacén lee bytes de Godot y los entrega al visor: se prueba con bytes armados.

Ninguna prueba necesita Godot ni el proyecto importado, que la CI no tiene a mano.
"""

import struct
import unittest

from lib import volcado_almacen as v


def _ctex(ancho: int, alto: int, mips: int, formato: int, datos: bytes, cabecera: int = 0x34):
    b = bytearray(cabecera)
    b[:4] = b"GST2"
    struct.pack_into("<HH", b, 0x28, ancho, alto)
    struct.pack_into("<II", b, 0x2C, mips, formato)
    return bytes(b) + datos


def _registro(indices: list[int], rect: tuple[float, ...]) -> bytes:
    cuerpo = struct.pack("<2I", v.TIPO_DE_REGISTRO, len(indices))
    cuerpo += struct.pack("<%dI" % len(indices), *indices)
    cuerpo += struct.pack("<I", v.MARCA_DE_RECTANGULO) + struct.pack("<4f", *rect)
    return cuerpo + b"\x00" * 16


class Rectangulos(unittest.TestCase):
    def test_encuentra_un_registro_que_no_esta_alineado(self):
        nombres = ["almacen", "gondola"]
        b = b"\xff" * 5 + _registro([0, 1], (0.125, 0.25, 0.375, 0.5)) + b"\x00" * 80
        esperado = {"almacen/gondola": [0.125, 0.25, 0.375, 0.5]}
        self.assertEqual(v.rectangulos(b, nombres), esperado)

    def test_lee_varios_registros_seguidos(self):
        nombres = ["a", "b", "c"]
        r = _registro([0], (0.0, 0.0, 0.5, 0.5)) + _registro([1, 2], (0.5, 0.0, 0.25, 0.25))
        salida = v.rectangulos(b"\x00" * 3 + r + b"\x00" * 80, nombres)
        self.assertEqual(sorted(salida), ["a", "b/c"])

    def test_sin_registros_dice_que_no_los_encontro(self):
        with self.assertRaises(ValueError):
            v.buscar_inicio(b"\x00" * 200, ["a"])

    def test_un_indice_fuera_de_la_tabla_no_es_un_registro(self):
        b = _registro([7], (0.1, 0.1, 0.2, 0.2)) + b"\x00" * 80
        with self.assertRaises(ValueError):
            v.buscar_inicio(b, ["a"])

    def test_las_filas_usadas_llegan_al_rectangulo_mas_bajo_y_dos_mas(self):
        rects = {"a": [0.0, 0.0, 0.5, 0.25], "b": [0.0, 0.25, 0.5, 0.25]}
        self.assertEqual(v.filas_usadas(rects), 1024 + 2)


class Lightmap(unittest.TestCase):
    def test_recortar_deja_las_filas_pedidas(self):
        crudo = bytes(range(256)) * (v.LADO_DEL_ATLAS * 8 * 3 // 256 + 1)
        self.assertEqual(len(v.recortar_lightmap(crudo, 2)), v.LADO_DEL_ATLAS * 2 * 8)

    def test_un_atlas_mas_corto_que_las_filas_usadas_es_un_error(self):
        with self.assertRaises(ValueError):
            v.recortar_lightmap(b"\x00" * 100, 4)

    def test_el_ctexarray_tiene_que_ser_un_ctexarray(self):
        with self.assertRaises(ValueError):
            v.capas_del_lightmap(b"GST2" + b"\x00" * 100, 4)

    def test_las_cuatro_capas_salen_con_las_filas_de_bloques_pedidas(self):
        capa = v.LADO_DEL_ATLAS * v.LADO_DEL_ATLAS
        cuerpo = b"".join(bytes([k]) * capa + b"\x00" * 16 for k in range(v.CAPAS_DEL_LIGHTMAP))
        b = b"GSTL" + b"\x00" * 48 + cuerpo
        capas = v.capas_del_lightmap(b, 3)
        self.assertEqual([len(c) for c in capas], [3 * (v.LADO_DEL_ATLAS // 4) * 16] * 4)
        self.assertEqual([c[0] for c in capas], [0, 1, 2, 3])

    def test_el_png_de_la_previa_lleva_la_firma_y_cierra_con_iend(self):
        salida = v.png(2, 2, bytes(12))
        self.assertTrue(salida.startswith(b"\x89PNG\r\n\x1a\n"))
        self.assertTrue(salida.endswith(b"IEND" + struct.pack(">I", 0xAE426082)))


class Sondas(unittest.TestCase):
    def test_la_cabecera_cuenta_puntos_tetraedros_y_coeficientes(self):
        s = {"points": [0.0] * 6, "tetrahedra": [0, 1, 0, 1], "sh": [0.5] * 8, "bounds": None}
        cuerpo, resumen = v.sondas_a_bytes(s)
        self.assertEqual(struct.unpack_from("<3I", cuerpo), (2, 1, 2))
        self.assertEqual(len(cuerpo), 12 + 6 * 4 + 4 * 4 + 8 * 4)
        self.assertEqual((resumen["puntos"], resumen["tetraedros"]), (2, 1))


class Texturas(unittest.TestCase):
    def test_un_bc1_de_cuatro_por_cuatro_son_ocho_bytes(self):
        self.assertEqual(v.bytes_de_un_nivel(4, 4, 8), 8)
        self.assertEqual(v.bytes_de_un_nivel(1, 1, 16), 16)

    def test_lee_los_niveles_de_un_ctex_con_mips(self):
        datos = b"\x01" * 32 + b"\x02" * 8
        formato, ancho, alto, niveles, cuerpo = v.leer_ctex(_ctex(8, 8, 1, 17, datos))
        self.assertEqual((formato, ancho, alto), ("bc1", 8, 8))
        self.assertEqual(niveles, [(8, 8, 32), (4, 4, 8)])
        self.assertEqual(cuerpo, datos)

    def test_no_acepta_un_archivo_que_no_es_ctex(self):
        with self.assertRaises(ValueError):
            v.leer_ctex(b"NOPE" + b"\x00" * 100)

    def test_no_acepta_un_formato_que_el_visor_no_sube(self):
        with self.assertRaises(ValueError):
            v.leer_ctex(_ctex(4, 4, 0, 99, b"\x00" * 8))

    def test_datos_que_no_empiezan_donde_se_espera_son_un_error(self):
        with self.assertRaises(ValueError):
            v.leer_ctex(_ctex(4, 4, 0, 17, b"\x00" * 8, cabecera=0x40))

    def test_el_paquete_apila_las_texturas_sin_huecos(self):
        paquete = v.Paquete()
        paquete.agregar_textura("a", _ctex(4, 4, 0, 17, b"\x01" * 8))
        paquete.agregar_textura("b", _ctex(8, 8, 1, 17, b"\x02" * 40))
        self.assertEqual(paquete.indice["a"]["niveles"], [{"w": 4, "h": 4, "o": 0, "n": 8}])
        self.assertEqual(paquete.indice["b"]["niveles"][0]["o"], 8)
        self.assertEqual(paquete.indice["b"]["niveles"][1]["o"], 8 + 32)
        self.assertEqual(len(paquete.binario()), paquete.cursor)

    def test_el_lightmap_entra_al_paquete_con_sus_cuatro_capas(self):
        paquete = v.Paquete()
        paquete.agregar_lightmap([b"\x00" * 16] * v.CAPAS_DEL_LIGHTMAP, 1)
        self.assertEqual(sorted(paquete.indice), ["__lightmap%d__" % k for k in range(4)])
        self.assertEqual(paquete.indice["__lightmap3__"]["niveles"][0]["o"], 48)

    def test_los_corchetes_de_un_nombre_no_son_un_conjunto_de_glob(self):
        self.assertEqual(v.glob_escapado("caja[1].png"), "caja[[]1].png")


if __name__ == "__main__":
    unittest.main()
