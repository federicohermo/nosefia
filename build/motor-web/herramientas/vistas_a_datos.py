"""Pasa las poses que leyó poses.mjs a datos/vistas.json: X, Y, Z y origen de la cámara, 12 números por vista."""
import json
import re
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
poses = json.loads((RAIZ / "herramientas" / "poses-godot.json").read_text(encoding="utf-8"))
salida = {}
for nombre, texto in poses.items():
    numeros = [float(x) for x in re.findall(r"-?\d+\.?\d*(?:e-?\d+)?", texto.split("|")[0])]
    assert len(numeros) == 12, (nombre, len(numeros))
    salida[nombre] = numeros
(RAIZ / "datos").mkdir(exist_ok=True)
(RAIZ / "datos" / "vistas.json").write_text(json.dumps(salida), encoding="utf-8")
print("vistas", len(salida))
