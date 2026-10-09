import os, sys, subprocess, zipfile, shutil, re, json, hashlib
from pathlib import Path

work = Path('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/.claude/worktrees/batch-64-309-c')
root = Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-64-309/c-mediciones-f17948fe')
project = root / 'proyecto'
variant = sys.argv[1]
godot = os.environ['GODOT_BIN']
def run(args, cwd=work):
    subprocess.run(args, cwd=cwd, check=True)
def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
if not project.exists():
    root.mkdir(parents=True,exist_ok=True)
    archive = root / 'base.zip'
    run(['git','archive','--format=zip','-o',str(archive),'f17948fe'])
    with zipfile.ZipFile(archive) as z:
        z.extractall(project)
    (project/'build/templates').mkdir(parents=True)
    (project/'build/.gdignore').touch()
    shutil.copyfile(work.parents[2]/'build/templates/web_release.zip',project/'build/templates/web_release.zip')
    settings=(project/'project.godot').read_text(encoding='utf-8')
    settings=settings.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="nosefia-medicion-327-f17948fe"')
    (project/'project.godot').write_text(settings,encoding='utf-8')
    (root/'full-project.godot').write_text(settings,encoding='utf-8')
    shutil.copyfile(project/'export_presets.cfg',root/'full-export-presets.cfg')
for name in ('fondo_ventanilla.png.import',):
    if variant == 'base' or variant.endswith('-base'):
        original=subprocess.run(['git','show',f'f17948fe:assets/ui/manada/{name}'],cwd=work,capture_output=True,check=True).stdout
        (project/'assets/ui/manada'/name).write_bytes(original)
    else:
        shutil.copyfile(work/'assets/ui/manada'/name, project/'assets/ui/manada'/name)
if variant == 'propuesta' or variant.endswith('-propuesta'):
    imported = (project/'.godot/imported').resolve()
    if not imported.is_relative_to(project.resolve()):
        raise RuntimeError('caché fuera de la copia aislada')
    for resource in imported.glob('fondo_ventanilla.png-*'):
        if resource.is_file():
            resource.unlink()
            print('caché de ventanilla retirada antes de importar:',resource.name)
if variant.startswith('ui-'):
    probe=(Path(__file__).parent/'c_probe.gd').read_text(encoding='utf8')
    roots=json.loads((Path(__file__).parent/'c-recursos-literales.json').read_text(encoding='utf8'))
    probe=probe.replace('# RAICES_EXPORT', 'var paths: Array[String] = '+json.dumps(roots,ensure_ascii=False)+'\n\tfor path: String in paths:\n\t\tif load(path) == null:\n\t\t\tpush_error("Falta recurso exportado: " + path)\n\t\t\treturn\n\tprint("[recursos] '+str(len(roots))+' recursos cargados OK")')
    (project/'probe_327.gd').write_text(probe,encoding='utf8')
    (project/'probe_327.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://probe_327.gd" id="1"]\n[node name="Medicion" type="Node"]\nscript = ExtResource("1")\n',encoding='utf-8')
    settings=(root/'full-project.godot').read_text(encoding='utf-8')
    settings=re.sub(r'run/main_scene="[^"]*"','run/main_scene="res://probe_327.tscn"',settings)
    settings=re.sub(r'\[autoload\]\n.*?(?=\n\[)','',settings,flags=re.S)
    (project/'project.godot').write_text(settings,encoding='utf-8')
else:
    for name in ('probe_327.gd','probe_327.gd.uid','probe_327.tscn'):
        (project/name).unlink(missing_ok=True)
    (project/'project.godot').write_text((root/'full-project.godot').read_text(encoding='utf-8'),encoding='utf-8')
presets=(root/'full-export-presets.cfg').read_text(encoding='utf-8') if (root/'full-export-presets.cfg').exists() else subprocess.run(['git','show','f17948fe:export_presets.cfg'],cwd=work,capture_output=True,check=True).stdout.decode('utf-8')
if variant.startswith('seleccion') or (variant.startswith('ui-') and 'exclusion' not in variant):
    selected=sorted('res://'+p.relative_to(project).as_posix() for pattern in ('src/**/*.tscn','src/**/*.tres','src/**/*.gd','src/**/*.gdshader','assets/reactions/*.tres') for p in project.glob(pattern))
    if variant.startswith('ui-'):
        selected.append('res://probe_327.tscn')
    presets=presets.replace('export_filter="all_resources"','export_filter="resources"\nexport_files=PackedStringArray('+', '.join(json.dumps(p) for p in selected)+')')
    (root/f'{variant}-resources.json').write_text(json.dumps(selected,indent=2),encoding='utf-8')
    (root/f'{variant}-export-presets.cfg').write_text(presets,encoding='utf-8')
if 'exclusion' in variant:
    excluded=['assets/ui/manada/fondo.png']+[f'assets/models/SEPT_JUEGOS_PROTOTIPO_{name}' for name in ['techo1_baseColor.jpg','cielorraso_sin_luces.png','painted_plaster_wall_diff_1k.jpg','piso_baseColor.png','textura mopa.png','textura balde.png']]
    presets=re.sub(r'exclude_filter="([^"]*)"',lambda m:'exclude_filter="'+m[1]+','+','.join(excluded)+'"',presets)
    fixed=subprocess.run(['git','show','444d05db:export_presets.cfg'],cwd=work,capture_output=True,check=True).stdout.decode('utf8')
    assert presets==fixed,'preset medido distinto del changeset base 444d05db'
    (root/f'{variant}-export-presets.cfg').write_text(presets,encoding='utf-8')
(project/'export_presets.cfg').write_text(presets,encoding='utf-8')
run([godot,'--headless','--path',str(project),'--import','--quit'])
web=root/variant/'web'
web.mkdir(parents=True,exist_ok=True)
run([godot,'--headless','--path',str(project),'--export-release','Web',str(web/'index.html')])
manifest={n:{'bytes':p.stat().st_size,'sha256':digest(p)} for n in ['index.pck','index.wasm','index.js'] if (p:=web/n).exists()}
manifest['source']={'base':'444d05db' if 'exclusion' in variant else 'f17948fe','geometry':'f17948fe','candidate_head':subprocess.run(['git','rev-parse','HEAD'],cwd=work,capture_output=True,check=True).stdout.decode().strip(),'preset_sha256':digest(project/'export_presets.cfg'),'ventanilla_png_sha256':digest(project/'assets/ui/manada/fondo_ventanilla.png')}
(root/variant/'huellas.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest))
run([sys.executable,str(work/'.github/scripts/preparar_plantilla_web.py'),'--verificar-export',str(web)])
run([sys.executable,str(work/'.claude/scripts/verificar_export.py'),str(web)])
