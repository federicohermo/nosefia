from pathlib import Path
import json, os, subprocess, shutil, xml.etree.ElementTree as ET
root = Path.cwd()
out = Path('D:/temporales/nosefia-batch-64-309/empleo-306'); out.mkdir(parents=True, exist_ok=True)
filters = json.loads(Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-64-309/c-gdunit-casos-exactos/argumentos-2390328d.json').read_text())
label = 'b-306-originales-exactos2'
env = dict(os.environ, APPDATA=str(root / '.godot/usuario_de_los_tests'))
cmd = [env['GODOT_BIN'], '--headless', '--path', str(root), '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0', 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-a', 'res://test/sistemas/marco/lugares_del_piso_test.gd']
for key in ['charco', 'notas']:
    args = filters[key]['gdunit_args']
    cmd += args[:args.index('--continue')]
cmd += ['--continue', '--ignoreHeadlessMode', '-rd', 'res://reports/' + label]
raw = out / (label + '-raw.log'); assert not raw.exists()
with raw.open('w', encoding='utf-8') as log:
    code = subprocess.run(cmd, env=env, stdout=log, stderr=subprocess.STDOUT).returncode
latest = max((root / 'reports' / label).glob('report_*/results.xml'), key=lambda p: int(p.parent.name.removeprefix('report_')))
dest = out / (label + '-results.xml'); shutil.copyfile(latest, dest)
suites = ET.parse(dest).getroot().findall('testsuite')
proof = {'code': code, 'diagnostico_filtrado_no_final': True, 'suites': len(suites), 'cases': sum(int(s.attrib['tests']) for s in suites), 'failures': sum(int(s.attrib['failures']) for s in suites), 'errors': sum(int(s.attrib['errors']) for s in suites), 'failed_cases': [{'suite': s.attrib['name'], 'case': c.attrib['name'], 'failures': [x.text for x in c.findall('failure')]} for s in suites for c in s.findall('testcase') if c.findall('failure')]}
(out / (label + '-resultados.json')).write_text(json.dumps(proof, indent=2, ensure_ascii=False), encoding='utf-8')
assert proof['suites'] == 3 and proof['cases'] == 5, proof
print(json.dumps(proof, ensure_ascii=False), flush=True)
raise SystemExit(code)
