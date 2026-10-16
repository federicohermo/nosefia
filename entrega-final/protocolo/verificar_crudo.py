import os
import sys
from pathlib import Path
sys.path.insert(0, str(Path.cwd() / '.claude/scripts'))
import verificar
from lib.godot import resolver
os.environ['GODOT_BIN'] = resolver(dict(os.environ))[0]
destino = Path(sys.argv[1])
destino.mkdir(parents=True, exist_ok=True)
original = verificar._correr
def guardar(nodo, comando, **kwargs):
    resultado = original(nodo, comando, **kwargs)
    nombre = nodo + ('-import' if '--import' in comando else '')
    (destino / (nombre + '.log')).write_text(resultado.salida, encoding='utf-8')
    return resultado
verificar._correr = guardar
verificar.main([])
