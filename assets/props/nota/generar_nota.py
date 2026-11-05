"""Regenera la textura de la nota de Yasmín: su texto, a mano, sobre el papel sin texto.

Uso: python generar_nota.py [--fuente RUTA]. El resultado es determinista para una misma fuente.
"""
import argparse
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

AQUI = Path(__file__).resolve().parent
BASE = AQUI.parent.parent / "models" / "SEPT_JUEGOS_PROTOTIPO_nota sin texto.png"
SALIDA = AQUI.parent.parent / "ui" / "manada" / "pistas" / "nota-bajo-la-puerta.png"
FUENTE = Path("C:/Windows/Fonts/Inkfree.ttf")
SEMILLA = 741
TINTA = (28, 36, 92)
MARGEN = 64
TAMANO = 56
INTERLINEADO = 70

PARRAFOS = [
    "Hola, Enrique.",
    "",
    "Te dejo esto por escrito porque no me estás contestando los mensajes. "
    "En serio, hace falta revisar si hay un cable pelado en el local o algo, "
    "porque se sigue cortando la luz. Por favor, respondé.",
    "",
    "Saludos,",
    "Yasmín.",
]


def renglones(fuente: ImageFont.FreeTypeFont, ancho: int) -> list[str]:
    salida: list[str] = []
    for parrafo in PARRAFOS:
        actual = ""
        for palabra in parrafo.split():
            prueba = f"{actual} {palabra}".strip()
            if fuente.getlength(prueba) <= ancho:
                actual = prueba
            else:
                salida.append(actual)
                actual = palabra
        salida.append(actual)
    return salida


def generar(fuente_ruta: Path, destino: Path) -> None:
    azar = random.Random(SEMILLA)
    papel = Image.open(BASE).convert("RGBA")
    ancho, alto = papel.size
    fuente = ImageFont.truetype(str(fuente_ruta), TAMANO)
    tinta = Image.new("RGBA", papel.size, (0, 0, 0, 0))
    y = MARGEN
    for renglon in renglones(fuente, ancho - 2 * MARGEN):
        x = MARGEN + azar.randint(-6, 10)
        for palabra in renglon.split():
            ancho_de_palabra = int(fuente.getlength(palabra)) + 24
            hoja = Image.new("RGBA", (ancho_de_palabra, TAMANO * 2), (0, 0, 0, 0))
            ImageDraw.Draw(hoja).text((8, TAMANO // 2), palabra, font=fuente, fill=TINTA + (235,))
            hoja = hoja.rotate(azar.uniform(-2.2, 2.2), resample=Image.BICUBIC, expand=False)
            tinta.alpha_composite(hoja, (x - 8, y - TAMANO // 2 + azar.randint(-4, 4)))
            x += int(fuente.getlength(palabra + " "))
        y += INTERLINEADO
    assert y < alto - MARGEN, "el texto no entra en el papel"
    destino.parent.mkdir(parents=True, exist_ok=True)
    Image.alpha_composite(papel, tinta).convert("RGB").save(destino, optimize=True)


if __name__ == "__main__":
    analizador = argparse.ArgumentParser()
    analizador.add_argument("--fuente", type=Path, default=FUENTE)
    generar(analizador.parse_args().fuente, SALIDA)
