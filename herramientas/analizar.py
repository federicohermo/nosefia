"""python analizar.py corrida.json [...]: fases J1->J2, cuadros y enlaces por tramo."""
import json
import statistics
import sys

FASES = [
    ("cierre", "persiana_bajada"),
    ("persiana_bajada", "cargando_visible"),
    ("cargando_visible", "calentar_inicio"),
    ("calentar_inicio", "calentar_sync_fin"),
    ("calentar_sync_fin", "destape_fin"),
    ("destape_fin", "calentar_fin"),
    ("calentar_fin", "jornada_abierta"),
    ("jornada_abierta", "instrucciones_legibles"),
    ("instrucciones_ok", "anunciar"),
    ("anunciar", "control"),
    ("cargando_visible", "control"),
    ("cierre", "control"),
]


def marcas_j2(d):
    m = {}
    vistas = False
    for n, t, links in d["marcas"]:
        if n == "fin_j1_forzado":
            vistas = True
        if vistas and n not in m:
            m[n] = (t, links)
    return m


def tramo(d, a, b):
    """Cuadros (intervalos rAF) entre dos tiempos."""
    ts = [c[0] for c in d["cuadros"] if not isinstance(c[0], str) and a <= c[0] <= b]
    dts = [y - x for x, y in zip(ts, ts[1:])]
    return dts


for ruta in sys.argv[1:]:
    d = json.load(open(ruta))
    m = marcas_j2(d)
    print(f"== {ruta} gpu={d['gpu']['gpu'][:40]} paralelo={d['gpu']['paralelo']} sinParalelo={d['sinParalelo']}")
    for a, b in FASES:
        if a in m and b in m:
            ta, la = m[a]
            tb, lb = m[b]
            dts = tramo(d, ta, tb)
            largo = max(dts) if dts else 0
            print(f"  {a:>18} -> {b:<22} {tb - ta:9.1f} ms  links {lb - la:4d}  cuadros {len(dts):4d}  max {largo:7.1f} ms  >50ms {sum(x > 50 for x in dts):3d}")
    t_ctrl = m["control"][0]
    cola_post = [c for c in d["cuadros"] if not isinstance(c[0], str) and c[0] > t_ctrl and c[1] > 0]
    tardios = [l for l in d["links"] if l["t"] > m["calentar_fin"][0]]
    print(f"  cuadros con cola>0 despues del control: {len(cola_post)}")
    for l in tardios:
        fase = max((n for n, (t, _) in m.items() if t <= l["t"]), key=lambda n: m[n][0])
        print(f"  link tardio t={l['t'] - t_ctrl:+.0f} ms tras control (fase {fase}) {l['ms']:.1f} ms len={l.get('len')} {l.get('defs', '')[:300]}")
    esperas = [c for c in d["cuadros"] if isinstance(c[0], str)]
    print(f"  esperas getProgramParameter >5ms: {len(esperas)} total {sum(c[2] for c in esperas):.0f} ms")
    warm = tramo(d, m["calentar_sync_fin"][0], m["destape_fin"][0])
    if warm:
        print(f"  destape: mediana cuadro {statistics.median(warm):.1f} ms, p90 {sorted(warm)[int(len(warm)*0.9)]:.1f}, suma {sum(warm):.0f}")
    links_w = [l for l in d["links"] if m["calentar_inicio"][0] <= l["t"] <= m["destape_fin"][0]]
    print(f"  links en calentamiento: {len(links_w)}, tiempo sincrono en linkProgram {sum(l['ms'] for l in links_w):.0f} ms")
