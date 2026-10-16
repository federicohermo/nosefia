import collections,json,re,subprocess,xml.etree.ElementTree as E
from pathlib import Path

s=Path(__file__).parent
p=s/'full-02'
base=s.parent/'base-integrada-02/crudo'
def lineas(p):return re.sub(r'\x1b\[[0-9;]*[A-Za-z]','',p.read_text(encoding='utf8',errors='replace')).splitlines()
def diagnosticos(p):return collections.Counter(l.strip() for l in lineas(p) if l.strip().startswith(('ERROR:','WARNING:')))
xml=E.parse(p/'results.xml').getroot()
nodos={n:json.loads((p/f'{n}.json').read_text(encoding='utf8')) for n in ['lint','formato','capas','tdd','specs','harness','tests','tests-import']}
incidentes={}
for log in p.glob('*.log'):
    fallos=[l for l in lineas(log) if re.search(r'SCRIPT ERROR|Parse Error|leaked|still in use|PagedAllocator|Pages in use',l)]
    if fallos:incidentes[log.name]=fallos
actual=diagnosticos(p/'tests.log');anterior=diagnosticos(base/'tests.log');rojo=diagnosticos(s/'full-01/tests.log')
pins=json.loads((p/'pins-ejecucion.json').read_text(encoding='utf8'))
r={'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'estado':subprocess.check_output(['git','status','--porcelain'],text=True),'codigo':int((p/'exit-code.txt').read_text()),'nodos':nodos,'suites':len(xml.findall('testsuite')),'casos':len(xml.findall('.//testcase')),'xml_atributos':xml.attrib,'problemas_xml':{t:len(xml.findall('.//'+t)) for t in ['failure','error','skipped']},'flaky':sum(int(n.attrib.get('flaky',0)) for n in xml),'incidentes':incidentes,'diagnosticos_literales':dict(actual),'base':str(base),'nuevos_literales_base':dict(actual-anterior),'retirados_literales_base':dict(anterior-actual),'nuevos_literales_rojo01':dict(actual-rojo),'retirados_literales_rojo01':dict(rojo-actual),'pins':pins,'limite':'Se conservan advertencias literales y cantidades; no se atribuye fase por orden combinado de stdout/stderr ni causa a diferencias de pose.'}
(p/'revision-carril-C.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf8')
assert r['head']=='fb4236e69c752e6879bb338b80e734e16b211b41' and not r['estado']
assert r['codigo']==0 and not incidentes and pins['misma_fuente_limpia']
assert all(n['codigo']==0 and not n['salteado'] for n in nodos.values())
assert r['suites']==288 and r['casos']==2191 and not any(r['problemas_xml'].values()) and not r['flaky']
assert not any(l.startswith('ERROR:') for l in actual-anterior),'ERROR nuevo frente a base'
print(json.dumps({k:r[k] for k in ['head','codigo','suites','casos','problemas_xml','flaky','incidentes','nuevos_literales_base','retirados_literales_base']},ensure_ascii=True,indent=2))
