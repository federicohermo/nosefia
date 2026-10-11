from pathlib import Path
import subprocess,os,re,shutil
s=Path(__file__).parent;d=s/'374-web-4b589ec6'

with (d/'importar.log').open('wb') as log:
 r=subprocess.run([os.environ['GODOT_BIN'],'--headless','--path',str(d/'proyecto'),'--verbose','--import','--quit'],stdout=log,stderr=subprocess.STDOUT,timeout=600)
t=(d/'importar.log').read_text(encoding='utf-8',errors='replace')
assert r.returncode==0 and not re.search(r'(?m)^(SCRIPT ERROR|ERROR|WARNING):',t),t
print('Import warm limpio')
