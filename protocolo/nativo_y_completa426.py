import os
from pathlib import Path
import re
import subprocess
import sys

p = Path(__file__).parent
sys.path.insert(0, str(Path.cwd()/'.claude/scripts'))
from lib.godot import resolver, entorno_de_la_suite
binary = resolver(dict(os.environ))[0]
env = entorno_de_la_suite(dict(os.environ), Path.cwd(), sys.platform)
args = [binary, '--path', str(Path.cwd()), '--rendering-driver', 'opengl3',
        '--script', str(p/'diagnostico426.gd'), '--', str(p/'nativo-01')]
log = p/'nativo-01.log'
with log.open('wb') as stream:
    process = subprocess.Popen(args, env=env, stdout=stream, stderr=subprocess.STDOUT)
    try:
        code = process.wait(timeout=240)
    except subprocess.TimeoutExpired:
        subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'])
        raise SystemExit(124)
raw = log.read_text(encoding='utf-8', errors='replace')
print(raw, flush=True)
if code or 'DIAGNOSTICO426_FINAL fallo=false' not in raw or re.search(r'SCRIPT ERROR|Parse Error|(^|\s)ERROR:|leaked at exit|Resources still in use',raw):
    raise SystemExit(1)
code = subprocess.run([sys.executable, str(p.parent/'verificar_crudo.py'), str(p.parent/'426-crudo-01')]).returncode
conteo = subprocess.run([sys.executable, '.claude/skills/implement-batch/scripts/conteo.py']).returncode
raise SystemExit(code or conteo)
