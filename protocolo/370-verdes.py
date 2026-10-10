import subprocess
import sys
from pathlib import Path

paths = subprocess.check_output(['git','diff','--name-only','--','*.gd'], encoding='utf-8').splitlines()
paths += subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','*.gd'], encoding='utf-8').splitlines()
paths = sorted({p for p in paths if p.endswith('_test.gd') and not p.endswith('giro_parejo_test.gd')})
print('SUITES_370', len(paths), paths, flush=True)
raise SystemExit(subprocess.call([sys.executable, str(Path(__file__).with_name('370-focal.py')), *paths]))
