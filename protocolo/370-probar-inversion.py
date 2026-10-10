import subprocess
import sys
from pathlib import Path
busqueda=subprocess.run(['rg','-l','_bolsas|BolsaDeBasura|bolsa_de_basura','test/escenas'],check=True,capture_output=True,text=True,encoding='utf-8')
suites=sorted(p.replace('\\','/') for p in busqueda.stdout.splitlines() if p.endswith('_test.gd'))
suites+=['test/dominio/almacen/tarea_de_la_basura_test.gd','test/sistemas/tareas/recolector_de_basura_test.gd','test/dominio/almacen/nota_pegada_test.gd','test/escenas/objetos/nota_pegada_test.gd']
suites=list(dict.fromkeys(suites))
print('BARRIDO_370',len(suites),*suites,sep='\n',flush=True)
sys.exit(subprocess.run([sys.executable,str(Path(__file__).with_name('370-focal.py')),*suites]).returncode)
