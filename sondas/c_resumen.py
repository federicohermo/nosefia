from pathlib import Path
from PIL import Image, ImageChops, ImageStat
import json, hashlib
scratch=Path(__file__).parent
root=Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-64-309/c-mediciones-f17948fe')
work=Path('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/.claude/worktrees/batch-64-309-c')
def load(p):
    return json.loads(p.read_text(encoding='utf-8'))
def compare(p,q):
    a,b=Image.open(p).convert('RGB'),Image.open(q).convert('RGB')
    assert a.size==b.size==(1920,1080)
    delta=ImageChops.difference(a,b)
    channels=delta.histogram()
    hist=[sum(channels[i+offset] for offset in (0,256,512)) for i in range(256)]
    total=sum(hist)
    acc=0
    for p99,n in enumerate(hist):
        acc+=n
        if acc>=total*.99:
            break
    return {'dimensions':a.size,'mae_rgb_255':sum(ImageStat.Stat(delta).mean)/3,'p99_difference_channel_255':p99,'max_difference_channel_255':max(v[1] for v in delta.getextrema()),'pixels_equal':a.tobytes()==b.tobytes()}
base=load(root/'exclusion-base/memoria.json')
candidate=load(root/'exclusion-propuesta/memoria.json')
assert all(d['fases']['almacen']['cobertura_completa'] for d in (base,candidate))
dxt=[t for t in candidate['fases']['almacen']['texturas'] if t['ancho']==1920 and t['alto']==1080 and 'DXT1' in t['formato']]
assert len(dxt)==1 and dxt[0]['mips']==1 and dxt[0]['bytes_estimados']==1036800
assert base['fases']['almacen']['cantidad']==candidate['fases']['almacen']['cantidad']
assert base['fases']['almacen']['bytes_estimados']-candidate['fases']['almacen']['bytes_estimados']==7257600
preserved=load(scratch/'c-preservados-base.json')
for file,digest in preserved.items():
    assert hashlib.sha256((work/file).read_bytes()).hexdigest()==digest,file
captures={name:compare(root/'ui-exclusion-base/capturas'/f'{name}.png',root/'ui-exclusion-propuesta/capturas'/f'{name}.png') for name in ('inicio','computadora','ventanilla')}
assert captures['inicio']['pixels_equal'] and captures['computadora']['pixels_equal']
historical=Path('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/reports/optimizacion-shading/segunda-revision/resultado-ui-origen')
historical_compare={v:compare(root/f'ui-exclusion-{v}/capturas/ventanilla.png',historical/f'ui_fondo_ventanilla_{old}.png') for v,old in [('base','base'),('propuesta','dxt')]}
summary={'base_commit':'f17948fe','preset':'all_resources + exclusion de siete archivos sin referencias, changeset independiente','preserved_sha256':preserved,'all_preserved':True,'dxt1_ventanilla':dxt[0],'base':{'conditions':base['condiciones'],'textures':base['fases']['almacen']['cantidad'],'logical_bytes':base['fases']['almacen']['bytes_estimados'],'pck':base['export_en_disco']['pck']},'propuesta':{'conditions':candidate['condiciones'],'textures':candidate['fases']['almacen']['cantidad'],'logical_bytes':candidate['fases']['almacen']['bytes_estimados'],'pck':candidate['export_en_disco']['pck']},'logical_savings_bytes':7257600,'pck_savings_bytes':base['export_en_disco']['pck']['bytes']-candidate['export_en_disco']['pck']['bytes'],'capture_comparisons':captures,'historical_capture_comparisons':historical_compare,'ui_runs':{v:load(root/f'ui-exclusion-{v}/capturas/ui.json') for v in ('base','propuesta')},'ui_runs_1280':{v:load(root/f'ui-exclusion-{v}/capturas-1280/ui.json') for v in ('base','propuesta')}}
summary['base_commit']='444d05db'
summary['geometry_commit']='f17948fe'
(root/'resumen.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps({k:summary[k] for k in ('logical_savings_bytes','pck_savings_bytes','capture_comparisons','historical_capture_comparisons')},indent=2))
