from pathlib import Path
import re
import subprocess
import sys

root = Path.cwd()
output = root / 'export' / sys.argv[1]
output.mkdir(parents=True, exist_ok=True)
project = root / 'project.godot'
preset = root / 'export_presets.cfg'
original_project, original_preset = project.read_bytes(), preset.read_bytes()
try:
    config = original_project.decode('utf-8')
    config = re.sub(r'run/main_scene="[^"]+"',
                    'run/main_scene="res://tmp/captura_compradores_web.tscn"', config)
    config = re.sub(r'\[autoload\]\r?\n.*?(?=\r?\n\[)', '', config, flags=re.S)
    project.write_text(config, encoding='utf-8')
    preset.write_text(original_preset.decode('utf-8').replace('tmp/*,', ''), encoding='utf-8')
    with (root / 'tmp' / (sys.argv[1] + '-export.log')).open('w') as log:
        result = subprocess.run([
            str(root / 'build/godot-native/windows-x86_64/godot.windows.editor.x86_64.console.exe'),
            '--headless', '--path', str(root), '--export-release', 'Web',
            str(output / 'index.html')], stdout=log, stderr=subprocess.STDOUT)
    print(result.returncode, output)
finally:
    project.write_bytes(original_project)
    preset.write_bytes(original_preset)
