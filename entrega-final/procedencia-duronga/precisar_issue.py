import json
from pathlib import Path
import subprocess

b = Path(__file__).resolve().parent
d = json.loads(subprocess.check_output(["gh", "api", "repos/federicohermo/nosefia/issues/434"]))
old = d["body"]
new = old.replace(
    "| Estantería de no comestibles | Actroncito (`ACTRONCITO`), Durextra (`DUREXTRA`), Poético (`POETICO`) |",
    "| Estantería de no comestibles | Actroncito (`ACTRONCITO`), Durextra (`DUREXTRA`), Poético (`POETICO`), Duronga (`DURONGA`, provisional) |",
)
line = next(x for x in new.splitlines(True) if x.startswith("| Góndolas (provisional"))
new = new.replace(line, "")
idx = new.index("- [ ] Cindolor sale de los estantes")
extra = """Las tandas principales de la estantería mural N conservan Actroncito y Durextra arriba; abajo comparten Poético a la izquierda y Duronga a la derecha (N.sur.1). Las referencias fijas permanecen en el mismo sector sobre los cuatro niveles existentes, sin cambiar alturas. La ubicación provisional procede del dibujo y del comentario de Tiago del 15/10/2026 a las 18:25:14.413 UTC; la vista resumida de comentarios no incluía esa respuesta, por lo que se conserva también la consulta completa.

"""
new = new[:idx] + extra + new[idx:]
assert new != old
p = b / "issue434-duronga-WHOLE-publicable.md"
p.write_bytes(new.encode("utf-8"))
subprocess.run(["gh", "issue", "edit", "434", "--repo", "federicohermo/nosefia",
                "--body-file", str(p)], check=True)
r = json.loads(subprocess.check_output(["gh", "api", "repos/federicohermo/nosefia/issues/434"]))
assert r["body"] == new
(b / "issue434-duronga-publicado.json").write_bytes(
    (json.dumps(r, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))
print("WHOLE issue N lower-right published and exact readback.")
