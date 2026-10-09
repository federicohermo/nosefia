from pathlib import Path
import os, subprocess, json, shutil, xml.etree.ElementTree as ET, hashlib

root = Path.cwd(); scratch = Path(__file__).parent
proof = json.loads((scratch / 'b-306-trazas-manifest.json').read_text())
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip() == proof['head']
assert hashlib.sha256(subprocess.check_output(['git', 'diff', '--binary'])).hexdigest() == proof['tracked_diff_sha256']
env = dict(os.environ, APPDATA=str(root / '.godot/usuario_de_los_tests'))
results = []
for item in proof['suites']:
    assert hashlib.sha256(Path(item['copy']).read_bytes()).hexdigest() == item['copy_sha256']
    label = 'b-306-trazas-' + item['label']
    raw = scratch / (label + '-raw.log'); assert not raw.exists()
    cmd = [env['GODOT_BIN'], '--headless', '--path', str(root), '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0', 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd'] + item['args'] + ['--continue', '--ignoreHeadlessMode', '-rd', 'res://reports/' + label]
    with raw.open('w', encoding='utf-8') as stream:
        code = subprocess.run(cmd, env=env, stdout=stream, stderr=subprocess.STDOUT).returncode
    reports = list((root / 'reports' / label).glob('report_*/results.xml'))
    if not reports:
        print(json.dumps({'label': label, 'code': code, 'raw': str(raw), 'missing_xml': True}), flush=True)
        raise SystemExit(2)
    latest = max(reports, key=lambda p: int(p.parent.name.removeprefix('report_')))
    dest = scratch / (label + '-results.xml'); shutil.copyfile(latest, dest)
    suites = ET.parse(dest).getroot().findall('testsuite')
    row = {'label': label, 'code': code, 'suites': len(suites), 'cases': sum(int(s.attrib['tests']) for s in suites), 'names': [c.attrib['name'] for s in suites for c in s.findall('testcase')], 'failures': sum(int(s.attrib['failures']) for s in suites), 'errors': sum(int(s.attrib['errors']) for s in suites), 'raw': str(raw)}
    assert row['suites'] == 1 and row['cases'] == 1 and row['names'] == [item['case']], row
    results.append(row)
    print(json.dumps(row), flush=True)
assert hashlib.sha256(subprocess.check_output(['git', 'diff', '--binary'])).hexdigest() == proof['tracked_diff_sha256']
(scratch / 'b-306-trazas-resultados.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
