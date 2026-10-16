import json
from pathlib import Path
import subprocess

base = Path(__file__).resolve().parent
d = json.loads(subprocess.check_output(["gh", "api", "repos/federicohermo/nosefia/issues/434"]))
body = d["body"]
old = "`test/escenas/modelo_integrado_test.gd`, `test/escenas/modelo_exportado_test.gd`"
new = "`test/escenas/reposicion_manual_test.gd` (sólo actualizar las precondiciones del caso heredado de superficie inválida tras mover Uakas: postura exterior desde piso libre, mira sobre apoyo horizontal real, volumen completo de la mano física y semánticamente libre mediante SAT; sin cambiar producción, reglas, umbrales ni el resto de sus casos); " + old
assert body.count(old) == 1
body = body.replace(old, new)
p = base / "issue434-fixture-WHOLE-publicable.md"
p.write_bytes(body.encode("utf-8"))
subprocess.run(["gh", "issue", "edit", "434", "--repo", "federicohermo/nosefia",
                "--body-file", str(p)], check=True)
readback = json.loads(subprocess.check_output(["gh", "api", "repos/federicohermo/nosefia/issues/434"]))
assert readback["body"] == body
(base / "issue434-fixture-publicado.json").write_bytes(
    (json.dumps(readback, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))
print("WHOLE issue fixture scope published and exact readback.")
