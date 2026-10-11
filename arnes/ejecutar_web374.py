from pathlib import Path
import os
import subprocess
import sys
import time
import urllib.request

s = Path(__file__).parent
export = Path((s / '374-web-path.txt').read_text(encoding='utf-8')) / 'web'
server_log = (s / '374-servidor-web.log').open('wb')
server = subprocess.Popen([sys.executable, '.github/scripts/servir_export.py', str(export), '8374'], stdout=server_log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
try:
    ready = False
    for _ in range(30):
        if server.poll() is not None:
            raise RuntimeError('Servidor propio no pudo abrir el puerto: ' + str(server.returncode))
        try:
            with urllib.request.urlopen('http://127.0.0.1:8374', timeout=1) as respuesta:
                contenido = respuesta.read()
            assert contenido == (export / 'index.html').read_bytes(), 'Otro paquete en el puerto'
            ready = True
            break
        except OSError:
            time.sleep(.2)
    assert ready, 'Servidor no disponible'
    resultado = subprocess.run(['node', str(s / 'navegador374.cjs')], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
    print(resultado.stdout.decode('utf-8', errors='replace'), end='', flush=True)
    sys.exit(resultado.returncode)
finally:
    server.terminate()
    try:
        server.wait(timeout=10)
    except subprocess.TimeoutExpired:
        server.kill()
        server.wait()
    server_log.close()
