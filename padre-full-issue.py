"""Run the original seven checks and count immediately, preserving the full report."""
from pathlib import Path
import subprocess,sys,json,hashlib,shutil,time,xml.etree.ElementTree as ET
issue,label=sys.argv[1:]
root=Path.cwd(); scratch=Path(__file__).parent
out=Path('D:/temporales/nosefia-batch-64-309')/('empleo-'+issue)
out.mkdir(parents=True,exist_ok=True)
raw=out/(label+'-tests-crudo.log'); assert not raw.exists()
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
assert not subprocess.check_output(['git','status','--porcelain'],text=True).strip()
start=time.time()
code=subprocess.run([sys.executable,str(scratch/'padre-verificar-con-log.py'),str(raw)]).returncode
count=subprocess.run([sys.executable,'.claude/skills/implement-batch/scripts/conteo.py'],capture_output=True,encoding='utf-8')
print(count.stdout+count.stderr,flush=True)
(out/(label+'-conteo.log')).write_bytes((count.stdout+count.stderr).encode())
latest=max((p for p in (root/'reports').glob('report_*') if (p/'results.xml').is_file()),key=lambda p:int(p.name.removeprefix('report_')))/'results.xml'
xml=out/(label+'-results.xml'); assert not xml.exists();shutil.copyfile(latest,xml)
suites=list(ET.parse(xml).getroot().iter('testsuite'))
result={'head':head,'code':code,'count_code':count.returncode,'elapsed':time.time()-start,'raw':str(raw),'xml':str(xml),'xml_sha256':hashlib.sha256(xml.read_bytes()).hexdigest(),'suites':len(suites),'cases':sum(int(x.get('tests','0')) for x in suites),**{k:sum(int(x.get(k,'0')) for x in suites) for k in ['errors','failures','skipped','flaky']}}
(out/(label+'-resultados.json')).write_bytes((json.dumps(result,indent=2)+'\n').encode())
print(json.dumps(result),flush=True)
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==head
assert not subprocess.check_output(['git','status','--porcelain'],text=True).strip()
raise SystemExit(code or count.returncode)
