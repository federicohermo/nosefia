import json,re
from pathlib import Path
p=Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010/301-evidencia')
b=json.loads((p/'base-escena.json').read_text())['nodos']
f=json.loads((p/'final-escena.json').read_text())['nodos']
assert set(b)==set(f)
d={n:{k:[b[n].get(k),f[n].get(k)] for k in set(b[n])|set(f[n]) if b[n].get(k)!=f[n].get(k)} for n in b if n.startswith('Estructura/') and b[n]!=f[n]}
permitidos={'Estructura/tachitobasura','Estructura/tachitobasura/StaticBody3D','Estructura/tachitobasura/StaticBody3D/CollisionShape3D','Estructura/tachitobasura/StaticBody3D/Volumen'}
assert set(d)==permitidos,set(d)
for n,cambios in d.items():
 assert set(cambios)<=({'bounds','transform','mundo'} if n=='Estructura/tachitobasura' else {'mundo'})
 for k,(antes,despues) in cambios.items():
  x=[float(v) for v in antes[antes.index('(')+1:-1].split(',')]
  y=[float(v) for v in despues[despues.index('(')+1:-1].split(',')]
  if k=='bounds':
   x[0]-=.66;x[2]+=.45
  else:
   x[9]-=.66;x[11]+=.45
  assert max(abs(u-v) for u,v in zip(x,y))<0.000001,(n,k,x,y)
reporte=dict(nodos_escena=len(b),estructurales=sum(n.startswith('Estructura/') for n in b),solo_tacho_y_descendientes=True,cambios=d)
(p/'comparacion-escena.json').write_text(json.dumps(reporte,ensure_ascii=False,indent=2)+'\n',encoding='utf8',newline='\n')
print('301_COMPARACION_ESCENA',reporte['nodos_escena'],reporte['estructurales'],'solo tacho y descendientes')
