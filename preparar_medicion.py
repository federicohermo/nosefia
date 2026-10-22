import configparser
import shutil
from pathlib import Path

raiz = Path.cwd()
destino = raiz / 'build/medicion'
archivos = [
    'src/ui/interrupciones/pantalla_de_carga.gd',
    'src/ui/interrupciones/pantalla_de_carga.tscn',
    'src/ui/interrupciones/persiana_de_la_noche.gd',
    'src/ui/interrupciones/persiana_de_la_noche.tscn',
    'src/ui/interrupciones/cabecera_con_solapa.gd',
    'src/ui/diegetica/lienzo_de_manada.gd',
    'src/dominio/jornada/entrada_a_la_noche.gd',
    'assets/models/SEPT_JUEGOS_PROTOTIPO_textura portón.png',
    'assets/audio/SFX_NOLEV_Puerta_Garage.wav',
]
for archivo in archivos:
    salida = destino / archivo
    salida.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(raiz / archivo, salida)
shutil.copytree(raiz / 'assets/ui/manada', destino / 'assets/ui/manada', dirs_exist_ok=True)
shutil.copy2(raiz / 'build/medir_carga.gd', destino / 'medir_carga.gd')
escena = (raiz / 'build/medir_carga.tscn').read_text().replace('res://build/', 'res://')
(destino / 'medir_carga.tscn').write_text(escena)
(destino / 'project.godot').write_text('''config_version=5
[application]
config/name="Medición de carga"
run/main_scene="res://medir_carga.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
[rendering]
renderer/rendering_method="gl_compatibility"
''', encoding='utf-8')
config = configparser.ConfigParser(interpolation=None)
config.read('export_presets.cfg', encoding='utf-8')
config['preset.0']['export_path'] = '"web/index.html"'
config['preset.0']['exclude_filter'] = '"web/*"'
config['preset.0.options']['custom_template/release'] = '"D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/build/templates/web_release.zip"'
with (destino / 'export_presets.cfg').open('w', encoding='utf-8') as salida:
    config.write(salida)
(destino / 'web').mkdir(exist_ok=True)
