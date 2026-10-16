"""Control verboso sin cambios; conserva el primer export y su retención."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import time

p = Path(__file__).parent
out = p/'434-web-final01'
pins = json.loads((out/'pins.json').read_bytes())
root = Path.cwd()
project = out/'proyecto'
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip() == pins['head']
assert not subprocess.check_output(['git','status','--porcelain']).strip()
for path,sha in pins['inputs'].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == sha
config = (project/'project.godot').read_bytes()
preset = (project/'export_presets.cfg').read_bytes()
real = out/'export-real'
control = out/'export-control02'
control.mkdir()
steps = []

def run(name,args,limit,cwd=project,marker=None):
    begin=time.monotonic()
    with (out/(name+'.log')).open('wb') as log:
        proc=subprocess.Popen(args,cwd=cwd,stdout=log,stderr=subprocess.STDOUT)
        try:
            code=proc.wait(timeout=limit)
        except subprocess.TimeoutExpired:
            subprocess.run(['taskkill','/PID',str(proc.pid),'/T','/F'],stdout=log,stderr=subprocess.STDOUT)
            proc.wait(timeout=30)
            code=124
    raw=(out/(name+'.log')).read_bytes()
    steps.append({'nombre':name,'returncode':code,'segundos':time.monotonic()-begin,'limite_s':limit,'comando':args})
    (out/'pasos02.json').write_bytes(json.dumps(steps,indent=2).encode())
    print(name,code,round(time.monotonic()-begin,1),flush=True)
    assert code==0
    assert not re.search(rb'SCRIPT ERROR|Parse Error|ERROR:|leaked at exit|resources still in use|Pages in use',raw,re.I),name
    if marker:
        assert marker in raw

godot=pins['godot']
run('export-control02',[godot,'--headless','--verbose','--path',str(project),'--export-release','Web',str(control/'index.html')],240)
hashes=lambda folder:{name:hashlib.sha256((folder/name).read_bytes()).hexdigest() for name in ['index.html','index.js','index.pck','index.wasm']}
assert hashes(real)==hashes(control), 'El control sin cambios alteró artefactos'
assert (project/'project.godot').read_bytes()==config
assert (project/'export_presets.cfg').read_bytes()==preset
run('sonda-paquete02',[godot,'--headless','--path',str(real),'--main-pack',str(real/'index.pck'),'--script',str(out/'sonda.gd')],120,real,b'434_PAQUETE_JORNADA_2_OK')
shutil.copyfile(p/'434-visual-final02/mapa.gd',project/'434_capturas.gd')
(project/'434_capturas.tscn').write_bytes(b'[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://434_capturas.gd" id="1"]\n\n[node name="Capturas434" type="Node"]\nscript = ExtResource("1")\n')
text,n=re.subn(rb'^run/main_scene=.*$',b'run/main_scene="res://434_capturas.tscn"',config,flags=re.M)
assert n==1
(project/'project.godot').write_bytes(text)
run('import-capturas02',[godot,'--headless','--path',str(project),'--import','--quit'],180)
visual=out/'export-capturas02'
visual.mkdir()
run('export-capturas02',[godot,'--headless','--path',str(project),'--export-release','Web',str(visual/'index.html')],240)
assert (project/'export_presets.cfg').read_bytes()==preset
assert not subprocess.check_output(['git','status','--porcelain']).strip()
files={str(f.relative_to(out)):{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for d in [real,control,visual] for f in d.iterdir() if f.is_file()}
(out/'manifiesto02.json').write_bytes(json.dumps({'head':pins['head'],'config_real_sha256':hashlib.sha256(config).hexdigest(),'preset_sha256':hashlib.sha256(preset).hexdigest(),'template_sha256':pins['inputs'][pins['template']],'archivos':files,'control':'Primero retenía162instancias/111recursos; repetición verbosa sin cambios limpia y cuatro artefactos idénticos. Se preservan ambos crudos.','limite_fixture':'Paquete de capturas distinto; sólo copia externa con cámara diagnóstica. Paquete real conserva proyecto/preset/plugins.'},ensure_ascii=False,indent=2).encode())
print('434_WEB_EXPORT02_OK',flush=True)
