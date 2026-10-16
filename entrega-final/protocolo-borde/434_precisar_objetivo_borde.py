import json
from pathlib import Path
import subprocess
p=Path(__file__).parent/'434-focal-borde01'
d=json.loads(subprocess.check_output(['gh','issue','view','434','--json','body,title,url']))
b=d['body']
b=b.replace('sólo derivar la postura exterior y la dirección hacia la cabecera de Saladik del frente del reparto actual','sólo derivar el objetivo, la postura exterior y la dirección hacia la cabecera de Saladik del bloque y frente del reparto actual')
b=b.replace('obtener el frente actual del bloque principal\nde Saladik y usar ese mismo frente al apuntar y recoger.','obtener la posición y el frente actuales del bloque principal\nde Saladik y usar esos datos al apuntar y recoger. La referencia importada conserva su\nruta histórica; el objetivo de la prueba sale del reparto vigente, como sus casilleros.')
b+='\nEl focal de borde01 confirmó que corregir sólo la dirección deja libres piso y cápsula, pero no acredita metal visible. Se conserva ese rojo; también se deriva el objetivo de la matriz principal vigente, sin cambiar los guards ni producción.\n'
f=p/'issue-objetivo-borde-entero.md'
f.write_bytes(b.encode())
subprocess.run(['gh','issue','edit','434','--body-file',str(f)],check=True)
actual=json.loads(subprocess.check_output(['gh','issue','view','434','--json','body,title,url']))
assert actual['body']==b
(p/'issue-objetivo-borde-publicado.json').write_bytes(json.dumps(actual,ensure_ascii=False,indent=2).encode())
