"""Pinta ranuras medidas en el panel, sin añadir superficies delante de la hoja."""

import math
import struct
import zlib


def _srgb(lineal: float) -> int:
    valor = 12.92 * lineal if lineal <= 0.0031308 else 1.055 * lineal ** (1 / 2.4) - 0.055
    return round(min(1.0, max(0.0, valor)) * 255)


def _bloque(nombre: bytes, datos: bytes) -> bytes:
    return struct.pack('>I', len(datos)) + nombre + datos + struct.pack(
        '>I', zlib.crc32(nombre + datos)
    )


def png_de_ranuras(
    color: tuple[float, float, float],
    bandas: list[tuple[float, float, float, float]],
    ancho: int = 256,
    alto: int = 512,
    color_interior: tuple[float, float, float] = (.16, .22, .20),
) -> bytes:
    """RGB opaco: las coordenadas V se miden desde abajo, como las UV de Blender."""
    filas = bytearray()
    for y in range(alto):
        filas.append(0)
        v = 1.0 - (y + 0.5) / alto
        for x in range(ancho):
            u = (x + 0.5) / ancho
            pixel = color
            for centro_u, centro_v, lado_u, lado_v in bandas:
                horizontal = (abs(u - centro_u) - lado_u / 2) * ancho
                vertical = (abs(v - centro_v) - lado_v / 2) * alto
                distancia = max(horizontal, vertical)
                if distancia > 1.1:
                    continue
                dentro = min(1.0, max(0.0, 0.5 - distancia))
                # Una pared interior oscura y un bisel inferior claro sugieren profundidad.
                relativo = (v - centro_v) / lado_v
                interior = 0.80 + 0.15 * (0.5 - relativo)
                sombra = tuple(interior * componente for componente in color_interior)
                pixel = tuple(a * (1 - dentro) + b * dentro for a, b in zip(color, sombra))
                if -1.05 <= vertical <= 0.2 and relativo < 0:
                    luz = math.exp(-((vertical + 0.4) / 0.65) ** 2) * 0.24
                    pixel = tuple(a * (1 - luz) + luz for a in pixel)
                break
            filas.extend(_srgb(componente) for componente in pixel)
    cabecera = struct.pack('>IIBBBBB', ancho, alto, 8, 2, 0, 0, 0)
    return b'\x89PNG\r\n\x1a\n' + _bloque(b'IHDR', cabecera) + _bloque(
        b'IDAT', zlib.compress(bytes(filas), 9)
    ) + _bloque(b'IEND', b'')
