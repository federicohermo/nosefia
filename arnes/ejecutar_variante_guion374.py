"""Mismo producto en cinco copias; la ancla ejecutada siempre es Consecuencia heredada."""

from pathlib import Path
import json
import os
import re
import subprocess

s = Path(__file__).parent
raiz = s / '374-variantes-discovery'
ancla = 'test/dominio/empleo/consecuencia_test.gd'
resultados = []
for etiqueta in ['consecuencia', 'instrucciones']:
    w = raiz / 'control'
    ancla = 'test/dominio/empleo/' + ('consecuencia_test.gd' if etiqueta == 'consecuencia' else 'instrucciones_del_jefe_test.gd')
    comando = [os.environ['GODOT_BIN'], '--path', str(w), '--headless', '--verbose',
               '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0',
               'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-a', 'test', '--continue',
               '--ignoreHeadlessMode', '-rd', 'res://reports/diagnosticoVariantes374']
    for p in sorted((w / 'test').rglob('*_test.gd')):
        ruta = p.relative_to(w).as_posix()
        if ruta != ancla:
            comando.extend(['-i', ruta])
    r = subprocess.run(comando, cwd=w, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       encoding='utf-8', errors='replace', timeout=120)
    (s / ('374-variante-guion-' + etiqueta + '.log')).write_text(r.stdout, encoding='utf-8')
    limpio = re.sub(r'\x1b\[[0-9;]*m', '', r.stdout)
    recursos = [x for x in limpio.splitlines() if x.startswith('Resource still in use:')]
    resumen = {'etiqueta': etiqueta, 'comando': comando, 'exit': r.returncode,
               'recursos': recursos, 'script_errors': limpio.count('SCRIPT ERROR:'),
               'diagnosticos': [x for x in limpio.splitlines()
                               if x.startswith(('WARNING:', 'ERROR:', 'Executed test suites:'))]}
    resultados.append(resumen)
    (s / '374-variante-guion-resultados.json').write_text(json.dumps(
        resultados, ensure_ascii=False, indent=2), encoding='utf-8')
    print(etiqueta, r.returncode, len(recursos), resumen['diagnosticos'], flush=True)
    assert r.returncode == 0 and not resumen['script_errors']
