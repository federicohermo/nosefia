"""Controla caída y coste físico; después registra cuatro gestos dibujados en la candidata."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import sys
import time

base = Path(__file__).parent
salida = base / '428/pareados-final03'
salida.mkdir()
raiz = Path.cwd()
control = raiz.parent / 'batch-425-controles'
sys.path.insert(0, str(raiz / '.claude/scripts'))
from lib.godot import entorno_de_la_suite

registro = []
for nombre, wt, head in [
    ('control425', control, 'bc26e68435b03298bcd8fb07524b73f3671cd7cf'),
    ('candidato428', raiz, 'd9bfd082'),
]:
    assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=wt).strip()
    actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=wt).decode().strip()
    assert actual.startswith(head)
    carpeta = salida / nombre
    carpeta.mkdir()
    entorno = entorno_de_la_suite(dict(os.environ), wt, sys.platform)
    fases = [
        ('import', ['--headless', '--import', '--quit'], 120),
        ('cascada', ['--headless', '--verbose', '--script', str(base / '428_cascada_control03.gd')], 90),
        ('perf', ['--rendering-driver', 'opengl3', '--windowed', '--resolution',
                  '1280x720', '--position', '0,0', '--script',
                  str(base / 'perf_contornos428_v02.gd'), '--', str(carpeta / 'perf.json')], 120),
    ]
    if nombre == 'candidato428':
        (base / '428/nativo-final02').mkdir()
        fases.append(('nativo-final', [
            '--rendering-driver', 'opengl3', '--windowed', '--resolution',
            '1280x720', '--position', '0,0', '--script',
            str(base / '428_nativo_final02.gd')], 120))
    for fase, args, tope in fases:
        inicio = time.monotonic()
        comando = [entorno['GODOT_BIN'], '--path', '.', *args]
        print('428_PAREADO_FASE', nombre, fase, flush=True)
        with (carpeta / (fase + '.log')).open('wb') as log:
            proceso = subprocess.Popen(comando, cwd=wt, env=entorno,
                                       stdout=log, stderr=subprocess.STDOUT)
            try:
                codigo = proceso.wait(timeout=tope)
            except subprocess.TimeoutExpired:
                if proceso.poll() is None:
                    subprocess.run(['taskkill', '/PID', str(proceso.pid), '/T', '/F'],
                                   capture_output=True)
                    proceso.wait(timeout=5)
                raise
        texto = (carpeta / (fase + '.log')).read_text(encoding='utf-8', errors='replace')
        diagnosticos = re.findall(
            r'^.*(?:SCRIPT ERROR|Parse Error|ERROR:|WARNING:|leaked at exit|'
            r'resources still in use|Pages in use exist at exit).*$', texto, re.M | re.I)
        registro.append({'wt': str(wt), 'head': actual, 'fase': fase,
                         'comando': comando, 'exit': codigo,
                         'duracion_s': time.monotonic() - inicio, 'diagnosticos': diagnosticos})
        (salida / 'auditoria.json').write_text(
            json.dumps(registro, ensure_ascii=False, indent=2), encoding='utf-8')
        print('428_PAREADO_RESULTADO', nombre, fase, codigo, diagnosticos, flush=True)
        assert codigo == 0 and not diagnosticos
        if fase == 'cascada':
            assert '428_CASCADA_CONTROL_FIN fallas=[]' in texto
        if fase == 'perf':
            assert '428_PERF_CONTORNOS_FIN' in texto
        if fase == 'nativo-final':
            assert '428_NATIVO_FINAL cuatro_gestos_reales fallas=[]' in texto
    assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=wt).strip()
print('428_PAREADOS_FIN', flush=True)
