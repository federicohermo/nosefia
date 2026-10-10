import subprocess
from pathlib import Path
r=Path.cwd(); s=Path(__file__).parent
p='test/dominio/almacen/tarea_de_la_basura_test.gd'
original=subprocess.run(['git','show','HEAD:'+p],check=True,capture_output=True).stdout.decode('utf-8')
nuevos=(s/'370-test-dominio.gd').read_text(encoding='utf-8').replace('for jornada in [1, 3, 4, 5]:','for jornada: int in [1, 3, 4, 5]:')
(r/p).write_text(original.replace('TareaDeLaBasura.de_la_jornada()','TareaDeLaBasura.de_la_jornada(2)')+nuevos,encoding='utf-8',newline='\n')
