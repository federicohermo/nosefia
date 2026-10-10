import os
import subprocess
import sys
from pathlib import Path
sys.path.insert(0, str(Path.cwd()/'.claude/scripts'))
from lib.godot import entorno_de_la_suite
motor=os.environ['GODOT_BIN']
entorno=entorno_de_la_suite(dict(os.environ), Path.cwd(), sys.platform)
subprocess.run([motor,'--headless','--path','.','--import','--quit'],env=entorno,check=True,timeout=120)
resultado=subprocess.run([motor,'--path','.','--script',str(Path(__file__).with_name('370-capturar.gd')),'--resolution','1280x720','--position','32,32','--rendering-method','gl_compatibility'],env=entorno,timeout=120)
sys.exit(resultado.returncode)
