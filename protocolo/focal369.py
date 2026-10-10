import os, subprocess, sys
from pathlib import Path
r=Path.cwd(); env=dict(os.environ);env['APPDATA']=str(r/'.godot/usuario_de_los_tests')
bin=env['GODOT_BIN']
code=subprocess.run([bin,'--headless','--path',str(r),'--import','--quit'],env=env).returncode
if code: sys.exit(code)
args=[bin,'--path',str(r),'--headless','-s','-d','--remote-debug','tcp://127.0.0.1:0','res://addons/gdUnit4/bin/GdUnitCmdTool.gd']
for suite in sys.argv[1:]: args+=['-a',suite]
args+=['--continue','--ignoreHeadlessMode','-rd','res://reports/focal-369']
sys.exit(subprocess.run(args,env=env).returncode)
