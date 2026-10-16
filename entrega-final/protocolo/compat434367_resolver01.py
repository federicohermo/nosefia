from pathlib import Path
import re
import shutil

root=Path.cwd()
out=Path(__file__).parent/'compat434367-merge-final01'
spec=root/'specs/store-stock/store-stock.md'
shutil.copyfile(spec,out/'spec-conflicto.md')
text=spec.read_text(encoding='utf-8')
pattern=r'<<<<<<< HEAD\n(.*?)=======\n(.*?)>>>>>>> 43e3e0ad79f664665afbe7939c3cfcd8bd093183\n'
blocks=list(re.finditer(pattern,text,re.S))
assert len(blocks)==3
def reconcile(match):
    ours,foreign=match.groups()
    if ours.startswith('provenance:'):
        return ours.replace('decisiones de #369 y #376','decisiones de #367, #369 y #376')
    if ours.startswith('- **Entrada:**'):
        return ('- **Entrada:** el sector y destino declarado de cada producto y si admite exhibición;\n'
                '  los productos que existen, sus casilleros totales y los de la fila de adelante\n'
                '  de su tanda reponible, la jornada que se abre, sus pedidos ya construidos y la\n'
                '  fuente de azar, lo vendido de cada producto, lo que el jugador lleva en la mano, la caja\n')
    assert ours.startswith('- **OQ-STK-005') and not foreign.strip()
    return ours[ours.index('- **OQ-STK-007'):]
spec.write_bytes(re.sub(pattern,reconcile,text,flags=re.S).encode())
test=root/'test/escenas/puestos/disposicion_de_la_gondola_test.gd'
shutil.copyfile(test,out/'disposicion-conflicto.gd')
text=test.read_text(encoding='utf-8')
assert len(list(re.finditer(pattern,text,re.S)))==1
text=re.sub(pattern,lambda m:m.group(2),text,flags=re.S)
test.write_bytes(text.encode())
print('Dos archivos conciliados; sectores/filas/Duronga y sorteo J1-J5 conservados')
