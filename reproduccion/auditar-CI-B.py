from pathlib import Path
import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET

run = '38957377068'
head = '838e0baae3ed7f61f6f3190a00058a5d6c10b503'
dest = Path('D:/nosefia-carril-B-429-444/ci470-838e')
dest.mkdir(exist_ok=True)
def gh(*args):
    return subprocess.check_output(['gh', *args])
state = json.loads(gh('run', 'view', run, '--json', 'status,conclusion,headSha,url,jobs'))
assert state['headSha'] == head
(dest/'estado.json').write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding='utf-8')
if state['status'] != 'completed':
    print(state['status'])
    raise SystemExit(2)
raw = gh('run', 'view', run, '--log')
(dest/'workflow.log').write_bytes(raw)
if not (dest/'reports-gdunit4').exists():
    subprocess.run(['gh', 'run', 'download', run, '--dir', str(dest)], check=True)
reports = []
own = []
for path in dest.rglob('results.xml'):
    root = ET.parse(path).getroot()
    suites = list(root.iter('testsuite'))
    counts = {key: sum(int(suite.get(key, 0)) for suite in suites) for key in ['tests','failures','errors','skipped','flaky']}
    reports.append({'path': str(path), 'suites': len(suites), **counts})
    for suite in suites:
        if suite.get('name') == 'sprites_de_compradores_jornada_2_test':
            own.append({'suite': suite.attrib, 'cases': [case.attrib for case in suite.findall('testcase')]})
assert reports and len(own) == 1
assert len(own[0]['cases']) == 9
for item in reports:
    assert all(item[key] == 0 for key in ['failures','errors','skipped','flaky']), item
text = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', raw.decode('utf-8', errors='replace'))
tokens = {token: text.count(token) for token in ['SCRIPT ERROR','Parse Error','ObjectDB instances leaked','resources still in use','Pages in use','Orphan StringName:','Remote Debugger: Unable to connect']}
nodes = [line for line in text.splitlines() if re.search(r'(7/7|\[OK\]|\[FAIL\]|nodos|Convergencia)', line)]
result = {'run':run,'head':head,'conclusion':state['conclusion'],'reports':reports,'own':own,'raw_sha256':hashlib.sha256(raw).hexdigest(),'tokens':tokens,'node_lines':nodes}
(dest/'revision-B.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'conclusion':state['conclusion'],'reports':reports,'tokens':tokens,'node_lines':nodes}, ensure_ascii=False, indent=2))
assert state['conclusion'] == 'success'
