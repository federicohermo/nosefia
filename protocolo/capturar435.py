import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path.cwd() / '.claude/scripts'))
from lib.godot import resolver, entorno_de_la_suite

scratch = Path(__file__).parent
binary = resolver(dict(os.environ))[0]
out = scratch / '435-capturas'
args = [binary, '--path', str(Path.cwd()), '--rendering-driver', 'opengl3',
        '--script', str(scratch / 'capturar435.gd'), '--', str(out)]
process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           env=entorno_de_la_suite(dict(os.environ), Path.cwd(), sys.platform), text=True,
                           encoding='utf-8', errors='replace')
try:
    raw, _ = process.communicate(timeout=180)
except subprocess.TimeoutExpired:
    subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'])
    raw, _ = process.communicate()
    print(raw)
    sys.exit(124)
print(raw)
if process.returncode or 'CAPTURAS435_FINAL 14' not in raw or any(x in raw for x in ['ERROR:', 'SCRIPT ERROR', 'Parse Error', 'leaked at exit', 'Resources still in use']):
    sys.exit(1)
