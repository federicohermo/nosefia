import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess

repo = Path.cwd()
scratch = Path(__file__).parent
spec = (repo / "specs/investigation/investigation.md").read_text(encoding="utf-8")
ids = re.findall(r"^### (AC-INV-\d{3})",spec,re.M)
citas = {identidad:[] for identidad in ids}
for base in (repo / "test",repo / ".claude/scripts/tests"):
    for p in base.rglob("*"):
        if p.is_file() and p.suffix in (".gd",".py"):
            for numero,linea in enumerate(p.read_text(encoding="utf-8").splitlines(),1):
                for identidad in re.findall(r"AC-INV-\d{3}",linea):
                    if identidad in citas:
                        citas[identidad].append({"ruta":p.relative_to(repo).as_posix(),"linea":numero})
faltan = [identidad for identidad in ids if not citas[identidad]]
obj = importlib.util.spec_from_file_location("generador_colilla",repo / "assets/props/colilla/generar_colilla.py")
mod = importlib.util.module_from_spec(obj)
obj.loader.exec_module(mod)
out = scratch / "colilla-regenerada.tscn"
mod.generar(out)
assert out.read_bytes() == (repo / "assets/props/colilla/colilla_visual.tscn").read_bytes()
resultado = {"ids":len(ids),"faltantes":faltan,"citas":citas,"generador_reproduce_bytes":True,
             "publicos_instancia_partida":len(re.findall(r"^func [a-z][^(]*",(repo / "src/dominio/empleo/partida.gd").read_text(encoding="utf-8"),re.M)),
             "estaticos_partida":len(re.findall(r"^static func [a-z][^(]*",(repo / "src/dominio/empleo/partida.gd").read_text(encoding="utf-8"),re.M)),
             "foto_2a_sha256":hashlib.sha256((repo / "assets/ui/manada/pistas/yasmin-circulo-original.png").read_bytes()).hexdigest(),
             "foto_2b_sha256":hashlib.sha256((repo / "assets/ui/manada/pistas/colilla.png").read_bytes()).hexdigest()}
(scratch / "preflight-cierre.json").write_text(json.dumps(resultado,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps({k:v for k,v in resultado.items() if k != "citas"},indent=2))
assert not faltan
