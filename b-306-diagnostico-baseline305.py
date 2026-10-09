from pathlib import Path
import os, subprocess, sys
root = Path.cwd(); scratch = Path(__file__).parent
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip() == '11301e9df6fd2510b4fa2ff1c0fd6db9d25fe963'
env = dict(os.environ, APPDATA=str(root / '.godot/usuario_de_los_tests'))
log = scratch / 'b-306-diagnostico-baseline305-import.log'; assert not log.exists()
with log.open('w', encoding='utf-8') as stream:
    code = subprocess.run([env['GODOT_BIN'], '--headless', '--path', str(root), '--import', '--quit'], env=env, stdout=stream, stderr=subprocess.STDOUT).returncode
assert code == 0
raise SystemExit(subprocess.run([sys.executable, str(scratch / 'b-306-diagnostico-full1.py'), 'b-306-diagnostico-baseline305']).returncode)
