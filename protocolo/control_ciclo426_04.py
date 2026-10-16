import os
from pathlib import Path
import subprocess
import sys
import re
import json

p=Path(__file__).parent
sys.path.insert(0,str(Path.cwd()/'.claude/scripts'))
from lib.godot import resolver, entorno_de_la_suite
binary=resolver(dict(os.environ))[0]
args=[binary,'--path',str(Path.cwd()),'--rendering-driver','opengl3',
      '--script',str(p/'diagnostico426_04.gd'),'--',str(p/'nativo-04')]
env=entorno_de_la_suite(dict(os.environ),Path.cwd(),sys.platform)
with (p/'nativo-04.log').open('wb') as stream:
    proceso=subprocess.Popen(args,env=env,stdout=stream,stderr=subprocess.STDOUT)
    try:
        code=proceso.wait(timeout=240)
    except subprocess.TimeoutExpired:
        subprocess.run(['taskkill','/PID',str(proceso.pid),'/T','/F'])
        raise SystemExit(124)
raw=(p/'nativo-04.log').read_text(encoding='utf-8',errors='replace')
print(raw,flush=True)
incidente={'fuente':'e3f9aafc','control':'Control04: antes de la primera escena espera un process_frame/frame_post_draw de raiz; captura arranque y registra identidad de camara real. No cambia fuente, luz, GI ni colliders.',
           'anterior':'Comprobaciones funcionales pasaron; primer escenario Saladik no es evidencia visual valida porque sus PNG muestran el mundo casi negro. Jorgillo y mixtos visibles. Causa no atribuida.',
           'exit':code,'args':args,'script_sha256':__import__('hashlib').sha256((p/'diagnostico426_04.gd').read_bytes()).hexdigest()}
(p/'nativo-04-control.json').write_text(json.dumps(incidente,indent=2),encoding='utf-8')
fallo=code or 'DIAGNOSTICO426_FINAL fallo=false' not in raw or re.search(r'SCRIPT ERROR|Parse Error|(^|\s)ERROR:|leaked at exit|Resources still in use',raw)
raise SystemExit(1 if fallo else 0)
