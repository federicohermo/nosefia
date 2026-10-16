import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).parent
out = root / "fisico-rojo-03"
out.mkdir(exist_ok=True)
repo = Path.cwd()
sys.path.insert(0, str(repo / ".claude/scripts"))
from lib.godot import resolver
godot, origen = resolver(dict(os.environ))
assert godot
env = {**os.environ, "APPDATA":str(out / "usuario-aislado"), "NOSEFIA_CAPTURA_AISLADA":"22"}
Path(env["APPDATA"]).mkdir(exist_ok=True)
reg = {"godot":godot,"origen":origen,"comandos":[],"source_head":subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip()}
reg["estado_inicial"] = subprocess.check_output(["git","status","--porcelain"],text=True)
for nombre, cmd in [
    ("import",[godot,"--headless","--path",str(repo),"--import","--quit"]),
    ("foto",[godot,"--path",str(repo),"--rendering-driver","opengl3","--script","res://assets/ui/manada/pistas/capturar_colilla.gd","--",str(out / "colilla.png")]),
    ("focal",[sys.executable,str(root / "focal-verbose.py"),str(out / "focal"),"res://test/escenas/pistas_de_la_segunda_jornada_test.gd","res://test/dominio/investigacion/expediente_test.gd"])
]:
    with (out / (nombre + ".log")).open("wb") as log:
        r = subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180)
    reg["comandos"].append({"nombre":nombre,"cmd":cmd,"codigo":r.returncode})
    print(nombre,r.returncode,flush=True)
    if r.returncode:
        break
reg["estado_final"] = subprocess.check_output(["git","status","--porcelain"],text=True)
(out / "resultado.json").write_text(json.dumps(reg,ensure_ascii=False,indent=2),encoding="utf-8")
sys.exit(reg["comandos"][-1]["codigo"])
