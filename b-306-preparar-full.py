from pathlib import Path
import subprocess, json, hashlib, re, datetime

root = Path.cwd()
scratch = Path(__file__).parent
baseline = '11301e9df6fd2510b4fa2ff1c0fd6db9d25fe963'
changed = subprocess.check_output(['git', 'diff', '--name-only', baseline], text=True).splitlines()
new = subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard'], text=True).splitlines()
files = sorted(set(changed + new))
pattern = re.compile(r'con_apercibimientos|Campo\.APERCIBIMIENTOS|"apercibimientos"')
rows = []
for folder in ['src', 'test', 'specs', 'docs', '.claude']:
    for path in (root / folder).rglob('*'):
        if not path.is_file() or any(part in path.relative_to(root).parts for part in ['.git', 'worktrees', 'scratch']):
            continue
        if path.suffix not in ['.gd', '.md', '.py', '.tscn', '.json']:
            continue
        for line, content in enumerate(path.read_text(encoding='utf-8', errors='replace').splitlines(), 1):
            if pattern.search(content):
                rows.append({'file': path.relative_to(root).as_posix(), 'line': line, 'content': content})
assert all(row['file'] == 'test/sistemas/marco/guardado_test.gd' and '"apercibimientos"' in row['content'] for row in rows), rows
public = {}
for file in files:
    path = root / file
    if path.suffix == '.gd':
        public[file] = len(re.findall(r'^(?:static )?func [a-z]', path.read_text(encoding='utf-8'), re.M))
proof = {'base': baseline, 'head_at_audit': subprocess.check_output(['git','rev-parse','HEAD'], text=True).strip(), 'files': files, 'count': len(files), 'retired_api_matches': rows, 'public_methods': public, 'created': str(datetime.datetime.now(datetime.timezone.utc))}
(scratch / 'b-306-alcance-y-barrido.json').write_text(json.dumps(proof, indent=2, ensure_ascii=False), encoding='utf-8')
source = (scratch / 'b-305-full2.py').read_text(encoding='utf-8').replace('b-305-full2', 'b-306-full1')
dest = scratch / 'b-306-full1.py'
if not dest.exists():
    dest.write_text(source, encoding='utf-8')
(scratch / 'b-306-invocacion-help-abortada.json').write_text(json.dumps({'command': 'python .claude/scripts/verificar.py --help', 'result': 'aborted; unknown flag ran nodes; no verification evidence accepted', 'pids_stopped': [108604, 106160, 91488, 37996], 'scope': 'only own processes; no source edit while active', 'correction': 'read CLI source; explicit --solo or final full through FIFO'}, indent=2), encoding='utf-8')
print(json.dumps(proof, ensure_ascii=False))
