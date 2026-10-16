import json
from pathlib import Path
import subprocess

b = Path(__file__).resolve().parent
d = json.loads(subprocess.check_output(["gh", "api", "repos/federicohermo/nosefia/issues/434"]))
body = d["body"]
assert body.count("Los tres no comestibles ocupan N") == 1
body = body.replace("Los tres no comestibles ocupan N", "Los cuatro no comestibles ocupan N")
old = "La confirmación final del dueño ya resuelve OQ-STK-008 y se registra antes de implementar. La regeneración final espera apilar la base final de #428; los comandos siguientes verifican la entrega completa, no sólo las copias de visualización."
new = "La confirmación final del dueño ya resuelve OQ-STK-008 y se registra antes de implementar. El carril integra los fixes de #428 hasta 26fdbab9, pero su entrega funcional definitiva aún requiere validación: no se afirma una base cerrada. Las regeneraciones conservan estructura byteidéntica; focales, capturas y suite completa de #434 usan la cabeza funcional de #428 que coordine el padre. Los comandos siguientes verifican la entrega completa, no sólo las copias de visualización."
assert body.count(old) == 1
body = body.replace(old, new)
p = b / "issue434-duronga-WHOLE-final.md"
p.write_bytes(body.encode("utf-8"))
subprocess.run(["gh", "issue", "edit", "434", "--repo", "federicohermo/nosefia",
                "--body-file", str(p)], check=True)
r = json.loads(subprocess.check_output(["gh", "api", "repos/federicohermo/nosefia/issues/434"]))
assert r["body"] == body
(b / "issue434-duronga-publicado-final.json").write_bytes(
    (json.dumps(r, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))
print("WHOLE issue final exact: four products, 428 functional validation still pending.")
