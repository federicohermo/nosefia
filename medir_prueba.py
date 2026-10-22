import hashlib
import json
from pathlib import Path
import sys

import bpy

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ / '.claude/scripts/blender'))
import disponer
import disponer_prueba

argumentos = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
destino = Path(argumentos[0]) if argumentos else Path(__file__).with_suffix('.json')
fuente = Path(bpy.data.filepath)
huella = hashlib.sha256(fuente.read_bytes()).hexdigest()
disponer_prueba.generar()
tandas = {}
for clave, copias in sorted(disponer.tandas_del_blend().items()):
    unidades = []
    for copia in copias:
        puntos = [copia.matrix_world @ v.co for v in copia.data.vertices]
        unidades.append({
            'nombre': copia.name,
            'producto': str(copia['producto']),
            'fila': str(copia['fila']),
            'orden': int(copia['orden']),
            'fija': bool(copia['fija']),
            'min': [min(p[i] for p in puntos) for i in range(3)],
            'max': [max(p[i] for p in puntos) for i in range(3)],
            'matriz': [list(fila) for fila in copia.matrix_world],
        })
    tandas[clave] = {
        'producto': unidades[0]['producto'],
        'cantidad': len(unidades),
        'min': [min(u['min'][i] for u in unidades) for i in range(3)],
        'max': [max(u['max'][i] for u in unidades) for i in range(3)],
        'unidades': unidades,
    }

esquinas = []
for mueble in ('A', 'B'):
    for nivel in range(4):
        for cabecera in ('norte', 'sur'):
            for lateral in ('este', 'oeste'):
                parejas = []
                for clave_a, tanda_a in tandas.items():
                    if not clave_a.startswith(f'{mueble}.{cabecera}.{nivel}/'):
                        continue
                    for clave_b, tanda_b in tandas.items():
                        if not clave_b.startswith(f'{mueble}.{lateral}.{nivel}/'):
                            continue
                        for a in tanda_a['unidades']:
                            for b in tanda_b['unidades']:
                                solapes = [min(a['max'][i], b['max'][i])
                                           - max(a['min'][i], b['min'][i]) for i in (0, 2)]
                                if min(solapes) <= 1e-6:
                                    continue
                                hueco = (a['min'][1] - b['max'][1] if cabecera == 'norte'
                                         else b['min'][1] - a['max'][1])
                                parejas.append({
                                    'cabecera': clave_a,
                                    'lateral': clave_b,
                                    'unidad_cabecera': a['nombre'],
                                    'unidad_lateral': b['nombre'],
                                    'producto_cabecera': a['producto'],
                                    'producto_lateral': b['producto'],
                                    'hueco_y': hueco,
                                    'solape_xz': solapes,
                                })
                parejas.sort(key=lambda p: p['hueco_y'])
                esquinas.append({
                    'mueble': mueble,
                    'nivel': nivel,
                    'cabecera': cabecera,
                    'lateral': lateral,
                    'minimo': parejas[0] if parejas else None,
                    'parejas': parejas,
                })

informe = {
    'fuente': str(fuente),
    'sha256_fuente': huella,
    'blender': bpy.app.version_string,
    'tandas': tandas,
    'esquinas': esquinas,
}
assert hashlib.sha256(fuente.read_bytes()).hexdigest() == huella
destino.write_text(json.dumps(informe, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'SNAPSHOT {destino} tandas={len(tandas)} unidades={sum(t["cantidad"] for t in tandas.values())}')
for esquina in esquinas:
    minimo = esquina['minimo']
    print('ESQUINA', esquina['mueble'], esquina['nivel'], esquina['cabecera'],
          esquina['lateral'], round(minimo['hueco_y'], 6) if minimo else None,
          minimo['producto_cabecera'] if minimo else None,
          minimo['producto_lateral'] if minimo else None)
