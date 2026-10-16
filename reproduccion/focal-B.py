from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time

root = Path.cwd()
sys.path.insert(0, str(root / '.claude/scripts'))
from lib.godot import resolver, entorno_de_la_suite
godot, origin = resolver(dict(os.environ))
assert godot and Path(godot).is_file()
output = Path(sys.argv[1])
output.mkdir(parents=True, exist_ok=True)
env = entorno_de_la_suite(dict(os.environ), root, sys.platform)
env['GODOT_BIN'] = godot
subprocess.run([sys.executable, str(Path(__file__).with_name('432-snapshot.py')), str(output / 'pins-pre')], check=True)
commands = [('import', [godot, '--headless', '--path', str(root), '--import', '--quit'])]
for index, suite in enumerate(sys.argv[2:]):
    commands.append((f'focal-{index:02d}', [godot, '--path', str(root), '--headless', '--verbose', '-s', '-d', '--remote-debug', 'tcp://127.0.0.1:0', 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-a', suite, '--continue', '--ignoreHeadlessMode', '-rd', 'res://reports/focal-437']))
results = []
for name, command in commands:
    start = time.monotonic()
    combined = []
    lock = threading.Lock()
    with (output / (name + '.stdout.log')).open('wb') as stdout, (output / (name + '.stderr.log')).open('wb') as stderr, (output / (name + '.cronologico.log')).open('wb') as chronological:
        process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, creationflags=subprocess.CREATE_NO_WINDOW)
        def consume(channel, target, label):
            for line in iter(channel.readline, b''):
                target.write(line)
                target.flush()
                with lock:
                    chronological.write(f'{time.monotonic()-start:.6f} {label} '.encode() + line)
                    chronological.flush()
                    combined.append(line)
        threads = [threading.Thread(target=consume, args=(process.stdout, stdout, 'stdout')), threading.Thread(target=consume, args=(process.stderr, stderr, 'stderr'))]
        for thread in threads:
            thread.start()
        code = process.wait(timeout=900)
        for thread in threads:
            thread.join()
    clean = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', b''.join(combined).decode('utf-8', errors='replace'))
    xml = re.search(r'Open XML Report at: file://([^\r\n]+results.xml)', clean)
    if xml and Path(xml[1]).is_file():
        shutil.copyfile(Path(xml[1]), output / (name + '.results.xml'))
    results.append({'name': name, 'command': command, 'pid': process.pid, 'exit': code, 'seconds': time.monotonic()-start})
    (output / 'commands.json').write_text(json.dumps({'head': subprocess.check_output(['git', 'rev-parse', 'HEAD']).decode().strip(), 'godot_origin': origin, 'results': results}, indent=2), encoding='utf-8')
    print(f'{name}: exit {code}', flush=True)
    if code:
        break
subprocess.run([sys.executable, str(Path(__file__).with_name('432-snapshot.py')), str(output / 'pins-post')], check=True)
code = max(item['exit'] for item in results)
(output / 'exit-code.txt').write_text(str(code), encoding='utf-8')
raise SystemExit(code)
