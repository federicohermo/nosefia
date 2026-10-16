import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path


sys.stdout.reconfigure(encoding="utf-8", errors="replace")
raiz = Path.cwd()
scratch = Path(__file__).parent
parser = argparse.ArgumentParser()
parser.add_argument("destino", type=Path)
parser.add_argument("paquete", type=Path)
parser.add_argument("--solo-paquete", action="store_true")
parser.add_argument("--plantilla", type=Path, required=True)
parser.add_argument("--manifiesto", type=Path, required=True)
args = parser.parse_args()
destino = args.destino.resolve()
head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
if not args.solo_paquete and head != "6d60f82c16bbbc1f7182e656ebead8df8bf5ad87":
    raise SystemExit("Las capturas nativas431 requieren su fuente fijada, no HEAD22")
sys.path.insert(0, str(raiz / ".claude/scripts"))
from lib.godot import resolver

godot, procedencia = resolver(dict(os.environ))
assert godot, "Godot no declarado"
print("GODOT431", procedencia, godot, flush=True)
destino.mkdir(parents=True, exist_ok=True)
entorno = dict(os.environ)
entorno["GODOT_BIN"] = godot
entorno["APPDATA"] = str(destino / "usuario-aislado")
Path(entorno["APPDATA"]).mkdir(exist_ok=True)
comandos = []


def correr(nombre, comando, cwd=raiz, marcador=None, timeout=180):
    log = destino / f"{nombre}.log"
    with log.open("wb") as salida:
        resultado = subprocess.run(comando, cwd=cwd, env=entorno, stdout=salida, stderr=subprocess.STDOUT, timeout=timeout)
    texto = log.read_text(encoding="utf-8", errors="replace")
    comandos.append({"nombre": nombre, "comando": comando, "cwd": str(cwd), "codigo": resultado.returncode})
    (destino / "comandos.json").write_text(json.dumps(comandos, ensure_ascii=False, indent=2), encoding="utf-8")
    print(nombre, resultado.returncode, str(log), flush=True)
    assert resultado.returncode == 0, nombre
    if marcador:
        assert marcador in texto, f"Falta marcador: {nombre}"
        assert not re.search(r"SCRIPT ERROR|Parse Error|(^|\n)(ERROR:|WARNING:)|leaked|still in use", texto), f"Diagnósticos en {log}"


capturas = destino / "nativo"
capturas.mkdir(exist_ok=True)
if not args.solo_paquete:
    for ancho, alto in ((1920, 1080), (1280, 720)):
        correr(f"nativo-{ancho}", [godot, "--path", str(raiz), "--rendering-driver", "opengl3", "--script", str(scratch / "capturar_nativo431.gd"), "--", str(capturas), str(ancho), str(alto)], marcador=f"NATIVO431_FINAL resolucion=({ancho}, {alto}) fallos=0")
paquete = args.paquete.resolve()
(destino / "paquete-ruta.txt").write_text(str(paquete), encoding="utf-8")
correr("exportar", [sys.executable, str(scratch / "exportar_paquete431.py"), str(paquete), str(args.plantilla.resolve()), str(args.manifiesto.resolve())], timeout=600)
web = paquete / "web"
checkpoint = destino / "checkpoint-jornada-2.guardado"
correr("sonda-paquete", [godot, "--headless", "--path", str(web), "--main-pack", str(web / "index.pck"), "--script", str(scratch / "paquete431.gd"), "--", str(checkpoint)], cwd=web, marcador="PAQUETE431_FINAL fallos=0")
correr("dialogos-paquete", [godot, "--headless", "--path", str(web), "--main-pack", str(web / "index.pck"), "--script", str(paquete / "proyecto/.github/scripts/verificar_dialogos_exportados.gd")], cwd=web)
print("CAPTURAS_Y_PAQUETE431_FINAL", flush=True)
