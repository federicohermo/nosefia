import os,subprocess
from pathlib import Path
scratch=Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010')
env={**os.environ,'APPDATA':str(Path.cwd()/'.godot/usuario_de_sondas_301')}
cmd=[os.environ['GODOT_BIN'],'--path','.','--headless','--verbose','--script',str(scratch/'301-bolsas.gd')]
with (scratch/'301-bolsas-verbose.log').open('w',encoding='utf8') as f:
 p=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=120,env=env)
print('301_BOLSAS_VERBOSE',p.returncode,flush=True)
raise SystemExit(p.returncode)
