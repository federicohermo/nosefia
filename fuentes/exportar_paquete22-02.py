"""Export original del HEAD commiteado; copia externa y preset versionado sin cambiar.

Uso: python exportar_paquete431.py <destino-nuevo> <plantilla.zip> <manifiesto.json>
Conserva import/export crudos y hashes. El recorrido y chequeo main-pack son pasos separados.
"""
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

root=Path.cwd()
if len(sys.argv)!=4: raise SystemExit('Exige destino, ZIP y manifiesto explícitos')
template=Path(sys.argv[2]).resolve()
template_manifest=Path(sys.argv[3]).resolve()
if not template.is_file() or not template_manifest.is_file():
    raise SystemExit('Falta la pareja explícita de plantilla Web')
dest=Path(sys.argv[1]).resolve()
if dest.exists(): raise SystemExit(f'El destino debe ser nuevo: {dest}')
if dest.is_relative_to(root): raise SystemExit('El export debe vivir fuera del worktree')
project=dest/'proyecto'
web=dest/'web'
project.mkdir(parents=True)
web.mkdir()
commit='fb4236e69c752e6879bb338b80e734e16b211b41'
head_orquestador=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
archive=dest/'arbol.zip'
subprocess.run(['git','archive','--format=zip','-o',str(archive),commit],check=True)
with zipfile.ZipFile(archive) as z: z.extractall(project)
archive.unlink()
target=project/'build/templates/web_release.zip'
target.parent.mkdir(parents=True)
(project/'build/.gdignore').write_text('',encoding='utf-8')
shutil.copy2(template,target)
shutil.copy2(template_manifest,target.with_suffix('.manifiesto.json'))
cache_fijada=Path('D:/nosefia-carril-C-429-444/431-export-03/proyecto/.godot')
if cache_fijada.is_dir(): shutil.copytree(cache_fijada,project/'.godot')
configuracion_original={name:(project/name).read_bytes() for name in ['project.godot','export_presets.cfg']}
preparador=project/'.github/scripts/preparar_plantilla_web.py'
with (dest/'plantilla-comprobar.log').open('wb') as log:
    code=subprocess.run([sys.executable,str(preparador),'--comprobar'],cwd=project,stdout=log,stderr=subprocess.STDOUT).returncode
if code: raise SystemExit('La guardia previa rechaza la plantilla; no importar ni exportar')
sys.path.insert(0, str(project / '.claude/scripts'))
from lib.godot import resolver
godot, procedencia = resolver(dict(os.environ))
if not godot: raise SystemExit('Godot no declarado')
print('GODOT22', procedencia, godot, flush=True)
control=None
def core_hashes():
    return {name:hashlib.sha256((web/name).read_bytes()).hexdigest() for name in ['index.html','index.js','index.pck','index.wasm']}

for label,args in [
    ('importar',['--import','--quit']),
    ('exportar',['--export-release','Web',str(web/'index.html')]),
]:
    with (dest/f'{label}.log').open('wb') as log:
        code=subprocess.run([godot,'--headless','--path',str(project),*args],stdout=log,stderr=subprocess.STDOUT).returncode
    if code: raise SystemExit(f'{label} salió{code}; leer{dest}/{label}.log')
    raw=(dest/f'{label}.log').read_text(encoding='utf-8',errors='replace')
    limpio=re.sub(r'\x1b\[[0-9;]*[A-Za-z]','',raw)
    if re.search(r'SCRIPT ERROR|Parse Error|(^|\s)ERROR:',limpio):
        errores=[line.strip() for line in limpio.splitlines() if line.startswith('ERROR:')]
        avisos=[line.strip() for line in limpio.splitlines() if line.startswith('WARNING:')]
        retencion=(label=='exportar' and errores and not re.search(r'SCRIPT ERROR|Parse Error',limpio)
            and any('resources still in use at exit' in line for line in errores)
            and all(re.fullmatch(r'ERROR: \d+ resources still in use at exit .*|ERROR: Pages in use exist at exit in PagedAllocator: .*',line) for line in errores)
            and all(re.fullmatch(r'WARNING: \d+ ObjectDB instances were leaked at exit .*',line) for line in avisos))
        if not retencion:
            raise SystemExit(f'{label} imprimió errores; leer {dest}/{label}.log')
        antes=core_hashes()
        with (dest/'exportar-control-verbose.log').open('wb') as log:
            code=subprocess.run([godot,'--headless','--path',str(project),'--verbose',*args],stdout=log,stderr=subprocess.STDOUT).returncode
        limpio=(dest/'exportar-control-verbose.log').read_text(encoding='utf-8',errors='replace')
        if code or re.search(r'SCRIPT ERROR|Parse Error|(^|\s)(ERROR:|WARNING:)|leaked|resources still in use',limpio):
            raise SystemExit('El control sin cambios también falló; leer exportar-control-verbose.log')
        if antes!=core_hashes():
            raise SystemExit('El control cambió algún artefacto; no se acepta como el mismo export')
        control={'primero':'exportar.log','segundo':'exportar-control-verbose.log','artefactos_identicos':True}
        print('EXPORT22_CONTROL_LIMPIO mismos proyecto, preset, plugins y cuatro artefactos')
for name in ['project.godot','export_presets.cfg']:
    if configuracion_original[name]!=(project/name).read_bytes():
        raise SystemExit(f'El motor alteró {name} de la copia')
with (dest/'plantilla-verificar-export.log').open('wb') as log:
    code=subprocess.run([sys.executable,str(preparador),'--verificar-export',str(web)],cwd=project,stdout=log,stderr=subprocess.STDOUT).returncode
if code: raise SystemExit('La guardia posterior rechaza el motor exportado')
files={}
for name in ['index.html','index.js','index.pck','index.wasm']:
    path=web/name
    if not path.is_file() or not path.stat().st_size: raise SystemExit(f'Falta{path}')
    files[name]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
record={'commit':commit,'head_del_orquestador':head_orquestador,'preset_sha256':hashlib.sha256(configuracion_original['export_presets.cfg']).hexdigest(),
    'proyecto_sha256':hashlib.sha256(configuracion_original['project.godot']).hexdigest(),
    'plantilla_sha256':hashlib.sha256(template.read_bytes()).hexdigest(),'archivos':files,
    'plantilla_manifest_sha256':hashlib.sha256(template_manifest.read_bytes()).hexdigest(),
    'guardias':{'comprobar':0,'verificar_export':0},
    'control_exportacion':control,'configuracion_identica':True}
(dest/'huellas.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(record,ensure_ascii=False,indent=2))
print('EXPORT22_FINAL')
