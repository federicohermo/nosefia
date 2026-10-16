import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).parent
out = root / "evidencia-04/control-pck-limpio-02"
out.mkdir(exist_ok=False)
sys.path.insert(0,str(Path.cwd() / ".claude/scripts"))
from lib.godot import resolver
godot, origen = resolver(dict(os.environ))
assert godot
exportado = Path("D:/nosefia-carril-C-429-444/431-export-03")
web = exportado / "web"
antes = {n:hashlib.sha256((web / n).read_bytes()).hexdigest() for n in ("index.html","index.js","index.pck","index.wasm")}
env = {**os.environ,"APPDATA":str(out / "usuario-aislado")}
Path(env["APPDATA"]).mkdir(exist_ok=True)
comandos = []
for nombre, script, args in [
    ("sonda-paquete",root / "paquete431-sin-marco.gd",["--",str(out / "checkpoint-jornada-2.guardado")]),
    ("dialogos-paquete",exportado / "proyecto/.github/scripts/verificar_dialogos_exportados.gd",[])
]:
    cmd = [godot,"--headless","--verbose","--path",str(web),"--main-pack",str(web / "index.pck"),"--script",str(script),*args]
    with (out / (nombre + ".log")).open("wb") as log:
        r = subprocess.run(cmd,cwd=web,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=120)
    raw = (out / (nombre + ".log")).read_text(encoding="utf-8",errors="replace")
    diagnosticos = [l for l in raw.splitlines() if re.search(r"SCRIPT ERROR|Parse Error|(^|\s)(ERROR:|WARNING:)|Leaked instance|Resource still in use|unclaimed string names",l)]
    comandos.append({"nombre":nombre,"cmd":cmd,"codigo":r.returncode,"diagnosticos":diagnosticos})
    (out / "resultado.json").write_text(json.dumps({"fuente":"6d60f82c16bbbc1f7182e656ebead8df8bf5ad87","godot":godot,"origen":origen,"comandos":comandos,"huellas_antes":antes},ensure_ascii=False,indent=2),encoding="utf-8")
    print(nombre,r.returncode,"diagnosticos",len(diagnosticos),flush=True)
    if r.returncode or diagnosticos:
        sys.exit(r.returncode or 1)
assert antes == {n:hashlib.sha256((web / n).read_bytes()).hexdigest() for n in antes}
print("PCK431_FINAL_LIMPIO mismos cuatro artefactos",flush=True)
