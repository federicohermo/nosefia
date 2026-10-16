import json,re,xml.etree.ElementTree as E
from pathlib import Path
p=Path(__file__).parent/'geometria-verde-09'
r=E.parse(p/'results.xml').getroot()
assert int(r.attrib['tests'])==17 and int(r.attrib['failures'])==0 and int(r.attrib['skipped'])==0
assert all(int(s.attrib.get('errors',0))==0 for s in r)
raw=(p/'tests.log').read_text(encoding='utf8')
assert not re.search('SCRIPT ERROR|Parse Error',raw)
resources=[l.removeprefix('Resource still in use: ').split(' (')[0] for l in raw.splitlines() if l.startswith('Resource still in use: ')]
assert len(resources)==100 and all(x.startswith('res://addons/gdUnit4/') for x in resources)
d={'suites':len(r),'casos':17,'fallos':0,'errores':0,'skips':0,'recursos_retenidos':resources,'limite':'Focal:100scriptsGdUnit; completa exige salida limpia','regeneracion_delta_max':max(x['delta_maximo'] for x in json.loads((p/'regeneracion.json').read_text()))}
(p/'revision.json').write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({k:v for k,v in d.items() if k!='recursos_retenidos'}))
