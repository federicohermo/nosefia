import datetime,hashlib,json
from pathlib import Path
s=Path(__file__).parent
archivos=['exportar_paquete22-02.py','paquete-y-nativo-02.py','paquete22.gd','capturar_nativo22.gd','ejecutar-web-22.py','recorrer-web-22.mjs','fixture-web-22.gd','fixture22.tscn','override.cfg']
datos={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'momento':'Lectura durante espera FIFO posterior al enqueue; archivos inmóviles desde sus respectivos encolados. No se inventa pin anterior.','product_head':'fb4236e69c752e6879bb338b80e734e16b211b41','insumos':{n:{'sha256':hashlib.sha256((s/n).read_bytes()).hexdigest(),'bytes':(s/n).stat().st_size} for n in archivos}}
(s/'insumos-fijos-durante-espera.json').write_text(json.dumps(datos,ensure_ascii=False,indent=2),encoding='utf8')
