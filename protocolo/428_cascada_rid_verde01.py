from pathlib import Path
import json
import os
import subprocess
import sys

base = Path(__file__).parent
salida = base / '428/cascada-rid-verde01'
salida.mkdir()
assert not subprocess.check_output(['git', 'status', '--porcelain']).strip()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD']).decode().strip()
sys.path.insert(0, str(Path.cwd() / '.claude/scripts'))
from lib.godot import entorno_de_la_suite

env = entorno_de_la_suite(dict(os.environ), Path.cwd(), sys.platform)
fases = [('import', ['--headless', '--import', '--quit'])]
for nombre, ruta in [
    ('puentes-y-matriz', 'escenas/objetos/apoyos_de_bordes_de_cajas'),
    ('cascada-heredada', 'escenas/objetos/caja_que_se_lleva'),
    ('sistema', 'sistemas/marco/red_de_seguridad'),
    ('reserva', 'escenas/puestos/reserva_de_gondolas'),
    ('integrada', 'escenas/red_de_seguridad_integrada'),
]:
    fases.append((nombre, ['--headless', '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0',
        'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-a', 'test/' + ruta + '_test.gd',
        '--continue', '--ignoreHeadlessMode', '-rd', 'res://reports/428-cascada-rid-verde01']))
for nombre, args in fases:
    r = subprocess.run([env['GODOT_BIN'], '--path', '.', *args], env=env,
                       capture_output=True, timeout=300)
    raw = r.stdout + r.stderr
    (salida / (nombre + '.log')).write_bytes(raw)
    texto = raw.decode('utf-8', errors='replace')
    print(nombre, r.returncode, texto[-900:], flush=True)
    assert r.returncode == 0 and not any(x in texto for x in ['SCRIPT ERROR:', 'Parse Error:'])

carpeta = base / '428/nativo-final05'
carpeta.mkdir()
r = subprocess.run([env['GODOT_BIN'], '--path', '.', '--rendering-driver', 'opengl3',
    '--windowed', '--resolution', '1280x720', '--position', '0,0',
    '--script', str(base / '428_nativo_final05.gd')], env=env, capture_output=True, timeout=120)
raw = r.stdout + r.stderr
(carpeta / 'nativo.log').write_bytes(raw)
texto = raw.decode('utf-8', errors='replace')
print('nativo', r.returncode, texto[-1400:], flush=True)
assert r.returncode == 0 and '428_NATIVO_FINAL cuatro_gestos_reales fallas=[]' in texto
assert not any(x in texto for x in ['SCRIPT ERROR:', 'Parse Error:', 'ERROR:', 'WARNING:'])
assert head == subprocess.check_output(['git', 'rev-parse', 'HEAD']).decode().strip()
(carpeta / 'fuente.json').write_text(json.dumps({'head': head,
    'script': str(base / '428_nativo_final05.gd'), 'cuatro_gestos': True}), encoding='utf-8')
print('428_CASCADA_RID_VERDE_FIN', head)
