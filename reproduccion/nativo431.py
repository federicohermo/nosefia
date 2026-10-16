import os
import re
import subprocess
import sys
from pathlib import Path


sys.stdout.reconfigure(encoding="utf-8", errors="replace")
raiz = Path.cwd()
scratch = Path(__file__).parent
salida = Path(sys.argv[1]).resolve()
salida.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(raiz / ".claude/scripts"))
from lib.godot import resolver

godot, origen = resolver(dict(os.environ))
assert godot, "Godot no declarado"
entorno = dict(os.environ)
entorno["APPDATA"] = str(salida / "usuario-aislado")
Path(entorno["APPDATA"]).mkdir(exist_ok=True)
print("GODOT431", origen, godot, flush=True)
for ancho, alto in ((1920, 1080), (1280, 720)):
    with (salida / f"nativo-{ancho}.log").open("wb") as log:
        codigo = subprocess.run([godot, "--path", str(raiz), "--rendering-driver", "opengl3", "--script", str(scratch / "capturar_nativo431.gd"), "--", str(salida), str(ancho), str(alto)], env=entorno, stdout=log, stderr=subprocess.STDOUT, timeout=150).returncode
    texto = (salida / f"nativo-{ancho}.log").read_text(encoding="utf-8", errors="replace")
    print(ancho, codigo, flush=True)
    assert codigo == 0 and f"NATIVO431_FINAL resolucion=({ancho}, {alto}) fallos=0" in texto
    assert not re.search(r"SCRIPT ERROR|Parse Error|(^|\n)(ERROR:|WARNING:)|leaked|still in use", texto)
print("NATIVO431_ADICIONAL_FINAL", flush=True)
