"""Descubrimiento por grupos; sólo ejecuta el dominio nuevo como ancla breve."""

from pathlib import Path
import json
import os
import re
import subprocess

s = Path(__file__).parent
w = Path.cwd()
ancla = 'test/dominio/empleo/instrucciones_del_jefe_test.gd'
archivos = [p.relative_to(w).as_posix() for p in sorted((w / 'test').rglob('*_test.gd'))]
resultados = []
for grupo in ['dominio', 'escenas', 'sistemas', 'ui']:
    incluidos = ['test/' + grupo]
    if grupo != 'dominio':
        incluidos.append(ancla)
    comando = [os.environ['GODOT_BIN'], '--path', str(w), '--headless', '--verbose',
               '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0',
               'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '--continue',
               '--ignoreHeadlessMode', '-rd', 'res://reports/diagnosticoGrupo374-' + grupo]
    for ruta in incluidos:
        comando.extend(['-a', ruta])
    for ruta in archivos:
        if ruta != ancla:
            comando.extend(['-i', ruta])
    r = subprocess.run(comando, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       encoding='utf-8', errors='replace', timeout=120)
    (s / ('374-discovery-grupo-' + grupo + '.log')).write_text(r.stdout, encoding='utf-8')
    limpio = re.sub(r'\x1b\[[0-9;]*m', '', r.stdout)
    recursos = [x for x in limpio.splitlines() if x.startswith('Resource still in use:')]
    resumen = {'grupo': grupo, 'comando': comando, 'exit': r.returncode,
               'recursos': recursos, 'script_errors': limpio.count('SCRIPT ERROR:'),
               'diagnosticos': [x for x in limpio.splitlines()
                               if x.startswith(('WARNING:', 'ERROR:', 'Executed test suites:'))]}
    resultados.append(resumen)
    (s / '374-discovery-grupos.json').write_text(json.dumps(
        resultados, ensure_ascii=False, indent=2), encoding='utf-8')
    print(grupo, r.returncode, len(recursos), resumen['diagnosticos'], flush=True)
    assert r.returncode == 0 and not resumen['script_errors']
