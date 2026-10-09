"""Own #309 focal runner. Invoke only through the shared turno.py queue."""

import os
import subprocess
import sys
from pathlib import Path

root = Path.cwd().resolve()
out = Path(__file__).resolve().parent
phase = sys.argv[1]
if phase not in ("red-domain", "green-domain", "red-ui", "green-all", "green-all2", "green-all3"):
    raise SystemExit("Unknown phase")
env = os.environ.copy()
env["APPDATA"] = str(root / ".godot/usuario_de_los_tests")
Path(env["APPDATA"]).mkdir(parents=True, exist_ok=True)
godot = env["GODOT_BIN"]
suites = ["test/dominio/ambiente/notificaciones_test.gd"]
if phase == "red-ui":
    suites = ["test/ui/pila_de_notificaciones_test.gd"]
elif phase.startswith("green-all"):
    suites += [
        "test/ui/pila_de_notificaciones_test.gd",
        "test/escenas/notificaciones_en_el_almacen_test.gd",
    ]
jobs = [("import", [godot, "--headless", "--path", str(root), "--import", "--quit"])]
jobs += [(Path(suite).stem, [
    godot, "--path", str(root), "--headless", "-s", "-d",
    "--remote-debug", "tcp://127.0.0.1:0",
    "res://addons/gdUnit4/bin/GdUnitCmdTool.gd", "-a", "res://" + suite,
    "--continue", "--ignoreHeadlessMode", "-rd", "res://reports/309-focales",
]) for suite in suites]
code = 0
for label, command in jobs:
    log = out / f"{phase}-{label}.log"
    if log.exists():
        raise SystemExit(f"Preserve previous run: {log}")
    print(f"FOCAL309_START {phase} {label}", flush=True)
    with log.open("wb") as output:
        result = subprocess.run(command, cwd=root, env=env, stdout=output,
                                stderr=subprocess.STDOUT)
    print(f"FOCAL309_EXIT {result.returncode} {log}", flush=True)
    if result.returncode:
        code = result.returncode
        if label == "import" or phase.startswith("red-"):
            break
raise SystemExit(code)
