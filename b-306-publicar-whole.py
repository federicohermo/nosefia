from pathlib import Path
import subprocess, json, hashlib
s=Path(__file__).parent
p=s/'306-whole-final.md'
t=p.read_text(encoding='utf-8')
t=t.replace('- [ ] `employment-record` declara', '- [ ] `to-spec` agrega BR-EMP-012 y AC-EMP-017–022, y BR-CLN-027–029 con AC-CLN-040–046. Se conservan los huecos de IDs retirados.\n- [ ] `employment-record` declara')
t=t.replace('Leer sobre#305 final la API que retira unidades entregadas; no modificar Agarre para fingir una soltada.', 'En305, objeto_agarrado retira el cuerpo de su grupo suelto; entregar no emite objeto_soltado. Se preserva ese flujo y no se finge una soltada para alimentar el lector.')
a=t.index('## Bordes');b=t.index('## Interfaz309',a)
t=t[:a]+'''## Bordes

- NINGUNA con deuda suma sólo llamados; conserva el legajo. GRAVE con dos motivos suma tres
  apercibimientos; NINGUNA con dos motivos suma uno.
- Tres medios y medio más medio llegan a cuatro y despiden. La quinta impecable con3,5sin
  motivos cumple el contrato; el comentario usa la lectura entera3.
- Una caja en el paso del depósito pertenece al depósito; un útil en el paso del baño pertenece
  al baño. Los laterales de esos pasos y el espacio sobre un techo más bajo quedan fuera.
- Una bolsa adentro no produce desorden; afuera produce OBJETO_AFUERA. Los tickets se incorporan
  al inventario de cuerpos del cierre en307.
- Lo tirado se excluye por Contenedor.tirados. Al abrir, los persistentes vuelven a su lugar;
  las unidades se limpian y se recrean según reposición, y los tickets se liberan según su puesto.
- El cuerpo sostenido exacto se excluye. Examen.iniciar real conserva ese cuerpo en Agarre,
  pero mientras se examina cuenta por su posición física. Terminar vuelve la exclusión de mano.
- Recuperar algo de afuera cambia la foto al cierre. Una unidad devuelta, colocada o sostenida
  no es desorden; recuperada y suelta adentro sí puede serlo.
- Anotar sin jornada abierta no acumula deuda para una noche futura. Una partida terminada
  rechaza llamados y cierres adicionales.
- El guardado viejo restaura0medios sin migración. El entero7 conserva3,5apercibimientos y la
  jornada. Un float7,0 vuelve al defecto: no se convierte a entero para eludir el tipo.

'''+t[b:]
for old,new in {
 'en718,8s,208/208suites,1629casos':'en 718,8 s, 208/208 suites, 1629 casos',
 'alrededor de0,102237':'alrededor de 0,102237',
 'sobre11301e9d leyó242cajas de colisión (25deshabilitadas),58polígonos convexos,31cajas de productos,5útiles,3bolsas':'sobre 11301e9d leyó 242 cajas de colisión (25 deshabilitadas), 58 polígonos convexos, 31 cajas de productos, 5 útiles, 3 bolsas',
 'ambas sondas salieron0':'ambas sondas salieron 0',
 '7 medios no despide,8sí':'7 medios no despide, 8 sí',
 'con GRAVE suma6 medios desde0':'con GRAVE suma 6 medios desde 0',
 'que estaría dentro':'que estarían dentro',
 'defecto0':'defecto 0',
 'restaura0':'restaura 0',
 'vuelve0':'vuelve 0',
 'ambasclaves':'ambas claves',
 'permanece1':'permanece 1',
 'diez partes:1local,3depósito y6baño':'diez partes: 1 local, 3 depósito y 6 baño',
 'de18 a19 públicos':'de 18 a 19 públicos',
 'de8 a9':'de 8 a 9',
 'dentro20':'dentro de 20',
 'en307':'en #307',
 'por295':'por #295',
 'pasos de305':'pasos de #305',
 'sobre305':'sobre #305',
 'cabeza11301e9d':'cabeza 11301e9d',
 'rotación45°':'rotación de 45°',
 'BASE':'BASE',
 'comparten ese recurso':'comparten ese recurso',
}.items():
 t=t.replace(old,new)
p.write_text(t,encoding='utf-8',newline='\n')
assert not subprocess.check_output(['git','status','--porcelain'],text=True).strip()
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()=='11301e9df6fd2510b4fa2ff1c0fd6db9d25fe963'
subprocess.run(['gh','issue','edit','306','--body-file',str(p)],check=True)
after=json.loads(subprocess.check_output(['gh','issue','view','306','--json','body'],text=True,encoding='utf-8'))['body'].replace('\r\n','\n')
assert after.strip()==t.strip()
proof={'head':'11301e9df6fd2510b4fa2ff1c0fd6db9d25fe963','whole_readback_exact':True,'sha256_normalized':hashlib.sha256(after.encode()).hexdigest(),'criteria':after.count('- [ ]'),'parts':10,'write_paths':43,'read_paths':28}
(s/'b-306-whole-readback.json').write_text(json.dumps(proof,indent=2),encoding='utf-8',newline='\n')
print(json.dumps(proof,indent=2))
