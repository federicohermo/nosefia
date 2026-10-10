import os
import subprocess
import sys
from pathlib import Path

scratch = Path(__file__).parent
comando = [sys.executable, str(scratch / 'focal369.py'),
           'test/dominio/empleo/reglas_de_la_partida_test.gd',
           'test/sistemas/tareas/acomodador_del_deposito_test.gd',
           'test/escenas/deposito_ordenado_test.gd',
           'test/escenas/objetos/ubicacion_en_el_deposito_test.gd',
           'test/escenas/red_de_seguridad_integrada_test.gd',
           'test/escenas/objetos/caja_que_se_lleva_test.gd']
resultado = subprocess.run(comando).returncode
if resultado:
    sys.exit(resultado)
raw = Path.cwd() / '.godot/usuario_de_los_tests/Godot/app_userdata/No se fía/logs/godot.log'
if raw.is_file():
    (scratch / '369-captura-validacion-godot.log').write_bytes(raw.read_bytes())
sys.exit(subprocess.run([sys.executable, str(scratch / 'captura369.py')]).returncode)
