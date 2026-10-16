import functools, hashlib, json, shutil, subprocess, sys, threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

export=Path(sys.argv[1]).resolve()
dest=Path(sys.argv[2]).resolve()
head=sys.argv[3]
scratch=Path(__file__).parent
web=export/'web'
dest.mkdir(parents=True,exist_ok=False)
fijados=json.loads((export/'huellas.json').read_text(encoding='utf8'))
assert fijados['commit']==head and fijados['guardias']=={'comprobar':0,'verificar_export':0}
archivos=['index.html','index.pck','index.js','index.wasm']
def hashes():return {n:hashlib.sha256((web/n).read_bytes()).hexdigest() for n in archivos}
antes=hashes()
assert antes=={n:fijados['archivos'][n]['sha256'] for n in archivos}
for n in ['fixture-web-22.gd','fixture22.tscn','override.cfg','recorrer-web-22.mjs']:
    shutil.copy2(scratch/n,dest/n)
preparador=export/'proyecto/.github/scripts/preparar_plantilla_web.py'
for n,args in [('comprobar',['--comprobar']),('verificar-export',['--verificar-export',str(web)])]:
    with (dest/f'plantilla-{n}.log').open('wb') as log:
        code=subprocess.run([sys.executable,str(preparador),*args],cwd=export/'proyecto',stdout=log,stderr=subprocess.STDOUT).returncode
    assert code==0,'Guardia '+n
(dest/'provenance.json').write_text(json.dumps({'product_head':head,'export':str(export),'artefactos_antes':antes,'guardias':{'comprobar':0,'verificar_export':0},'fixture_sha256':{n:hashlib.sha256((dest/n).read_bytes()).hexdigest() for n in ['fixture-web-22.gd','fixture22.tscn','override.cfg','recorrer-web-22.mjs']},'limite':'Fixture externo crea Partida J2 en memoria y prepara pose/reloj/apertura/fijación. No registra identidades ni reemplaza PCK; gestos reales de Chrome. No acredita persistencia436.'},ensure_ascii=False,indent=2),encoding='utf8')
class Headers(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy','same-origin')
        self.send_header('Cross-Origin-Embedder-Policy','require-corp')
        self.send_header('Cache-Control','no-store')
        super().end_headers()
    def log_message(self,format,*args):
        with (dest/'http.log').open('a',encoding='utf8') as log:log.write(format%args+'\n')
server=ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Headers,directory=str(web)))
threading.Thread(target=server.serve_forever,daemon=True).start()
url=f'http://127.0.0.1:{server.server_port}/index.html'
cmd=['node',str(dest/'recorrer-web-22.mjs'),url,str(dest/'capturas'),str(dest/'fixture-web-22.gd')]
try:
    with (dest/'stdout.log').open('wb') as out,(dest/'stderr.log').open('wb') as err:
        proceso=subprocess.Popen(cmd,cwd=dest,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
        try:codigo=proceso.wait(timeout=450)
        except subprocess.TimeoutExpired:
            with (dest/'timeout.log').open('wb') as log:subprocess.run(['taskkill','/PID',str(proceso.pid),'/T','/F'],stdout=log,stderr=log)
            proceso.wait(timeout=30);codigo=124
finally:
    server.shutdown();server.server_close()
despues=hashes()
assert antes==despues,'Se alteró un artefacto de producto'
(dest/'comando.json').write_text(json.dumps({'cmd':cmd,'codigo':codigo,'pid':proceso.pid,'url':url,'artefactos_despues':despues,'identicos':antes==despues},indent=2),encoding='utf8')
(dest/'exit-code.txt').write_text(str(codigo),encoding='utf8')
print('CHROME22',codigo)
raise SystemExit(codigo)
