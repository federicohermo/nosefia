"""Conservar stdout y stderr de cada nodo, también cuando verificar.py sale verde."""

import importlib.util
import subprocess
import sys
from pathlib import Path

raiz = Path.cwd()
prefijo = Path(sys.argv[1])
script = raiz / '.claude/scripts/verificar.py'
sys.path.insert(0, str(script.parent))
spec = importlib.util.spec_from_file_location('verificar_batch', script)
modulo = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = modulo
spec.loader.exec_module(modulo)
correr_original = modulo._correr


def correr_con_log(nodo, comando, cwd=modulo.RAIZ, entorno=None):
    resultado = correr_original(nodo, comando, cwd, entorno)
    sufijo = 'importacion' if '--import' in comando else nodo
    ruta = prefijo.with_name(prefijo.name + '-' + sufijo + '.log')
    ruta.parent.mkdir(parents=True, exist_ok=True)
    ruta.write_text(resultado.salida, encoding='utf-8')
    return resultado


modulo._correr = correr_con_log
sys.argv = [str(script)]
try:
    modulo.main()
except SystemExit as salida:
    codigo = int(salida.code or 0)
conteo = subprocess.run([
    sys.executable, '.claude/skills/implement-batch/scripts/conteo.py'
]).returncode
raise SystemExit(codigo or conteo)
