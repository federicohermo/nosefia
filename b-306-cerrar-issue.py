from pathlib import Path
import subprocess, json, hashlib

s = Path('C:/Users/fede_/orca/workspaces/nosefia/darter/.claude/scratch/batch-64-309')
out = Path(__file__).parent
full = json.loads((out / 'b-306-full3-resultados.json').read_text(encoding='utf-8'))
assert full['code'] == full['count_code'] == full['errors'] == full['failures'] == full['skipped'] == 0
current = json.loads(subprocess.check_output(['gh', 'issue', 'view', '306', '--json', 'body'], encoding='utf-8'))['body']
authorized = (s / 'padre-306-whole-carga-minima.md').read_text(encoding='utf-8')
assert current.strip() == authorized.strip(), 'Issue changed since authorized whole body'
assert current.count('- [ ]') == 19, current.count('- [ ]')
body = current.replace('- [ ]', '- [x]')
path = out / 'b-306-issue-cumplido.md'; path.write_text(body, encoding='utf-8', newline='\n')
subprocess.run(['gh', 'issue', 'edit', '306', '--body-file', str(path)], check=True)
readback = json.loads(subprocess.check_output(['gh', 'issue', 'view', '306', '--json', 'body'], encoding='utf-8'))['body']
assert readback == body
proof = {'head': full['head'], 'issue': 306, 'criteria': 19, 'body_sha256': hashlib.sha256(body.encode()).hexdigest(), 'readback_exact': True}
(out / 'b-306-issue-cumplido-proof.json').write_text(json.dumps(proof, indent=2), encoding='utf-8')
print(json.dumps(proof))
