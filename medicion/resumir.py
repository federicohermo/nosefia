import json, sys
t = open(sys.argv[1], encoding="utf-8").read()
d = json.loads(t[t.index("@@") + 2:].split("\n")[0])
for e, v in d.items():
    if e.endswith(".0") and e.split(".")[1] in ("este", "oeste", "sur") and e.split(".")[0] in ("A", "B", "N"):
        u = v["unidades"]
        gaps = []
        for a, b in zip(u, u[1:]):
            g = round(b[0] - a[1], 4)
            gaps.append((g, "X" if a[2] != b[2] else ""))
        print(e, [(p) for p in sorted({x[2] for x in u})], len(u), "ancho", round(u[0][1]-u[0][0],3))
        print("   ", " ".join(f"{g:.3f}{m}" for g, m in gaps))
