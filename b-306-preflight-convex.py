from pathlib import Path
import os, subprocess, json
s=Path(__file__).parent; root=Path.cwd()
assert not subprocess.check_output(['git','status','--porcelain'],text=True).strip()
env=dict(os.environ,APPDATA=str(root/'.godot/usuario_de_los_tests'))
log=s/'b-306-preflight-convex-raw.log'; assert not log.exists()
with log.open('w',encoding='utf-8') as stream:
    result=subprocess.run([env['GODOT_BIN'],'--headless','--path',str(root),'--script',str(s/'b-306-medir-convex.gd')],env=env,stdout=stream,stderr=subprocess.STDOUT)
raw=log.read_text(encoding='utf-8')
line=next((line.removeprefix('B306_CONVEX=') for line in raw.splitlines() if line.startswith('B306_CONVEX=')),None)
assert result.returncode==0 and line is not None,raw
rows=json.loads(line)
(s/'b-306-convex-305.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8',newline='\n')
print(json.dumps({'code':result.returncode,'count':len(rows),'techo':[r for r in rows if 'faldon' in r['ruta']]},ensure_ascii=False),flush=True)
