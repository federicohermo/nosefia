import os
import subprocess
import sys
from pathlib import Path

raiz = Path.cwd()
entorno = dict(os.environ)
entorno['APPDATA'] = str(raiz / '.godot/usuario_de_los_tests')
comando = [entorno['GODOT_BIN'], '--path', str(raiz), '--resolution', '1600x900',
           '--position', '-2000,-2000', '--script',
           'C:/Users/fede_/AppData/Local/Temp/nosefia-batch-364-370-20261010/captura369.gd']
raise SystemExit(subprocess.run(comando, env=entorno).returncode)
