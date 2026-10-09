from pathlib import Path
import os, subprocess, json, shutil, sys, xml.etree.ElementTree as ET
root=Path.cwd(); scratch=Path(__file__).parent
env=dict(os.environ,APPDATA=str(root/'.godot/usuario_de_los_tests'))
label=sys.argv[1] if len(sys.argv)>1 else 'b-306-rojo1'
raw=scratch/(label+'-raw.log'); assert not raw.exists()
with (scratch/(label+'-import.log')).open('w',encoding='utf-8') as stream:
    imported=subprocess.run([env['GODOT_BIN'],'--headless','--path',str(root),'--import','--quit'],env=env,stdout=stream,stderr=subprocess.STDOUT)
assert imported.returncode==0
cmd=[env['GODOT_BIN'],'--headless','--path',str(root),'-s','-d','--remote-debug','tcp://127.0.0.1:0','res://addons/gdUnit4/bin/GdUnitCmdTool.gd']
suites=['test/dominio/almacen/reglas_del_cierre_test.gd','test/dominio/empleo/llamados_de_la_partida_test.gd','test/escenas/puestos/habitaciones_del_almacen_test.gd','test/sistemas/marco/agarre_test.gd']
if label!='b-306-rojo1': suites+=['test/dominio/empleo/legajo_test.gd','test/dominio/empleo/partida_test.gd','test/dominio/empleo/partida_serializada_test.gd','test/dominio/empleo/parte_de_cierre_test.gd','test/dominio/empleo/politica_de_guardado_test.gd','test/sistemas/marco/guardado_test.gd','test/dominio/reglas_test.gd']
for suite in suites:
    cmd+=['-a',suite]
cmd+=['--continue','--ignoreHeadlessMode','-rd','res://reports/'+label]
with raw.open('w',encoding='utf-8') as stream:
    result=subprocess.run(cmd,env=env,stdout=stream,stderr=subprocess.STDOUT)
latest=max((root/'reports'/label).glob('report_*/results.xml'),key=lambda p:int(p.parent.name.removeprefix('report_')))
dest=scratch/(label+'-results.xml'); shutil.copyfile(latest,dest)
x=ET.parse(dest).getroot(); suites=x.findall('testsuite')
proof={'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'code':result.returncode,'suites':len(suites),'cases':sum(int(s.attrib['tests']) for s in suites),'errors':sum(int(s.attrib['errors']) for s in suites),'failures':sum(int(s.attrib['failures']) for s in suites),'raw':str(raw)}
(scratch/(label+'-resultados.json')).write_text(json.dumps(proof,indent=2),encoding='utf-8')
print(json.dumps(proof),flush=True)
raise SystemExit(result.returncode)
