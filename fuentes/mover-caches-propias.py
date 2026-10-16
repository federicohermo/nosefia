import datetime,hashlib,json,shutil
from pathlib import Path

scratch=Path(__file__).parent.parent
raices=[scratch/'carril-C-431/evidencia-01',scratch/'carril-C-431/evidencia-03',scratch/'carril-C-22/fisico-rojo-03']
destino=Path('D:/nosefia-carril-C-429-444/caches-inactivas-01').resolve()
assert destino==Path('D:/nosefia-carril-C-429-444/caches-inactivas-01').resolve()
destino.mkdir(exist_ok=False)
def hashes(p):return {x.relative_to(p).as_posix():{'bytes':x.stat().st_size,'sha256':hashlib.sha256(x.read_bytes()).hexdigest()} for x in p.rglob('*') if x.is_file()}
registro={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'alcance':'Sólo shader_cache propias inactivas autorizadas por raíz; crudos y PNG conservan sus rutas.','movimientos':[]}
for raiz in raices:
    raiz=raiz.resolve()
    for origen in list(raiz.rglob('shader_cache')):
        origen=origen.resolve()
        assert origen.name=='shader_cache' and origen.is_relative_to(raiz)
        copia=(destino/origen.relative_to(scratch.resolve())).resolve()
        assert copia.is_relative_to(destino) and not copia.exists()
        antes=hashes(origen)
        copia.parent.mkdir(parents=True,exist_ok=True)
        shutil.move(str(origen),str(copia))
        despues=hashes(copia)
        assert antes==despues and not origen.exists()
        registro['movimientos'].append({'origen':str(origen),'destino':str(copia),'archivos':antes,'bytes':sum(x['bytes'] for x in antes.values()),'identicos':True})
        (destino/'registro.json').write_text(json.dumps(registro,ensure_ascii=False,indent=2),encoding='utf8')
publicable=Path('D:/nosefia-carril-C-429-444/22-publicable-01/fisico-rojo-03/usuario-aislado').resolve()
assert publicable.is_relative_to(Path('D:/nosefia-carril-C-429-444/22-publicable-01').resolve())
retirada=destino/'copia-publicable-runtime'
if publicable.exists():
    antes=hashes(publicable);shutil.move(str(publicable),str(retirada));assert hashes(retirada)==antes
    registro['publicacion_runtime_retirada']={'origen':str(publicable),'destino':str(retirada),'archivos':antes,'identicos':True,'limite':'El primer commit e24a11 conserva historial; el correctivo retira sólo runtime, sin crudos.'}
registro['bytes_liberados_c']=sum(x['bytes'] for x in registro['movimientos'])
(destino/'registro.json').write_text(json.dumps(registro,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'movimientos':len(registro['movimientos']),'bytes_liberados_c':registro['bytes_liberados_c'],'registro':str(destino/'registro.json')},indent=2))
