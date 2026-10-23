"""python analiza2.py corrida.json: J1->J2, enlaces tardios en J2 y la caja del jugador real."""
import json, re, sys
d = json.load(open(sys.argv[1]))
m = {}; v = False
for n, t, l in d["marcas"]:
    if n == "fin_j1_forzado": v = True
    if v and n not in m: m[n] = (t, l)
def dur(a, b): return m[b][0] - m[a][0] if a in m and b in m else float("nan")
print(f"{sys.argv[1]} {d['navegador']} paralelo={d['gpu']['paralelo']} completa={d['completa']}")
print(f"  cargando_visible -> control : {dur('cargando_visible','control')/1000:.2f} s")
print(f"  cierre -> control           : {dur('cierre','control')/1000:.2f} s")
print(f"  destape (sync_fin->destape_fin): {dur('calentar_sync_fin','destape_fin')/1000:.2f} s  links {m['destape_fin'][1]-m['calentar_sync_fin'][1]}")
print(f"  calentar_sync (sync)        : {dur('calentar_inicio','calentar_sync_fin')/1000:.2f} s")
fin = m["calentar_fin"][0]
tard = [l for l in d["links"] if l["t"] > fin]
ctrl = m["control"][0]
def raros(defs):
    ds = [x.strip().split(" ")[0] for x in defs.split("#define ") if x.strip()]
    clave = ["MODE_UNSHADED","USE_INSTANCING","UV2_USED","BASE_PASS","USE_LIGHTMAP_CAPTURE","DISABLE_LIGHTMAP","DISABLE_LIGHT_OMNI","DISABLE_LIGHT_SPOT","DISABLE_LIGHT_AREA","DISABLE_REFLECTION_PROBE","SECOND_REFLECTION_PROBE","USE_ADDITIVE_LIGHTING","ADDITIVE_OMNI","SHADOW_MODE_PCF_5","CUSTOM0_USED","OVERRIDE_POSITION","SPECULAR_DISABLED"]
    return " ".join(k for k in clave if k in ds)
print(f"  enlaces despues de calentar_fin: {len(tard)}")
nom = sorted([(t, n) for n, (t, _) in m.items()])
for l in tard:
    fase = [n for t, n in nom if t <= l["t"]][-1]
    print(f"    t={(l['t']-ctrl)/1000:+.2f}s tras control fase={fase} len={l.get('len')} {raros(l.get('defs',''))}")
marc = {}
for n, t, x in d["dato"]:
    if t >= m["control"][0]: marc.setdefault(n, []).append((t, x))
print("  marcas de J2:")
for n, t, x in [(n, t, x) for n, t, x in d["dato"] if t >= ctrl]:
    print(f"    {(t-ctrl)/1000:8.2f}s {n} {x if x not in (None,'None') else ''}")
rep = d.get("rep", [])
print(f"  muestras de la caja: {len(rep)}")
# cuadros con la cola > 0 durante la reproduccion
ini = next((t for n, t, _ in d["dato"] if n == "repro_inicio"), None)
fin_r = next((t for n, t, _ in d["dato"] if n == "repro_fin"), None)
if ini and fin_r:
    cq = [c for c in d["cuadros"] if not isinstance(c[0], str) and ini <= c[0] <= fin_r and c[1] > 0]
    print(f"  cuadros con cola>0 en la reproduccion: {len(cq)}")
    if cq: print(f"    desde {(cq[0][0]-ctrl)/1000:+.2f}s hasta {(cq[-1][0]-ctrl)/1000:+.2f}s")
    ts = [c[0] for c in d["cuadros"] if not isinstance(c[0], str) and ini <= c[0] <= fin_r]
    dts = [b - a for a, b in zip(ts, ts[1:])]
    print(f"  cuadros en la reproduccion: {len(dts)} max {max(dts):.1f} ms  >50ms: {sum(x>50 for x in dts)}")
