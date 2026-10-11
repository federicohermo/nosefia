import os
from pathlib import Path
import subprocess
import sys

env = os.environ.copy()
env['APPDATA'] = str(Path.cwd() / '.godot' / 'usuario_de_los_tests')
godot = env['GODOT_BIN']
codigo = subprocess.run([godot, '--headless', '--path', '.', '--import', '--quit'], env=env).returncode
if codigo:
    raise SystemExit(codigo)
codigo = 0
for indice, suite in enumerate(sys.argv[1:]):
    resultado = subprocess.run([godot, '--path', '.', '--headless', '-s', '-d',
        '--remote-debug', 'tcp://127.0.0.1:0',
        'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-a', suite, '--continue',
        '--ignoreHeadlessMode', '-rd', f'res://reports/focal-374-{indice}'], env=env)
    codigo = resultado.returncode or codigo
raise SystemExit(codigo)
