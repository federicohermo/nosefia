from pathlib import Path
import os, subprocess, json, shutil, sys, xml.etree.ElementTree as ET, hashlib

root = Path.cwd(); scratch = Path('D:/temporales/nosefia-batch-64-309/empleo-306')
scratch.mkdir(parents=True, exist_ok=True)
label = sys.argv[1]
suites = ['test/escenas/puestos/contenedor_de_basura_test.gd']
env = dict(os.environ, APPDATA=str(root / '.godot/usuario_de_los_tests'))
raw = scratch / (label + '-raw.log'); assert not raw.exists()
cmd = [env['GODOT_BIN'], '--headless', '--path', str(root), '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0', 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd']
for suite in suites:
    cmd += ['-a', suite]
cmd += ['--continue', '--ignoreHeadlessMode', '-rd', 'res://reports/' + label]
with raw.open('w', encoding='utf-8') as stream:
    code = subprocess.run(cmd, env=env, stdout=stream, stderr=subprocess.STDOUT).returncode
latest = max((root / 'reports' / label).glob('report_*/results.xml'), key=lambda p: int(p.parent.name.removeprefix('report_')))
dest = scratch / (label + '-results.xml'); shutil.copyfile(latest, dest)
xml_suites = ET.parse(dest).getroot().findall('testsuite')
proof = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), 'code': code, 'suites': len(xml_suites), 'cases': sum(int(s.attrib['tests']) for s in xml_suites), 'failures': sum(int(s.attrib['failures']) for s in xml_suites), 'errors': sum(int(s.attrib['errors']) for s in xml_suites), 'skipped': sum(int(s.attrib['skipped']) for s in xml_suites), 'failed_cases': [{'suite': s.attrib['name'], 'case': c.attrib['name'], 'failures': [x.text for x in c.findall('failure')]} for s in xml_suites for c in s.findall('testcase') if c.findall('failure')], 'raw': str(raw), 'xml_sha256': hashlib.sha256(dest.read_bytes()).hexdigest()}
(scratch / (label + '-resultados.json')).write_text(json.dumps(proof, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps(proof, ensure_ascii=False), flush=True)
raise SystemExit(code)
