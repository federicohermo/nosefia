import json,re,shutil
from pathlib import Path
s=Path(__file__).parent
p=Path.cwd()/'src/escenas/puestos/estructura_del_almacen.tscn'
real=json.loads((s/'geometria-verde-06/volumenes-regenerados.json').read_text(encoding='utf8'))
shutil.copy2(s/'volumenes-propuestos.json',s/'volumenes-desde-glb-anterior.json')
(s/'volumenes-propuestos.json').write_text(json.dumps(real,indent=2),encoding='utf8')
texto=p.read_text(encoding='utf8')
for i,(ruta,formas) in enumerate(real.items()):
    for j,puntos in enumerate(formas):
        valores=', '.join(f'{v:.9f}' for punto in puntos for v in punto)
        patron=rf'(\[sub_resource type="ConvexPolygonShape3D" id="colilla_volumen_{i}_{j}"\]\nmargin = 0.001\npoints = )PackedVector3Array\([^\n]*\)'
        texto,n=re.subn(patron,lambda m:m[1]+f'PackedVector3Array({valores})',texto)
        assert n==1,(ruta,j)
p.write_text(texto,encoding='utf8',newline='\n')
f=(s/'focal-geometria.py').read_text(encoding='utf8').replace("out=scratch/'geometria-verde-06'","out=scratch/'geometria-verde-07'")
(s/'focal-geometria-07.py').write_text(f,encoding='utf8')
print('Resultados Godot importados sustituyen aproximación offline; regeneración conserva tolerancia1e-6.')
