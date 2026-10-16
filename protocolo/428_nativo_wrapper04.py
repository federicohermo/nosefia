from pathlib import Path
import json
import os
import subprocess
import sys

base = Path(__file__).parent
salida = base / '428/nativo-final04'
salida.mkdir()
assert not subprocess.check_output(['git', 'status', '--porcelain']).strip()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD']).decode().strip()
sys.path.insert(0, str(Path.cwd() / '.claude/scripts'))
from lib.godot import entorno_de_la_suite

env = entorno_de_la_suite(dict(os.environ), Path.cwd(), sys.platform)
for nombre, args in [
    ('import', ['--headless', '--import', '--quit']),
    ('nativo', ['--rendering-driver', 'opengl3', '--windowed', '--resolution', '1280x720',
                '--position', '0,0', '--script', str(base / '428_nativo_final04.gd')]),
]:
    r = subprocess.run([env['GODOT_BIN'], '--path', '.', *args], env=env,
                       capture_output=True, timeout=120)
    raw = r.stdout + r.stderr
    (salida / (nombre + '.log')).write_bytes(raw)
    texto = raw.decode('utf-8', errors='replace')
    print(nombre, r.returncode, texto[-1600:], flush=True)
    assert r.returncode == 0
    if nombre == 'nativo':
        assert '428_NATIVO_FINAL cuatro_gestos_reales fallas=[]' in texto
        assert not any(s in texto for s in ['SCRIPT ERROR:', 'Parse Error:', 'ERROR:',
            'WARNING:', 'leaked at exit', 'resources still in use'])
assert head == subprocess.check_output(['git', 'rev-parse', 'HEAD']).decode().strip()
(salida / 'fuente.json').write_text(json.dumps({'head': head,
    'script': str(base / '428_nativo_final04.gd'), 'cuatro_gestos': True}), encoding='utf-8')
print('428_NATIVO04_FINAL_OK', head)
