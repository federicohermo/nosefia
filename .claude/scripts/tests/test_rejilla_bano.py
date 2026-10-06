"""El PNG mantiene tamaño web y pinta únicamente las bandas medidas."""

import struct
import unittest
import zlib

from lib.rejilla_bano import png_de_ranuras


class TestRejillaBano(unittest.TestCase):
    def test_png_opaco_tiene_256_por_512_y_crc_validos(self):
        datos = png_de_ranuras((.86, .86, .82), [])
        self.assertEqual(datos[:8], b'\x89PNG\r\n\x1a\n')
        self.assertEqual(struct.unpack('>IIBBBBB', datos[16:29]), (256, 512, 8, 2, 0, 0, 0))
        posicion = 8
        while posicion < len(datos):
            largo = struct.unpack_from('>I', datos, posicion)[0]
            final = posicion + 8 + largo
            self.assertEqual(struct.unpack_from('>I', datos, final)[0],
                             zlib.crc32(datos[posicion + 4:final]))
            posicion = final + 4
        self.assertEqual(posicion, len(datos))

    def test_las_cuatro_bandas_son_oscuras_sin_manchar_el_resto_del_panel(self):
        bandas = [(.5, (.35 + i * .06 - .317237) / 2.32, .46 / 1.42, .022 / 2.32)
                  for i in range(4)]
        datos = png_de_ranuras((.86, .86, .82), bandas)
        largo = struct.unpack_from('>I', datos, 33)[0]
        filas = zlib.decompress(datos[41:41 + largo])

        def pixel(u, v):
            x, y = int(u * 256), int((1 - v) * 512)
            inicio = y * (1 + 256 * 3) + 1 + x * 3
            return tuple(filas[inicio:inicio + 3])

        blanco = pixel(.5, .5)
        for banda in bandas:
            self.assertLess(max(pixel(.5, banda[1])), min(blanco) - 80)
            self.assertEqual(pixel(.1, banda[1]), blanco)
            self.assertEqual(pixel(.5, banda[1] + .03 / 2.32), blanco)


if __name__ == '__main__':
    unittest.main()
