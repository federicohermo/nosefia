from pathlib import Path
import json, re
s=Path(__file__).parent
t=(s/'306-whole-preparado.md').read_text(encoding='utf-8')
def replace(old,new):
    global t
    assert old in t,old[:100]
    t=t.replace(old,new)
t=re.sub(r'^> Borrador completo.*?\n\n','',t,flags=re.M)
replace('- **Base y dependencias:** después de #305 final;', '- **Base y dependencias:** `11301e9df6fd2510b4fa2ff1c0fd6db9d25fe963`, cabeza certificada de #305 (PR355, FULL2 7/7 en718,8s,208/208suites,1629casos);')
replace('La altura actual provisional', 'La altura medida')
replace('Al llegar a#305 final se miden en mundo los pisos, paredes, techos, pasos, hueco de ventanilla y cuerpos.', 'La medición nativa sobre11301e9d leyó242cajas de colisión (25deshabilitadas),58polígonos convexos,31cajas de productos,5útiles,3bolsas, pisos, techos, pasos y hueco. Se compusieron transforms locales de ancestros sin montar la escena; ambas sondas salieron0, sin diagnósticos. El lector queda con transform identidad en Estructura. Los nombres históricos se usan sólo para localizar evidencia, no como contrato.')
replace('Las tres cajas cubren piso a techo sin solaparse; cada paso pertenece a su habitación de destino.', 'Cada habitación es una unión finita de volúmenes locales, desde el piso hasta su techo real, sin solaparse con otra habitación; cada paso estrecho pertenece a su habitación de destino. No se usa una envolvente que cubra el hueco junto a un paso o encima de un techo más bajo.')
replace('las cajas se declaran en coordenadas locales', 'las uniones de cajas se declaran en coordenadas locales')
replace('dentro de cada habitación y uno afuera', 'dentro de cada parte de una habitación y puntos afuera')
replace('una caja rotada.', 'una caja rotada, un hueco de la unión, el lateral de un paso estrecho o el espacio encima de un techo más bajo.')
replace('local: AABB, deposito: AABB, bano: AABB', 'local: Array[AABB], deposito: Array[AABB], bano: Array[AABB]')
replace('exporta `local: AABB`, `deposito: AABB` y `bano: AABB`', 'exporta `local: Array[AABB]`, `deposito: Array[AABB]` y `bano: Array[AABB]`')
replace('con cajas sintéticas', 'con uniones de cajas sintéticas')
replace('Este alcance fue aprobado por el padre el 2026-10-09; se concretará con la transformación real de la cabeza #305 final, sin ejecución anticipada.', 'La ampliación a uniones finitas fue autorizada al medir el techo escalonado y los pasos de305; no cambia geometría, arte ni colisiones interiores. Se usan diez partes:1local,3depósito y6baño. El espejo puro recibe los arrays y comprueba pertenencia a cualquiera de sus partes, no a una caja envolvente; arrays vacíos dan AFUERA.')
replace('## Interfaz309 preservada (preparacion readonly)', '## Interfaz309 preservada')
replace('Lectura source c315ccd5; fe620b92 solo ratifica notifications.', 'Base inmediata11301e9d, que hereda309fe620b92.')
replace('Las rutas y counts se fijan contra dependencia inmediata certificada antes de publicar.', 'Las rutas y cantidades anteriores se midieron contra la dependencia inmediata certificada.')
replace('Jugador/guard297 y gesto/caja304 se conservan.', 'Jugador/guard297 y gesto/caja304 se conservan.')
parts={
 'local':[[-2.480001,0.10223747,-7.870002,7.870002,4.370002,6.280002]],
 'deposito':[
  [-4.594377,0.10273747,-15.397972,4.64691782,4.86959791,-8.25329],
  [4.64691782,0.10273747,-15.397972,7.925532,4.872668,-8.25329],
  [5.882002,0.10223747,-8.25329,7.606002,2.886001,-7.870002]],
 'bano':[
  [8.291861,0.10223747,-0.311377,8.342008,3.229942,6.278322],
  [8.342008,0.10223747,-0.311377,13.43466,4.724773,3.753796],
  [8.342008,0.10223747,3.753796,13.43466,4.869401,3.795349],
  [8.342008,0.10223747,3.795349,13.43466,3.239967,6.278322],
  [7.870002,0.10223747,-0.104,8.080002,2.850001,1.576001],
  [8.080002,0.10223747,-0.10535,8.291861,2.851981,1.577521]]}
rows=[]
for room,boxes in parts.items():
 for i,b in enumerate(boxes,1):
  rows.append(f'| {room} {i} | [{b[0]}, {b[3]}] | [{b[1]}, {b[4]}] | [{b[2]}, {b[5]}] |')
geometry='''## Medición y declaración de habitaciones sobre305

Estas cifras describen sólo la cabeza11301e9d. Se declaran en el espacio local del lector,
cuya transformación es identidad. La pertenencia normativa depende del interior y sus fronteras,
no de un nombre antiguo de colisión. Las pruebas funcionales derivan los puntos de los arrays
exportados y de las caras vigentes, incluyendo un punto bajo y otro sobre cada techo distinto,
centros de ambos pasos y laterales que quedan afuera de las uniones. Los sintéticos ejercen
unión disjunta y rotación45° del lector y de un padre.

| Parte | X mínimo/máximo | Y piso/techo | Z mínimo/máximo |
|---|---|---|---|
'''+ '\n'.join(rows)+'''

Las dos primeras partes del depósito siguen el fondo y se separan donde cambia su techo;
la tercera es sólo el acceso del local. En baño, una franja oeste baja y tres sectores centrales
respetan las alturas existentes; las dos partes restantes siguen ambas mitades del acceso y sus
dinteles. No se extienden esos accesos a todo el ancho de la habitación. Se conserva el soporte
interior y sólo se agregan colisiones a las seis mallas de pavimento exterior existentes,
a y−0,01776253. No se tocan vereda, proyecciones, materiales ni texturas.

Evidencia externa: b-306-mediciones-305.json, b-306-convex-305.json y sus logs fusionados.
Los dos borradores de pruebas sintéticas adaptados a unión se aplican como tests primero y
se ejecutan en rojo sobre stubs; su gdformat/gdlint externo no se presenta como prueba de motor.

'''
t=t.replace('## Límites de archivos',geometry+'## Límites de archivos')
assert '> Borrador completo' not in t
assert 'IDs a reservar' not in t
(s/'306-whole-final.md').write_text(t,encoding='utf-8',newline='\n')
(s/'b-306-particion-305.json').write_text(json.dumps({'head':'11301e9df6fd2510b4fa2ff1c0fd6db9d25fe963','parts':parts},indent=2),encoding='utf-8',newline='\n')
print('WHOLE306 final externo:',len(t),'caracteres; partes',sum(map(len,parts.values())))
