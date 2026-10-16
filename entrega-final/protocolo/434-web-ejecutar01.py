"""Instantánea exportada: paquete real primero; fixture visual separado después."""
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import time

p = Path(__file__).parent
out = p / '434-web-final01'
pins = json.loads((out / 'pins.json').read_bytes())
root = Path.cwd()

def check():
    assert subprocess.check_output(['git','rev-parse','HEAD'], text=True).strip() == pins['head']
    assert not subprocess.check_output(['git','status','--porcelain']).strip()
    for path, sha in pins['inputs'].items():
        assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == sha, path

check()
project = out / 'proyecto'
project.mkdir()
with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['git','archive',pins['head']]))) as archive:
    archive.extractall(project, filter='data')
template = Path(pins['template'])
(project / 'build/templates').mkdir(parents=True, exist_ok=True)
shutil.copyfile(template, project / 'build/templates/web_release.zip')
config = (project / 'project.godot').read_bytes()
preset = (project / 'export_presets.cfg').read_bytes()
steps = []

def run(name, args, limit, cwd=project, marker=None):
    start = time.monotonic()
    with (out / (name+'.log')).open('wb') as log:
        proc = subprocess.Popen(args, cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
        try:
            code = proc.wait(timeout=limit)
        except subprocess.TimeoutExpired:
            subprocess.run(['taskkill','/PID',str(proc.pid),'/T','/F'], stdout=log, stderr=subprocess.STDOUT)
            proc.wait(timeout=30)
            code = 124
    raw = (out / (name+'.log')).read_bytes()
    steps.append({'nombre':name,'returncode':code,'limite_s':limit,'segundos':time.monotonic()-start,'comando':args,'sha256_log':hashlib.sha256(raw).hexdigest()})
    (out/'pasos.json').write_bytes(json.dumps(steps,indent=2).encode())
    print(name,code,round(time.monotonic()-start,1),flush=True)
    if code:
        raise SystemExit(code)
    assert not re.search(rb'SCRIPT ERROR|Parse Error|ERROR:|leaked at exit|resources still in use|Pages in use', raw, re.I), name
    if marker:
        assert marker in raw, name

run('cache', [sys.executable,str(p/'434-reutilizar_cache.py'),str(root),str(project),str(out/'cache-verificada.json')],180)
godot = pins['godot']
run('import-real',[godot,'--headless','--path',str(project),'--import','--quit'],240)
real = out/'export-real'
real.mkdir()
run('export-real',[godot,'--headless','--path',str(project),'--export-release','Web',str(real/'index.html')],240)
assert (project/'project.godot').read_bytes() == config
assert (project/'export_presets.cfg').read_bytes() == preset
run('sonda-paquete',[godot,'--headless','--path',str(real),'--main-pack',str(real/'index.pck'),'--script',str(out/'sonda.gd')],120,real,b'434_PAQUETE_JORNADA_2_OK')
shutil.copyfile(p/'434-visual-final02/mapa.gd',project/'434_capturas.gd')
(project/'434_capturas.tscn').write_bytes(b'[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://434_capturas.gd" id="1"]\n\n[node name="Capturas434" type="Node"]\nscript = ExtResource("1")\n')
text,n = re.subn(rb'^run/main_scene=.*$', b'run/main_scene="res://434_capturas.tscn"',config,flags=re.M)
assert n == 1
(project/'project.godot').write_bytes(text)
run('import-capturas',[godot,'--headless','--path',str(project),'--import','--quit'],180)
visual = out/'export-capturas'
visual.mkdir()
run('export-capturas',[godot,'--headless','--path',str(project),'--export-release','Web',str(visual/'index.html')],240)
assert (project/'export_presets.cfg').read_bytes() == preset
check()
files = {str(f.relative_to(out)):{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for d in [real,visual] for f in d.iterdir() if f.is_file()}
(out/'manifiesto.json').write_bytes(json.dumps({'head':pins['head'],'config_real_sha256':hashlib.sha256(config).hexdigest(),'preset_sha256':hashlib.sha256(preset).hexdigest(),'template_sha256':hashlib.sha256(template.read_bytes()).hexdigest(),'archivos':files,'diferencia_fixture':'Sólo copia externa: escena principal y script de cámara; paquete real exportado antes sin esas modificaciones.'},ensure_ascii=False,indent=2).encode())
print('434_WEB_EXPORT01_OK',flush=True)
