import json, math, shutil
from pathlib import Path

raiz = Path.cwd()
scratch = Path(__file__).parent
medidas = json.loads((scratch/'volumen-01/medidas.json').read_text(encoding='utf8'))
assert len(medidas['faltan'])==5
def paredes(puntos):
    puntos=list(dict.fromkeys(tuple(round(v,8) for v in p) for p in puntos))
    eje=next(i for i in range(3) if len({round(p[i],5) for p in puntos})==3)
    grupos=[[p for p in puntos if abs(p[eje]-n)<1e-5] for n in sorted({round(p[eje],5) for p in puntos})]
    frente=next(g for g in grupos if len(g)==8)
    anillos=sorted((g for g in grupos if len(g)==4),key=lambda g:abs(g[0][eje]-frente[0][eje]),reverse=True)
    centro=[sum(p[k] for p in frente)/8 for k in range(3)]
    frente.sort(key=lambda p:sum((p[k]-centro[k])**2 for k in range(3)))
    anillos.extend([frente[:4],frente[4:]])
    u,v=(eje+1)%3,(eje+2)%3
    for g in anillos:g.sort(key=lambda p:math.atan2(p[v]-centro[v],p[u]-centro[u]))
    return [anillos[0]+anillos[1]]+[[p for g in anillos for p in (g[k],g[(k+1)%4])] for k in range(4)]

propuesta={}
originales=json.loads((scratch/'geometria-offline.json').read_text(encoding='utf8'))
for i,dato in enumerate(medidas['medidas']):
    ruta=dato['ruta'].removeprefix('Estructura/')
    piezas=originales[i]['piezas']
    formas=[]
    for pieza in piezas:
        ps=list(dict.fromkeys(tuple(p) for p in pieza['puntos']))
        formas.extend(paredes(ps) if ruta=='tableroluz' else [ps])
    propuesta[ruta]=formas
(scratch/'volumenes-propuestos.json').write_text(json.dumps(propuesta,indent=2),encoding='utf8')

# La corrida completa previa ya conserva el rojo funcional de ambos oráculos.
for nombre,destino in [('regresion-volumen.gd','test/escenas/volumen_de_los_solidos_test.gd'),('regresion-gi.gd','test/escenas/pistas_de_la_segunda_jornada_test.gd')]:
    p=raiz/destino
    with p.open('a',encoding='utf8',newline='\n') as f:f.write('\n'+(scratch/nombre).read_text(encoding='utf8'))
shutil.copyfile(scratch/'generar_volumenes_para_colilla.gd',raiz/'.github/scripts/generar_volumenes_para_colilla.gd')
(raiz/'.github/scripts/generar_volumenes_para_colilla.gd.uid').write_text('uid://c2m22volumenes\n',encoding='utf8')
generador=raiz/'assets/props/colilla/generar_colilla.py'
s=generador.read_text(encoding='utf8');assert "'gi_mode = 1'" not in s
s=s.replace("f'mesh = SubResource(\"malla_{nombre}\")', '',","f'mesh = SubResource(\"malla_{nombre}\")', 'gi_mode = 1', '',")
generador.write_text(s,encoding='utf8',newline='\n')
import runpy
runpy.run_path(str(generador),run_name='__main__')
archivo=raiz/'src/escenas/puestos/estructura_del_almacen.tscn'
s=archivo.read_text(encoding='utf8');assert 'VolumenColilla' not in s
recursos=[];nodos=[]
for i,(ruta,formas) in enumerate(propuesta.items()):
    for j,ps in enumerate(formas):
        id=f'colilla_volumen_{i}_{j}'
        valores=', '.join(f'{v:.9f}' for p in ps for v in p)
        recursos.append(f'[sub_resource type="ConvexPolygonShape3D" id="{id}"]\nmargin = 0.001\npoints = PackedVector3Array({valores})\n')
        nodos.append(f'[node name="VolumenColilla{j}" type="CollisionShape3D" parent="{ruta}/StaticBody3D"]\nshape = SubResource("{id}")\n')
pos=s.index('[node ')
s=s[:pos]+'\n'.join(recursos)+'\n'+s[pos:]+'\n'+'\n'.join(nodos)
archivo.write_text(s,encoding='utf8',newline='\n')
print('Aplicadas cinco mallas,',sum(map(len,propuesta.values())),'sólidos interiores; GI dinámico y regresiones.')
