"""Ejecuta el main original de verificar y conserva su salida cruda de Godot."""

import sys
from pathlib import Path

raiz = Path.cwd().resolve()
sys.path.insert(0, str(raiz / ".claude/scripts"))
from lib.consola import configurar
import verificar

configurar()
salida = Path(sys.argv[1]).resolve()
salida.parent.mkdir(parents=True, exist_ok=True)
if salida.exists():
    raise SystemExit("Log ya existente: conservar y elegir un nombre nuevo")
original = verificar._correr


def con_log(nodo, *args, **kwargs):
    resultado = original(nodo, *args, **kwargs)
    if nodo == "tests":
        with salida.open("a", encoding="utf-8") as archivo:
            archivo.write(f"\n=== tests: codigo={resultado.codigo} ===\n")
            archivo.write(resultado.salida)
    return resultado


verificar._correr = con_log
verificar.main()
