"""Resume medidas/extra: segunda visita de Godot, CPU frenada 4 veces y Firefox.
Uso: python resumir_extra.py"""
import glob, json, statistics
from pathlib import Path
R = Path(__file__).resolve().parents[1] / "medidas" / "extra"
def med(v):
    v = [x for x in v if x is not None]
    return f"{statistics.median(v):.2f} ({min(v):.2f}–{max(v):.2f}) n={len(v)}" if v else "—"
def lado(f):
    return Path(f).stem.split("-")[-1]
print("## Segunda visita de Godot (mismo perfil)")
for k in ("1", "2"):
    v = [json.load(open(f))["almacen_ms"] / 1000 for f in glob.glob(str(R / f"godot-2visita-r*-{k}.json"))]
    print(f"- visita {k}: {med(v)} s")
for pref, titulo in (("cpu4", "## CPU frenada 4 veces (Chrome, sin tope de cuadros)"), ("ff", "## Firefox (con tope de cuadros)")):
    print("\n" + titulo)
    por = {}
    for f in sorted(glob.glob(str(R / f"{pref}-r*-*.json"))):
        j = json.load(open(f)); l = lado(f)
        if l == "G":
            v = j.get("vistas", {}).get("gondola") or {}
            d = {"almacen": (j.get("almacen_ms") or 0) / 1000 or None, "segunda": None, "p50": v.get("p50"), "p95": v.get("p95"), "max": (j.get("caminando") or {}).get("max"), "err": len(j.get("errores") or [])}
        else:
            p = j.get("primera", {}); s = j.get("segunda", {}); v = j.get("vistas", {}).get("gondola") or {}
            d = {"almacen": (p.get("almacen_ms") or 0) / 1000 or None, "segunda": (s.get("almacen_ms") or 0) / 1000 or None, "p50": v.get("p50"), "p95": v.get("p95"), "max": j.get("recorrido_max_ms"), "err": len(j.get("errores") or [])}
        por.setdefault(l, []).append(d)
    for l in "GTWP":
        if l in por:
            r = por[l]
            print(f"- {l} ({len(r)} corridas): almacén {med([x['almacen'] for x in r])} s · segunda {med([x['segunda'] for x in r])} s · góndola p50 {med([x['p50'] for x in r])} ms · p95 {med([x['p95'] for x in r])} ms · cuadro más largo {med([x['max'] for x in r])} ms · errores {sum(x['err'] for x in r)}")
