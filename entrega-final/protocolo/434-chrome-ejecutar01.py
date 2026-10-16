import functools
import hashlib
import http.server
import json
from pathlib import Path
import subprocess
import threading

p=Path(__file__).parent
pins=json.loads((p/'434-chrome-pins01.json').read_bytes())
for path,sha in pins['inputs'].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==sha
out=p/'434-chrome-final01'
out.mkdir()
head='29fdc763871c5833b9d28b5c6d71d71d3aeac03f'
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==head
assert not subprocess.check_output(['git','status','--porcelain']).strip()
web=p/'434-web-final01'
manifest=json.loads((web/'manifiesto02.json').read_bytes())
for path,info in manifest['archivos'].items():
    assert hashlib.sha256((web/path).read_bytes()).hexdigest()==info['sha256']
class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy','same-origin')
        self.send_header('Cross-Origin-Embedder-Policy','require-corp')
        super().end_headers()
    def log_message(self,fmt,*args):
        with (out/'http.log').open('a',encoding='utf-8') as f:
            f.write(fmt%args+'\n')
server=http.server.ThreadingHTTPServer(('127.0.0.1',8069),functools.partial(Handler,directory=str(web)))
threading.Thread(target=server.serve_forever,daemon=True).start()
main='D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia'
args=['node',str(p/'434-chrome01.mjs'),main,'http://127.0.0.1:8069',str(out),str(p/'427/checkpoint-j2.guardado')]
try:
    with (out/'driver.log').open('wb') as log:
        proc=subprocess.Popen(args,stdout=log,stderr=subprocess.STDOUT)
        try:
            code=proc.wait(timeout=600)
        except subprocess.TimeoutExpired:
            subprocess.run(['taskkill','/PID',str(proc.pid),'/T','/F'],stdout=log,stderr=subprocess.STDOUT)
            proc.wait(timeout=30)
            code=124
finally:
    server.shutdown()
    server.server_close()
(out/'estado.json').write_bytes(json.dumps({'head':head,'returncode':code,'limite_s':600,'comando':args,'servidor_propio_cerrado':True},indent=2).encode())
assert not subprocess.check_output(['git','status','--porcelain']).strip()
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==head
for path,sha in pins['inputs'].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==sha
print('434_CHROME01 terminó',code,flush=True)
raise SystemExit(code)
