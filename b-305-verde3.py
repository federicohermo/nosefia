from pathlib import Path
import os, subprocess, json, shutil, xml.etree.ElementTree as ET
root=Path.cwd(); scratch=Path(__file__).parent
env=dict(os.environ, APPDATA=str(root/'.godot/usuario_de_los_tests'))
log=scratch/'b-305-verde3-raw.log'
assert not log.exists()
cmd=[env['GODOT_BIN'],'--headless','--path',str(root),'-s','-d','--remote-debug','tcp://127.0.0.1:0','res://addons/gdUnit4/bin/GdUnitCmdTool.gd','-a','test/escenas/puestos/tiro_al_contenedor_test.gd','--continue','--ignoreHeadlessMode','-rd','res://reports/b-305-verde3']
with log.open('w',encoding='utf-8') as stream:
    result=subprocess.run(cmd,env=env,stdout=stream,stderr=subprocess.STDOUT)
latest=max((root/'reports/b-305-verde3').glob('report_*/results.xml'),key=lambda p:int(p.parent.name.removeprefix('report_')))
dest=scratch/'b-305-verde3-results.xml'
shutil.copyfile(latest,dest)
x=ET.parse(dest).getroot()
proof={'code':result.returncode,'suites':len(x.findall('testsuite')),'cases':sum(int(s.attrib['tests']) for s in x.findall('testsuite')),'errors':sum(int(s.attrib['errors']) for s in x.findall('testsuite')),'failures':sum(int(s.attrib['failures']) for s in x.findall('testsuite')),'raw':str(log)}
(scratch/'b-305-verde3-resultados.json').write_text(json.dumps(proof,indent=2),encoding='utf-8')
print(json.dumps(proof),flush=True)
raise SystemExit(result.returncode)
