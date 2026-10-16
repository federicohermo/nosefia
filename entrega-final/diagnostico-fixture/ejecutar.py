import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

base = Path(__file__).resolve().parent
pins = json.loads((base / "sourcepins.json").read_text(encoding="utf-8"))
assert subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip() == pins["head"]
assert subprocess.check_output(["git", "status", "--porcelain=v1"]) == b""
for path, sha in pins["inputs"].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == sha, path
sys.path.insert(0, str(Path.cwd() / ".claude/scripts"))
from lib.godot import entorno_de_la_suite

result = subprocess.run(
    [pins["godot"], "--headless", "--path", ".", "--script", str(base / "observar.gd")],
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120,
    env=entorno_de_la_suite(dict(os.environ), Path.cwd(), sys.platform),
)
(base / "observer.log").write_bytes(result.stdout)
print(result.stdout.decode("utf-8", "replace"), flush=True)
assert result.returncode == 0, result.returncode
assert b"434_OBSERVER_SUPERFICIE_COMPLETO" in result.stdout
assert not any(x in result.stdout for x in (b"ERROR:", b"SCRIPT ERROR", b"Parse Error"))
for path, sha in pins["inputs"].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == sha, path
print("434_OBSERVER_INPUTS_INTACTOS", flush=True)
