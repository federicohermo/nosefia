"""A/B con exactamente la misma ancla heredada y el mismo gatillo byte-idéntico."""

from pathlib import Path
import hashlib
import json
import os
import re
import subprocess

s = Path(__file__).parent
actual = Path.cwd()
base = s / '373-web-33828836' / 'proyecto'
ancla = 'test/dominio/empleo/consecuencia_test.gd'
gatillo = 'test/dominio/almacen/atencion_test.gd'
for nombre in [ancla, gatillo]:
    assert (base / nombre).read_text(encoding='utf-8') == (actual / nombre).read_text(encoding='utf-8'), nombre
resultados = []
for etiqueta, w, rutas in [
    ('base-completo', base, ['test']),
    ('actual-completo', actual, ['test']),
    ('base-atencion', base, [gatillo, ancla]),
    ('actual-atencion', actual, [gatillo, ancla]),
]:
    comando = [os.environ['GODOT_BIN'], '--path', str(w), '--headless', '--verbose',
               '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0',
               'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '--continue',
               '--ignoreHeadlessMode', '-rd', 'res://reports/control374-' + etiqueta]
    for ruta in rutas:
        comando.extend(['-a', ruta])
    for p in sorted((w / 'test').rglob('*_test.gd')):
        ruta = p.relative_to(w).as_posix()
        if ruta != ancla:
            comando.extend(['-i', ruta])
    r = subprocess.run(comando, cwd=w, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       encoding='utf-8', errors='replace', timeout=120)
    (s / ('374-control-' + etiqueta + '.log')).write_text(r.stdout, encoding='utf-8')
    limpio = re.sub(r'\x1b\[[0-9;]*m', '', r.stdout)
    recursos = [x for x in limpio.splitlines() if x.startswith('Resource still in use:')]
    resumen = {'etiqueta': etiqueta, 'comando': comando, 'exit': r.returncode,
               'recursos': recursos, 'script_errors': limpio.count('SCRIPT ERROR:'),
               'ancla_sha256_LF': hashlib.sha256((w / ancla).read_bytes().replace(b'\r\n', b'\n')).hexdigest(),
               'gatillo_sha256_LF': hashlib.sha256((w / gatillo).read_bytes().replace(b'\r\n', b'\n')).hexdigest(),
               'diagnosticos': [x for x in limpio.splitlines()
                               if x.startswith(('WARNING:', 'ERROR:', 'Executed test suites:'))]}
    resultados.append(resumen)
    (s / '374-control-equivalente.json').write_text(json.dumps(
        resultados, ensure_ascii=False, indent=2), encoding='utf-8')
    print(etiqueta, r.returncode, len(recursos), resumen['diagnosticos'], flush=True)
    assert r.returncode == 0 and not resumen['script_errors']
