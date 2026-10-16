import os,sys,subprocess
from pathlib import Path
sys.path.insert(0,str(Path.cwd()/'.claude/scripts'))
from lib.godot import resolver,entorno_de_la_suite
binary=resolver(dict(os.environ))[0]
code=subprocess.run([binary,'--headless','--path',str(Path.cwd()),'--import','--quit']).returncode
if code:sys.exit(code)
args=[binary,'--path',str(Path.cwd()),'--rendering-driver','opengl3','--script',str(Path(__file__).parent/'diagnostico427_completo2.gd'),'--',str(Path(__file__).parent/sys.argv[1])]
p=subprocess.Popen(args,env=entorno_de_la_suite(dict(os.environ),Path.cwd(),sys.platform))
try:sys.exit(p.wait(timeout=240))
except subprocess.TimeoutExpired:
 subprocess.run(['taskkill','/PID',str(p.pid),'/T','/F']);sys.exit(124)
