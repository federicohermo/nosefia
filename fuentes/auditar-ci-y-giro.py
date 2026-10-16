import json,re,subprocess,xml.etree.ElementTree as E
from pathlib import Path
s=Path(__file__).parent
p=s/'ci-fb42'
with (p/'job-log-completo.txt').open('wb') as log:
    subprocess.run(['gh','api','repos/federicohermo/nosefia/actions/jobs/117153364336/logs','--allow-escape-sequences'],stdout=log,stderr=subprocess.STDOUT,check=True)
meta=json.loads(subprocess.check_output(['gh','api','repos/federicohermo/nosefia/actions/runs/38954361180/jobs']))
(p/'jobs.json').write_text(json.dumps(meta,indent=2),encoding='utf8')
assert meta['jobs'][0]['conclusion']=='success'
xml=next((p/'artefactos').rglob('results.xml'));r=E.parse(xml).getroot()
giro=next(x for x in r if x.attrib['name']=='giro_parejo_test')
caso=next(x for x in giro if x.attrib.get('name')=='test_una_caja_contra_la_pared_se_corre_sin_escalones')
d={'head':json.loads((p/'run.json').read_text())['head_sha'],'job_conclusion':'success','suites':len(r),'casos':len(r.findall('.//testcase')),'problemas':{t:len(r.findall('.//'+t)) for t in ['failure','error','skipped']},'giro_suite':giro.attrib,'giro_caso':caso.attrib,'giro_xml':E.tostring(caso,encoding='unicode')}
raw=(p/'job-log-completo.txt').read_text(encoding='utf8',errors='replace')
d['incidentes_raw']=[l for l in raw.splitlines() if re.search(r'SCRIPT ERROR|Parse Error|leaked|still in use|Pages in use',l)]
(p/'revision-xml.json').write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf8')
assert d['head']=='fb4236e69c752e6879bb338b80e734e16b211b41' and d['suites']==288 and d['casos']==2191
assert not any(d['problemas'].values()) and not d['incidentes_raw']
f=s/'giro-control-01';r=E.parse(f/'results.xml').getroot()
raw=(f/'tests.log').read_text(encoding='utf8',errors='replace')
resources=[l.split('Resource still in use: ')[1].split(' (')[0] for l in raw.splitlines() if l.startswith('Resource still in use: ')]
fd={'suites':len(r),'casos':len(r.findall('.//testcase')),'problemas':{t:len(r.findall('.//'+t)) for t in ['failure','error','skipped']},'resources':resources,'script_parse':bool(re.search(r'SCRIPT ERROR|Parse Error',raw)),'limite':'Pasó el control sobre igual fuente; no determina la causa de1/107 en la completa local.'}
(f/'revision.json').write_text(json.dumps(fd,ensure_ascii=False,indent=2),encoding='utf8')
assert not any(fd['problemas'].values()) and not fd['script_parse'] and all(x.startswith('res://addons/gdUnit4/') for x in resources)
print(json.dumps({'ci':d,'focal':{k:v for k,v in fd.items() if k!='resources'}},ensure_ascii=True,indent=2))
