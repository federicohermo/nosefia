"""Convergencia propia de #434, no la integrada del lote."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

head=sys.argv[1]
assert re.fullmatch('[0-9a-f]{40}',head)
p=Path(__file__).parent
root=Path.cwd()
out=p/'434-full02'
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==head
assert not subprocess.check_output(['git','status','--porcelain']).strip()
subprocess.run(['git','merge-base','--is-ancestor','3e381d1be90e30589e9c7b38905199a576c43201',head],check=True)
out.mkdir()
(out/'pins.json').write_bytes(json.dumps({'head':head,'428':'3e381d1be90e30589e9c7b38905199a576c43201','driver_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'crudo_wrapper_sha256':hashlib.sha256((p/'verificar_crudo.py').read_bytes()).hexdigest()},indent=2).encode())
start=time.monotonic()
with (out/'verificar.log').open('wb') as log:
    proc=subprocess.Popen([sys.executable,str(p/'verificar_crudo.py'),str(out/'crudo')],stdout=log,stderr=subprocess.STDOUT)
    try:
        code=proc.wait(timeout=2700)
    except subprocess.TimeoutExpired:
        subprocess.run(['taskkill','/PID',str(proc.pid),'/T','/F'],stdout=log,stderr=subprocess.STDOUT)
        proc.wait(timeout=30)
        (out/'timeout.json').write_bytes(json.dumps({'pid_propio':proc.pid,'head':head,'limite_s':2700}).encode())
        raise SystemExit(124)
with (out/'conteo.log').open('wb') as log:
    count=subprocess.run([sys.executable,'.claude/skills/implement-batch/scripts/conteo.py'],stdout=log,stderr=subprocess.STDOUT,timeout=60)
reports=list((root/'reports').glob('report_*/results.xml'))
assert reports
xml=max(reports,key=lambda f:int(f.parent.name.removeprefix('report_')))
shutil.copyfile(xml,out/'results.xml')
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==head
assert not subprocess.check_output(['git','status','--porcelain']).strip()
(out/'ejecucion.json').write_bytes(json.dumps({'head':head,'exit_verificar':code,'exit_conteo':count.returncode,'segundos':time.monotonic()-start,'limite_s':2700,'conteo_inmediato':True,'xml_original':str(xml),'archivos':{str(f.relative_to(out)):{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in out.rglob('*') if f.is_file()}},indent=2).encode())
print((out/'verificar.log').read_text(encoding='utf-8',errors='replace')[-1400:])
print((out/'conteo.log').read_text(encoding='utf-8',errors='replace'))
print('434_FULL02_FINAL',code,count.returncode,round(time.monotonic()-start,1),flush=True)
raise SystemExit(code or count.returncode)
