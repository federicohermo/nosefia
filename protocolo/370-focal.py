import os
import subprocess
import sys
from pathlib import Path

raiz = Path.cwd()
sys.path.insert(0, str(raiz / ".claude/scripts"))
from lib.godot import entorno_de_la_suite

godot = os.environ["GODOT_BIN"]
entorno = entorno_de_la_suite(dict(os.environ), raiz, sys.platform)
comandos = [
    [godot, "--headless", "--path", str(raiz), "--import", "--quit"],
    [godot, "--path", str(raiz), "--headless", "-s", "-d",
     "--remote-debug", "tcp://127.0.0.1:0",
     "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
     *sum((["-a", s] for s in sys.argv[1:]), []),
     "--continue", "--ignoreHeadlessMode", "-rd", "res://reports"],
]
for comando in comandos:
    resultado = subprocess.run(comando, env=entorno)
    if resultado.returncode:
        sys.exit(resultado.returncode)
