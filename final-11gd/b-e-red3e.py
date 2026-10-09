import json
import os
from pathlib import Path
import re
import subprocess
import time

scratch=Path('C:/Users/fede_/orca/workspaces/nosefia/darter/.claude/scratch/batch-64-309')
raiz=Path.cwd().resolve()
suite='test/escenas/objetos/caja_de_productos_test.gd'
objetivo='test_reparentar_conserva_las_etiquetas_y_destruir_no_da_error'
metodos=re.findall(r'^func (test_\w+)\(', (raiz/suite).read_text(encoding='utf-8'),re.M)
resultados=[]
for modo in ['suite']:
 log=scratch/('b-e-red3e-'+modo+'.log')
 comando=[os.environ['GODOT_BIN'],'--headless','--verbose','--path',str(raiz),'-s','-d','--remote-debug','tcp://127.0.0.1:0','res://addons/gdUnit4/bin/GdUnitCmdTool.gd','-a','res://'+suite,'--continue','--ignoreHeadlessMode','-rd','res://reports/b-e-red3e-'+modo]
 if modo=='aislado':
  for metodo in metodos:
   if metodo!=objetivo: comando+=['-i','caja_de_productos_test:'+metodo]
 env=dict(os.environ,APPDATA=str(raiz/'.godot/usuario_de_los_tests'))
 inicio=time.monotonic()
 with log.open('xb') as f:
  p=subprocess.Popen(comando,cwd=raiz,env=env,stdout=f,stderr=subprocess.STDOUT)
  dato=dict(modo=modo,pid=p.pid,comando=comando,appdata=env['APPDATA'],log=str(log),diagnostico_sin_validar_TDD=False)
  dato['codigo']=p.wait(timeout=60)
 dato['segundos']=round(time.monotonic()-inicio,2)
 resultados.append(dato)
 print(json.dumps(dato),flush=True)
(scratch/'b-e-red3e-resultados.json').write_text(json.dumps(resultados,indent=2),encoding='utf-8')
raise SystemExit(max(r['codigo'] for r in resultados))

