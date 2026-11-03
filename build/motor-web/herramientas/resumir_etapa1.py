"""Junta las corridas de medidas/etapa1 en una tabla por modo: mediana y rango de cada lado.

Uso: python resumir_etapa1.py [modo ...]     (sin modos, todos los que haya)
"""
import glob
import json
import statistics
import sys
from pathlib import Path

R = Path(__file__).resolve().parents[1] / "medidas" / "etapa1"
NOMBRES = {
    "G": "Godot WebGL2 (la web de hoy)",
    "T": "Three.js WebGPU",
    "W": "Three.js WebGL2",
    "P": "PlayCanvas WebGL2",
    "t": "Three.js WebGPU sin las palancas",
    "w": "Three.js WebGL2 sin las palancas",
}
METRICAS = [
    ("almacen", "Almacén en pantalla, primera visita (s)"),
    ("segunda", "Segunda visita (s)"),
    ("mb", "Bytes por la red (MiB)"),
    ("mem", "Memoria de Chrome (MB)"),
    ("p50", "Cuadro en la góndola, mediana (ms)"),
    ("p95", "Cuadro en la góndola, p95 (ms)"),
    ("cpu", "CPU por cuadro en la góndola, mediana (ms)"),
    ("largo", "Cuadro más largo recorriendo (ms)"),
    ("err", "Errores en la consola"),
]


def sacar(lado, j):
    vistas = j.get("vistas") or {}
    gon = vistas.get("gondola") or {}
    if lado == "G":
        return {
            "almacen": (j.get("almacen_ms") or 0) / 1000 or None,
            "segunda": None,
            "mb": (j.get("bytes_total") or 0) / 1048576 or None,
            "mem": j.get("memoria_mb"),
            "p50": gon.get("p50"),
            "p95": gon.get("p95"),
            "cpu": None,
            "largo": (j.get("caminando") or {}).get("max"),
            "err": len(j.get("errores") or []),
        }
    p, s = j.get("primera") or {}, j.get("segunda") or {}
    return {
        "almacen": (p.get("almacen_ms") or 0) / 1000 or None,
        "segunda": (s.get("almacen_ms") or 0) / 1000 or None,
        "mb": (p.get("bytes_total") or 0) / 1048576 or None,
        "mem": j.get("memoria_mb"),
        "p50": gon.get("p50"),
        "p95": gon.get("p95"),
        "cpu": ((j.get("cpu") or {}).get("gondola") or {}).get("p50"),
        "largo": j.get("recorrido_max_ms"),
        "err": len(j.get("errores") or []),
    }


def celda(valores):
    v = [x for x in valores if x is not None]
    if not v:
        return "sin dato"
    return f"{statistics.median(v):.2f} ({min(v):.2f} a {max(v):.2f}), n={len(v)}"


def modos_presentes():
    return sorted({Path(f).stem.split("-")[0] for f in glob.glob(str(R / "*-r*-*.json"))})


def main():
    for modo in sys.argv[1:] or modos_presentes():
        por_lado = {}
        for f in sorted(glob.glob(str(R / f"{modo}-r*-*.json"))):
            lado = Path(f).stem.split("-")[-1]
            por_lado.setdefault(lado, []).append(sacar(lado, json.load(open(f, encoding="utf-8"))))
        print(f"\n# Modo {modo}")
        for lado in "GTWPtw":
            if lado not in por_lado:
                continue
            filas = por_lado[lado]
            print(f"\n## {NOMBRES[lado]}, {len(filas)} corridas")
            for clave, nombre in METRICAS:
                if clave == "err":
                    print(f"- {nombre}: {sum(r['err'] for r in filas)}")
                else:
                    print(f"- {nombre}: {celda([r[clave] for r in filas])}")


main()
