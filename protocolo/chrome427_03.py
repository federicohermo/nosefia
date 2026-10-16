import json
from pathlib import Path
import subprocess

p = Path(__file__).parent
wt = 'D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/.claude/worktrees/batch-426-427-presentacion'
args = ['node', str(p/'recorrer_archivos427_03.mjs'), wt,
        'http://127.0.0.1:8067/index.html', str(p/'web-real-03'), str(p/'checkpoint-j2.guardado')]
process = subprocess.Popen(args)
try:
    code = process.wait(timeout=720)
except subprocess.TimeoutExpired:
    (p/'chrome427-03-timeout.json').write_text(json.dumps({'pid':process.pid,'limite_segundos':720,'args':args}), encoding='utf-8')
    subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'])
    raise SystemExit(124)
raise SystemExit(code)
