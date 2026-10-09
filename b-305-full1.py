from pathlib import Path
import subprocess, sys, json, hashlib, shutil, time, xml.etree.ElementTree as ET
root=Path.cwd(); scratch=Path(__file__).parent
raw=scratch/'b-305-full1-tests-crudo.log'
assert not raw.exists()
start=time.time()
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
code=subprocess.run([sys.executable,str(scratch/'padre-verificar-con-log.py'),str(raw)]).returncode
count=subprocess.run([sys.executable,'.claude/skills/implement-batch/scripts/conteo.py'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
print(count.stdout,flush=True)
(scratch/'b-305-full1-conteo.log').write_text(count.stdout,encoding='utf-8')
reports=[p for p in (root/'reports').glob('report_*') if (p/'results.xml').is_file()]
latest=max(reports,key=lambda p:int(p.name.removeprefix('report_')))/'results.xml'
dest=scratch/'b-305-full1-results.xml'
assert not dest.exists()
shutil.copyfile(latest,dest)
xml=ET.parse(dest).getroot()
result={'head':head,'code':code,'count_code':count.returncode,'count':count.stdout,'elapsed':time.time()-start,'raw':str(raw),'xml':str(dest),'xml_sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'suites':len(xml.findall('testsuite')),'cases':sum(int(x.attrib['tests']) for x in xml.findall('testsuite')),'errors':sum(int(x.attrib['errors']) for x in xml.findall('testsuite')),'failures':sum(int(x.attrib['failures']) for x in xml.findall('testsuite')),'skipped':sum(int(x.attrib['skipped']) for x in xml.findall('testsuite'))}
(scratch/'b-305-full1-resultados.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result),flush=True)
raise SystemExit(code or count.returncode)
