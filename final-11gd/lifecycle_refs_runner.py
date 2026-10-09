"""Contrasta cuatro variantes de referencia material, bajo FIFO y sin fuente editada."""

import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path.cwd().resolve()
OUT = Path(__file__).resolve().parent
results = []
for mode in ['original-null', 'original-retained', 'predelete-null', 'predelete-retained']:
    log = OUT / f'lifecycle-refs-{mode}.log'
    if log.exists():
        raise SystemExit(f'Conservar evidencia {log}')
    env = os.environ.copy()
    env['APPDATA'] = str(OUT / f'usuario-lifecycle-refs-{mode}')
    with log.open('w', encoding='utf-8', newline='\n') as output:
        result = subprocess.run([env['GODOT_BIN'], '--headless', '--verbose', '--path', str(ROOT),
                                 '-s', str(OUT / 'sonda_lifecycle_refs.gd'), '--', mode],
                                env=env, stdout=output, stderr=subprocess.STDOUT)
    raw = log.read_text(encoding='utf-8')
    errors = [line for line in raw.splitlines() if re.match(r'^(?:SCRIPT )?ERROR:', line)]
    item = {'mode': mode, 'exit': result.returncode, 'errors': errors, 'log': str(log),
            'checks': sum(line.startswith('LIFECYCLE OK ') for line in raw.splitlines()),
            'failed_checks': sum(line.startswith('LIFECYCLE FALLO ') for line in raw.splitlines()),
            'leak_warning': 'ObjectDB' in raw or 'resources still in use' in raw}
    item['valid_premises'] = (result.returncode == 0 and item['checks'] >= 16
                              and not item['failed_checks'] and not item['leak_warning']
                              and 'LIFECYCLE FIN fallos=0' in raw
                              and all('Parameter "material" is null' in line for line in errors))
    print(json.dumps(item), flush=True)
    results.append(item)
target = OUT / 'lifecycle-refs-resultados.json'
if target.exists():
    raise SystemExit('Conservar resultados existentes')
target.write_text(json.dumps(results, indent=2), encoding='utf-8', newline='\n')
raise SystemExit(0 if all(item['valid_premises'] for item in results) else 1)
