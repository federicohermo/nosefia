import re
import subprocess
from pathlib import Path

ruta = 'src/escenas/puestos/disposicion_de_prueba.tres'
antes = subprocess.check_output(['git','show','6afac29e:'+ruta]).decode('utf8')
despues = Path(ruta).read_text(encoding='utf8')
total = 0
tandas = 0
for clave in ('principales','guias'):
    def bloques(texto):
        linea = next(l for l in texto.splitlines() if l.startswith(clave+' ='))
        return [[float(x) for x in b.split(',') if x.strip()]
                for b in re.findall(r'PackedFloat32Array\(([^)]*)\)',linea)]
    a,b=bloques(antes),bloques(despues)
    assert len(a)==len(b)
    for aa,bb in zip(a,b):
        assert len(aa)==len(bb)
        total+=len(bb)//12
        tandas+=bool(bb)
        for i,(x,y) in enumerate(zip(aa,bb)):
            if i%12==11:
                assert abs(x-y)<=.04001
            else:
                assert x==y,(clave,i,x,y)
def metadatos(texto):
    return [l for l in texto.splitlines() if not l.startswith(('principales =','guias ='))]
assert metadatos(antes)==metadatos(despues)
assert total==784 and tandas==64
print('Recurso publicado conserva 64 tandas, 784 unidades y todos los metadatos.')
print('Solo varia Z de las copias, hasta 40 mm. Bases, X y alturas identicos.')
