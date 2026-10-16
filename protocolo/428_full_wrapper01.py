"""Convergencia congelada; el conteo va inmediatamente después, sin otra suite."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

base = Path(__file__).parent / '428/full01'
base.mkdir()
raiz = Path.cwd()
assert not subprocess.check_output(['git', 'status', '--porcelain']).strip()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD']).decode().strip()
inicio = time.monotonic()
comando = [sys.executable, str(Path(__file__).parent / 'verificar_crudo.py'), str(base / 'crudo')]
with (base / 'verificar.log').open('wb') as archivo:
    resultado = subprocess.run(comando, stdout=archivo, stderr=subprocess.STDOUT)
with (base / 'conteo.log').open('wb') as archivo:
    conteo = subprocess.run(
        [sys.executable, '.claude/skills/implement-batch/scripts/conteo.py'],
        stdout=archivo, stderr=subprocess.STDOUT)
final = subprocess.check_output(['git', 'rev-parse', 'HEAD']).decode().strip()
assert final == head and not subprocess.check_output(['git', 'status', '--porcelain']).strip()
informe = {'head': head, 'exit_verificar': resultado.returncode,
           'exit_conteo': conteo.returncode, 'duracion_s': time.monotonic() - inicio,
           'cantidad_suites_fuente': len(list((raiz / 'test').rglob('*_test.gd'))),
           'salidas': {p.relative_to(base).as_posix(): {
               'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
               for p in base.rglob('*.log')}}
(base / 'auditoria.json').write_text(json.dumps(informe, indent=2), encoding='utf-8')
print((base / 'verificar.log').read_text(encoding='utf-8', errors='replace')[-2600:])
print((base / 'conteo.log').read_text(encoding='utf-8', errors='replace'))
print(json.dumps(informe, indent=2))
raise SystemExit(resultado.returncode or conteo.returncode)
