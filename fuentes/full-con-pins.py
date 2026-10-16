import datetime
import json
from pathlib import Path
import subprocess
import sys

out = Path(sys.argv[1]).resolve()
esperado = sys.argv[2]
out.mkdir(exist_ok=True)
def pin():
    return {"head":subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),
            "estado_porcelain":subprocess.check_output(["git","status","--porcelain"],text=True),
            "utc":datetime.datetime.now(datetime.timezone.utc).isoformat()}
antes = pin()
assert antes["head"] == esperado and not antes["estado_porcelain"]
datos = {"antes_de_ejecucion":antes,"esperado":esperado,"limite":"Este pin se toma al adquirir turno; el pin separado pre-enqueue identifica el inicio de congelación."}
(out / "pins-ejecucion.json").write_text(json.dumps(datos,indent=2),encoding="utf-8")
cmd = [sys.executable,str(Path(__file__).parent.parent / "verificar-con-crudo.py"),str(out)]
with (out / "wrapper-completo.log").open("wb") as log:
    r = subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT)
datos.update({"despues_de_ejecucion":pin(),"comando":cmd,"codigo":r.returncode})
datos["misma_fuente_limpia"] = datos["despues_de_ejecucion"]["head"] == esperado and not datos["despues_de_ejecucion"]["estado_porcelain"]
(out / "pins-ejecucion.json").write_text(json.dumps(datos,indent=2),encoding="utf-8")
print("\n".join((out / "wrapper-completo.log").read_text(encoding="utf-8",errors="replace").splitlines()[-45:]))
assert datos["misma_fuente_limpia"],"La fuente cambió durante completa"
sys.exit(r.returncode)
