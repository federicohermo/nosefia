import hashlib,json
from pathlib import Path
s=Path(__file__).parent
src=(s/'capturar_nativo22-encolado02.gd').read_text(encoding='utf8')
inicio=src.index('\nfunc _foto(');fin=src.index('\nfunc _ejercer()',inicio)
src=src[:inicio]+'\nfunc _foto(nombre: String) -> void:\n\tprint("PCK22_ESTADO ", nombre)\n\tawait _cuadros()\n\n'+src[fin:]
src=src.replace('\troot.mode = Window.MODE_WINDOWED\n','').replace('NATIVO22','PAQUETE22')
esperado=json.loads((s/'insumos-fijos-durante-espera.json').read_text(encoding='utf8'))['insumos']['paquete22.gd']['sha256']
posibles=[src.encode('utf8'),src.replace('\n','\r\n').encode('utf8')]
coincidente=next((raw for raw in posibles if hashlib.sha256(raw).hexdigest()==esperado),None)
assert coincidente is not None,'La reconstrucción no coincide con el hash anterior; no presentarla como original'
(s/'paquete22-medido01.gd').write_bytes(coincidente)
(s/'paquete22-medido01-procedencia.json').write_text(json.dumps({'sha256':esperado,'metodo':'Reconstrucción determinista con preparar-paquete.py conservado y native encodado02 anterior al cambio. Bytes contrastados contra hash registrado durante espera, antes de modificar fixture.','limite':'Se distingue esta reconstrucción verificada de una copia archivada antes del cambio.'},ensure_ascii=False,indent=2),encoding='utf8')
print('FixturePCK01 reconstruido byteexacto frente a pin anterior.')
