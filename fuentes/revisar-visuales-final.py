import collections,hashlib,json,re
from pathlib import Path
s=Path(__file__).parent;e=s/'evidencia-04';w=e/'web-04';c=w/'capturas'
datos=json.loads((c/'recorrido.json').read_text(encoding='utf8'))
shots=[x for x in datos if 'snapshot' in x]
logs=json.loads((c/'consola.json').read_text(encoding='utf8'))
assert json.loads((c/'resultado.json').read_text())['exit_code']==0
assert json.loads((w/'comando.json').read_text())['identicos']
for x in shots:
    d=x['dom'];assert x['frames']>=2 and d['visible']=='visible' and d['aislado']
    assert (d['ancho'],d['alto']) in [(1280,720),(1920,1080)]
    if x['game']:assert not x['game']['fallos'] and x['game']['viewport']==[d['ancho'],d['alto']]
errores=[x for x in logs if x['type'] in ['error','pageerror','runner-error'] or re.search(r'SCRIPT ERROR|Parse Error|(^|\s)ERROR:',x['text'])]
assert not errores
avisos=collections.Counter(x['text'] for x in logs if x['type']=='warning')
control=s.parent/'carril-C-431/evidencia-04/web-05/consola.json'
if not control.exists():control=s.parent/'carril-C-431/evidencia-04/web-05/capturas/consola.json'
anteriores=json.loads(control.read_text(encoding='utf8'))
norm=lambda t:re.sub(r'0x[0-9a-fA-F]+','<handle>',t)
conocidos={norm(x['text']) for x in anteriores if x['type']=='warning'}
desconocidos=[t for t in avisos if norm(t) not in conocidos]
assert not desconocidos,desconocidos
probes={}
for nombre in ['sonda-paquete.log','dialogos-paquete.log','nativo-1280.log','nativo-1920.log']:
    raw=(e/nombre).read_text(encoding='utf8',errors='replace')
    incidentes=[l for l in raw.splitlines() if re.search(r'SCRIPT ERROR|Parse Error|(^|\s)(ERROR:|WARNING:)|leaked|still in use|Pages in use',l)]
    assert not incidentes,(nombre,incidentes)
    probes[nombre]={'sin_script_parse_retenciones':True,'sha256':hashlib.sha256((e/nombre).read_bytes()).hexdigest()}
huellas=json.loads((Path('D:/nosefia-carril-C-429-444/22-export-04')/'huellas.json').read_text())
assert huellas['guardias']=={'comprobar':0,'verificar_export':0}
r={'product_head':huellas['commit'],'snapshots':len(shots),'png_web':len(list(c.glob('*.png'))),'png_nativos':len(list((e/'nativo').glob('*.png'))),'errores':errores,'avisos_literales':dict(avisos),'avisos_solo_handle_conocidos':not desconocidos,'limite_avisos':'Se conserva cantidad por cada mensaje literal. La comparación contra431 reemplaza sólohandle hexadecimal; no se asume igual número de inicializaciones.','probes':probes,'guardias':huellas['guardias'],'inspeccion_visual':'Abiertas7PNGWeb y6nativas: mainmenú original, frase lila, HOY/AYER y fotos con adjuntos. Círculo original y colilla visibles, texto completo.','full_local':'Dos completas locales rojas conservadas; CI propia verde y final integrada pendiente.'}
(e/'revision-carril-C.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({k:v for k,v in r.items() if k not in ['avisos_literales','probes']},ensure_ascii=True,indent=2))
