from pathlib import Path
import json
import numpy as np
from PIL import Image

carpeta = Path(__file__).parent / 'capturas373'
resultados = {}
import sys
for motor in sys.argv[1:] or ['escritorio','web']:
    medidas = json.loads((carpeta / f'{motor}-medidas.json').read_text(encoding='utf-8'))
    for ancho in [1920,1280]:
        cerrado = np.array(Image.open(carpeta / f'{motor}-cerrado-{ancho}.png').convert('RGB'),dtype=np.float64)/255
        abierto = np.array(Image.open(carpeta / f'{motor}-menu-{ancho}.png').convert('RGB'),dtype=np.float64)/255
        sinvelo = np.array(Image.open(carpeta / f'{motor}-menu-sin-velo-{ancho}.png').convert('RGB'),dtype=np.float64)/255
        assert cerrado.shape==abierto.shape==sinvelo.shape
        alto,ancho_real,_=cerrado.shape
        assert (ancho_real,alto)==(ancho,ancho*9//16)
        luminancia=lambda a: a @ np.array([0.2126,0.7152,0.0722])
        regiones=[]
        for izquierda,derecha in [(0.05,0.30),(0.70,0.95)]:
            recorte=(slice(int(alto*.22),int(alto*.82)),slice(int(ancho*izquierda),int(ancho*derecha)))
            a,b=luminancia(cerrado[recorte]),luminancia(abierto[recorte])
            normalizado=lambda p:(np.abs(np.diff(p,axis=0)).mean()+np.abs(np.diff(p,axis=1)).mean())/max(p.mean(),.001)
            regiones.append({'luminancia_base':float(a.mean()),'luminancia_velo':float(b.mean()),'razon_luz':float(b.mean()/a.mean()),'gradiente_normalizado_base':float(normalizado(a)),'gradiente_normalizado_velo':float(normalizado(b)),'razon_gradiente':float(normalizado(b)/normalizado(a))})
        assert all(r['razon_luz']<.85 for r in regiones), regiones
        assert any(r['razon_gradiente']<.8 for r in regiones), regiones
        x,y,w,h=medidas[str(ancho)]['rect']
        margen=40*ancho/1920
        interior=(slice(int(y+margen),int(y+h-margen)),slice(int(x+margen),int(x+w-margen)))
        diferencia=np.abs(abierto[interior]-sinvelo[interior])
        assert diferencia.mean()<.005, diferencia.mean()
        resultados[f'{motor}-{ancho}']={'regiones':regiones,'diferencia_media_dentro_del_celular':float(diferencia.mean()),'rect':medidas[str(ancho)]['rect']}
(carpeta/'pixeles-AC-INV-034.json').write_text(json.dumps(resultados,indent=2),encoding='utf-8')
print(json.dumps(resultados,indent=2))
