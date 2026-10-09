import os,subprocess,sys
from pathlib import Path
script=Path(__file__).with_suffix('.gd')
r=subprocess.run([os.environ['GODOT_BIN'],'--path','.','--script',str(script)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=45)
print(r.stdout,end='')
if r.returncode or 'SONDA304_SCOPE_LIBERADO' not in r.stdout or 'SONDA304_MONTAJE_LIBERADO' not in r.stdout or any(x in r.stdout for x in ('ERROR:','SCRIPT ERROR','ObjectDB','resources still in use','instances were leaked','Leaked instance')):
 sys.exit(1)
if r.stdout.count('SONDA304_DESCARTE_VALIDADO') != 8:
 sys.exit(1)
print('SONDA304_FINAL_LIMPIA')
