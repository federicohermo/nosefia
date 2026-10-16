from pathlib import Path
import os,subprocess,sys
p=Path(__file__).parent
out=p/'nativo-final'
out.mkdir(exist_ok=True)
entorno = dict(os.environ)
entorno['APPDATA'] = str(p/'nativo-userfs')
Path(entorno['APPDATA']).mkdir(exist_ok=True)
for w,h in [(1920,1080),(1280,720)]:
    cmd=[os.environ['GODOT_BIN'],'--path','.', '--rendering-driver','opengl3','--script',str(p/'capturar_nativo430.gd'),'--',str(out),str(w),str(h)]
    with (out/f'nativo-{w}.log').open('wb') as log:
        proceso=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,env=entorno)
        try:
            codigo=proceso.wait(timeout=150)
        except subprocess.TimeoutExpired:
            print(f'NATIVO430_TIMEOUT pid propio={proceso.pid}',flush=True)
            subprocess.run(['taskkill','/PID',str(proceso.pid),'/T','/F'],check=False)
            proceso.wait(timeout=10)
            raise SystemExit(1)
    s=(out/f'nativo-{w}.log').read_text(encoding='utf-8',errors='replace')
    print(s,flush=True)
    if codigo or f'NATIVO430_FINAL resolucion=({w}, {h}) fallos=0' not in s or any(x in s for x in ['SCRIPT ERROR','Parse Error','ERROR:', 'WARNING:', 'leaked','still in use']):
        sys.exit(codigo or 1)
print('NATIVO430_AMBAS_FINAL',flush=True)
