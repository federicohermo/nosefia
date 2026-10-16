"""Valida fuentes/env y corre sólo la generación autorizada, sin suites ni capturas."""
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys

base = Path(__file__).resolve().parent
raiz = Path.cwd()
pins = json.loads((base/"sourcepins.json").read_text(encoding="utf-8"))
assert subprocess.check_output(["git", "rev-parse", "HEAD"]).decode().strip() == pins["head"]
assert subprocess.check_output(["git", "status", "--porcelain=v1"]) == b""
for path, sha in pins["inputs"].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == sha, path
os.environ["GODOT_BIN"] = pins["godot"]
os.environ["BLENDER_BIN"] = pins["blender"]
sys.path.insert(0, str(raiz/".claude/scripts"))
print("434_RECURSOS_PINS_Y_ENV_VERIFICADOS", flush=True)
runpy.run_path(str(base/"pipeline.py"), run_name="__main__")
for path, sha in pins["estables"].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == sha, path
print("434_RECURSOS_CODIGO_Y_ESTRUCTURA_INTACTOS", flush=True)
