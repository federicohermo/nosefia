from pathlib import Path
import hashlib
import importlib.util
import io
import json
import sys
import unittest

base = Path(__file__).parent
wt = Path('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/.claude/worktrees/batch-428-apoyos')
sys.path.insert(0,str(wt/'.claude/scripts'))
import lib.gondola
from lib.reparto import PRODUCTOS
from lib.apoyos_del_modelo import actualizar_apoyos, mallas_del_glb

resultados = []
for estado, archivo in [('rojo','gondola-rojo.py'),('verde','gondola.py')]:
    spec = importlib.util.spec_from_file_location('lib.gondola',base/archivo)
    modulo = importlib.util.module_from_spec(spec)
    sys.modules['lib.gondola'] = modulo
    spec.loader.exec_module(modulo)
    lib.gondola = modulo
    spec_test = importlib.util.spec_from_file_location('test_gondola_'+estado,base/'test_gondola.py')
    pruebas = importlib.util.module_from_spec(spec_test)
    sys.modules[spec_test.name] = pruebas
    spec_test.loader.exec_module(pruebas)
    stream = io.StringIO()
    resultado = unittest.TextTestRunner(stream=stream,verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromModule(pruebas))
    (base/(estado+'.log')).write_bytes(stream.getvalue().encode('utf-8'))
    resultados.append({'estado':estado,'casos':resultado.testsRun,'errores':len(resultado.errors),
        'fallos':len(resultado.failures)})
    if estado=='rojo':
        assert len(resultado.failures)==2 and not resultado.errors
    else:
        assert resultado.wasSuccessful()

texto = (wt/'src/escenas/puestos/estructura_del_almacen.tscn').read_text(encoding='utf-8')
identidades = [modulo.nombre_en_godot(p.objeto) for p in PRODUCTOS]
rutas = []
for bloque in texto.split('\n\n'):
    cabecera = bloque.split('\n',1)[0]
    if not cabecera.startswith('[node '):
        continue
    import re
    nombre = re.search(r'name="([^"]+)"',cabecera)
    padre = re.search(r'parent="([^"]+)"',cabecera)
    if nombre and padre and nombre[1] in identidades and '\nvisible = false' in bloque:
        rutas.append(nombre[1] if padre[1]=='.' else padre[1]+'/'+nombre[1])
assert len(rutas)==32
nuevo = modulo.apagar_las_unidades(texto,rutas,identidades)
assert modulo.apagar_las_unidades(nuevo,rutas,identidades)==nuevo
assert nuevo.rstrip('\n') == texto.rstrip('\n')
mallas = mallas_del_glb((wt/'assets/models/SEPT_JUEGOS_PROTOTIPO.glb').read_bytes(),
                       ['bano_riel_frontal','gondolanueva','gondolanueva2'])
final = actualizar_apoyos(nuevo,mallas)
assert final == texto
informe = {'prototipo_externo':True,'tests':resultados,'identidades':identidades,
    'rutas_activas':rutas,'estructura_utf8_sha256':hashlib.sha256(texto.encode('utf-8')).hexdigest(),
    'estructura_byteidentica_tras_apagado_y_compuestos':True,
    'apagado_normaliza_salto_final_como_legacy':True,
    'limite':'No sustituye TDD versionado, revisión merge-tree ni ejecución bpy formal.'}
(base/'auditoria-pura.json').write_bytes(json.dumps(informe,indent=2,ensure_ascii=False).encode('utf-8'))
print(json.dumps(resultados), 'estructura32unidades+lector byteidéntica')
