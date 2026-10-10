from pathlib import Path
import hashlib
import json
import os
import re
import subprocess

scratch=Path(__file__).parent
raiz=Path.cwd()
commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
destino=scratch/('373-web-'+commit[:8])
proyecto=destino/'proyecto'
web=destino/'web'
godot=os.environ['GODOT_BIN']
for log in [destino/'importar.log']:
    texto=log.read_text(encoding='utf-8',errors='replace')
    assert not re.search(r'(?m)^(SCRIPT ERROR|ERROR|WARNING):',texto),str(log)
with (destino/'exportar-reintento.log').open('wb') as log:
    subprocess.run([godot,'--headless','--path',str(proyecto),'--verbose','--export-release','Web',str(web/'index.html')],stdout=log,stderr=subprocess.STDOUT,timeout=600,check=True)
texto=(destino/'exportar-reintento.log').read_text(encoding='utf-8',errors='replace')
assert not re.search(r'(?m)^(SCRIPT ERROR|ERROR|WARNING):',texto),texto
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
huellas = {'fixture_sha256': hashlib.sha256((scratch / 'bootstrap373.gd').read_bytes()).hexdigest(), 'commit': commit, 'fixture': 'bootstrap373.gd', 'aislamiento': 'Sólo editor_plugins deshabilitados en copia externa; main_scene de sonda; preset versionado sin cambios.', 'piezas': {p.name: {'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in web.iterdir() if p.is_file()}, 'importacion_validada': 'importar.log', 'exportacion_validada': 'exportar-reintento.log', 'preset_sha256': hashlib.sha256((proyecto / 'export_presets.cfg').read_bytes()).hexdigest()}
(destino / 'huellas.json').write_text(json.dumps(huellas, indent=2), encoding='utf-8')
(scratch / '373-web-path.txt').write_text(str(destino), encoding='utf-8')
print(destino)
print((destino / 'dialogos.log').read_text(encoding='utf-8'))
