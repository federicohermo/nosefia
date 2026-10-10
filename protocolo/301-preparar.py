import os
import subprocess
from pathlib import Path
scratch=Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010')
godot=os.environ['GODOT_BIN']
entorno={**os.environ,'APPDATA':str(Path.cwd()/'.godot/usuario_de_sondas_301')}
for etiqueta,cmd in [
 ('base-escena',[godot,'--path','.','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--script',str(scratch/'301-escena.gd'),'--','base']),
 ('candidato-escena',[godot,'--path','.','--headless','--script',str(scratch/'301-escena.gd'),'--','candidato']),
 ('candidato-apoyo',[godot,'--path','.','--headless','--script',str(scratch/'301-apoyo.gd'),'--','candidato']),
]:
 with (scratch/f'301-{etiqueta}.log').open('w',encoding='utf8') as f:
  p=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=360,env=entorno)
 print(etiqueta,p.returncode,flush=True)
 if p.returncode:
  raise SystemExit(p.returncode)
