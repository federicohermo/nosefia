"""Compara cada variante contra la base, por vista: cuántos píxeles cambian y cuánto."""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

carpeta = Path(sys.argv[1])
for vista in ["cara_de_lado", "cabecera", "bandeja_de_heladera"]:
    base = np.asarray(Image.open(carpeta / f"{vista}-base.png").convert("RGB")).astype(int)
    for variante in ["identidad", "suave", "media", "fuerte", "propuesta"]:
        ruta = carpeta / f"{vista}-{variante}.png"
        if not ruta.exists():
            continue
        otra = np.asarray(Image.open(ruta).convert("RGB")).astype(int)
        dif = np.abs(otra - base).max(axis=2)
        print(
            f"{vista:22s} {variante:10s} max={dif.max():3d} "
            f"pix>2={int((dif > 2).sum()):7d} pix>8={int((dif > 8).sum()):7d}"
        )
