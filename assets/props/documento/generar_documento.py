"""Regenera las texturas del documento de la pista 6B desde la exportación de Figma.

Uso: python generar_documento.py --entrada RUTA_DE_LA_EXPORTACION. La exportación es el nodo
1865:1063 de «Manada - UI», tal como la entrega Figma. Su fondo es un color liso que no es parte
del papel: los píxeles de ese color unidos al borde pasan a transparentes, y el papel no cambia.
El dorso es el mismo contorno en blanco. El resultado es determinista.
"""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw

SALIDA = Path(__file__).resolve().parent.parent.parent / "ui" / "manada" / "pistas"
FONDO = (199, 210, 217, 255)
PAPEL_DEL_DORSO = (234, 229, 221, 255)


def recortar(origen: Image.Image) -> Image.Image:
    papel = origen.convert("RGBA")
    assert papel.getpixel((0, 0)) == FONDO, "la exportación no trae el fondo esperado"
    ImageDraw.floodfill(papel, (0, 0), (0, 0, 0, 0), thresh=0)
    return papel


def dorso(papel: Image.Image) -> Image.Image:
    salida = Image.new("RGBA", papel.size, (0, 0, 0, 0))
    salida.paste(PAPEL_DEL_DORSO, mask=papel.getchannel("A").point(lambda a: 255 if a else 0))
    return salida


if __name__ == "__main__":
    analizador = argparse.ArgumentParser()
    analizador.add_argument("--entrada", type=Path, required=True)
    recortado = recortar(Image.open(analizador.parse_args().entrada))
    recortado.save(SALIDA / "documento-impreso.png", optimize=True)
    dorso(recortado).save(SALIDA / "documento-dorso.png", optimize=True)
