"""Contraste del mismo discovery en la copia exportada de producto #373, sin editarla."""

from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys

s = Path(__file__).parent
w = s / '373-web-33828836' / 'proyecto'
archivos = sorted((w / 'test').rglob('*_test.gd'))
assert len(archivos) == 236
elegida = 'test/dominio/empleo/partida_test.gd'
comando = [os.environ['GODOT_BIN'], '--path', str(w), '--headless', '--verbose',
           '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0',
           'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-a', 'test',
           '--continue', '--ignoreHeadlessMode', '-rd', 'res://reports/diagnosticoBase373']
for p in archivos:
    ruta = p.relative_to(w).as_posix()
    if ruta != elegida:
        comando.extend(['-i', ruta])
huellas = {p.relative_to(w).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
           for carpeta in ['src', 'test', 'addons']
           for p in (w / carpeta).rglob('*') if p.is_file()}
(s / '374-base373-comando.json').write_text(json.dumps({
    'producto': '33828836d19b8913efbc0c3d2dc09186b5af13f6',
    'comando': comando, 'huellas_fuentes': huellas,
}, ensure_ascii=False, indent=2), encoding='utf-8')
r = subprocess.run(comando, cwd=w, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                   encoding='utf-8', errors='replace', timeout=180)
print(r.stdout, end='', flush=True)
for nombre, sha in huellas.items():
    assert hashlib.sha256((w / nombre).read_bytes()).hexdigest() == sha, nombre
sys.exit(r.returncode)
