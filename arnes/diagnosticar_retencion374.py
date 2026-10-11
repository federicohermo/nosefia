"""Sonda acotada: las tres suites nuevas juntas, con inventario verbose del motor."""

from pathlib import Path
import json
import os
import subprocess
import sys

s = Path(__file__).parent
w = Path.cwd()
comando = [os.environ['GODOT_BIN'], '--path', str(w), '--headless', '--verbose',
           '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0',
           'res://addons/gdUnit4/bin/GdUnitCmdTool.gd',
           '-a', 'test/dominio/empleo/instrucciones_del_jefe_test.gd',
           '-a', 'test/ui/interrupciones/pantalla_de_instrucciones_test.gd',
           '-a', 'test/escenas/instrucciones_en_el_almacen_test.gd',
           '--continue', '--ignoreHeadlessMode', '-rd', 'res://reports/diagnostico374']
(s / '374-retencion-comando.json').write_text(json.dumps({
    'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'comando': comando,
}, ensure_ascii=False, indent=2), encoding='utf-8')
r = subprocess.run(comando, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                   encoding='utf-8', errors='replace', timeout=180)
print(r.stdout, end='', flush=True)
sys.exit(r.returncode)
