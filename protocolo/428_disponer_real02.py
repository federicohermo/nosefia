"""Ejecuta el generador versionado: compara cuatro salidas antes de escribir byteidéntico."""
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess

raiz = Path.cwd()
salida = Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-425-435/428/disponer-real02')
salida.mkdir(exist_ok=True)
fuente = raiz/'assets/models/SEPT_JUEGOS_PROTOTIPO.blend'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
sha_fuente = sha(fuente)
spec = importlib.util.spec_from_file_location('disponer_428_real',
    raiz/'.claude/scripts/blender/disponer.py')
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
rutas = [modulo.DISPOSICION, modulo.CONTENIDO, modulo.GUIA, modulo.ESTRUCTURA]
antes = {ruta: ruta.read_bytes() for ruta in rutas}
recogidas = {}
escribir = modulo.escribir
modulo.escribir = lambda ruta, texto: recogidas.__setitem__(ruta, texto.encode('utf-8'))
pasos = []
for numero in [1, 2]:
    recogidas.clear()
    modulo.principal()
    assert set(recogidas) == set(rutas), 'Debe calcular las cuatro salidas reales'
    diferencias = []
    for ruta in rutas:
        if recogidas[ruta] != antes[ruta]:
            diferencias.append(str(ruta.relative_to(raiz)))
            (salida/(f'diferente-{numero}-'+ruta.name)).write_bytes(recogidas[ruta])
    pasos.append({'paso': numero, 'diferencias': diferencias,
        'archivos': {str(r.relative_to(raiz)): {
            'antes_sha256': hashlib.sha256(antes[r]).hexdigest(),
            'calculado_sha256': hashlib.sha256(recogidas[r]).hexdigest(),
            'bytes': len(recogidas[r]), 'byteidentico': recogidas[r] == antes[r]
        } for r in rutas}})
    if diferencias:
        break
    for ruta in rutas:
        escribir(ruta, recogidas[ruta].decode('utf-8'))
        assert ruta.read_bytes() == antes[ruta]
informe = {'head': subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
    'blend_sha256_antes': sha_fuente, 'blend_sha256_despues': sha(fuente),
    'script_sha256': sha(raiz/'.claude/scripts/blender/disponer.py'), 'pasos': pasos,
    'limite': 'No exporta arte; el generador ejecutado es el versionado y evalúa bpy real.'}
(salida/'auditoria.json').write_bytes(json.dumps(informe,indent=2,ensure_ascii=False).encode('utf-8'))
assert sha(fuente) == sha_fuente
assert len(pasos)==2 and all(not p['diferencias'] for p in pasos), 'Salidas distintas conservadas'
print('428_DISPONER_REAL_DOS_PASOS_CUATRO_SALIDAS_BYTEIDENTICAS')
