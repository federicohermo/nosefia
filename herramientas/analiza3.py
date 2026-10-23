"""analiza3.py corrida.json [--v]: J1->J2 y J2->J3, y los enlaces tardios de J2 y de J3 (con la limpieza)."""
import json, sys


def analizar(d):
    M = d["dato"]
    def primero(n, desde=-1e18, hasta=1e18):
        for nom, t, _ in M:
            if nom == n and desde <= t <= hasta: return t
        return None
    f1 = primero("fin_j1_forzado"); f2 = primero("fin_j2_forzado")
    def fase(a, b, tag):
        cv = primero("cargando_visible", a, b); ct = primero("control", a, b)
        cf = primero("calentar_fin", a, b); cs = primero("calentar_sync_fin", a, b); de = primero("destape_fin", a, b); ci = primero("calentar_inicio", a, b)
        ci2 = primero("cierre", a, b)
        r = {"tag": tag}
        if cv and ct: r["cargando_control_s"] = (ct - cv) / 1000
        if cv and cf: r["carga_s"] = (cf - cv) / 1000
        if ci2 and ct: r["cierre_control_s"] = (ct - ci2) / 1000
        if cs and ci: r["sync_s"] = (cs - ci) / 1000
        if de and cs: r["destape_s"] = (de - cs) / 1000
        enl = [l for l in d["links"] if cv and cf and cv <= l["t"] <= cf]
        r["programas_en_la_carga"] = len(enl)
        r["pendientes"] = next((x for n, t, x in M if n == "cargando_visible" and a <= t <= b), None)
        return r, cf, ct
    r1, cf1, c1 = fase(f1, f2, "J1->J2")
    r2, cf2, c2 = fase(f2, 1e18, "J2->J3")
    cf2 = cf2 or primero("seguir", f2)
    if "cargando_control_s" not in r2: r2["sin_pantalla_de_carga"] = True
    fin = max(t for _, t, _ in M)
    lim_i = primero("limpieza_inicio"); lim_f = primero("limpieza_fin")
    def tardios(a, b):
        return [l for l in d["links"] if a < l["t"] <= b]
    out = {"j1_j2": r1, "j2_j3": r2}
    out["tardios_j2"] = len(tardios(cf1, f2))
    out["tardios_j3_antes_de_limpiar"] = len(tardios(cf2, lim_i)) if lim_i else None
    out["tardios_j3_limpiando"] = len(tardios(lim_i, lim_f + 1000)) if lim_i and lim_f else None
    def cola(a, b):
        cs = [c for c in d["cuadros"] if not isinstance(c[0], str) and a <= c[0] <= b]
        return sum(1 for c in cs if c[1] > 0), len(cs), max([y[0]-x[0] for x, y in zip(cs, cs[1:])] or [0])
    if lim_i and lim_f:
        out["cuadros_con_cola_limpiando"], out["cuadros_limpiando"], out["max_cuadro_ms"] = cola(lim_i, lim_f)
        out["cuadros_con_cola_j3_tras_control"] = cola(c2, lim_f)[0]
    out["cuadros_con_cola_j2_tras_control"] = cola(c1, f2)[0]
    return out, d, cf2


if __name__ == "__main__":
    out, d, cf2 = analizar(json.load(open(sys.argv[1])))
    print(json.dumps(out, indent=1))
    if "--v" in sys.argv:
        for l in [l for l in d["links"] if l["t"] > cf2]: print((l["t"] - cf2) / 1000, l.get("defs", "")[:200])
