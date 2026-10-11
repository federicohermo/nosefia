"""Cinco copias externas: mismo producto y diferente conjunto descubierto de tests."""

from pathlib import Path
import json
import shutil

s = Path(__file__).parent
w = Path.cwd()
raiz = s / '374-variantes-discovery'
nuevas = [
    'dominio/empleo/instrucciones_del_jefe_test.gd',
    'ui/interrupciones/pantalla_de_instrucciones_test.gd',
    'escenas/instrucciones_en_el_almacen_test.gd',
]
variantes = [('control', nuevas), ('ninguna', []), ('dominio', nuevas[:1]),
             ('ui', nuevas[1:2]), ('escena', nuevas[2:])]
for nombre, conservar in variantes:
    destino = raiz / nombre
    destino.mkdir(parents=True)
    for carpeta in ['src', 'addons']:
        shutil.copytree(w / carpeta, destino / carpeta)
    excluidas = {str(w / 'test' / ruta) for ruta in nuevas if ruta not in conservar}

    def ignorar(directorio, archivos):
        return [archivo for archivo in archivos if str(Path(directorio) / archivo) in excluidas]

    shutil.copytree(w / 'test', destino / 'test', ignore=ignorar)
    for archivo in ['project.godot', 'default_bus_layout.tres']:
        shutil.copy2(w / archivo, destino / archivo)
    (destino / '.godot').mkdir()
    for archivo in ['global_script_class_cache.cfg', 'uid_cache.bin']:
        shutil.copy2(w / '.godot' / archivo, destino / '.godot' / archivo)
    for p in (w / 'src').rglob('*'):
        if p.is_file():
            assert p.read_bytes() == (destino / p.relative_to(w)).read_bytes()
    print(nombre, len(list((destino / 'test').rglob('*_test.gd'))), flush=True)
(s / '374-variantes-preparadas.json').write_text(json.dumps({
    'root': str(raiz), 'variantes': variantes,
    'diferencia': 'Exclusivamente presencia de las tres suites nuevas; src idéntico en las cinco.',
}, ensure_ascii=False, indent=2), encoding='utf-8')
