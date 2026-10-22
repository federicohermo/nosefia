import base64
import json
import subprocess
from pathlib import Path

ORCA = r'C:/Users/fede_/AppData/Local/Programs/orca/resources/bin/orca.exe'
PAGINA = '7b62b5ce-b45c-4476-a9c4-9f8f587a7458'


def orca(*argumentos):
    salida = subprocess.run([ORCA, *argumentos, '--page', PAGINA, '--json'], capture_output=True, text=True, encoding='utf-8', check=True)
    respuesta = json.loads(salida.stdout)
    if not respuesta['ok']:
        raise RuntimeError(respuesta)
    return respuesta['result']


medidas = []
for ancho, alto in [(1280, 720), (960, 720), (1440, 640)]:
    orca('exec', '--command', f'set viewport {ancho} {alto}')
    for presentacion in [0, 1]:
        orca('goto', '--url', f'http://127.0.0.1:8765/prueba3.html?p={presentacion}')
        orca('snapshot')
        for intento in range(60):
            listo = orca('eval', '--expression', "document.body.classList.contains('cargando')")
            if listo['result'] == 'true':
                break
        else:
            raise RuntimeError('La carga no llegó a dibujarse')
        lectura = orca('eval', '--expression', "({size:[innerWidth,innerHeight],puntos:document.getElementById('latido').getAnimations({subtree:true}).map(a=>({estado:a.playState,duracion:a.effect.getTiming().duration,desfase:a.effect.getTiming().delay})),ubicacion:document.getElementById('latido').getBoundingClientRect().toJSON()})")
        medidas.append({'ancho': ancho, 'alto': alto, 'presentacion': presentacion, 'medida': json.loads(lectura['result'])})
        orca('eval', '--expression', "document.getElementById('latido').getAnimations({subtree:true}).forEach(a=>{a.pause();a.currentTime=450})")
        captura = orca('screenshot')
        Path(f'build/web-despues-{ancho}x{alto}-{presentacion}.png').write_bytes(base64.b64decode(captura['data']))
Path('build/medidas-web.json').write_text(json.dumps(medidas, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(medidas, ensure_ascii=False))
