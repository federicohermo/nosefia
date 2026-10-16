from pathlib import Path
import re
root=Path.cwd()
original=(root/'test/escenas/un_lugar_por_producto_test.gd').read_text(encoding='utf-8')
start=original.index('func _lugar_en_el_pasillo(')
end=original.index('\n\n\n##',start)
helper=original[start:end]
path=root/'test/escenas/compatibilidad_guia_sin_principal_test.gd'
path.write_bytes((path.read_text(encoding='utf-8')+'\n\n\n'+helper+'\n').encode())
print('Helper de piso/cápsula/rayo conservado íntegro de un_lugar_por_producto')
