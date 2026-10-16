from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

p=Path(__file__).parent
root=Path.cwd()
out=p/'compat434367-focal-final04'
ours='d647a2031f5e6ad3862a286ce042b680eaeb8e18'
foreign='43e3e0ad79f664665afbe7939c3cfcd8bd093183'
head='6eff3f59cc08a175df0a64d21a6667a789c56ad7'
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==head
assert not subprocess.check_output(['git','status','--porcelain']).strip()
for commit in [ours,foreign]:
    subprocess.run(['git','merge-base','--is-ancestor',commit,head],check=True)
xml=root/'reports/compat434367-final04/report_1/results.xml'
shutil.copyfile(xml,out/'results.xml')
tree=ET.parse(xml)
assert len(tree.findall('.//testsuite'))==9 and len(tree.findall('.//testcase'))==66
assert not tree.findall('.//failure') and not tree.findall('.//error') and not tree.findall('.//skipped')
raw=(out/'tests.log').read_text(encoding='utf-8',errors='replace')
raw=re.sub(r'\x1b\[[0-9;]*[A-Za-z]','',raw)
assert not re.search(r'SCRIPT ERROR|Parse Error|leaked at exit|resources still in use|Pages in use',raw,re.I)
diagnostics=re.findall(r'^(?:ERROR:|WARNING:).+$',raw,re.M)
diff=subprocess.check_output(['git','diff','--name-only',ours,head],text=True).splitlines()
assert not any(x.endswith(('.tscn','.blend','.glb','.res')) for x in diff)
(out/'union-desde434.patch').write_bytes(subprocess.check_output(['git','diff','--binary',ours,head]))
for label,commit in [('spec434',ours),('spec367',foreign),('spec-union',head)]:
    (out/(label+'.md')).write_bytes(subprocess.check_output(['git','show',commit+':specs/store-stock/store-stock.md']))
for name in ['compatibilidad_guia_sin_principal_test.gd','compatibilidad_guia_sin_principal_test.gd.uid']:
    shutil.copyfile(root/'test/escenas'/name,out/name)
report={'head_union_efimera':head,'434':ours,'367':foreign,'suites':9,'casos':66,'fallos':0,'errores_script_parse_fugas':0,'diagnosticos':diagnostics,'archivos_cambiados_por_union':diff,'assets_y_escenas_sin_cambios':True,'alcance':'API cuatro argumentos, compradores compartidos,200semillas J1-J5, guías completas, guía sin principal con foco/clic real/agarrar/reponer,32sectores y alcance, bordes/estabilidad de cajas. No es full de la unión, ni PR, ni merge a la entrega del lote.','incidentes':'01 falló por comparar objetos Producto que Catalogo.de crea nuevos; identidad correcta es Id.02 falló sólo por la postura vieja del borde.03 preparado, nunca encolado.04 definitivo verde. Se preservan crudos y XML de01/02.'}
(out/'revision-root.json').write_bytes(json.dumps(report,ensure_ascii=False,indent=2).encode())
print(json.dumps({'head':head,'suites':9,'casos':66,'diagnosticos':diagnostics},ensure_ascii=False,indent=2))
