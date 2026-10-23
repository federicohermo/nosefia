import json, statistics, sys, glob
from analiza3 import analizar
PREFIJO = sys.argv[1] if len(sys.argv) > 1 else "J3"
filas = {}
for nav in ("chrome", "ff"):
    for ver in ("old", "new"):
        rs = []
        for f in sorted(glob.glob(f"{PREFIJO}_{ver}_{nav}[0-9].json")):
            d = json.load(open(f))
            if not d["completa"]: print("INCOMPLETA", f); continue
            rs.append(analizar(d)[0])
        if rs: filas[(nav, ver)] = rs
def med(rs, k, sub): 
    v = [r[sub][k] for r in rs if k in r[sub]]
    return (round(statistics.median(v), 2), [round(x, 2) for x in v]) if v else None
for (nav, ver), rs in filas.items():
    print(f"== {nav} {ver} ({len(rs)} corridas)")
    for sub in ("j1_j2", "j2_j3"):
        print(f"  {sub} cierre->control s:", med(rs, "cierre_control_s", sub))
        print(f"  {sub} cargando->control s:", med(rs, "cargando_control_s", sub), " programas en la carga:", med(rs, "programas_en_la_carga", sub), "pendientes:", [r[sub].get("pendientes") for r in rs])
    print("  enlaces tardios J2:", [r["tardios_j2"] for r in rs], " J3 antes de limpiar:", [r["tardios_j3_antes_de_limpiar"] for r in rs], " J3 limpiando:", [r["tardios_j3_limpiando"] for r in rs])
    print("  cuadros con cola>0 limpiando:", [r.get("cuadros_con_cola_limpiando") for r in rs], " max cuadro ms:", [round(r.get("max_cuadro_ms", 0), 1) for r in rs])
