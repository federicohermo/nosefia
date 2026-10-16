import os
from pathlib import Path
import subprocess

base = Path(__file__).parent
folder = base/'428/disponer-real02'
folder.mkdir(exist_ok=True)
blender = Path('C:/Program Files/Blender Foundation/Blender 5.2/blender.exe')
assert blender.is_file()
result = subprocess.run([str(blender),'--background',
    str(Path.cwd()/'assets/models/SEPT_JUEGOS_PROTOTIPO.blend'),
    '--python',str(base/'428_disponer_real02.py'),'--python-exit-code','1'],
    stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',
    errors='replace',timeout=900,env=dict(os.environ))
(folder/'blender.log').write_bytes(result.stdout.encode('utf-8'))
print(result.stdout,flush=True)
assert '428_DISPONER_REAL_DOS_PASOS_CUATRO_SALIDAS_BYTEIDENTICAS' in result.stdout
raise SystemExit(result.returncode)
