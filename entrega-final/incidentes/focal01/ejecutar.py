"""Import y focales de #434 con canales crudos en orden, siempre por FIFO."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")
base = Path(__file__).resolve().parent
raiz = Path.cwd()
pins = json.loads((base / "sourcepins.json").read_text(encoding="utf-8"))
assert subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip() == pins["head"]
assert subprocess.check_output(["git", "status", "--porcelain=v1"]) == b""
for path, sha in pins["inputs"].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == sha, path
sys.path.insert(0, str(raiz / ".claude/scripts"))
from lib.godot import entorno_de_la_suite

godot = pins["godot"]
env = entorno_de_la_suite(dict(os.environ), raiz, sys.platform)
env["PYTHONIOENCODING"] = "utf-8"


def correr(nombre, args):
    resultado = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               env=env, timeout=1200)
    (base / (nombre + ".log")).write_bytes(resultado.stdout)
    print(resultado.stdout.decode("utf-8", "replace"), flush=True)
    (base / (nombre + "-estado.json")).write_bytes(
        (json.dumps({"returncode": resultado.returncode, "comando": args}, indent=2) + "\n").encode())
    if resultado.returncode:
        raise SystemExit(resultado.returncode)
    if nombre == "import" and any(x in resultado.stdout for x in (
            b"SCRIPT ERROR", b"Parse Error", b"ERROR:")):
        raise SystemExit("El import devolvió error con exit0")


correr("import", [godot, "--headless", "--path", str(raiz), "--import", "--quit"])
args = [godot, "--path", str(raiz), "--headless", "-s", "-d",
        "--remote-debug", "tcp://127.0.0.1:0",
        "res://addons/gdUnit4/bin/GdUnitCmdTool.gd", "--continue",
        "--ignoreHeadlessMode", "-rd", "res://reports/focal-434-actual01"]
for suite in pins["suites"]:
    args.extend(["-a", suite])
correr("tests", args)
for path, sha in pins["inputs"].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == sha, path
print("434_FOCAL_ACTUAL_COMPLETA", flush=True)
