import json
from pathlib import Path
from PIL import Image, ImageChops


def mascara(imagen):
    colores = {(216, 180, 104), (217, 217, 217), (240, 244, 209)}
    resultado = Image.new('1', imagen.size)
    resultado.putdata([pixel in colores for pixel in imagen.convert('RGB').getdata()])
    return resultado


resultados = {}
inicial_antes = Image.open('build/antes-0.png')
inicial_despues = Image.open('build/despues-1280x720-0.png')
resultados['inicial_nativa_antes_despues'] = ImageChops.difference(inicial_antes, inicial_despues).getbbox()
for ancho, alto in [(1280, 720), (960, 720), (1440, 640)]:
    inicial = Image.open(f'build/web-despues-{ancho}x{alto}-0.png')
    entre_noches = Image.open(f'build/web-despues-{ancho}x{alto}-1.png')
    escala = min(ancho / 1920, alto / 1080)
    x = (ancho - 1920 * escala) / 2
    y = (alto - 1080 * escala) / 2
    zona = (int(x + 630 * escala), int(y + 515 * escala), int(x + 1270 * escala), int(y + 625 * escala))
    diferencia = ImageChops.difference(mascara(inicial).crop(zona), mascara(entre_noches).crop(zona))
    resultados[f'web_{ancho}x{alto}_mascara_barra_y_texto'] = diferencia.getbbox()
    assert diferencia.getbbox() is None, resultados
assert resultados['inicial_nativa_antes_despues'] is None, resultados
Path('build/comparacion.json').write_text(json.dumps(resultados, indent=2), encoding='utf-8')
print(json.dumps(resultados))
