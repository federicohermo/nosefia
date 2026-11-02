"""Junta las corridas de medidas/campana en una tabla: mediana y rango por lado.
Uso: python resumir.py <modo: vsync|libre>"""
import glob, json, statistics, sys
from pathlib import Path

R = Path(__file__).resolve().parents[1] / "medidas" / "campana"
NOMBRES = {"G": "Godot WebGL2 (la web de hoy)", "T": "Three.js WebGPU", "W": "Three.js WebGL2", "P": "PlayCanvas WebGL2"}


def sacar(lado, j):
    if lado == "G":
        v = j.get("vistas", {})
        return {
            "almacen_s": (j.get("almacen_ms") or 0) / 1000 or None,
            "segunda_s": None,
            "mb": (j.get("bytes_total") or 0) / 1048576 or None,
            "mem": j.get("memoria_mb"),
            "gon50": v.get("gondola", {}).get("p50"), "gon95": v.get("gondola", {}).get("p95"),
            "rec95": j.get("recorrido", {}).get("p95") if j.get("recorrido") else None,
            "camina95": j.get("caminando", {}).get("p95"),
            "largo": j.get("caminando", {}).get("max"),
        }
    p = j.get("primera", {})
    s = j.get("segunda", {})
    v = j.get("vistas", {})
    p95s = [x["p95"] for x in v.values() if x]
    return {
        "almacen_s": (p.get("almacen_ms") or 0) / 1000 or None,
        "segunda_s": (s.get("almacen_ms") or 0) / 1000 or None,
        "mb": (p.get("bytes_total") or 0) / 1048576 or None,
        "mem": j.get("memoria_mb"),
        "gon50": v.get("gondola", {}).get("p50"), "gon95": v.get("gondola", {}).get("p95"),
        "rec95": max(p95s) if p95s else None,
        "camina95": None,
        "largo": j.get("recorrido_max_ms"),
    }


def fila(valores):
    v = [x for x in valores if x is not None]
    if not v:
        return "—"
    return f"{statistics.median(v):.2f} ({min(v):.2f}–{max(v):.2f}) n={len(v)}"


def main():
    modo = sys.argv[1]
    por_lado = {}
    for f in sorted(glob.glob(str(R / f"{modo}-r*-*.json"))):
        lado = Path(f).stem.split("-")[-1]
        por_lado.setdefault(lado, []).append(sacar(lado, json.load(open(f))))
    claves = [("almacen_s", "Almacén en pantalla, primera visita (s)"), ("segunda_s", "Segunda visita (s)"), ("mb", "Bytes por la red (MiB)"),
              ("mem", "Memoria de Chrome (MB)"), ("gon50", "Cuadro en la góndola, mediana (ms)"), ("gon95", "Cuadro en la góndola, p95 (ms)"),
              ("rec95", "Peor p95 entre las seis vistas (ms)"), ("largo", "Cuadro más largo (ms)")]
    for lado in "GTWP":
        if lado not in por_lado:
            continue
        print(f"\n## {NOMBRES[lado]} — {len(por_lado[lado])} corridas")
        for k, n in claves:
            print(f"- {n}: {fila([r[k] for r in por_lado[lado]])}")


main()
