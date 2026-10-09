from pathlib import Path
import os, subprocess, json, re, hashlib
s=Path(__file__).parent; root=Path.cwd()
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
assert head=='11301e9df6fd2510b4fa2ff1c0fd6db9d25fe963'
assert not subprocess.check_output(['git','status','--porcelain'],text=True).strip()
full=json.loads((s/'b-305-full2-resultados.json').read_text(encoding='utf-8'))
assert full['head']==head and full['code']==full['count_code']==0
env=dict(os.environ,APPDATA=str(root/'.godot/usuario_de_los_tests'))
log=s/'b-306-preflight-raw.log'; assert not log.exists()
cmd=[env['GODOT_BIN'],'--headless','--path',str(root),'--script',str(s/'b-306-medir.gd')]
with log.open('w',encoding='utf-8') as stream:
    result=subprocess.run(cmd,env=env,stdout=stream,stderr=subprocess.STDOUT)
data=log.read_text(encoding='utf-8')
marker=next((line.removeprefix('B306_MEDIDAS=') for line in data.splitlines() if line.startswith('B306_MEDIDAS=')),None)
assert result.returncode==0 and marker is not None,data
measurement=json.loads(marker)
measurement.update({'head':head,'code':result.returncode,'raw':str(log),'script_sha256':hashlib.sha256((s/'b-306-medir.gd').read_bytes()).hexdigest()})
(s/'b-306-mediciones-305.json').write_text(json.dumps(measurement,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'head':head,'code':result.returncode,'boxes':len(measurement['cajas_solidas']),'pavimentos':measurement['pavimentos'],'cuerpos':measurement['cuerpos'],'estructura_pose':measurement['estructura_pose']},ensure_ascii=False),flush=True)
