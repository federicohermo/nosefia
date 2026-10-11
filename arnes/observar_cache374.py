"""Mismo descubrimiento acotado, con lectura pasiva del caché antes de desmontar."""

from pathlib import Path
import json
import os
import subprocess
import sys

s = Path(__file__).parent
datos = json.loads((s / '374-discovery-comando.json').read_text(encoding='utf-8'))
comando = datos['comando']
comando[comando.index('res://addons/gdUnit4/bin/GdUnitCmdTool.gd')] = str(s / '374-cache-observador' / 'GdUnitCmdTool.gd')
comando[0] = os.environ['GODOT_BIN']
(s / '374-cache-comando.json').write_text(json.dumps({
    'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'comando': comando,
}, ensure_ascii=False, indent=2), encoding='utf-8')
r = subprocess.run(comando, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                   encoding='utf-8', errors='replace', timeout=180)
print(r.stdout, end='', flush=True)
sys.exit(r.returncode)
