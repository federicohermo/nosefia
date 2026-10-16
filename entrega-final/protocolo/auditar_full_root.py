"""Revisión estructurada del crudo: poses intactas, sólo @N normalizado."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

parser=argparse.ArgumentParser()
parser.add_argument('--dir',required=True,type=Path)
parser.add_argument('--control',required=True,type=Path)
parser.add_argument('--head',required=True)
parser.add_argument('--permitir-roja',action='store_true')
args=parser.parse_args()
record=json.loads((args.dir/'ejecucion.json').read_bytes())
assert record['head']==args.head
if not args.permitir_roja:
    assert record['exit_verificar']==record['exit_conteo']==0
required={'capas','formato','harness','lint','specs','tdd','tests','tests-import'}
assert {f.stem for f in (args.dir/'crudo').glob('*.log')}==required
ansi=re.compile(r'\x1b\[[0-9;]*[A-Za-z]')
headers=re.compile(r'^(?:ERROR:|WARNING:|SCRIPT ERROR:).+$',re.M)
def read(path):
    raw=ansi.sub('',path.read_text(encoding='utf-8',errors='replace'))
    found=list(headers.finditer(raw))
    blocks=[]
    for i,match in enumerate(found):
        end=found[i+1].start() if i+1<len(found) else len(raw)
        block=raw[match.start():end]
        blocks.append({'encabezado':match.group(),'firma_sin_contador':re.sub(r'@\d+\b','@ID',match.group()),'contexto_completo':block,'casos_en_stack':re.findall(r'\[\d+\] (test_\w+)',block)})
    return raw,blocks
control,old=read(args.control)
raw,new=read(args.dir/'crudo/tests.log')
counts_old=Counter(x['firma_sin_contador'] for x in old)
counts_new=Counter(x['firma_sin_contador'] for x in new)
xml=ET.parse(args.dir/'results.xml')
suites=xml.findall('.//testsuite')
cases=xml.findall('.//testcase')
failures=xml.findall('.//failure')
errors=xml.findall('.//error')
skipped=xml.findall('.//skipped')
bad=[]
for f in (args.dir/'crudo').glob('*.log'):
    text=ansi.sub('',f.read_text(encoding='utf-8',errors='replace'))
    if re.search(r'SCRIPT ERROR|Parse Error|leaked at exit|resources still in use|Pages in use',text,re.I):
        bad.append(f.name)
if not args.permitir_roja:
    assert not failures and not errors and not skipped
assert not bad,bad
report={'head':args.head,'exit_verificar':record['exit_verificar'],'exit_conteo':record['exit_conteo'],'suites':len(suites),'casos':len(cases),'aserciones_fallidas':len(failures),'errores_xml':len(errors),'skips':len(skipped),'script_parse_fugas':bad,'segundos':record['segundos'],'control':str(args.control),'diagnosticos_control':len(old),'diagnosticos_candidata':len(new),'nuevos':dict(counts_new-counts_old),'ausentes':dict(counts_old-counts_new),'bloques_control':old,'bloques_candidata':new,'conteos_crudos':re.findall(r'Executed test (?:suites|cases).+',raw),'nodos':{f.name:{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in (args.dir/'crudo').glob('*.log')},'limite':'Revisión de todos los nodos, XML y diagnósticos. Sólo se normalizan @N; poses/clases quedan intactas. No se infiere fase ni causa por orden de stdout/stderr concatenados.'}
(args.dir/'revision-root.json').write_bytes(json.dumps(report,ensure_ascii=False,indent=2).encode())
print(json.dumps({k:v for k,v in report.items() if not k.startswith('bloques') and k!='nodos'},ensure_ascii=False,indent=2))
