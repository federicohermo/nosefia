import json
import struct
from pathlib import Path

carpeta = Path(__file__).parent
a = (carpeta / 'antes.glb').read_bytes()
b = Path('assets/models/SEPT_JUEGOS_PROTOTIPO.glb').read_bytes()
n = struct.unpack_from('<I',a,12)[0]
assert a[20:20+n] == b[20:20+n]
g = json.loads(a[20:20+n])
base = 28+n
cambios = {}
cubiertos = set()
for mesh in g['meshes']:
    for p in mesh['primitives']:
        for semantica,i in p['attributes'].items():
            acc=g['accessors'][i]
            if acc['componentType'] != 5126:
                continue
            view=g['bufferViews'][acc['bufferView']]
            componentes={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[acc['type']]
            stride=view.get('byteStride',componentes*4)
            for indice in range(acc['count']):
                inicio=base+view.get('byteOffset',0)+acc.get('byteOffset',0)+indice*stride
                va=struct.unpack_from('<'+'f'*componentes,a,inicio)
                vb=struct.unpack_from('<'+'f'*componentes,b,inicio)
                if va!=vb:
                    cambios[semantica]=max(cambios.get(semantica,0),max(abs(x-y) for x,y in zip(va,vb)))
                    cubiertos.update(range(inicio,inicio+componentes*4))
assert all(i in cubiertos for i,(x,y) in enumerate(zip(a,b)) if x!=y)
assert all(delta < 1e-6 for delta in cambios.values())
print('JSON, nombres, jerarquia, materiales, indices e imagenes identicos.')
print('Deltas maximos de atributos flotantes:',cambios)
