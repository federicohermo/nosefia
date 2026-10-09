from pathlib import Path
import json,re,hashlib
from c_decode_scn import BinaryResource
from c_pck_resources import resources
scratch=Path(__file__).parent
root=Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-64-309/c-mediciones-f17948fe')
project=root/'proyecto'
work=Path('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/.claude/worktrees/batch-64-309-c')
def read(name):
    return json.loads((scratch/name).read_text(encoding='utf8'))
def diff(before,after):
    a={e['path']:e for e in before['entries']};b={e['path']:e for e in after['entries']}
    return {'removed':sorted((a[p] for p in a.keys()-b.keys()),key=lambda e:e['bytes'],reverse=True),'added':sorted((b[p] for p in b.keys()-a.keys()),key=lambda e:e['bytes'],reverse=True),'modified':[{'path':p,'before':a[p],'after':b[p]} for p in sorted(a.keys()&b.keys()) if (a[p]['md5'],a[p]['bytes'])!=(b[p]['md5'],b[p]['bytes'])],'pck_delta_bytes':after['bytes']-before['bytes']}
base=read('c-pck-base.json');candidate=read('c-pck-propuesta.json')
fixedbase=read('c-pck-exclusion-base.json');fixedcandidate=read('c-pck-exclusion-propuesta.json')
preset=(root/'exclusion-base-export-presets.cfg').read_text(encoding='utf8')
assert preset==(root/'exclusion-propuesta-export-presets.cfg').read_text(encoding='utf8')
excluded=re.search(r'exclude_filter="([^"]+)"',preset)[1].split(',')[-7:]
allowed=set();sources={}
for source in excluded:
    imported=project/(source+'.import')
    text=imported.read_text(encoding='utf8')
    allowed.add(source+'.import')
    allowed.update(re.findall(r'"res://(\.godot/imported/[^"]+)"',text))
    sources[source]={'sha256':hashlib.sha256((project/source).read_bytes()).hexdigest(),'import_sha256':hashlib.sha256(imported.read_bytes()).hexdigest()}
    assert (project/source).read_bytes()==(work/source).read_bytes(),source
    assert imported.read_bytes()==(work/(source+'.import')).read_bytes(),source+'.import'
comparisons={'fix_base':diff(base,fixedbase),'fix_candidate':diff(candidate,fixedcandidate),'compression_same_preset':diff(fixedbase,fixedcandidate)}
for name in ['fix_base','fix_candidate']:
    d=comparisons[name]
    assert {e['path'] for e in d['removed']}==allowed,(name,d)
    assert not d['added'],(name,d)
    before=resources(root/('base' if name=='fix_base' else 'propuesta')/'web/index.pck')
    after=resources(root/('exclusion-base' if name=='fix_base' else 'exclusion-propuesta')/'web/index.pck')
    for modified in d['modified']:
        path=modified['path'];a=before[path];b=after[path]
        if path=='.godot/global_script_class_cache.cfg':
            def classes(data):
                return sorted(tuple(sorted(re.findall(r'"([^"]+)": ([^\n]+)',block))) for block in re.findall(r'\{([^}]+)\}',data.decode(),re.S))
            assert classes(a)==classes(b)
            modified['semantic_check']='mismos106 mapeos de clases; cambia únicamente orden'
        elif path=='.godot/uid_cache.bin':
            import struct
            def uids(data):
                count=struct.unpack_from('<I',data)[0];pos=4;items={}
                for index in range(count):
                    uid,length=struct.unpack_from('<QI',data,pos);pos+=12
                    items[uid]=data[pos:pos+length].decode();pos+=length
                assert pos==len(data)
                return items
            ua,ub=uids(a),uids(b)
            assert {ua[k] for k in ua.keys()-ub.keys()}=={'res://'+s for s in excluded}
            assert not ub.keys()-ua.keys() and all(ua[k]==ub[k] for k in ua.keys()&ub.keys())
            modified['semantic_check']='414→407: sólo siete mappings UID de recursos excluidos, sin otros cambios'
        elif path.endswith('-status_panel.scn'):
            source_scene=(project/'addons/godot_mcp/ui/status_panel.tscn').read_text(encoding='utf8')
            assert ' unique_id=' not in source_scene
            assert source_scene==(work/'addons/godot_mcp/ui/status_panel.tscn').read_text(encoding='utf8')
            da,db=BinaryResource(a).parse(),BinaryResource(b).parse()
            ids_a=da['resources'][0]['properties']['_bundled'].pop('node_ids')
            ids_b=db['resources'][0]['properties']['_bundled'].pop('node_ids')
            assert da==db and len(ids_a)==len(ids_b)==1
            assert a[:605]==b[:605] and a[609:]==b[609:]
            modified['semantic_check']={'field':'_bundled.node_ids[0]','before':ids_a,'after':ids_b,'all_other_bytes_identical':True,'source_has_authored_unique_id':False}
        else:
            raise AssertionError((name,modified))
compression=comparisons['compression_same_preset']
assert len(compression['removed'])==len(compression['added'])==len(compression['modified'])==1
assert 'fondo_ventanilla.png' in compression['removed'][0]['path'] and 'fondo_ventanilla.png' in compression['added'][0]['path']
assert compression['modified'][0]['path']=='assets/ui/manada/fondo_ventanilla.png.import'
result={'base':'444d05db','pre_fix_base':'f17948fe','preset_sha256':hashlib.sha256(preset.encode()).hexdigest(),'excluded_files_preserved':sources,'comparisons':comparisons,'all_other_pck_resources_identical':True,'metadata_semantically_verified':True,'status_panel_generated_id_source':'https://raw.githubusercontent.com/godotengine/godot/master/scene/resources/packed_scene.cpp'}
(scratch/'c-exclusion-validacion.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({name:{'pck_delta_bytes':d['pck_delta_bytes'],'removed':len(d['removed']),'added':len(d['added']),'modified':len(d['modified'])} for name,d in comparisons.items()},indent=2))
