from pathlib import Path
import hashlib
import json
import re

base = Path('D:/nosefia-carril-B-429-444')
first = base/'export-final-437-444-01'
final = base/'export-final-437-444-02'
a = json.loads((first/'huellas.json').read_text(encoding='utf-8'))
b = json.loads((final/'huellas.json').read_text(encoding='utf-8'))
protocol = json.loads((final/'protocolo-B.json').read_text(encoding='utf-8'))
assert a['archivos'] == b['archivos']
assert b['commit'] == '4fa20754cd58c7f4a62699183a4a625df3e0d90a'
assert protocol['new_437_textures_cold'] is False
ctex = []
for path in protocol['cache_present_16_ctex']:
    before = (first/'proyecto'/path.removeprefix('res://')).read_bytes()
    after = (final/'proyecto'/path.removeprefix('res://')).read_bytes()
    assert before == after, path
    ctex.append({'path':path,'sha256':hashlib.sha256(after).hexdigest()})
assert len(ctex) == 16
logs = {}
for label in ['importar','exportar','probe437','probe444']:
    raw = (final/(label+'.log')).read_text(encoding='utf-8',errors='strict')
    clean = re.sub(r'\x1b\[[0-9;]*[A-Za-z]','',raw)
    errors = [line for line in clean.splitlines() if re.search(r'SCRIPT ERROR|Parse Error|(^|\s)ERROR:|ObjectDB instances|resources still in use|Pages in use',line)]
    assert not errors, (label,errors)
    logs[label] = {'errors':errors,'orphan_string_names':clean.count('Orphan StringName:'),'sha256':hashlib.sha256((final/(label+'.log')).read_bytes()).hexdigest()}
assert 'SPRITES437_PCK_OK' in (final/'probe437.log').read_text(encoding='utf-8')
assert 'PAQUETE444_FINAL fallos=0' in (final/'probe444.log').read_text(encoding='utf-8')
result = {'head':b['commit'],'own_437_head':protocol['own_437_head'],'40_source_blobs_437_identical':len(protocol['40_blobs_437_identical'])==40,'19_product_files_437_unchanged_after_export':len(protocol['after_export_19_product_files_byte_identical_to_head'])==19,'four_web_artifacts_byte_identical_01_02':True,'ctex_16_byte_identical_01_02':ctex,'cold_claim':'01:16newtextures absent before import;02:cached continuity, no second cold claim','files':b['archivos'],'logs':logs,'final_markers':['SPRITES437_PCK_OK','PAQUETE444_FINAL fallos=0'],'pending':['root shared full all7 nodes','root real native/Web captures afterdraw']}
(final/'revision-B.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'head':result['head'],'logs':logs,'PCK':b['archivos']['index.pck'],'all_four_artifacts_equal':True,'ctex_identical':16},ensure_ascii=False,indent=2))
