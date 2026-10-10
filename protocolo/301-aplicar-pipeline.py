import os, subprocess, sys
from pathlib import Path
scratch=Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010')
blender='C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
godot=os.environ['GODOT_BIN']
raiz=Path.cwd()
entorno={**os.environ,'APPDATA':str(raiz/'.godot/usuario_de_sondas_301')}
pasos=[
 ('acomodador-copia',[blender,str(scratch/'301-modelo-externo.blend'),'--background','--python-exit-code','1','--python',str(scratch/'301-modelo.py'),'--','acomodar',str(raiz/'.claude/scripts/blender/acomodar.py')],600),
 ('aplicar-blend',[blender,'assets/models/SEPT_JUEGOS_PROTOTIPO.blend','--background','--python-exit-code','1','--python',str(scratch/'301-modelo.py'),'--','aplicar'],180),
 ('exportar',[sys.executable,'.claude/scripts/exportar_modelo.py'],600),
 ('comparar-glb',[sys.executable,str(scratch/'301-comparar-glb.py')],180),
 ('hornear',[sys.executable,'.claude/scripts/hornear.py'],1300),
 ('final-escena',[godot,'--path','.','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--script',str(scratch/'301-escena.gd'),'--','final'],360),
 ('final-apoyo',[godot,'--path','.','--headless','--script',str(scratch/'301-apoyo.gd'),'--','final'],180),
 ('final-bolsas',[godot,'--path','.','--headless','--script',str(scratch/'301-bolsas.gd')],180),
]
for etiqueta,cmd,tope in pasos:
 print('EMPIEZA',etiqueta,flush=True)
 with (scratch/f'301-{etiqueta}.log').open('w',encoding='utf8') as f:
  p=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=tope,env=entorno)
 print('RESULTADO',etiqueta,p.returncode,flush=True)
 if p.returncode:
  print((scratch/f'301-{etiqueta}.log').read_text(encoding='utf8')[-9000:],flush=True)
  raise SystemExit(p.returncode)
print('301_PIPELINE_FINAL',flush=True)
