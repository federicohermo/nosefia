import hashlib
import json
from pathlib import Path
import subprocess

base = Path(__file__).resolve().parent
pins = json.loads((base/"sourcepins.json").read_text(encoding="utf-8"))
for path, sha in pins["inputs"].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == sha, path
command = [pins["blender"], "--background", pins["fuentes"]["original"],
           "--python-exit-code", "1", "--python", str(base/"medir.py")]
try:
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300)
except subprocess.TimeoutExpired as error:
    (base/"blender.log").write_bytes(error.stdout or b"")
    raise
(base/"blender.log").write_bytes(result.stdout)
print(result.stdout.decode("utf-8", "replace")[-8000:], flush=True)
assert result.returncode == 0, result.returncode
assert b"434_SONDA_RNA_READONLY_COMPLETA" in result.stdout
for path, sha in pins["inputs"].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == sha, path
print("434_TRES_FUENTES_Y_CODIGO_BYTEIDENTICOS", flush=True)
