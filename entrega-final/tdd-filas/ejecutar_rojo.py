"""Snapshot externo del código publicado; corrida pura, sin Godot/Blender ni WT edits."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

base = Path(__file__).resolve().parent
wt = Path("D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/.claude/worktrees/batch-434-sectores")
head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=wt).decode().strip()
assert head == "4d62b6e765501288b03c21521879e591579807dc"
assert subprocess.check_output(["git", "status", "--porcelain=v1"], cwd=wt) == b""
target = base/"scripts/lib"
target.mkdir(parents=True, exist_ok=True)
for name in ("__init__.py", "reparto.py"):
    shutil.copyfile(wt/".claude/scripts/lib"/name, target/name)
pins = {p.relative_to(base).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in (target/"__init__.py", target/"reparto.py", base/"test_decision_filas.py")}
result = subprocess.run([sys.executable, "-m", "unittest", "test_decision_filas.py", "-v"], cwd=base,
    env={**os.environ, "PYTHONPATH": str(base/"scripts")}, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
(base/"rojo.log").write_bytes(result.stdout)
assert result.returncode == 1, result.returncode
assert b"AssertionError" in result.stdout and b"ImportError" not in result.stdout
assert b"AttributeError" not in result.stdout and b"ERROR:" not in result.stdout
(base/"sourcepins-rojo.json").write_bytes(json.dumps({"head": head, "inputs": pins,
    "exit": result.returncode, "rojo": "aserciones sobre API Tanda existente; sin imports inexistentes",
    "produccion_WT_sin_cambios": True}, indent=2).encode("utf-8"))
assert subprocess.check_output(["git", "status", "--porcelain=v1"], cwd=wt) == b""
print(result.stdout.decode("utf-8", "replace"))
