"""Límite de ejecución real; la espera FIFO la maneja turno.py."""
import hashlib
import json
import subprocess
from pathlib import Path

base = Path(__file__).resolve().parent
pins = json.loads((base/"sourcepins02.json").read_text(encoding="utf-8"))
for rel, sha in pins["inputs"].items():
    assert hashlib.sha256((base/rel).read_bytes()).hexdigest() == sha, rel
command = ["C:/Program Files/Blender Foundation/Blender 5.2/blender.exe", "--background",
           str(base/"fuente.blend"), "--python-exit-code", "1", "--python", str(base/"renderizar02.py")]
try:
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
except subprocess.TimeoutExpired as exc:
    (base/"reintento-lateral"/"blender.log").write_bytes(exc.stdout or b"")
    raise SystemExit("Tiempo máximo de180s agotado")
(base/"reintento-lateral"/"blender.log").write_bytes(result.stdout)
print(result.stdout.decode("utf-8", "replace")[-6000:], flush=True)
assert result.returncode == 0, result.returncode
assert b"434_COMPARACION_REAL_1_2_FILAS_OK" in result.stdout
assert len(list((base/"reintento-lateral").glob("*.png"))) == 4
for rel, sha in pins["inputs"].items():
    assert hashlib.sha256((base/rel).read_bytes()).hexdigest() == sha, rel
print("434_COMPARACION_INPUTS_INTACTOS_4_PNG_OK")
