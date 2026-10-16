"""Calcula todas las salidas antes de escribir; estructura debe permanecer byteidéntica."""
import importlib.util
from pathlib import Path

raiz = Path.cwd()
spec = importlib.util.spec_from_file_location(
    "disponer_434", raiz / ".claude/scripts/blender/disponer.py")
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
salidas = {}
escribir_original = modulo.escribir


def recoger(ruta, texto):
    salidas[ruta] = texto


modulo.escribir = recoger
modulo.principal()
assert modulo.ESTRUCTURA in salidas, "El generador no calculó la estructura"
calculada = salidas[modulo.ESTRUCTURA].encode("utf-8")
if calculada != modulo.ESTRUCTURA.read_bytes():
    destino = Path("C:/Users/fede_/AppData/Local/Temp/nosefia-batch-425-435/434-recursos-escala-local01/434-estructura-calculada.tscn")
    destino.write_bytes(calculada)
    raise RuntimeError("La estructura calculada difiere: ningún archivo fue escrito")
for ruta, texto in salidas.items():
    escribir_original(ruta, texto)
print("434_ESTRUCTURA_BYTEIDENTICA_ANTES_DE_ESCRIBIR")
