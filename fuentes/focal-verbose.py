import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


sys.stdout.reconfigure(encoding="utf-8", errors="replace")
raiz = Path.cwd()
destino = Path(sys.argv[1])
destino.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(raiz / ".claude/scripts"))
from lib.godot import entorno_de_la_suite, resolver

godot, origen = resolver(dict(os.environ))
assert godot, "Godot no declarado"
entorno = entorno_de_la_suite(dict(os.environ), raiz, sys.platform)
entorno["GODOT_BIN"] = godot
datos = {"godot": godot, "origen": origen, "cwd": str(raiz), "head": subprocess.check_output(["git", "rev-parse", "HEAD"]).decode().strip(), "comandos": []}
comandos = [("import", [godot, "--headless", "--path", str(raiz), "--import", "--quit"])]
comandos.append(("tests", [godot, "--verbose", "--headless", "--path", str(raiz), "-s", "-d", "--remote-debug", "tcp://127.0.0.1:0", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd", *[a for suite in sys.argv[2:] for a in ["-a", suite]], "--continue", "--ignoreHeadlessMode", "-rd", "res://reports"]))
codigo = 0
for nombre, comando in comandos:
    with (destino / f"{nombre}.log").open("wb") as salida:
        codigo = subprocess.run(comando, env=entorno, stdout=salida, stderr=subprocess.STDOUT).returncode
    datos["comandos"].append({"nombre": nombre, "comando": comando, "codigo": codigo})
    print(nombre, codigo, flush=True)
    if codigo:
        break
reportes = [p for p in (raiz / "reports").glob("report_*") if (p / "results.xml").is_file()]
if reportes:
    ultimo = max(reportes, key=lambda p: int(p.name.removeprefix("report_")))
    shutil.copy2(ultimo / "results.xml", destino / "results.xml")
datos["head_despues"] = subprocess.check_output(["git", "rev-parse", "HEAD"]).decode().strip()
(destino / "resultado.json").write_text(json.dumps(datos, ensure_ascii=False, indent=2), encoding="utf-8")
(destino / "exit-code.txt").write_text(str(codigo), encoding="utf-8")
raise SystemExit(codigo)
