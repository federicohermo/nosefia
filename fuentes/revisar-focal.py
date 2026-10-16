"""Lee crudos/XML originales y compara retenciones con el focal base verbose."""
from collections import Counter
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET


def leer(carpeta: Path):
    texto = (carpeta / 'tests.log').read_text(encoding='utf-8', errors='replace')
    texto = re.sub(r'\x1b\[[0-9;]*[A-Za-z]', '', texto)
    xml = ET.parse(carpeta / 'results.xml').getroot()
    casos = {}
    for suite in xml.findall('.//testsuite'):
        for caso in suite.findall('testcase'):
            casos[(suite.attrib.get('name'), caso.attrib.get('name'))] = {
                'fallos': len(caso.findall('failure')), 'errores': len(caso.findall('error')),
                'skips': len(caso.findall('skipped')),
            }
    return texto, xml, casos


def retenciones(texto):
    recursos = re.findall(r'^Resource still in use: (.+?) \(([^)]+)\)', texto, re.M)
    return {
        'clases': dict(Counter(re.findall(r'^Leaked instance: ([^:\s]+):', texto, re.M))),
        'rutas': sorted(ruta for ruta, _clase in recursos),
        'recursos': [{'ruta': ruta, 'clase': clase} for ruta, clase in sorted(recursos)],
        'lineas_recursos': [l for l in texto.splitlines() if l.startswith('Resource still in use:')],
        'paginas': sorted(set(re.findall(r'Pages in use exist at exit in PagedAllocator: (\S+)', texto))),
        'avisos': [l for l in texto.splitlines() if re.search(r'ObjectDB instances|resources still in use|Pages in use|unclaimed string names', l)],
    }


carpeta = Path(sys.argv[1]).resolve()
texto, xml, casos = leer(carpeta)
base = Path('C:/Users/fede_/AppData/Local/Temp/nosefia-watch-429-444/base-focal-02')
base_texto = (base / 'tests.log').read_text(encoding='utf-8', errors='replace')
actual = retenciones(texto)
anterior = retenciones(base_texto)
rojo = Path(__file__).parent / 'dominio-rojo-01'
_, _, casos_rojos = leer(rojo)
resultado = {
    'carpeta': str(carpeta), 'codigo': (carpeta / 'exit-code.txt').read_text().strip(),
    'xml': xml.attrib, 'suites': len(xml.findall('.//testsuite')), 'casos': len(casos),
    'fallos': len(xml.findall('.//failure')), 'errores': len(xml.findall('.//error')),
    'skips': len(xml.findall('.//skipped')),
    'script_parse': [l for l in texto.splitlines() if re.search(r'SCRIPT ERROR|Parse Error', l)],
    'diagnosticos': [l for l in texto.splitlines() if re.search(r'(^|\s)(ERROR:|WARNING:)', l)],
    'conteos': [l for l in texto.splitlines() if 'Executed test suites' in l],
    'casos_previos': {str(k): casos.get(k, {'ausente': True}) for k in casos_rojos},
    'todos_los_17_previos_verdes': all(k in casos and not any(casos[k].values()) for k in casos_rojos),
    'retenciones': actual,
    'base_retenciones': anterior,
    'delta_rutas_agregadas': sorted(set(actual['rutas']) - set(anterior['rutas'])),
    'delta_rutas_retiradas': sorted(set(anterior['rutas']) - set(actual['rutas'])),
    'rutas_y_cantidades_iguales': actual['rutas'] == anterior['rutas'],
    'clases_iguales': actual['clases'] == anterior['clases'],
    'paginas_iguales': actual['paginas'] == anterior['paginas'],
    'limite': 'Se comparan nombres, rutas completas y páginas. Los IDs de instancias son efímeros. No se atribuyen instancias sin ruta individualmente. El focal no certifica una completa sin retenciones.',
}
(carpeta / 'auditoria.json').write_text(json.dumps(resultado, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({k:v for k,v in resultado.items() if k not in ['retenciones','base_retenciones']}, ensure_ascii=True, indent=2))
print('RECURSOS', len(actual['rutas']), 'CLASES', actual['clases'])
