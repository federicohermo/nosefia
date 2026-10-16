from pathlib import Path
import os
import subprocess
import sys

base = Path(__file__).parent
salida = base / '428/runner-traza03'
salida.mkdir()
sys.path.insert(0, str(Path.cwd() / '.claude/scripts'))
from lib.godot import entorno_de_la_suite

env = entorno_de_la_suite(dict(os.environ), Path.cwd(), sys.platform)
for nombre, args in [
    ('import', ['--headless', '--import', '--quit']),
    ('runner', ['--headless', '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0',
        str(base / '428_03_GdUnitCmdTool.gd'), '-a',
        'test/escenas/objetos/caja_que_se_lleva_test.gd', '--continue',
        '--ignoreHeadlessMode', '-rd', 'res://reports/428-runner-traza03']),
]:
    r = subprocess.run([env['GODOT_BIN'], '--path', '.', *args], env=env,
                       capture_output=True, timeout=300)
    raw = r.stdout + r.stderr
    (salida / (nombre + '.log')).write_bytes(raw)
    texto = raw.decode('utf-8', errors='replace')
    print(nombre, r.returncode, texto[-1400:], flush=True)
    assert not any(x in texto for x in ['SCRIPT ERROR:', 'Parse Error:'])
    if nombre == 'import':
        assert r.returncode == 0
    else:
        assert 'Executed test cases : (20/20)' in texto and '428_RUNNER_PILA' in texto
print('428_RUNNER_TRAZA_COMPLETA; diagnostico observado, no verde de producto.')
