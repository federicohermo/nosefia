from pathlib import Path
import os
import subprocess
import sys

base = Path(__file__).parent / '428/full-regresiones-rojo01'
base.mkdir()
sys.path.insert(0, str(Path.cwd() / '.claude/scripts'))
from lib.godot import entorno_de_la_suite

env = entorno_de_la_suite(dict(os.environ), Path.cwd(), sys.platform)
for nombre, argumentos in [
    ('import', ['--headless', '--import', '--quit']),
    ('tests', ['--headless', '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0',
               'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-a',
               'test/sistemas/marco/red_de_seguridad_test.gd', '--continue',
               '--ignoreHeadlessMode', '-rd', 'res://reports/428-full-regresiones-rojo01']),
]:
    result = subprocess.run([env['GODOT_BIN'], '--path', '.', *argumentos], env=env,
                            capture_output=True, timeout=240)
    raw = result.stdout + result.stderr
    (base / (nombre + '.log')).write_bytes(raw)
    print(raw.decode('utf-8', errors='replace'), flush=True)
    if result.returncode:
        raise SystemExit(result.returncode)
