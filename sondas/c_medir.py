import subprocess,sys,socket,time
from pathlib import Path
work=Path('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/.claude/worktrees/batch-64-309-c')
root=Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-64-309/c-mediciones-f17948fe')
variant=sys.argv[1]
port=8060
for family,address in [(socket.AF_INET,('127.0.0.1',port)),(socket.AF_INET6,('::1',port))]:
    with socket.socket(family,socket.SOCK_STREAM) as sock:
        sock.settimeout(.5)
        if sock.connect_ex(address)==0:
            raise RuntimeError('puerto ocupado')
output=root/variant
subprocess.run([sys.executable,str(work/'.github/scripts/preparar_plantilla_web.py'),'--verificar-export',str(output/'web')],cwd=work,check=True)
with (output/'servidor.log').open('wb') as log:
    server=subprocess.Popen([sys.executable,str(work/'.github/scripts/servir_export.py'),str(output/'web'),str(port)],stdout=log,stderr=subprocess.STDOUT)
    try:
        for intento in range(100):
            with socket.socket() as sock:
                if sock.connect_ex(('127.0.0.1',port))==0:
                    break
            time.sleep(.1)
        if variant.startswith('ui-'):
            subprocess.run(['node',str(Path(__file__).parent/'c_ui.mjs'),f'http://localhost:{port}',str(output/'capturas')],cwd=work,check=True)
            subprocess.run(['node',str(Path(__file__).parent/'c_ui.mjs'),f'http://localhost:{port}',str(output/'capturas-1280'),'1280x720'],cwd=work,check=True)
        else:
            for script,nombre in [('medir_memoria_de_texturas.mjs','memoria.json'),('medir_la_carga.mjs','carga.json')]:
                subprocess.run(['node',str(work/'.github/scripts'/script),f'http://localhost:{port}',str(output/nombre),'--sin-ventana'],cwd=work,check=True)
            subprocess.run(['node',str(Path(__file__).parent/'c_game.mjs'),f'http://localhost:{port}',str(output/'capturas')],cwd=work,check=True)
    finally:
        server.terminate()
        server.wait(timeout=10)
