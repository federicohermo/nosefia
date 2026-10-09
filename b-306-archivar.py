from pathlib import Path
import json, subprocess, hashlib

s = Path(__file__).parent
out = Path('D:/temporales/nosefia-batch-64-309/empleo-306')
result = json.loads((out / 'b-306-full3-resultados.json').read_text(encoding='utf-8'))
assert result['code'] == result['count_code'] == 0
assert result['failures'] == result['errors'] == result['skipped'] == 0
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
assert result['head'] == head
assert not subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()
diagnostics = {}
for label, path in [('base305', s / 'b-305-full2-tests-crudo.log'), ('final306', out / 'b-306-full3-tests-crudo.log')]:
    raw = path.read_text(encoding='utf-8')
    diagnostics[label] = {
        'material_null': raw.count('ERROR: Parameter "material" is null.'),
        'ObjectDB_lines': [line for line in raw.splitlines() if 'ObjectDB' in line],
        'resources_still': [line for line in raw.splitlines() if 'resources still in use' in line],
        'outside_tree': raw.count('ERROR: Condition "!is_inside_tree()" is true.'),
        'script_errors': raw.count('SCRIPT ERROR'), 'parse_errors': raw.count('Parse Error'),
        'warnings': [line for line in raw.splitlines() if 'WARNING:' in line],
    }
assert diagnostics['final306']['script_errors'] == diagnostics['final306']['parse_errors'] == 0
dest = out / 'evidencia'
dest.mkdir(parents=True, exist_ok=True)
paths = [p for directory in [s, out] for p in directory.glob('b-306-*') if p.is_file() and p.suffix in {'.log', '.xml', '.json', '.py', '.gd', '.diff'}]
paths += [s / name for name in ['306-whole-final.md', 'padre-verificar-con-log.py']]
paths += list(out.glob('b-306-whole-*.md'))
paths += list(s.glob('padre-306-whole-*.md')) + list(s.glob('padre-306-whole-*.proof.json'))
paths += list(out.glob('padre-306-verde5-*'))
paths += list((Path.cwd() / '.godot/b306-diagnostico').glob('*.gd'))
files = []
for path in sorted(paths):
    data = path.read_bytes()
    # Use the very same plumbing as capturas_a_rama, including Git's newline conversion.
    blob_id = subprocess.check_output(['git', 'hash-object', '-w', str(path)], text=True).strip()
    canonical = subprocess.check_output(['git', 'cat-file', 'blob', blob_id])
    (dest / path.name).write_bytes(canonical)
    files.append({'path': path.name, 'sha256': hashlib.sha256(canonical).hexdigest(), 'bytes': len(canonical), 'blob': blob_id, 'local_sha256': hashlib.sha256(data).hexdigest(), 'local_bytes': len(data)})
final_xml = next(item for item in files if item['path'] == 'b-306-full3-results.xml')
assert final_xml['sha256'] == result['xml_sha256']
manifest = {'issue': 306, 'base': '11301e9df6fd2510b4fa2ff1c0fd6db9d25fe963', 'head': head, 'formal_final_full': 3, 'first_formal_full_failed': {'suites': 214, 'cases': 1670, 'assertions': 12, 'errors': 0}, 'second_formal_full_failed': {'suites': 214, 'cases': 1671, 'assertions': 1, 'errors': 0, 'xml_sha256': '29a93f2a58e321771d51187e706b344458a521d74ff06409123fc836e0ce20e9'}, 'diagnostic_copies_not_final_proof': True, 'aborted_nonproof_invocation': 'b-306-invocacion-help-abortada.json', 'result': result, 'raw_classification': diagnostics, 'byte_basis': 'SHA256 and bytes of canonical Git blobs, verified again after publication; local bytes retained only as provenance.', 'files': files}
(dest / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8', newline='\n')
(out / 'b-306-full3-auditoria.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8', newline='\n')
print(json.dumps({'folder': str(dest), 'files': len(files), 'raw': diagnostics}, ensure_ascii=False, indent=2))
