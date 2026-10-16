import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import time

p = Path(__file__).parent
raiz = Path.cwd()
pins = json.loads((p / 'pins-nativo.json').read_bytes())
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip() == pins['head']
assert not subprocess.check_output(['git', 'status', '--porcelain']).strip()
for ruta, sha in pins['inputs'].items():
    assert hashlib.sha256(Path(ruta).read_bytes()).hexdigest() == sha
inicio = time.monotonic()
resultados = []
for w, h in [(1280, 720), (1920, 1080)]:
    carpeta = p / f'nativo-{w}x{h}'
    carpeta.mkdir(exist_ok=False)
    args = [pins['godot'], '--path', str(raiz), '--rendering-method', 'gl_compatibility',
            '--rendering-driver', 'opengl3', '--resolution', f'{w}x{h}',
            '--script', str(p / 'nativo.gd'), '--', str(carpeta), str(w), str(h)]
    with (carpeta / 'motor.log').open('wb') as log:
        proceso = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT)
        try:
            codigo = proceso.wait(timeout=180)
        except subprocess.TimeoutExpired:
            subprocess.run(['taskkill', '/PID', str(proceso.pid), '/T', '/F'], stdout=log, stderr=subprocess.STDOUT)
            proceso.wait(timeout=30)
            raise SystemExit(124)
    raw = (carpeta / 'motor.log').read_text(encoding='utf-8', errors='replace')
    assert codigo == 0 and '434_MAPA_COMPLETO_OK' in raw
    assert not re.search(r'SCRIPT ERROR|Parse Error|ERROR:|leaked at exit|resources still in use|Pages in use', raw, re.I), str(carpeta)
    vistas = [json.loads(x) for x in re.findall(r'^434_VISTA:(.*)$', raw, re.M)]
    assert len(vistas) == 11 and all(x['jornada'] == 2 and x['cupo_duronga'] > 0 for x in vistas)
    archivos = sorted(carpeta.glob('*.png'))
    assert len(archivos) == 11
    for f in archivos:
        assert struct.unpack('>II', f.read_bytes()[16:24]) == (w, h)
    resultados.append({'resolucion': [w, h], 'vistas': vistas,
                       'png': {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in archivos}})
for ruta, sha in pins['inputs'].items():
    assert hashlib.sha256(Path(ruta).read_bytes()).hexdigest() == sha
assert not subprocess.check_output(['git', 'status', '--porcelain']).strip()
(p / 'auditoria-nativo.json').write_bytes(json.dumps({'head': pins['head'], 'segundos': time.monotonic()-inicio,
    'resultados': resultados, 'limite': 'Cámara de observación del mapa; alcance e interacción se prueban en las suites.'}, ensure_ascii=False, indent=2).encode('utf-8'))
print('434_NATIVO_FINAL01_OK 22PNG/2res/11sectores; fuente intacta.', flush=True)
