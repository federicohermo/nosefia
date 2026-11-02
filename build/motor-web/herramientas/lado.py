"""Pone las capturas de dos lados una al lado de la otra, a la mitad del tamaño, una fila por vista.
Uso: python lado.py <salida.png> <prefijo-a> <prefijo-b> <vista>..."""
import sys
from pathlib import Path
from PIL import Image
R = Path(__file__).resolve().parents[1] / "capturas"
salida, a, b, *vistas = sys.argv[1:]
filas = []
for v in vistas:
    ia, ib = Image.open(R / f"{a}-{v}.png").convert("RGB"), Image.open(R / f"{b}-{v}.png").convert("RGB")
    w, h = ia.size[0] // 2, ia.size[1] // 2
    fila = Image.new("RGB", (w * 2 + 4, h))
    fila.paste(ia.resize((w, h)), (0, 0)); fila.paste(ib.resize((w, h)), (w + 4, 0))
    filas.append(fila)
out = Image.new("RGB", (filas[0].size[0], sum(f.size[1] + 4 for f in filas)))
y = 0
for f in filas:
    out.paste(f, (0, y)); y += f.size[1] + 4
out.save(R / salida)
