"""Descubre todo, ejecuta sólo los catorce casos nuevos y conserva retención verbose."""

from pathlib import Path
import json
import os
import subprocess
import sys

s = Path(__file__).parent
w = Path.cwd()
nuevas = {
    'test/dominio/empleo/instrucciones_del_jefe_test.gd',
    'test/ui/interrupciones/pantalla_de_instrucciones_test.gd',
    'test/escenas/instrucciones_en_el_almacen_test.gd',
}
ignoradas = [p.relative_to(w).as_posix() for p in sorted((w / 'test').rglob('*_test.gd'))
             if p.relative_to(w).as_posix() not in nuevas]
assert len(ignoradas) == 236
comando = [os.environ['GODOT_BIN'], '--path', str(w), '--headless', '--verbose',
           '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0',
           'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-a', 'test',
           '--continue', '--ignoreHeadlessMode', '-rd', 'res://reports/diagnosticoDiscovery374']
for ruta in ignoradas:
    comando.extend(['-i', ruta])
(s / '374-discovery-comando.json').write_text(json.dumps({
    'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'comando': comando, 'exclusiones_solo_diagnostico': ignoradas,
}, ensure_ascii=False, indent=2), encoding='utf-8')
r = subprocess.run(comando, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                   encoding='utf-8', errors='replace', timeout=180)
print(r.stdout, end='', flush=True)
sys.exit(r.returncode)
