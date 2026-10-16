import os,sys,subprocess
from pathlib import Path
sys.path.insert(0,str(Path.cwd()/'.claude/scripts'))
from lib.godot import resolver,entorno_de_la_suite
binary=resolver(dict(os.environ))[0]
assert binary
code=subprocess.run([binary,'--headless','--path',str(Path.cwd()),'--import','--quit']).returncode
if code: sys.exit(code)
args=[binary,'--path',str(Path.cwd()),'--headless','-s','-d','--remote-debug','tcp://127.0.0.1:0','res://addons/gdUnit4/bin/GdUnitCmdTool.gd','--continue','--ignoreHeadlessMode','-rd','res://reports/focal-426']
for suite in sys.argv[1:]: args.extend(['-a',suite])
sys.exit(subprocess.run(args,env=entorno_de_la_suite(dict(os.environ),Path.cwd(),sys.platform)).returncode)
