import argparse,hashlib,json,shutil,subprocess
from pathlib import Path

args=argparse.ArgumentParser();args.add_argument('--parcial',action='store_true');op=args.parse_args()
s=Path(__file__).parent;d=s/'publicable';d.mkdir(exist_ok=True)
directorios=['dominio-rojo-01','dominio-rojo-01-fuente','integracion-rojo-02','integracion-rojo-02-fuente','fisico-rojo-03','fisico-rojo-03-fuente','fisico-rojo-04','verde-05','verde-05-fuente','full-01','volumen-01','geometria-verde-06','geometria-verde-07','geometria-verde-09','evidencia-01']
if not op.parcial:directorios+=['full-02','evidencia-04','giro-control-01','ci-fb42']
for nombre in directorios:
    if (s/nombre).is_dir():shutil.copytree(s/nombre,d/nombre,dirs_exist_ok=True)
(d/'fuentes').mkdir(exist_ok=True)
for p in s.iterdir():
    if p.is_file() and p.suffix in ['.py','.gd','.mjs','.json','.log','.txt','.tscn','.cfg']:
        shutil.copy2(p,d/'fuentes'/p.name)
shutil.copy2(s.parent/'issue-22-volumenes-publicar.md',d/'brief-publicado.md')
head='fb4236e69c752e6879bb338b80e734e16b211b41'
paths=subprocess.check_output(['git','diff','--name-only','6d60f82c16bbbc1f7182e656ebead8df8bf5ad87',head],text=True).splitlines()
fuente={}
for nombre in paths:
    raw=subprocess.check_output(['git','cat-file','blob',head+':'+nombre])
    destino=d/'fuente-entregada'/nombre;destino.parent.mkdir(parents=True,exist_ok=True);destino.write_bytes(raw)
    fuente[nombre]={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'blob':subprocess.check_output(['git','rev-parse',head+':'+nombre],text=True).strip()}
(d/'fuente-entregada.json').write_text(json.dumps({'head':head,'archivos':fuente},ensure_ascii=False,indent=2),encoding='utf8')
if op.parcial:
    print('Preparación parcial local; no manifiesto final ni publicación.');raise SystemExit(0)
full=json.loads((s/'full-02/revision-carril-C.json').read_text(encoding='utf8'))
web=json.loads((s/'evidencia-04/web-04/capturas/resultado.json').read_text(encoding='utf8'))
paquete=json.loads((s/'evidencia-04/comandos.json').read_text(encoding='utf8'))
assert full['codigo']==1 and full['suites']==288 and full['casos']==2191 and not full['incidentes']
assert full['problemas_xml']=={'failure':1,'error':0,'skipped':0}
ci=json.loads((s/'ci-fb42/revision-xml.json').read_text(encoding='utf8'))
assert ci['job_conclusion']=='success' and not any(ci['problemas'].values())
assert web['exit_code']==0 and all(c['codigo']==0 for c in paquete['comandos'])
export=Path('D:/nosefia-carril-C-429-444/22-export-04')
dest=d/'export';dest.mkdir(exist_ok=True)
for p in export.iterdir():
    if p.is_file() and p.suffix in ['.json','.log','.txt']:shutil.copy2(p,dest/p.name)
huellas=json.loads((export/'huellas.json').read_text(encoding='utf8'))
assert huellas['commit']==head and huellas['guardias']=={'comprobar':0,'verificar_export':0}
readme=(s/'README-final.md').read_text(encoding='utf8')
readme=readme.replace('FULL_PENDING','CI propia sobrefb4236e6:7/7nodos,288suites y2191casos; XML0fallos/errores/skips y crudo sinScript/Parse/retenciones.\nLas dos completas locales permanecen rojas. La verificación definitiva integrada está pendiente; PR468 conserva borrador.\nHarnessPython:640casos, un skip heredado por ausencia de recursosRSCC; motivo y sonda estática conservados.')
readme=readme.replace('WEB_PENDING','Paquete final y nativos: sondas estrictas y guardias0/0. Chrome04:33snapshots/PNG en ambas resoluciones, estados y consola íntegros.\nLas26capturas nativas están en evidencia-04/nativo y Web en evidencia-04/web-04/capturas; los intentos anteriores mantienen sus límites explícitos.')
assert 'PENDING' not in readme
(d/'README.md').write_text(readme,encoding='utf8')
manifest={'issue':22,'pr':468,'product_head':head,'base_pr':'improvement/431-separadores-de-jornadas-en-chats','base_head':'6d60f82c16bbbc1f7182e656ebead8df8bf5ad87','full_definitiva':None,'full_conjunta':'pendiente','locales':{'full-01':'roja:GI/volumen','full-02':'roja:giro1/107'},'ci_propia':'ci-fb42','web_definitiva':True,'paquete_definitivo':'export/huellas.json','nativos_definitivos':'evidencia-04/nativo','web_definitiva_ruta':'evidencia-04/web-04/capturas','alcance':'Motor genérico y memoriaJ2, sin elección/persistencia436 ni notificación385. Fuente y evidencia independiente por intento.','archivos':{}}
(d/'manifiesto.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
print('Publicable completo preparado; el publisher recalculará desde blobs Git.')
