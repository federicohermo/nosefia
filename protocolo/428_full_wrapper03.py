"""Convergencia congelada con límite de su propia familia de procesos y XML preservado."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys
import time

base = Path(__file__).parent / '428/full03'
base.mkdir()
raiz = Path.cwd()
assert not subprocess.check_output(['git', 'status', '--porcelain']).strip()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD']).decode().strip()
inicio = time.monotonic()
comando = [sys.executable, str(Path(__file__).parent / 'verificar_crudo.py'), str(base / 'crudo')]
with (base / 'verificar.log').open('wb') as archivo:
    proceso = subprocess.Popen(comando, stdout=archivo, stderr=subprocess.STDOUT)
    try:
        exit_verificar = proceso.wait(timeout=2700)
    except subprocess.TimeoutExpired:
        subprocess.run(['taskkill', '/PID', str(proceso.pid), '/T', '/F'], check=False,
                       stdout=archivo, stderr=subprocess.STDOUT)
        proceso.wait(timeout=30)
        (base / 'timeout.json').write_text(json.dumps({'pid_propio': proceso.pid,
            'head': head, 'limite_s': 2700}), encoding='utf-8')
        raise SystemExit(124)
with (base / 'conteo.log').open('wb') as archivo:
    conteo = subprocess.run(
        [sys.executable, '.claude/skills/implement-batch/scripts/conteo.py'],
        stdout=archivo, stderr=subprocess.STDOUT, timeout=60)
reportes = sorted((raiz / 'reports').glob('report_*/results.xml'), key=lambda p: p.stat().st_mtime)
assert reportes, 'La suite debe producir su XML.'
reporte = reportes[-1]
shutil.copyfile(reporte, base / 'results.xml')
final = subprocess.check_output(['git', 'rev-parse', 'HEAD']).decode().strip()
assert final == head and not subprocess.check_output(['git', 'status', '--porcelain']).strip()
informe = {'head': head, 'exit_verificar': exit_verificar,
           'exit_conteo': conteo.returncode, 'duracion_s': time.monotonic() - inicio,
           'limite_verificar_s': 2700, 'reporte_original': str(reporte),
           'cantidad_suites_fuente': len(list((raiz / 'test').rglob('*_test.gd'))),
           'salidas': {p.relative_to(base).as_posix(): {
               'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
               for p in base.rglob('*') if p.is_file()}}
(base / 'auditoria.json').write_text(json.dumps(informe, indent=2), encoding='utf-8')
print((base / 'verificar.log').read_text(encoding='utf-8', errors='replace')[-2600:])
print((base / 'conteo.log').read_text(encoding='utf-8', errors='replace'))
print(json.dumps(informe, indent=2))
raise SystemExit(exit_verificar or conteo.returncode)
