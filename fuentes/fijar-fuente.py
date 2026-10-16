import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

repo = Path.cwd()
out = Path(sys.argv[1])
out.mkdir(exist_ok=False)
def git(*args):
    return subprocess.check_output(["git",*args],text=True,encoding="utf-8")
head = git("rev-parse","HEAD").strip()
status = git("status","--porcelain")
archivos = {}
for ruta in sorted(set(git("ls-files","--modified","--others","--exclude-standard").splitlines())):
    src = repo / ruta
    if src.is_file():
        datos = src.read_bytes()
        dst = out / ruta
        dst.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(src,dst)
        assert dst.read_bytes() == datos
        archivos[ruta] = {"bytes":len(datos),"sha256":hashlib.sha256(datos).hexdigest()}
assert head == git("rev-parse","HEAD").strip() and status == git("status","--porcelain")
(out / "manifest.json").write_text(json.dumps({"head":head,"status":status,"archivos":archivos,
    "momento":"Copia durante espera de cola, posterior a enqueue. Árbol congelado desde enqueue; no inventa pin previo."},ensure_ascii=False,indent=2),encoding="utf-8")
print("FUENTE",len(archivos),str(out))
