"""Wrapper externo: no modifica producto, preset ni receta del export raíz."""
from pathlib import Path
import hashlib
import json
import os
import re
import runpy
import subprocess
import sys
import threading
import time

if len(sys.argv) != 3:
    raise SystemExit('Uso: wrapper HEAD DESTINO_NUEVO')
head, destination = sys.argv[1:]
dest = Path(destination).resolve()
assert not dest.exists()
root = Path.cwd()
temp = Path('C:/Users/fede_/AppData/Local/Temp/nosefia-watch-429-444')
script = temp/'exportar-paquete444-root.py'
template = Path('D:/nosefia-carril-A-429-444/429-web-export-01/proyecto/build/templates/web_release.zip')
template_manifest = template.with_suffix('.manifiesto.json')
cache = Path('D:/nosefia-carril-C-429-444/22-export-04/proyecto/.godot')
art_probe = Path('D:/nosefia-carril-B-429-444/437-frio-export-01/probar437-pck.gd')
strict_probe = temp/'preparacion-444/.github/scripts/verificar_dialogos_jornada_2_exportados.gd'
own_head = '838e0baae3ed7f61f6f3190a00058a5d6c10b503'
assert all(path.is_file() for path in [script, template, template_manifest, art_probe, strict_probe])
assert cache.is_dir()
def git(*args):
    return subprocess.check_output(['git', *args], cwd=root)
paths = git('diff-tree','--no-commit-id','--name-only','-r',own_head).decode().splitlines()
assert len(paths) == 40
blobs = []
ctex = []
for path in paths:
    expected = git('rev-parse',own_head+':'+path).decode().strip()
    actual = git('rev-parse',head+':'+path).decode().strip()
    assert actual == expected, ('Delta en fuente437',path,expected,actual)
    blobs.append({'path':path,'blob':actual})
    if path.endswith('.png.import'):
        text = git('show',head+':'+path).decode('utf-8')
        ctex.extend(re.findall(r'res://\.godot/imported/[^"\]]+\.ctex', text))
ctex = sorted(set(ctex))
assert len(ctex) == 16
assert all(not (cache/path.removeprefix('res://.godot/')).exists() for path in ctex), 'La caché base ya contiene arte437'
protocol = {'head':head,'own_437_head':own_head,'40_blobs_437_identical':blobs,'cache':str(cache),'cache_absent_16_ctex':ctex,'windows_full_clone_cold':False,'new_437_textures_cold':True,'script_sha256':hashlib.sha256(script.read_bytes()).hexdigest(),'template_sha256':hashlib.sha256(template.read_bytes()).hexdigest(),'processes':[]}
protocol['wrapper_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
original_run = subprocess.run

def persist():
    if dest.exists():
        (dest/'protocolo-B.json').write_text(json.dumps(protocol,ensure_ascii=False,indent=2),encoding='utf-8')

def captured(command, **kwargs):
    target = kwargs.pop('stdout', None)
    kwargs.pop('stderr', None)
    name = Path(target.name).stem if target is not None else 'probe'
    if '--import' in command:
        project = dest/'proyecto'
        missing = [path for path in ctex if not (project/path.removeprefix('res://')).exists()]
        assert len(missing) == 16
        protocol['before_import_16_ctex_absent_in_external_copy'] = missing
        protocol['before_import_time_utc'] = time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())
        persist()
    start = time.monotonic()
    kwargs.setdefault('creationflags', subprocess.CREATE_NO_WINDOW)
    process = subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE,**kwargs)
    record = {'label':name,'command':list(map(str,command)),'pid':process.pid,'start_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
    protocol['processes'].append(record)
    persist()
    lock = threading.Lock()
    with (dest/(name+'.stdout.log')).open('xb') as out, (dest/(name+'.stderr.log')).open('xb') as err, (dest/(name+'.cronologico.log')).open('xb') as chrono:
        def consume(stream, output, channel):
            for line in iter(stream.readline,b''):
                output.write(line)
                output.flush()
                with lock:
                    if target is not None:
                        target.write(line)
                        target.flush()
                    chrono.write(f'{time.monotonic()-start:.6f} {channel} '.encode()+line)
                    chrono.flush()
        threads = [threading.Thread(target=consume,args=(process.stdout,out,'stdout')),threading.Thread(target=consume,args=(process.stderr,err,'stderr'))]
        for thread in threads:
            thread.start()
        code = process.wait()
        for thread in threads:
            thread.join()
    record.update({'exit':code,'seconds':time.monotonic()-start})
    persist()
    print(name+': exit '+str(code),flush=True)
    return subprocess.CompletedProcess(command,code)

def intercept(command, *args, **kwargs):
    if isinstance(command,(list,tuple)) and str(command[0]).lower().endswith('.exe') and 'godot' in str(command[0]).lower():
        assert not args
        return captured(command,**kwargs)
    return original_run(command,*args,**kwargs)

subprocess.run = intercept
sys.argv = [str(script),str(dest),str(template),str(template_manifest),head,str(cache)]
try:
    result = runpy.run_path(str(script),run_name='__main__')
finally:
    subprocess.run = original_run
    persist()
godot = result['godot']
unchanged = []
for path in paths:
    if path.endswith('.png') or path.endswith('/idle.tres') or path == 'src/escenas/puestos/ventanilla.gd':
        expected = git('show',head+':'+path)
        actual = (dest/'proyecto'/path).read_bytes()
        assert actual == expected, ('El export alteró fuente de arte437',path)
        unchanged.append({'path':path,'sha256':hashlib.sha256(actual).hexdigest()})
assert len(unchanged) == 19
protocol['after_export_19_product_files_byte_identical_to_head'] = unchanged
persist()
run_dir = dest/'sondas-externas'
run_dir.mkdir()
env = dict(os.environ)
env['APPDATA'] = str(dest/'usuario-sondas')
for label, source, marker in [('probe437',art_probe,'SPRITES437_PCK_OK'),('probe444',strict_probe,'PAQUETE444_FINAL fallos=0')]:
    copy = run_dir/source.name
    copy.write_bytes(source.read_bytes())
    protocol[label+'_sha256'] = hashlib.sha256(copy.read_bytes()).hexdigest()
    with (dest/(label+'.log')).open('xb') as log:
        code = captured([godot,'--headless','--verbose','--main-pack',str(dest/'web/index.pck'),'-s',str(copy)],cwd=run_dir,env=env,stdout=log).returncode
    raw = (dest/(label+'.log')).read_text(encoding='utf-8',errors='replace')
    assert code == 0 and marker in raw
    assert not re.search(r'SCRIPT ERROR|Parse Error|(^|\s)ERROR:|ObjectDB instances|resources still in use|Pages in use',raw)
    protocol[label] = {'exit':0,'marker':marker,'outside_source':True}
persist()
print('EXPORT_FINAL_437_444_B_OK',flush=True)
