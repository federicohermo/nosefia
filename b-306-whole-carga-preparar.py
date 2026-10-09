from pathlib import Path
import json, hashlib, difflib, re, subprocess

s = Path('C:/Users/fede_/orca/workspaces/nosefia/darter/.claude/scratch/batch-64-309')
out = Path(__file__).parent
path = s / 'padre-306-whole-cabinas.md'
original = path.read_text(encoding='utf-8'); body = original
old = '`test/escenas/puestos/notas_del_almacen_test.gd`; `test/escenas/objetos/caja_que_se_lleva_test.gd` |'
assert body.count(old) == 1
body = body.replace(old, old[:-2] + '; `test/escenas/puestos/contenedor_de_basura_test.gd` |')
old = 'El mismo recorrido sin pared y los candidatos accesibles del lado actual se conservan.'
old = 'Un caso geométrico con piso a ambos lados y una pared demuestra el rechazo; el mismo recorrido sin pared y los candidatos accesibles del lado actual se conservan.'
assert body.count(old) == 1
body = body.replace(old, old + ' La prueba heredada de carga del contenedor mantiene veintiocho unidades reales y establece una pose inicial de caída libre sobre la boca, derivada de su geometría vigente y de la forma de cada unidad, comprobando volumen libre antes de avanzar física. Conserva más de seis cuerpos dentro antes de cerrar, el bloqueo de la tapa y la ausencia de penetración del cuerpo y de la tapa, sin desactivar colisiones, gravedad ni red de seguridad ni cambiar Jugador/Agarre.')
old = 'Estas dos rutas de test son las únicas correcciones de fixture adicionales; sus versiones instrumentadas son diagnósticas y los casos originales corregidos deben pasar en las suites y la convergencia formal.'
assert body.count(old) == 1
body = body.replace(old, 'Estas dos rutas corrigen las premisas de notas y caja; sus versiones instrumentadas son diagnósticas y los casos originales corregidos deben pasar en las suites y la convergencia formal.')
body += '''

La segunda convergencia formal sobre `01bda52fac0e92b191e7c367086c9a7798e0d895` ejecutó
214/214 suites y 1671 casos: quedó una aserción fallida, cero errores y cero salteos, en la
carga del contenedor. FULL1 y FULL2 permanecen fallidos y preservados. El caso había pasado
en los focales completos A/B y GREEN3; eso no certifica la segunda convergencia ni permite
atribuirlo a IDs o declararlo inestable sin evidencia.

Una copia instrumentada del caso completo, con originales y aserciones intactos, mostró que
el rayo del jugador apunta al borde delantero del contenedor y que 27 de las 28 unidades son
recolocadas por el flujo normal de soltado antes de comenzar la caída. El primer punto pedido
(2.93, 1.452238, -14.94747) se convierte en (3.0, 1.446469, -14.55757); el rayo alcanza el
borde en (3.0, 1.177237, -14.55757). Sólo siete cuerpos quedan dentro en ese diagnóstico:
el marcador solicitado no acredita una carga física sobre la boca.

Se autoriza una quinta ruta adicional, `test/escenas/puestos/contenedor_de_basura_test.gd`:
Se escribe pasa de 47 a 48 rutas. El archivo real está en puestos, no en objetos. Su prueba
de contención y cierre conserva las veintiocho unidades reales retiradas por la reposición,
sus formas, materiales, máscaras, grupos y seguridad. Después de retirar y soltar mediante
las APIs vigentes, establece explícitamente la pose de arranque de la caída sobre la boca.
El alto se deriva del límite mundial de la malla del cuerpo del contenedor, del límite de
los cuerpos ya cargados y del mínimo vertical de la forma real de la nueva unidad, más el
roce vigente. Se conserva la orientación y la distribución XZ de carga, y se afirma que su
forma no intersecta ningún sólido con su máscara y exclusión propia antes de avanzar física.
La unidad parte sin velocidad lineal ni angular, con gravedad y colisión activas; no se
desactiva la red de seguridad ni se fuerza el cuerpo a través de paredes o tapa. El caso
verifica contención física, mientras los gestos de #305 permanecen cubiertos por sus suites.
Conserva la caída/espera física, más de seis unidades dentro antes de cerrar, el bloqueo por
la carga y todas las aserciones de penetración. No hay umbral relajado, nuevo caso ni cambio
normativo. El espejo mantiene sus once tests públicos; los ayudantes nuevos son privados.
La suite original completa debe pasar antes del FULL3 formal sobre commit y push exactos.

La lectura viva para esta ampliación está congelada en `01bda52fac0e92b191e7c367086c9a7798e0d895`,
tracked limpio. El original del fixture tiene SHA256
`0bd174cd4dab7671dcf332fb6f837344aaa211fdb83f3a7b6703f36aed23be8e`; manifest, diff,
28 poses pedidas/soltadas y 28 poses estables se conservan fuera de fuente. La copia filtrada
es diagnóstico con tiempo perturbado por prints, no un rojo, un verde final ni convergencia.
'''
assert body.count('- [ ]') == 19
row = next(line for line in body.splitlines() if line.startswith('| Se escribe |'))
routes = re.findall(r'`([^`]+)`', row); assert len(routes) == len(set(routes)) == 48
target = out / 'b-306-whole-carga-final.md'; target.write_text(body, encoding='utf-8', newline='\n')
(out / 'b-306-whole-carga.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True), body.splitlines(True), fromfile='padre-306-whole-cabinas.md', tofile=target.name)), encoding='utf-8', newline='\n')
print(json.dumps({'file': str(target), 'sha256': hashlib.sha256(body.encode()).hexdigest(), 'write_routes': len(routes), 'criteria': 19}))
