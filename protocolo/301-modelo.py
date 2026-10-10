import bpy
import hashlib
import json
import sys
from pathlib import Path
from mathutils import Vector

scratch = Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010')
args = sys.argv[sys.argv.index('--')+1:]
modo = args[0]

def resumen():
    objetos = {}
    for o in bpy.data.objects:
        datos = dict(tipo=o.type, padre=o.parent.name if o.parent else None,
                     transform=[list(f) for f in o.matrix_local],
                     mundo=[list(f) for f in o.matrix_world],
                     materiales=[s.material.name if s.material else None for s in o.material_slots])
        if o.type == 'MESH':
            h = hashlib.sha256()
            for v in o.data.vertices:
                h.update(str(tuple(v.co)).encode())
            for p in o.data.polygons:
                h.update(str((tuple(p.vertices),p.material_index)).encode())
            for uv in o.data.uv_layers:
                for dato in uv.data:
                    h.update(str(tuple(dato.uv)).encode())
            datos['malla'] = h.hexdigest()
            puntos = [o.matrix_world @ Vector(c) for c in o.bound_box]
            datos['min'] = [min(p[i] for p in puntos) for i in range(3)]
            datos['max'] = [max(p[i] for p in puntos) for i in range(3)]
        objetos[o.name] = datos
    return objetos

if modo == 'candidato':
    antes = resumen()
    (scratch/'301-blend-base.json').write_text(json.dumps(antes,indent=2),encoding='utf8')
    candidatos = [o for o in bpy.data.objects if o.name.startswith('tachitobasura')]
    print('TACHOS', [(o.name,list(o.location)) for o in candidatos])
    t = bpy.data.objects.get('tachitobasura-col')
    assert t is not None
    t.location.x -= 0.66
    t.location.y -= 0.45
    bpy.context.view_layer.update()
    despues = resumen()
    (scratch/'301-blend-candidato.json').write_text(json.dumps(despues,indent=2),encoding='utf8')
    destino = scratch/'301-modelo-externo.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(destino),check_existing=False)
    print('CANDIDATO', json.dumps(despues[t.name]))
elif modo == 'acomodar':
    import runpy
    antes = resumen()
    runpy.run_path(args[1],run_name='__main__')
    despues = resumen()
    assert antes['tachitobasura-col'] == despues['tachitobasura-col'], 'acomodador devolvio tacho'
    (scratch/'301-acomodador.json').write_text(json.dumps(dict(tacho_preservado=True,antes=antes['tachitobasura-col'],despues=despues['tachitobasura-col']),indent=2),encoding='utf8')
elif modo == 'aplicar':
    antes = resumen()
    t=bpy.data.objects['tachitobasura-col']
    t.location.x -= 0.66
    t.location.y -= 0.45
    bpy.context.view_layer.update()
    despues=resumen()
    assert set(antes)==set(despues)
    for nombre in antes:
        if nombre != t.name:
            assert antes[nombre]==despues[nombre], nombre
    assert antes[t.name]['malla']==despues[t.name]['malla']
    assert antes[t.name]['materiales']==despues[t.name]['materiales']
    assert antes[t.name]['transform'][2]==despues[t.name]['transform'][2]
    (scratch/'301-blend-final.json').write_text(json.dumps(despues,indent=2),encoding='utf8')
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,check_existing=False)
    print('SOLO_TACHO_XY_CAMBIO',len(antes))
