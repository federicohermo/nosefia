from pathlib import Path
import os, subprocess, json, shutil, sys, xml.etree.ElementTree as ET
root=Path.cwd(); scratch=Path(__file__).parent
env=dict(os.environ,APPDATA=str(root/'.godot/usuario_de_los_tests'))
label=sys.argv[1] if len(sys.argv)>1 else 'b-306-rojo2'
raw=scratch/(label+'-raw.log'); assert not raw.exists()
with (scratch/(label+'-import.log')).open('w',encoding='utf-8') as stream:
    imported=subprocess.run([env['GODOT_BIN'],'--headless','--path',str(root),'--import','--quit'],env=env,stdout=stream,stderr=subprocess.STDOUT)
assert imported.returncode==0
cmd=[env['GODOT_BIN'],'--headless','--path',str(root),'-s','-d','--remote-debug','tcp://127.0.0.1:0','res://addons/gdUnit4/bin/GdUnitCmdTool.gd']
for suite in ['test/escenas/cierre_del_almacen_test.gd','test/escenas/unidades_sueltas_del_cierre_test.gd','test/escenas/soporte_del_exterior_test.gd','test/sistemas/marco/ciclo_de_jornadas_test.gd','test/sistemas/marco/enlace_de_guardado_test.gd','test/sistemas/marco/guardado_test.gd']:
    cmd+=['-a',suite]
cmd+=['--continue','--ignoreHeadlessMode','-rd','res://reports/'+label]
with raw.open('w',encoding='utf-8') as stream:
    result=subprocess.run(cmd,env=env,stdout=stream,stderr=subprocess.STDOUT)
paths=list((root/'reports'/label).glob('report_*/results.xml'))
proof={'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'code':result.returncode,'raw':str(raw)}
if paths:
 latest=max(paths,key=lambda p:int(p.parent.name.removeprefix('report_')))
 dest=scratch/(label+'-results.xml'); shutil.copyfile(latest,dest)
 suites=ET.parse(dest).getroot().findall('testsuite')
 proof.update(suites=len(suites),cases=sum(int(s.attrib['tests']) for s in suites),errors=sum(int(s.attrib['errors']) for s in suites),failures=sum(int(s.attrib['failures']) for s in suites))
(scratch/(label+'-resultados.json')).write_text(json.dumps(proof,indent=2),encoding='utf-8')
print(json.dumps(proof),flush=True)
raise SystemExit(result.returncode)
