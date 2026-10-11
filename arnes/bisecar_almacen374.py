"""Reduce el descubrimiento de almacén a un gatillo mínimo sin ejecutar sus casos."""

from pathlib import Path
import json
import os
import re
import subprocess

s = Path(__file__).parent
w = Path.cwd()
ancla = 'test/dominio/empleo/instrucciones_del_jefe_test.gd'
archivos = [p.relative_to(w).as_posix() for p in sorted((w / 'test').rglob('*_test.gd'))]
resultados = []


def medir(rutas):
    n = len(resultados)
    comando = [os.environ['GODOT_BIN'], '--path', str(w), '--headless', '--verbose',
               '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0',
               'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '--continue',
               '--ignoreHeadlessMode', '-rd', 'res://reports/diagnosticoAlmacen374-' + str(n)]
    for ruta in rutas + [ancla]:
        comando.extend(['-a', ruta])
    for ruta in archivos:
        if ruta != ancla:
            comando.extend(['-i', ruta])
    r = subprocess.run(comando, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       encoding='utf-8', errors='replace', timeout=120)
    (s / ('374-discovery-almacen-%02d.log' % n)).write_text(r.stdout, encoding='utf-8')
    limpio = re.sub(r'\x1b\[[0-9;]*m', '', r.stdout)
    recursos = [x for x in limpio.splitlines() if x.startswith('Resource still in use:')]
    resumen = {'rutas': rutas, 'comando': comando, 'exit': r.returncode, 'recursos': recursos,
               'script_errors': limpio.count('SCRIPT ERROR:')}
    resultados.append(resumen)
    (s / '374-discovery-almacen-biseccion.json').write_text(json.dumps(
        resultados, ensure_ascii=False, indent=2), encoding='utf-8')
    print(n, len(rutas), len(recursos), rutas, flush=True)
    assert r.returncode == 0 and not resumen['script_errors']
    return len(recursos)


candidatas = [p.relative_to(w).as_posix() for p in sorted(
    (w / 'test/dominio/almacen').rglob('*_test.gd'))]
while len(candidatas) > 1:
    corte = len(candidatas) // 2
    primera, segunda = candidatas[:corte], candidatas[corte:]
    if medir(primera) > 100:
        candidatas = primera
    elif medir(segunda) > 100:
        candidatas = segunda
    else:
        print('La retención requiere combinación de grupos; no hay gatillo individual en esta división.')
        break
if len(candidatas) == 1:
    medir(candidatas)
    print('Gatillo aislado:', candidatas[0])
