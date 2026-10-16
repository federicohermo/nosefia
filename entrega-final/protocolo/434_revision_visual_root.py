import hashlib
import json
from pathlib import Path
import subprocess

p=Path(__file__).parent
wt=Path('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/.claude/worktrees/batch-434-sectores')
final='619e9d6e9a19f75833b4c1bc9a3cd1981de46e5e'
runtime='29fdc763871c5833b9d28b5c6d71d71d3aeac03f'
changed=subprocess.check_output(['git','-C',str(wt),'diff','--name-only',runtime,final],text=True).splitlines()
assert changed==['specs/store-stock/store-stock.md']
native=p/'434-visual-final02'
web=p/'434-chrome-final01'
console=json.loads((web/'consola.json').read_bytes())
diagnostics=[x for x in console if x['paquete']=='camara-diagnostica']
errors=[x for x in diagnostics if x['type'] in ['error','pageerror'] or 'SCRIPT ERROR' in x['text'] or 'Parse Error' in x['text']]
assert not errors
views=[x for x in diagnostics if x['text'].startswith('434_VISTA:')]
assert len(views)==22
products=json.loads((web/'productos.json').read_bytes())
assert len(products)==32 and all(x['principal']>0 and x['frente_principal']>0 for x in products)
real=json.loads((p/'434-real-final02/resultado.json').read_bytes())
assert not real['failure'] and not real['errors']
native_files=sorted(native.glob('nativo-*/*.png'))
web_files=sorted(web.glob('mapa-*.png'))
assert len(native_files)==len(web_files)==22
record={
 'head_final':final,'head_runtime':runtime,'diferencia_solo_estado_spec':changed,
 'revision_humana_root':'Abiertas las22PNG nativas finales y las22PNG web del mapa. Once sectores completos, etiquetas/materiales legibles, cuatro niveles existentes; Cindolor en H2, Oaaaa/Terminator fuera; Duronga exhibida y filas actuales conservadas.',
 'nativo':{'resoluciones':[[1280,720],[1920,1080]],'png':{str(f.relative_to(native)):hashlib.sha256(f.read_bytes()).hexdigest() for f in native_files}},
 'web_mapa':{'contexto':'camara-diagnostica','errores':errors,'avisos':[x for x in diagnostics if x['type']=='warning'],'png':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in web_files}},
 'web_real02':{'resultado':real,'entrada_1920_valida':True,'desplazamiento':'Mouse capturado, teclado mueve al jugador hasta el paredón. Últimas2PNG no sirven para mostrar sectores; se conservan como diagnóstico del recorrido.', 'advertencias':[x for x in json.loads((p/'434-real-final02/consola.json').read_bytes()) if x['type']=='warning']},
 'incidentes':{'nativo01':'Tres encuadres cortaban arriba. Conservados; nativo02 abre el FOV sólo de cámara diagnóstica para N/H1/H2. Sin modelo/preset editado.',
 'chrome01':'Driver conjunto exit1: dos pageerror de pointer lock en contexto real. No se atribuyen al contexto diagnóstico, que tiene cero errores y22vistas; real02 repite con foco/mouse afirmado y termina0.',
 'export01':'Primer export exit0 retuvo162instancias/111recursos y fue rechazado. Control02 verboso con mismo proyecto/preset/plugins y cuatro archivos byteidénticos salió limpio. Sonda main-pack del PCK real limpia.'},
 'limite':'Las44vistas de sectores usan cámara de observación, no prueban recorrido a pie ni gestos. Las suites prueban alcance/interacción; real02 acredita arranque y entrada de teclado/mouse. Paquetes real y diagnóstico tienen hashes separados.'}
(p/'434-revision-visual-root.json').write_bytes(json.dumps(record,ensure_ascii=False,indent=2).encode())
print('ROOT_VISUAL434_44PNG_REVISADAS; provenance explícita; no se afirma Chrome01 verde')
