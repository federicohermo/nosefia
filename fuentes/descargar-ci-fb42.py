import json,subprocess,xml.etree.ElementTree as E
from pathlib import Path
s=Path(__file__).parent/'ci-fb42';s.mkdir(exist_ok=True)
run='38954361180'
meta=json.loads(subprocess.check_output(['gh','api','repos/federicohermo/nosefia/actions/runs/'+run]))
assert meta['head_sha']=='fb4236e69c752e6879bb338b80e734e16b211b41'
(s/'run.json').write_text(json.dumps(meta,indent=2),encoding='utf8')
subprocess.run(['gh','run','download',run,'--dir',str(s/'artefactos')],check=True)
with (s/'log-completo.txt').open('wb') as log:subprocess.run(['gh','run','view',run,'--log'],stdout=log,stderr=subprocess.STDOUT,check=True)
xmls=list((s/'artefactos').rglob('results.xml'));assert len(xmls)==1
r=E.parse(xmls[0]).getroot()
giro=next(x for x in r if x.attrib['name']=='giro_parejo_test')
caso=next(x for x in giro if x.attrib.get('name')=='test_una_caja_contra_la_pared_se_corre_sin_escalones')
d={'head':meta['head_sha'],'conclusion':meta['conclusion'],'xml':str(xmls[0]),'suites':len(r),'casos':len(r.findall('.//testcase')),'problemas':{t:len(r.findall('.//'+t)) for t in ['failure','error','skipped']},'giro_suite':giro.attrib,'giro_caso':caso.attrib,'giro_xml':E.tostring(caso,encoding='unicode')}
(s/'revision-xml.json').write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf8')
assert meta['conclusion']=='success' and not any(d['problemas'].values())
print(json.dumps(d,ensure_ascii=True,indent=2))
