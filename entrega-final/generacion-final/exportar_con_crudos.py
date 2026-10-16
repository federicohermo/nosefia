"""Ejecuta el exportador versionado conservando sus canales internos completos."""
from pathlib import Path
import runpy
import subprocess
import sys

base = Path(__file__).resolve().parent
original = subprocess.run
contador = 0
etapa = sys.argv[1]
assert etapa in ("primera", "repetida")


def conservar(comando, **opciones):
    global contador
    contador += 1
    texto = opciones.pop("text", False)
    encoding = opciones.pop("encoding", "utf-8")
    errors = opciones.pop("errors", "strict")
    resultado = original(comando, timeout=900, **opciones)
    (base/f"exportador-{etapa}-{contador}-stdout.log").write_bytes(resultado.stdout or b"")
    (base/f"exportador-{etapa}-{contador}-stderr.log").write_bytes(resultado.stderr or b"")
    if texto:
        resultado.stdout = (resultado.stdout or b"").decode(encoding, errors)
        resultado.stderr = (resultado.stderr or b"").decode(encoding, errors)
    return resultado


subprocess.run = conservar
runpy.run_path(str(Path.cwd()/".claude/scripts/exportar_modelo.py"), run_name="__main__")
