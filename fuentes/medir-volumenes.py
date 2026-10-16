import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).parent
out = root / "volumen-01"
out.mkdir(exist_ok=True)
sys.path.insert(0,str(Path.cwd() / ".claude/scripts"))
from lib.godot import resolver
godot, origen = resolver(dict(os.environ))
assert godot
env = {**os.environ,"APPDATA":"D:/nosefia-carril-C-429-444/22-usuario-volumen-01"}
Path(env["APPDATA"]).mkdir(exist_ok=True)
cmd = [godot,"--headless","--verbose","--path",str(Path.cwd()),"--script",str(root / "medir-volumenes.gd"),"--",str(out / "medidas.json")]
with (out / "medir.log").open("wb") as log:
    r = subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=120)
(out / "comando.json").write_text(json.dumps({"cmd":cmd,"codigo":r.returncode,"godot_origen":origen},indent=2),encoding="utf-8")
raw = (out / "medir.log").read_text(encoding="utf-8",errors="replace")
print("\n".join(l for l in raw.splitlines() if "VOLUMEN22" in l or "SCRIPT ERROR" in l or l.startswith("ERROR:")))
sys.exit(r.returncode)
