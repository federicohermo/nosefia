import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).parent
out = root / "evidencia-03"
out.mkdir(exist_ok=True)
exportado = Path("D:/nosefia-carril-C-429-444/22-export-03")
sys.path.insert(0,str(Path.cwd() / ".claude/scripts"))
from lib.godot import resolver
godot, origen = resolver(dict(os.environ))
assert godot
env = {**os.environ,"APPDATA":"D:/nosefia-carril-C-429-444/22-usuario-evidencia-03"}
Path(env["APPDATA"]).mkdir(exist_ok=True)
reg = {"fuente":"fb4236e69c752e6879bb338b80e734e16b211b41","godot":godot,"origen":origen,"comandos":[]}
def correr(nombre,cmd, cwd=None, marcador=None):
    with (out / (nombre + ".log")).open("wb") as log:
        r = subprocess.run(cmd,env=env,cwd=cwd,stdout=log,stderr=subprocess.STDOUT,timeout=600)
    raw = (out / (nombre + ".log")).read_text(encoding="utf-8",errors="replace")
    reg["comandos"].append({"nombre":nombre,"cmd":cmd,"codigo":r.returncode,"cwd":str(cwd) if cwd else str(Path.cwd())})
    (out / "comandos.json").write_text(json.dumps(reg,ensure_ascii=False,indent=2),encoding="utf-8")
    print(nombre,r.returncode,flush=True)
    assert r.returncode == 0,nombre
    if marcador:
        assert marcador in raw, nombre + " sin marcador"
        assert not re.search(r"SCRIPT ERROR|Parse Error|(^|\n)(ERROR:|WARNING:)|leaked|still in use",raw),nombre + " con diagnósticos"
correr("exportar",[sys.executable,str(root / "exportar_paquete22-02.py"),str(exportado),
                   "D:/nosefia-429-444-plantilla-compilada-03/build/templates/web_release.zip",
                   "D:/nosefia-429-444-plantilla-compilada-03/build/templates/web_release.manifiesto.json"])
web = exportado / "web"
correr("sonda-paquete",[godot,"--headless","--verbose","--path",str(web),"--main-pack",str(web / "index.pck"),
                        "--script",str(root / "paquete22.gd"),"--",str(out),"1280","720"],cwd=web,
       marcador="PAQUETE22_FINAL resolucion=(1280, 720) fallos=0")
correr("dialogos-paquete",[godot,"--headless","--path",str(web),"--main-pack",str(web / "index.pck"),
                          "--script",str(exportado / "proyecto/.github/scripts/verificar_dialogos_exportados.gd")],cwd=web)
nativo = out / "nativo"
nativo.mkdir(exist_ok=True)
for ancho, alto in ((1920,1080),(1280,720)):
    correr("nativo-" + str(ancho),[godot,"--path",str(exportado / "proyecto"),"--rendering-driver","opengl3",
                                  "--script",str(root / "capturar_nativo22.gd"),"--",str(nativo),str(ancho),str(alto)],
           marcador=f"NATIVO22_FINAL resolucion=({ancho}, {alto}) fallos=0")
print("EVIDENCIA22_PAQUETE_NATIVO_FINAL",flush=True)

