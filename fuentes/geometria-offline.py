import json, struct
from pathlib import Path
import numpy as np
from scipy.spatial import ConvexHull

raiz = Path(r'D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/.claude/worktrees/batch-429-444-investigacion')
blob = (raiz / 'assets/models/SEPT_JUEGOS_PROTOTIPO.glb').read_bytes()
tam, tipo = struct.unpack_from('<II', blob, 12)
g = json.loads(blob[20:20+tam])
inicio = 20+tam
binario = blob[inicio+8:]
tipos = {5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'}
dim = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
def acc(i):
    a=g['accessors'][i]; v=g['bufferViews'][a['bufferView']]
    dtype=np.dtype(tipos[a['componentType']]); n=dim[a['type']]
    off=v.get('byteOffset',0)+a.get('byteOffset',0)
    return np.ndarray((a['count'],n),dtype=dtype,buffer=binario,offset=off,strides=(v.get('byteStride',n*dtype.itemsize),dtype.itemsize)).copy()

salida=[]
for i,n in enumerate(g['nodes']):
    nombre=n.get('name','')
    if nombre in ['board tareas-col','tableroluz-col'] or ('tapa' in nombre and 'tachitobasura' in nombre):
        if 'mesh' not in n: continue
        puntos=[]; caras=[]
        for p in g['meshes'][n['mesh']]['primitives']:
            vs=acc(p['attributes']['POSITION']); ids=acc(p['indices']).reshape(-1)
            caras.extend(vs[ids].tolist()); puntos.extend(vs.tolist())
        ps=np.unique(np.array(puntos),axis=0); hull=ConvexHull(ps)
        parent={tuple(p):tuple(p) for p in caras}
        def root(p):
            while parent[p]!=p: p=parent[p]
            return p
        for j in range(0,len(caras),3):
            a=root(tuple(caras[j]))
            for b in caras[j+1:j+3]: parent[root(tuple(b))]=a
        grupos={}
        for p in caras: grupos.setdefault(root(tuple(p)),[]).append(p)
        piezas=[]
        for grupo in grupos.values():
            qs=np.unique(grupo,axis=0); h=ConvexHull(qs)
            triangulos=np.array(grupo).reshape(-1,3,3)
            vol=abs(np.einsum('ij,ij->i',triangulos[:,0],np.cross(triangulos[:,1],triangulos[:,2])).sum()/6)
            piezas.append({'puntos':qs.tolist(),'caras':grupo,'volumen_hull':h.volume,'volumen_malla':float(vol),'convexo_por_volumen':bool(abs(h.volume-vol)<1e-6)})
        datos={'nombre':nombre,'node':i,'gltf':n,'puntos':ps.tolist(),'caras':caras,'bbox':[ps.min(0).tolist(),ps.max(0).tolist()],'volumen_hull':hull.volume,'vertices_hull':len(hull.vertices),'planos_hull':len(hull.simplices)}
        datos['piezas']=piezas
        salida.append(datos)
        print(nombre, 'puntos',len(ps),'caras',len(caras)//3,'bbox',datos['bbox'],'hull',hull.volume,len(hull.vertices))
        print('piezas',[(len(p['puntos']),p['volumen_hull'],p['volumen_malla'],p['convexo_por_volumen']) for p in piezas])
        if nombre=='tableroluz-col':
            for p in piezas:
                qs=np.array(p['puntos']); eje=next(k for k in range(3) if len(np.unique(qs[:,k].round(5)))==3)
                niveles=np.unique(qs[:,eje].round(5)); otros=[k for k in range(3) if k!=eje]
                grupos=[qs[np.abs(qs[:,eje]-v)<1e-5] for v in niveles]
                frontal=next(v for v in grupos if len(v)==8); fondo=next(v for v in grupos if len(v)==4 and abs(v[0,eje]-frontal[0,eje])==max(abs(qs[:,eje]-frontal[0,eje])))
                interior=next(v for v in grupos if len(v)==4 and not np.array_equal(v,fondo))
                centro=frontal[:,otros].mean(0); dist=np.linalg.norm(frontal[:,otros]-centro,axis=1); orden=np.argsort(dist)
                frente_dentro=frontal[orden[:4]]; frente_fuera=frontal[orden[4:]]
                anillos=[fondo,frente_fuera,interior,frente_dentro]
                anillos=[v[np.argsort(np.arctan2(v[:,otros[1]]-centro[1],v[:,otros[0]]-centro[0]))] for v in anillos]
                celdas=[np.vstack([anillos[0],anillos[2]])]
                for k in range(4): celdas.append(np.vstack([v[[k,(k+1)%4]] for v in anillos]))
                p['celdas']= [v.tolist() for v in celdas]
                print('descompuesto',eje,'volumen',sum(ConvexHull(v).volume for v in celdas),'original',p['volumen_malla'])
Path(__file__).with_name('geometria-offline.json').write_text(json.dumps(salida,ensure_ascii=False,indent=2),encoding='utf8')
