"""Compara capturas con las de Godot: brillo medio por canal, error medio y una imagen de diferencias.
Uso: python comparar.py <prefijo-a> <prefijo-b> <vista>...  (capturas/<prefijo>-<vista>.png)"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parents[1] / "capturas"


def cargar(p):
    return np.asarray(Image.open(p).convert("RGB")).astype(np.float32)


def main():
    a, b, *vistas = sys.argv[1:]
    for v in vistas:
        ia, ib = cargar(RAIZ / f"{a}-{v}.png"), cargar(RAIZ / f"{b}-{v}.png")
        h = min(ia.shape[0], ib.shape[0]); w = min(ia.shape[1], ib.shape[1])
        ia, ib = ia[:h, :w], ib[:h, :w]
        # Se ignora la esquina de los textos de cada visor.
        m = np.ones((h, w), bool); m[:80, :260] = False; m[-110:, :140] = False
        dif = np.abs(ia - ib).mean(axis=2)
        print(f"{v:10s} media {a} {ia[m].mean(axis=0).round(1)} {b} {ib[m].mean(axis=0).round(1)}  error medio {dif[m].mean():.2f}  >32: {(dif[m] > 32).mean() * 100:.2f}%")
        Image.fromarray(np.clip(dif * 4, 0, 255).astype(np.uint8)).save(RAIZ / f"dif-{a}-{b}-{v}.png")


main()
