import hashlib, io, json, math, struct, sys
from pathlib import Path
from PIL import Image
scratch=Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010')

class GLB:
 def __init__(self,p):
  raw=Path(p).read_bytes(); n,t=struct.unpack_from('<II',raw,12)
  self.j=json.loads(raw[20:20+n]); self.b=raw[28+n:]
 def buffer(self,i):
  v=self.j['bufferViews'][i]; off=v.get('byteOffset',0)
  return self.b[off:off+v['byteLength']]
 def accessor(self,i):
  a=self.j['accessors'][i]; v=self.j['bufferViews'][a['bufferView']]
  f={5120:'b',5121:'B',5122:'h',5123:'H',5125:'I',5126:'f'}[a['componentType']]
  k={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
  size=struct.calcsize('<'+f*k); stride=v.get('byteStride',size)
  off=v.get('byteOffset',0)+a.get('byteOffset',0)
  return [struct.unpack_from('<'+f*k,self.b,off+r*stride) for r in range(a['count'])]
 def mesh(self,i):
  m=self.j['meshes'][i]
  out=[]
  for p in m['primitives']:
   out.append(dict(material=self.j['materials'][p['material']]['name'] if 'material'in p else None,
    mode=p.get('mode',4),indices=self.accessor(p['indices']) if 'indices'in p else None,
    attrs={k:self.accessor(v) for k,v in p['attributes'].items()}))
  return out

a=GLB(scratch/'301-base.glb'); b=GLB(Path.cwd()/'assets/models/SEPT_JUEGOS_PROTOTIPO.glb')
errores=[]; maxdelta={}; conteo=0
na={n['name']:n for n in a.j['nodes']}; nb={n['name']:n for n in b.j['nodes']}
assert set(na)==set(nb)
for nombre in sorted(na):
 x,y=na[nombre],nb[nombre]
 for k in set(x)|set(y):
  if k=='mesh': continue
  if nombre=='tachitobasura-col' and k=='translation':
   assert all(abs(u-v)<1e-6 for u,v in zip(y[k],[x[k][0]-.66,x[k][1],x[k][2]+.45])),(x[k],y[k])
   continue
  if x.get(k)!=y.get(k): errores.append(f'nodo {nombre} {k}: {x.get(k)} -> {y.get(k)}')
 if 'mesh' not in x: continue
 mx,my=a.mesh(x['mesh']),b.mesh(y['mesh'])
 if len(mx)!=len(my): errores.append(f'superficies {nombre}');continue
 for p,q in zip(mx,my):
  conteo+=1
  for k in ('material','mode','indices'):
   if p[k]!=q[k]: errores.append(f'{nombre} {k}')
  if set(p['attrs'])!=set(q['attrs']): errores.append(f'{nombre} atributos');continue
  for atributo in p['attrs']:
   v,w=p['attrs'][atributo],q['attrs'][atributo]
   if len(v)!=len(w): errores.append(f'{nombre} {atributo} largo');continue
   delta=max((abs(j-k) for r,s in zip(v,w) for j,k in zip(r,s)),default=0)
   maxdelta[atributo]=max(maxdelta.get(atributo,0),delta)
   if delta>0.000001: errores.append(f'{nombre} {atributo} delta {delta}')
for clave in ('materials','textures','samplers','scenes'):
 if a.j.get(clave)!=b.j.get(clave): errores.append('catalogo '+clave)
assert len(a.j['images'])==len(b.j['images'])
for x,y in zip(a.j['images'],b.j['images']):
 px=Image.open(io.BytesIO(a.buffer(x['bufferView']))).convert('RGBA')
 py=Image.open(io.BytesIO(b.buffer(y['bufferView']))).convert('RGBA')
 if x.get('name')!=y.get('name') or px.size!=py.size or px.tobytes()!=py.tobytes(): errores.append('imagen '+x.get('name',''))
reporte=dict(nodos=len(na),superficies=conteo,imagenes=len(a.j['images']),deltas_maximos=maxdelta,errores=errores)
(scratch/'301-evidencia'/'comparacion-glb.json').write_text(json.dumps(reporte,indent=2),encoding='utf8')
print(json.dumps(reporte,indent=2))
raise SystemExit(bool(errores))
