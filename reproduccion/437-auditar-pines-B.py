from pathlib import Path
import hashlib
import json
import subprocess

root = Path.cwd()
proof = Path('C:/Users/fede_/AppData/Local/Temp/nosefia-watch-429-444/437-verde-02')
pre = json.loads((proof/'pins-pre/manifest.json').read_text(encoding='utf-8'))
post = json.loads((proof/'pins-post/manifest.json').read_text(encoding='utf-8'))
assert pre == post, 'La fuente cambió durante el focal'
head = subprocess.check_output(['git','rev-parse','HEAD'], cwd=root).decode().strip()
assert head == '838e0baae3ed7f61f6f3190a00058a5d6c10b503'
items = []
for item in pre['files']:
    path = item['path']
    pin = (proof/'pins-pre/files'/path).read_bytes()
    assert hashlib.sha256(pin).hexdigest() == item['sha256']
    pinned_blob = subprocess.check_output(['git','hash-object','--path',path,'--stdin'], input=pin, cwd=root).decode().strip()
    committed_blob = subprocess.check_output(['git','rev-parse',head+':'+path], cwd=root).decode().strip()
    assert pinned_blob == committed_blob, path
    items.append({'path':path,'git_blob':committed_blob,'raw_pin_sha256':item['sha256']})
assert len(items) == 40
record = {'head':head,'head_before_focal':pre['head'],'pre_post_identical':True,'committed_blobs_match_all_40_pinned_files':True,'git_filters_applied_for_canonical_blob_comparison':True,'files':items}
dest = Path('D:/nosefia-carril-B-429-444/437-revision-pines-B.json')
dest.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
print(str(dest))
print('40/40 pinned files == committed blobs; pre == post')
