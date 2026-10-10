from pathlib import Path
import hashlib
import json
import os
import re
import subprocess

s=Path(__file__).parent
r=Path.cwd()
destino=Path((s/'373-web-path.txt').read_text(encoding='utf-8'))
proyecto=destino/'proyecto'
commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
ficha=json.loads((destino/'huellas.json').read_text(encoding='utf-8'))
exportado=ficha['commit']
subprocess.run(['git','diff','--quiet',exportado,commit,'--','src','assets','project.godot','export_presets.cfg'],check=True)
comando=[os.environ['GODOT_BIN'],'--path',str(proyecto),'--rendering-method','gl_compatibility','--rendering-driver','opengl3','--resolution','1280x720','--script',str(s/'capturar373-largo.gd')]
proceso=subprocess.run(comando,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
texto=proceso.stdout.decode('utf-8',errors='replace')
print(texto,end='',flush=True)
if proceso.returncode or re.search(r'(?m)^(SCRIPT ERROR|ERROR|WARNING):',texto):
    raise SystemExit(proceso.returncode or 1)
ficha={'commit':exportado,'verificacion_commit':commit,'fixture_sha256':hashlib.sha256((s/'capturar373-largo.gd').read_bytes()).hexdigest(),'modelo_sha256':hashlib.sha256((proyecto/'assets/models/SEPT_JUEGOS_PROTOTIPO.glb').read_bytes()).hexdigest(),'project_externo_sha256':hashlib.sha256((proyecto/'project.godot').read_bytes()).hexdigest(),'preset_sha256':hashlib.sha256((proyecto/'export_presets.cfg').read_bytes()).hexdigest(),'origen':'git archive + import frío del modelo; sólo editor_plugins deshabilitados y main_scene de sonda en la copia externa.'}
assert ficha['modelo_sha256']==hashlib.sha256((r/'assets/models/SEPT_JUEGOS_PROTOTIPO.glb').read_bytes()).hexdigest()
(s/'capturas373/escritorio-procedencia.json').write_text(json.dumps(ficha,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps(ficha,indent=2,ensure_ascii=False))
