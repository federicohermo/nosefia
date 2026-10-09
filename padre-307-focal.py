from pathlib import Path
import os, subprocess, json, shutil, sys, hashlib, xml.etree.ElementTree as ET

root = Path.cwd()
out = Path('D:/temporales/nosefia-batch-64-309/empleo-307')
out.mkdir(parents=True, exist_ok=True)
label = sys.argv[1]
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
diff = subprocess.check_output(['git', 'diff', '--binary'])
env = dict(os.environ, APPDATA=str(root / '.godot/usuario_de_los_tests'))
raw = out / (label + '-raw.log'); assert not raw.exists()
if 'rojo1' in label:
    import_log = out / (label + '-import.log')
    with import_log.open('w', encoding='utf-8') as stream:
        imported = subprocess.run([env['GODOT_BIN'], '--headless', '--path', str(root), '--import', '--quit'], env=env, stdout=stream, stderr=subprocess.STDOUT)
    assert imported.returncode == 0
suites = ['test/escenas/tickets_del_cierre_test.gd']
cmd = [env['GODOT_BIN'], '--headless', '--path', str(root), '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0', 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd']
for suite in suites:
    cmd += ['-a', suite]
cmd += ['--continue', '--ignoreHeadlessMode', '-rd', 'res://reports/' + label]
with raw.open('w', encoding='utf-8') as stream:
    code = subprocess.run(cmd, env=env, stdout=stream, stderr=subprocess.STDOUT).returncode
reports = list((root / 'reports' / label).glob('report_*/results.xml'))
proof = {'head': head, 'diff_sha256': hashlib.sha256(diff).hexdigest(), 'code': code, 'raw': str(raw), 'command': cmd}
if reports:
    latest = max(reports, key=lambda p: int(p.parent.name.removeprefix('report_')))
    dest = out / (label + '-results.xml'); shutil.copyfile(latest, dest)
    suites_xml = ET.parse(dest).getroot().findall('testsuite')
    proof.update({'suites': len(suites_xml), 'cases': sum(int(s.attrib['tests']) for s in suites_xml), 'failures': sum(int(s.attrib['failures']) for s in suites_xml), 'errors': sum(int(s.attrib['errors']) for s in suites_xml), 'skipped': sum(int(s.attrib['skipped']) for s in suites_xml), 'xml_sha256': hashlib.sha256(dest.read_bytes()).hexdigest(), 'failed_cases': [{'suite': s.attrib['name'], 'case': c.attrib['name'], 'failures': [x.text for x in c.findall('failure')], 'errors': [x.text for x in c.findall('error')]} for s in suites_xml for c in s.findall('testcase') if c.findall('failure') or c.findall('error')]})
(out / (label + '-resultados.json')).write_text(json.dumps(proof, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps(proof, ensure_ascii=False), flush=True)
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip() == head
assert subprocess.check_output(['git', 'diff', '--binary']) == diff
raise SystemExit(code)
