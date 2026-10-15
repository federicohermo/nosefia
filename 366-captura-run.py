import os,subprocess,re,sys
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8',errors='replace')
root=Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-365-366')
env=dict(os.environ)
env['APPDATA']=str(root/'366-captura-userdata');env['LOCALAPPDATA']=str(root/'366-captura-localdata')
Path(env['APPDATA']).mkdir(exist_ok=True);Path(env['LOCALAPPDATA']).mkdir(exist_ok=True)
si=subprocess.STARTUPINFO();si.dwFlags|=subprocess.STARTF_USESHOWWINDOW;si.wShowWindow=0
args=[env['GODOT_BIN'],'--path','.', '--audio-driver','Dummy','--position','-16000,-16000','--script',str(root/'366-capturar.gd')]
proc=subprocess.Popen(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,startupinfo=si)
try:
 stdout,stderr=proc.communicate(timeout=180)
except subprocess.TimeoutExpired:
 subprocess.run(['taskkill','/PID',str(proc.pid),'/T','/F'],capture_output=True)
 stdout,stderr=proc.communicate()
 (root/'366-captura-raw.log').write_bytes(stdout+stderr+b'\nCAPTURA_TIMEOUT\n')
 raise
raw=stdout+stderr;(root/'366-captura-raw.log').write_bytes(raw)
print(raw.decode('utf-8',errors='replace'))
if proc.returncode or re.search(rb'SCRIPT ERROR|Parse Error|ERROR:|ObjectDB|resources still|leaked',raw) or b'CAPTURA_366_VALIDA' not in raw:sys.exit(1)
