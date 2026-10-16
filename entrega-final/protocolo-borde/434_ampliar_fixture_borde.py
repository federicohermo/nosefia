import json
from pathlib import Path
import subprocess

p=Path(__file__).parent/'434-full01'
data=json.loads(subprocess.check_output(['gh','issue','view','434','--json','body,title,url']))
body=data['body']
(p/'issue-antes-fixture-borde.json').write_bytes(json.dumps(data,ensure_ascii=False,indent=2).encode())
needle='`test/escenas/reposicion_manual_test.gd` (sólo actualizar'
assert body.count(needle)==1
body=body.replace(needle,'`test/escenas/objetos/apoyos_de_bordes_de_cajas_test.gd` (sólo derivar la postura exterior y la dirección hacia la cabecera de Saladik del frente del reparto actual; conservar el gesto real, piso/cápsula libres, metal visible/físico, estabilidad180cuadros, recogida, inventario/tareas y los mismos umbrales); '+needle)
old='El carril integra los fixes de #428 hasta 26fdbab9, pero su entrega funcional definitiva aún requiere validación: no se afirma una base cerrada.'
assert body.count(old)==1
body=body.replace(old,'El carril integra la cabeza final de #428 `3e381d1be90e30589e9c7b38905199a576c43201`, cuya tercera completa terminó 7/7 y cuyo PR es #460. La fuente funcional de #434 `29fdc763` pasó77/77focales; `619e9d6e` sólo ratifica el estado del spec. Su primera completa terminó6/7:270suites/2080casos, con10aserciones en dos casos de postura de cabecera; no se presenta como convergencia verde.')
body+='''

### Regresión de premisa del borde tras cambiar sectores

La primera completa de #434 conserva dos casos de #428 que se paraban siempre hacia
`Vector3.FORWARD` de la fuente de Saladik. Tras el reparto, Saladik está en la cabecera
opuesta de la segunda isla: ese desplazamiento lleva el jugador dentro del mueble. Fallaron
las premisas de piso real, cápsula libre y metal visible, antes de acreditar el apoyo.

La actualización queda limitada al fixture: obtener el frente actual del bloque principal
de Saladik y usar ese mismo frente al apuntar y recoger. Se conservan el objetivo sobre
metal de la cabecera, la mira y el gesto del juego, los dos tamaños,180cuadros de reposo,
comparación visual/física, recogida y ausencia de cambios de inventario/tareas, con los
mismos umbrales. No se cambia producción, geometría ni la decisión de acomodar apoyada.
El rojo completo se preserva; la suite del borde se ejecuta antes de repetir la completa.
'''
path=p/'issue-fixture-borde-entero.md'
path.write_bytes(body.encode())
subprocess.run(['gh','issue','edit','434','--body-file',str(path)],check=True)
actual=json.loads(subprocess.check_output(['gh','issue','view','434','--json','body,title,url']))
assert actual['body']==body
(p/'issue-fixture-borde-publicado.json').write_bytes(json.dumps(actual,ensure_ascii=False,indent=2).encode())
print('Issue434 entero actualizado y releído antes de cambiar el fixture')
