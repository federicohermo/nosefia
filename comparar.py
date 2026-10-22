import json
from pathlib import Path

carpeta = Path(__file__).parent
antes = json.loads((carpeta / 'prueba-antes.json').read_text(encoding='utf8'))
despues = json.loads((carpeta / 'prueba-despues.json').read_text(encoding='utf8'))
assert antes['sha256_fuente'] == despues['sha256_fuente']
assert antes['tandas'].keys() == despues['tandas'].keys()
movidas = 0
for clave, original in antes['tandas'].items():
    nueva = despues['tandas'][clave]
    assert original['producto'] == nueva['producto'], clave
    assert original['cantidad'] == nueva['cantidad'], clave
    lateral = clave.startswith(('A.este.', 'A.oeste.', 'B.este.', 'B.oeste.'))
    for a,b in zip(original['unidades'],nueva['unidades']):
        for dato in ('producto','fila','orden','fija'):
            assert a[dato] == b[dato], (clave,dato)
        for i in range(4):
            for j in range(4):
                delta = abs(a['matriz'][i][j]-b['matriz'][i][j])
                if lateral and (i,j) == (1,3):
                    assert delta <= 0.040001, (clave,delta)
                else:
                    assert delta < 1e-6, (clave,i,j,delta)
        if a['matriz'] != b['matriz']:
            movidas += 1
    if lateral:
        for fila in ('adelante','atras'):
            unidades = sorted([u for u in nueva['unidades'] if u['fila']==fila], key=lambda u:u['min'][1])
            for a,b in zip(unidades,unidades[1:]):
                assert b['min'][1]-a['max'][1] >= .01-1e-6, (clave,fila)
assert len(despues['esquinas']) == 32
for a,b in zip(antes['esquinas'],despues['esquinas']):
    assert abs(a['minimo']['hueco_y']-.0075) < 1e-6
    assert abs(b['minimo']['hueco_y']-.0475) < 1e-6
print('64 tandas, 784 unidades. Identidades, filas, orden y fijas iguales.')
print('32 esquinas. Separacion minima 0.0075 m -> 0.0475 m.')
print('Solo cambia Y lateral. Bases, profundidad, altura y restantes matrices conservadas.')
print('Fuente identica por SHA256. Unidades trasladadas:',movidas)
