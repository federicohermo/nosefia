from pathlib import Path
import os
import subprocess
import sys

base = Path(__file__).parent
salida = base / '428/full-regresiones-verde01'
salida.mkdir()
sys.path.insert(0, str(Path.cwd() / '.claude/scripts'))
from lib.godot import entorno_de_la_suite

env = entorno_de_la_suite(dict(os.environ), Path.cwd(), sys.platform)
fases = [('import', ['--headless', '--import', '--quit'])]
for nombre, ruta in [
    ('cascada-heredada', 'escenas/objetos/caja_que_se_lleva'),
    ('bolsa-heredada', 'escenas/reposicion_manual'),
    ('sistema', 'sistemas/marco/red_de_seguridad'),
    ('integrada', 'escenas/red_de_seguridad_integrada'),
    ('matriz', 'escenas/objetos/apoyos_de_bordes_de_cajas'),
    ('reserva', 'escenas/puestos/reserva_de_gondolas'),
]:
    fases.append((nombre, [
        '--headless', '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0',
        'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-a', 'test/' + ruta + '_test.gd',
        '--continue', '--ignoreHeadlessMode', '-rd', 'res://reports/428-full-regresiones-verde01']))
for nombre, argumentos in fases:
    resultado = subprocess.run([env['GODOT_BIN'], '--path', '.', *argumentos],
                               env=env, capture_output=True, timeout=300)
    raw = resultado.stdout + resultado.stderr
    (salida / (nombre + '.log')).write_bytes(raw)
    print('428_REGRESIONES_FASE', nombre, resultado.returncode, flush=True)
    print(raw.decode('utf-8', errors='replace')[-4500:], flush=True)
    if resultado.returncode:
        raise SystemExit(resultado.returncode)

carpeta = base / '428/nativo-final04'
carpeta.mkdir()
resultado = subprocess.run([env['GODOT_BIN'], '--path', '.',
    '--rendering-driver', 'opengl3', '--windowed', '--resolution', '1280x720',
    '--position', '0,0', '--script', str(base / '428_nativo_final03.gd')],
    env=env, capture_output=True, timeout=120)
raw = resultado.stdout + resultado.stderr
(salida / 'nativo-final.log').write_bytes(raw)
texto = raw.decode('utf-8', errors='replace')
print('428_NATIVE_REPOSO', resultado.returncode, flush=True)
assert resultado.returncode == 0 and '428_NATIVO_FINAL cuatro_gestos_reales fallas=[]' in texto
assert not any(s in texto for s in ['SCRIPT ERROR:', 'Parse Error:', 'ERROR:', 'WARNING:',
                                   'leaked at exit', 'resources still in use'])
print('428_REGRESIONES_FOCAL_VERDE_FIN')

