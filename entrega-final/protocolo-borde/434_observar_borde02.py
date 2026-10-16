from pathlib import Path
import os
import subprocess
import re
p=Path(__file__).parent
with (p/'434-observer-borde02.log').open('wb') as log:
    proc=subprocess.Popen([os.environ['GODOT_BIN'],'--headless','--path',str(Path.cwd()),'--script',str(p/'434_observar_borde02.gd')],stdout=log,stderr=subprocess.STDOUT)
    try:
        code=proc.wait(timeout=60)
    except subprocess.TimeoutExpired:
        subprocess.run(['taskkill','/PID',str(proc.pid),'/T','/F'],stdout=log,stderr=subprocess.STDOUT)
        proc.wait(timeout=30)
        raise SystemExit(124)
raw=(p/'434-observer-borde02.log').read_bytes()
print(raw.decode('utf-8','replace'))
assert code==0 and b'434_BORDE_OBSERVER_OK' in raw
assert not re.search(rb'SCRIPT ERROR|Parse Error|ERROR:|leaked at exit|resources still in use|Pages in use',raw,re.I)
