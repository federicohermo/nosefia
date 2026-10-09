from pathlib import Path
import os, subprocess, json, shutil, sys, xml.etree.ElementTree as ET
root = Path.cwd(); scratch = Path(__file__).parent
label = sys.argv[1]
env = dict(os.environ, APPDATA=str(root / '.godot/usuario_de_los_tests'))
raw = scratch / (label + '-raw.log'); assert not raw.exists()
cmd = [env['GODOT_BIN'], '--headless', '--path', str(root), '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0', 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd']
for suite in ['test/escenas/almacen_test.gd', 'test/escenas/lo_soltado_fuera_de_los_solidos_test.gd', 'test/escenas/objetos/caja_que_se_lleva_test.gd', 'test/escenas/puestos/contenedor_de_basura_test.gd', 'test/escenas/puestos/notas_del_almacen_test.gd']:
    cmd += ['-a', suite]
cmd += ['--continue', '--ignoreHeadlessMode', '-rd', 'res://reports/' + label]
with raw.open('w', encoding='utf-8') as stream:
    code = subprocess.run(cmd, env=env, stdout=stream, stderr=subprocess.STDOUT).returncode
latest = max((root / 'reports' / label).glob('report_*/results.xml'), key=lambda p: int(p.parent.name.removeprefix('report_')))
dest = scratch / (label + '-results.xml'); shutil.copyfile(latest, dest)
suites = ET.parse(dest).getroot().findall('testsuite')
proof = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), 'code': code, 'suites': len(suites), 'cases': sum(int(s.attrib['tests']) for s in suites), 'failures': sum(int(s.attrib['failures']) for s in suites), 'errors': sum(int(s.attrib['errors']) for s in suites), 'failed_cases': [{'suite': s.attrib['name'], 'case': c.attrib['name'], 'failures': [x.text for x in c.findall('failure')]} for s in suites for c in s.findall('testcase') if c.findall('failure')], 'raw': str(raw)}
(scratch / (label + '-resultados.json')).write_text(json.dumps(proof, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps(proof, ensure_ascii=False), flush=True)
raise SystemExit(code)
