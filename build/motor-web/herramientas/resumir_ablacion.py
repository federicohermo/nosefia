"""Junta las corridas de ablacion.sh: carga y CPU por cuadro de cada variante, por API.

Uso: python resumir_ablacion.py
"""
import glob
import json
import statistics
import sys
from pathlib import Path

R = Path(__file__).resolve().parents[1] / "medidas" / "etapa1"
ORDEN = ["todo", "luces-nativas", "fusion-0", "estatico-0", "bundle-0"]


def mediana(v):
    v = [x for x in v if x is not None]
    return f"{statistics.median(v):.2f} ({min(v):.2f} a {max(v):.2f})" if v else "sin dato"


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    datos = {}
    for f in glob.glob(str(R / "abl-r*-*.json")):
        _, _, api, *variante = Path(f).stem.split("-")
        j = json.load(open(f, encoding="utf-8"))
        gon = (j.get("vistas") or {}).get("gondola") or {}
        cpu = ((j.get("cpu_cuadro") or {}).get("gondola") or {}).get("p50")
        carga = (j.get("primera") or {}).get("almacen_ms")
        datos.setdefault((api, "-".join(variante)), []).append((carga and carga / 1000, cpu, gon.get("p50")))
    for api in ("webgl2", "webgpu"):
        print(f"\n## {api}")
        print("| Variante apagada | Carga (s) | CPU por cuadro (ms) | Cuadro (ms) | Corridas |")
        print("|---|---|---|---|---|")
        for var in ORDEN:
            filas = datos.get((api, var))
            if not filas:
                continue
            nombre = "ninguna (todo prendido)" if var == "todo" else var.replace("-", "=")
            print(f"| {nombre} | {mediana([x[0] for x in filas])} | {mediana([x[1] for x in filas])} | {mediana([x[2] for x in filas])} | {len(filas)} |")


main()
