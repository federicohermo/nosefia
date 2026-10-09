"""RED/GREEN del lifecycle de caja bajo turno.py, raw fusionado y sin sobrescribir."""

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path.cwd().resolve()
OUT = Path(__file__).resolve().parent
phase = sys.argv[1]
if phase not in ['red3', 'green3']:
    raise SystemExit('Fase inválida')
env = os.environ.copy()
env['APPDATA'] = str(ROOT / '.godot/usuario_de_los_tests')
godot = env['GODOT_BIN']
suites = ['test/escenas/objetos/caja_de_productos_test.gd']
if phase == 'green3':
    suites += ['test/escenas/objetos/caja_que_se_lleva_test.gd',
               'test/escenas/objetos/caja_que_recibe_y_cuenta_test.gd']
jobs = [('import', [godot, '--headless', '--path', str(ROOT), '--import', '--quit'])]
jobs += [(Path(suite).stem, [godot, '--headless', '--path', str(ROOT), '-s', '-d',
          '--remote-debug', 'tcp://127.0.0.1:0', 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd',
          '-a', f'res://{suite}', '--continue', '--ignoreHeadlessMode',
          '-rd', 'res://reports/b-e-green3g']) for suite in suites]
code = 0
for label, command in jobs:
    log = OUT / f'b-e-green3g-{label}.log'
    if log.exists():
        raise SystemExit(f'Conservar evidencia {log}')
    print(f'FOCAL_START {phase} {label}', flush=True)
    with log.open('w', encoding='utf-8', newline='\n') as output:
        result = subprocess.run(command, env=env, stdout=output, stderr=subprocess.STDOUT)
    print(f'FOCAL_EXIT {result.returncode} {log}', flush=True)
    code = result.returncode or code
    if label == 'import' and code:
        break
raise SystemExit(code)
