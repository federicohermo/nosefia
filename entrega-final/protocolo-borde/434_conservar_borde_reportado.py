import json
from pathlib import Path
import subprocess
p=Path(__file__).parent
d=json.loads(subprocess.check_output(['gh','issue','view','434','--json','body,title,url']))
b=d['body']
start=b.index('### Regresión de premisa del borde tras cambiar sectores')
b=b[:start]+'''### Regresión de premisa del borde tras cambiar sectores

La primera completa de #434 conserva dos casos de #428 que ubicaban la cabecera reportada
mediante la fuente de Saladik y un desplazamiento hacia `Vector3.FORWARD`. #434 mueve esa
fuente a la cabecera opuesta. La sonda03 de sólo lectura confirma que la referencia importada
y la matriz actual coinciden allí: no hay una referencia desactualizada. Seguir Saladik cambia
el lugar observado y no conserva el borde reportado de #428.

El fixture debe localizar el metal superior de la cabecera frontal reportada por su malla,
sin depender de la ubicación de un producto. Reutiliza la lectura de caras superiores que
ya tiene la suite, elige la cara superior de mayor área del extremo frontal y apunta desde
el mismo desplazamiento exterior. Se mantienen las premisas de piso transitable y cápsula
libre, la mira y el gesto reales, ambos tamaños,180cuadros de reposo, comparación
visual/física, recogida, inventario/tareas y todos los umbrales. No cambia producción,
geometría ni la decisión del usuario de acomodar la caja apoyada.

Se preservan la completa roja y el focal borde01. La corrección de sólo dirección fue
insuficiente porque seguía a Saladik; el observer02 se rechazó por retención de recursos,
y el observer03 limpio mide el metal del extremo reportado. La invocación03 que no llegó
a crear su script también se conserva como incidente, no como evidencia del motor.
'''
b=b.replace('sólo derivar el objetivo, la postura exterior y la dirección hacia la cabecera de Saladik del bloque y frente del reparto actual','sólo localizar la cabecera reportada por su malla, sin depender de la posición actual de Saladik, y derivar el objetivo/postura exterior de sus caras superiores')
f=p/'434-issue-borde-geometria-entero.md'
f.write_bytes(b.encode())
subprocess.run(['gh','issue','edit','434','--body-file',str(f)],check=True)
actual=json.loads(subprocess.check_output(['gh','issue','view','434','--json','body,title,url']))
assert actual['body']==b
(p/'434-issue-borde-geometria-publicado.json').write_bytes(json.dumps(actual,ensure_ascii=False,indent=2).encode())
