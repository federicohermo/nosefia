"""Ejecuta comparación EXTERNA bajo turno.py, con fuente E limpia y congelada."""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path.cwd().resolve()
OUT = Path(__file__).resolve().parent
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
status = subprocess.check_output(['git', 'status', '--short'], text=True)
if head != '55af872433ec3d89354205e8e061c87776c659b9' or status.strip():
    raise SystemExit('No coincide fuente congelada; no ejecutar')
results = []
for mode in ['original', 'predelete']:
    log = OUT / f'lifecycle-{mode}.log'
    if log.exists():
        raise SystemExit(f'Conservar log: {log}')
    env = os.environ.copy()
    env['APPDATA'] = str(OUT / f'usuario-lifecycle-{mode}')
    command = [env['GODOT_BIN'], '--headless', '--verbose', '--path', str(ROOT),
               '-s', str(OUT / 'sonda_lifecycle.gd'), '--', mode]
    with log.open('w', encoding='utf-8', newline='\n') as output:
        result = subprocess.run(command, env=env, stdout=output, stderr=subprocess.STDOUT)
    raw = log.read_text(encoding='utf-8')
    errors = [line for line in raw.splitlines() if re.match(r'^(?:SCRIPT )?ERROR:', line)]
    item = {'mode': mode, 'head': head, 'exit': result.returncode, 'log': str(log),
            'appdata': env['APPDATA'], 'errors': errors,
            'checks': sum(line.startswith('LIFECYCLE OK ') for line in raw.splitlines()),
            'failed_checks': sum(line.startswith('LIFECYCLE FALLO ') for line in raw.splitlines()),
            'leak_warning': 'ObjectDB' in raw or 'resources still in use' in raw}
    material = [line for line in errors if 'Parameter "material" is null' in line]
    expected = len(material) >= 1 if mode == 'original' else len(material) == 0
    item['valid'] = (result.returncode == 0 and expected and len(material) == len(errors)
                     and not item['failed_checks'] and item['checks'] >= 14
                     and not item['leak_warning'] and 'LIFECYCLE FIN fallos=0' in raw)
    results.append(item)
    print(json.dumps(item), flush=True)
target = OUT / 'lifecycle-resultados.json'
if target.exists():
    raise SystemExit('Conservar resultados existentes')
target.write_text(json.dumps(results, indent=2), encoding='utf-8', newline='\n')
status_after = subprocess.check_output(['git', 'status', '--short'], text=True)
raise SystemExit(0 if all(item['valid'] for item in results) and not status_after.strip() else 1)
