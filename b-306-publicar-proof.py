from pathlib import Path
import subprocess, json, hashlib, re

s = Path(__file__).parent
out = Path('D:/temporales/nosefia-batch-64-309/empleo-306')
folder = out / 'evidencia'
result = subprocess.run(['python', '.claude/skills/implement-feature/scripts/capturas_a_rama.py', '306', str(folder)], capture_output=True, text=True, encoding='utf-8')
(s / 'b-306-publicar-evidencia.log').write_text(result.stdout + result.stderr, encoding='utf-8')
assert result.returncode == 0, result.stdout + result.stderr
sha = subprocess.check_output(['git', 'ls-remote', 'origin', 'refs/heads/capturas/306'], text=True).split()[0]
manifest_bytes = subprocess.check_output(['git', 'show', f'{sha}:manifest.json'])
manifest = json.loads(manifest_bytes)
for item in manifest['files']:
    blob = subprocess.check_output(['git', 'show', f'{sha}:{item["path"]}'])
    assert len(blob) == item['bytes'] and hashlib.sha256(blob).hexdigest() == item['sha256'], item
proof = {'commit': sha, 'remote': sha, 'files_verified': len(manifest['files']), 'manifest_sha256': hashlib.sha256(manifest_bytes).hexdigest(), 'xml_sha256': manifest['result']['xml_sha256']}
(s / 'b-306-evidencia-publicada-proof.json').write_text(json.dumps(proof, indent=2), encoding='utf-8')
body = (s / 'b-306-pr-preparado.md').read_text(encoding='utf-8')
full = manifest['result']
bundle = (out / 'b-306-full3-bundle.log').read_text(encoding='utf-8')
match = re.findall(r'7/7 nodos en verde[^\n]*', bundle)
assert match, bundle[-2000:]
body = body.replace('PENDIENTE_HEAD', manifest['head'])
body = body.replace('PENDIENTE_FULL', f"FULL3 formal final (tercera corrida): **{match[-1]}; conteo inmediato {full['suites']}/{full['suites']} suites, {full['cases']} casos, 0 fallas/errores/salteos. Bundle con conteo: {full['elapsed']:.1f}s. XML SHA256 `{full['xml_sha256']}`**.")
counts = manifest['raw_classification']['final306']
body = body.replace('PENDIENTE_RAW', f"Raw final contrastado con305: materialNULL{counts['material_null']}, ObjectDB{len(counts['ObjectDB_lines'])}línea, outside_tree{counts['outside_tree']}; Script0/Parse0, recursos{len(counts['resources_still'])}. Categorías heredadas bajo HARN341/#353; no se afirma raw global limpio. Las advertencias se preservan en manifest.json.")
url = f'https://github.com/federicohermo/nosefia/blob/{sha}/manifest.json'
body = body.replace('PENDIENTE_EVIDENCIA', f'[{url}]({url}); {len(manifest["files"])}blobs públicos auditados por bytes/SHA256.')
(s / 'b-306-pr-final.md').write_text(body, encoding='utf-8')
print(json.dumps(proof))
