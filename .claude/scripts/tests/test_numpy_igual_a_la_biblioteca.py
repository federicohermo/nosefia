"""La herramienta de color hace en Blender lo mismo que su biblioteca de referencia.

`lib/color_de_caja.py` es la matemática, probada con listas de Python. La herramienta la repite
sobre arreglos de numpy porque las fuentes llegan a 90 millones de píxeles. **Sin este test, las
dos copias se separan y nadie lo ve.**

Necesita Blender: la CI no lo tiene, y ahí el caso se saltea **diciendo qué no miró**. Un salteo
no es un verde: la comparación corre en la máquina que declara `BLENDER_BIN`.
"""

import os
import random
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

from lib import color_de_caja
from lib.blender import resolver
from lib.repo import RAIZ

SCRIPTS = RAIZ / ".claude" / "scripts"


def _escribir_png(ruta: Path, ancho: int, alto: int, canales: int, datos: list[int]) -> None:
    tipo = {1: 0, 3: 2, 4: 6}[canales]
    paso = ancho * canales
    crudo = b"".join(b"\x00" + bytes(datos[fila * paso : (fila + 1) * paso]) for fila in range(alto))

    def trozo(nombre: bytes, contenido: bytes) -> bytes:
        cuerpo = nombre + contenido
        return struct.pack(">I", len(contenido)) + cuerpo + struct.pack(">I", zlib.crc32(cuerpo))

    ruta.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + trozo(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, tipo, 0, 0, 0))
        + trozo(b"IDAT", zlib.compress(crudo))
        + trozo(b"IEND", b"")
    )


def _predictor(filtro: int, izquierda: int, arriba: int, diagonal: int) -> int:
    if filtro == 1:
        return izquierda
    if filtro == 2:
        return arriba
    if filtro == 3:
        return (izquierda + arriba) // 2
    if filtro == 4:
        p = izquierda + arriba - diagonal
        pa, pb, pc = abs(p - izquierda), abs(p - arriba), abs(p - diagonal)
        if pa <= pb and pa <= pc:
            return izquierda
        return arriba if pb <= pc else diagonal
    return 0


def _leer_png(ruta: Path) -> tuple[int, int, int, list[int]]:
    """Un PNG de 8 bits sin entrelazar: ancho, alto, canales y los bytes de arriba hacia abajo."""
    datos = ruta.read_bytes()
    posicion, ihdr, idat = 8, b"", b""
    while posicion < len(datos):
        largo, nombre = struct.unpack(">I4s", datos[posicion : posicion + 8])
        cuerpo = datos[posicion + 8 : posicion + 8 + largo]
        if nombre == b"IHDR":
            ihdr = cuerpo
        elif nombre == b"IDAT":
            idat += cuerpo
        posicion += 12 + largo
    ancho, alto, profundidad, tipo = struct.unpack(">IIBB", ihdr[:10])
    assert profundidad == 8, f"se esperaba 8 bits y el PNG trae {profundidad}"
    canales = {0: 1, 2: 3, 4: 2, 6: 4}[tipo]
    paso = ancho * canales
    crudo = zlib.decompress(idat)
    filas: list[bytearray] = []
    for fila in range(alto):
        filtro = crudo[fila * (paso + 1)]
        actual = bytearray(crudo[fila * (paso + 1) + 1 : (fila + 1) * (paso + 1)])
        previa = filas[-1] if filas else bytearray(paso)
        for i in range(paso):
            izquierda = actual[i - canales] if i >= canales else 0
            diagonal = previa[i - canales] if i >= canales else 0
            actual[i] = (actual[i] + _predictor(filtro, izquierda, previa[i], diagonal)) & 255
        filas.append(actual)
    return ancho, alto, canales, [byte for fila in filas for byte in fila]


def _blender() -> None:
    ejecutable, _ = resolver(dict(os.environ))
    if ejecutable is None:
        raise unittest.SkipTest(
            "no corre: falta Blender, así que no se comparó el arreglo de numpy con la "
            "biblioteca. Se declara con BLENDER_BIN."
        )


def _correr(*argumentos: str) -> None:
    resultado = subprocess.run(
        [sys.executable, *argumentos], capture_output=True, text=True, encoding="utf-8",
        errors="replace", timeout=300,
    )
    assert resultado.returncode == 0, resultado.stdout + resultado.stderr


def _niveles(pixel) -> tuple[float, ...]:
    return tuple(round(255 * canal) / 255 for canal in pixel)


def _caja(lado: int, base, variacion: float, semilla: int):
    azar = random.Random(semilla)
    pixeles = []
    for fila in range(lado):
        for columna in range(lado):
            if fila < 4 and columna < 4:
                pixeles.append((0.0, 0.0, 0.0))
            else:
                roce = (azar.random() - 0.5) * variacion
                pixeles.append(_niveles(tuple(min(1.0, max(0.0, c + roce)) for c in base)))
    return pixeles


class ElColor(unittest.TestCase):
    def test_en_blender_da_lo_mismo_que_la_biblioteca(self):
        _blender()
        lado = 16
        original = _caja(lado, (0.55, 0.42, 0.28), 0.2, 1)
        nueva = _caja(lado, (0.72, 0.52, 0.30), 0.3, 2)
        with tempfile.TemporaryDirectory() as carpeta:
            base = Path(carpeta)
            for nombre, pixeles in (("nueva", nueva), ("original", original)):
                bytes_ = [round(255 * canal) for pixel in pixeles for canal in pixel]
                _escribir_png(base / f"{nombre}.png", lado, lado, 3, bytes_)
            salida = base / "salida.png"
            _correr(
                str(SCRIPTS / "igualar_color_de_caja.py"), str(base / "nueva.png"),
                str(base / "original.png"), str(salida),
            )
            _, _, canales, obtenido = _leer_png(salida)
        self.assertEqual(canales, 3)
        ajuste = color_de_caja.ajustar((lado, lado, nueva), (lado, lado, original))
        esperado = color_de_caja.aplicar(ajuste, (lado, lado, nueva))[2]
        en_bytes = [round(255 * canal) for pixel in esperado for canal in pixel]
        diferencias = [abs(a - b) for a, b in zip(en_bytes, obtenido)]
        self.assertLessEqual(sum(diferencias) / len(diferencias), 1.0)
        self.assertLessEqual(max(diferencias), 4)


if __name__ == "__main__":
    unittest.main()
