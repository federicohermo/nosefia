"""python resumen.py prefijo...: mediana de los tiempos J1->J2 de las corridas T_<prefijo>N.json"""
import json, statistics, sys, glob
def marcas(d):
    m = {}; v = False
    for n, t, l in d["marcas"]:
        if n == "fin_j1_forzado": v = True
        if v and n not in m: m[n] = (t, l)
    return m
for pref in sys.argv[1:]:
    filas = []
    for f in sorted(glob.glob(f"T_{pref}[0-9].json")):
        d = json.load(open(f)); m = marcas(d)
        g = lambda a, b: (m[b][0] - m[a][0]) / 1000
        tard = [l for l in d["links"] if l["t"] > m["calentar_fin"][0]]
        ctrl = m["control"][0]
        tard_jugando = [l for l in tard if l["t"] > ctrl]
        filas.append(dict(f=f, vis_ctrl=g("cargando_visible", "control"), cierre_ctrl=g("cierre", "control"),
            destape=g("calentar_sync_fin", "destape_fin"), fin=g("destape_fin", "calentar_fin"), sync=g("calentar_inicio", "calentar_sync_fin"),
            links=m["destape_fin"][1] - m["calentar_inicio"][1], tard=len(tard), tard_jugando=len(tard_jugando), completa=d["completa"],
            cuadros=sum(1 for c in d["cuadros"] if not isinstance(c[0], str) and m["calentar_sync_fin"][0] <= c[0] <= m["destape_fin"][0])))
    if not filas: continue
    print(f"== {pref}  ({len(filas)} corridas)")
    for r in filas:
        print(f"  {r['f']:22s} vis->ctrl {r['vis_ctrl']:6.2f}  cierre->ctrl {r['cierre_ctrl']:6.2f}  sync {r['sync']:5.2f}  destape {r['destape']:6.2f} ({r['cuadros']:3d} cuadros)  cola_final {r['fin']:5.2f}  links {r['links']:3d}  tardios {r['tard']} (jugando {r['tard_jugando']}) completa={r['completa']}")
    for k in ("vis_ctrl", "cierre_ctrl", "destape", "fin", "links"):
        print(f"  mediana {k:11s}: {statistics.median(r[k] for r in filas):.2f}")
