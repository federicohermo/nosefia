from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile

scratch = Path(__file__).parent
raiz = Path.cwd()
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
destino = scratch / ('373-web-' + commit[:8])
if destino.exists():
    raise SystemExit(f'Destino ya existe: {destino}')
proyecto = destino / 'proyecto'
web = destino / 'web'
proyecto.mkdir(parents=True)
web.mkdir()
paquete = destino / 'arbol.zip'
subprocess.run(['git', 'archive', '--format=zip', '-o', str(paquete), commit], check=True)
with zipfile.ZipFile(paquete) as z:
    z.extractall(proyecto)
paquete.unlink()
shutil.copytree(raiz / '.godot', proyecto / '.godot')
importados = (proyecto / '.godot/imported').resolve()
assert importados.is_relative_to(destino.resolve())
for recurso in importados.glob('SEPT_JUEGOS_PROTOTIPO.glb-*'):
    assert recurso.resolve().is_relative_to(importados) and recurso.is_file()
    recurso.unlink()
plantilla = raiz / 'build/templates/web_release.zip'
if not plantilla.is_file():
    plantilla = Path('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/build/templates/web_release.zip')
assert plantilla.is_file(), plantilla
(proyecto / 'build/templates').mkdir(parents=True)
(proyecto / 'build/.gdignore').write_text('', encoding='utf-8')
shutil.copyfile(plantilla, proyecto / 'build/templates/web_release.zip')
shutil.copyfile(scratch / 'bootstrap373.gd', proyecto / 'captura373.gd')
(proyecto / 'captura373.tscn').write_text('''[gd_scene format=3]
[ext_resource type="Script" path="res://captura373.gd" id="1"]
[node name="Captura" type="Node"]
script = ExtResource("1")
''', encoding='utf-8')
p = proyecto / 'project.godot'
t = p.read_text(encoding='utf-8')
t, n = re.subn(r'run/main_scene="[^"]*"', 'run/main_scene="res://captura373.tscn"', t)
assert n == 1
t, n = re.subn(r'(?m)^enabled=PackedStringArray\([^\n]*\)', 'enabled=PackedStringArray()', t)
assert n == 1
p.write_text(t, encoding='utf-8')
presets = (proyecto / 'export_presets.cfg').read_text(encoding='utf-8')
assert 'assets/' not in re.search(r'exclude_filter="([^"]*)"', presets).group(1)
godot = os.environ['GODOT_BIN']
base = [godot, '--headless', '--path', str(proyecto)]
for etiqueta, argumentos in [('importar', ['--import', '--quit']), ('exportar', ['--verbose', '--export-release', 'Web', str(web / 'index.html')])]:
    with (destino / (etiqueta + '.log')).open('wb') as log:
        subprocess.run(base + argumentos, stdout=log, stderr=subprocess.STDOUT, timeout=600, check=True)
    texto = (destino / (etiqueta + '.log')).read_text(encoding='utf-8', errors='replace')
    if re.search(r'(?m)^(SCRIPT ERROR|ERROR|WARNING):', texto):
        raise RuntimeError(texto)
for nombre in ['index.html', 'index.pck', 'index.wasm']:
    assert (web / nombre).stat().st_size > 0
with (destino / 'dialogos.log').open('wb') as log:
    subprocess.run([godot, '--headless', '--path', str(web), '--main-pack', str(web / 'index.pck'), '--script', str(raiz / '.github/scripts/verificar_dialogos_exportados.gd')], cwd=web, stdout=log, stderr=subprocess.STDOUT, timeout=600, check=True)
texto_dialogos = (destino / 'dialogos.log').read_text(encoding='utf-8', errors='replace')
assert 'Diálogos exportados: las nueve entradas de Martín y Tiago están presentes.' in texto_dialogos, texto_dialogos
if re.search(r'(?m)^(SCRIPT ERROR|ERROR|WARNING):', texto_dialogos):
    raise RuntimeError(texto_dialogos)
preset_versionado = subprocess.check_output(['git', 'show', commit + ':export_presets.cfg'])
assert (proyecto / 'export_presets.cfg').read_bytes() == preset_versionado, 'El export no uso el preset versionado exacto'
huellas = {'fixture_sha256': hashlib.sha256((scratch / 'bootstrap373.gd').read_bytes()).hexdigest(), 'commit': commit, 'fixture': 'bootstrap373.gd', 'aislamiento': 'S?lo main_scene de sonda y editor_plugins deshabilitados en copia externa; preset versionado exacto.', 'piezas': {p.name: {'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in web.iterdir() if p.is_file()}, 'preset_sha256': hashlib.sha256((proyecto / 'export_presets.cfg').read_bytes()).hexdigest()}
(destino / 'huellas.json').write_text(json.dumps(huellas, indent=2), encoding='utf-8')
(scratch / '373-web-path.txt').write_text(str(destino), encoding='utf-8')
print(destino)
print((destino / 'dialogos.log').read_text(encoding='utf-8'))
