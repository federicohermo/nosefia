import datetime,json,subprocess,sys
from pathlib import Path
s=Path(__file__).parent
out=s/'full-02';out.mkdir(exist_ok=True)
head='fb4236e69c752e6879bb338b80e734e16b211b41'
pin={'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'estado_porcelain':subprocess.check_output(['git','status','--porcelain'],text=True),'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
assert pin['head']==head and not pin['estado_porcelain']
(out/'pin-pre-enqueue.json').write_text(json.dumps(pin,indent=2),encoding='utf8')
cmd=[sys.executable,'.claude/skills/implement-batch/scripts/turno.py','C:/Users/fede_/AppData/Local/Temp/nosefia-batch-367-385/cola','carril-C-22-full-02',str(s/'full-02-turno.log'),'--',sys.executable,str(s/'full-con-pins.py'),str(out),head]
raise SystemExit(subprocess.run(cmd).returncode)
