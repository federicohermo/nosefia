from pathlib import Path
import json,re,struct
scratch=Path(__file__).parent
project=Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-64-309/c-mediciones-f17948fe/proyecto')
removed=json.loads((scratch/'c-pck-diff-seleccion.json').read_text())['removed']
import_map={}
for p in project.glob('assets/**/*.import'):
    text=p.read_text(encoding='utf8')
    source=re.search(r'source_file="([^"]+)"',text)
    if source:
        for dest in re.findall(r'"res://(\.godot/imported/[^"]+)"',text):
            import_map[dest]=source[1]
references={}
for pattern in ('src/**/*.gd','src/**/*.tscn','src/**/*.tres','assets/**/*.tres','assets/**/*.gd'):
    for p in project.glob(pattern):
        for ref in re.findall(r'"(res://[^"]+)"',p.read_text(encoding='utf8')):
            references.setdefault(ref,[]).append(p.relative_to(project).as_posix())
glb=project/'assets/models/SEPT_JUEGOS_PROTOTIPO.glb'
data=glb.read_bytes();length,kind=struct.unpack_from('<II',data,12)
gltf=json.loads(data[20:20+length])
images=[{'name':image.get('name'),'uri':image.get('uri'),'bufferView':image.get('bufferView')} for image in gltf.get('images',[])]
result=[]
for entry in removed:
    if entry['bytes']<10000:
        continue
    source=import_map.get(entry['path'])
    result.append({**entry,'source':source,'literal_references':references.get(source,[])})
(scratch/'c-retirados-por-origen.json').write_text(json.dumps({'entries':result,'model_images':images},ensure_ascii=False,indent=2),encoding='utf8')
required={ref for ref in references if (project/ref.removeprefix('res://')).is_file()}
for pattern in ('src/**/*.gd','src/**/*.tres','src/**/*.tscn','src/**/*.gdshader','assets/**/*.res','assets/**/*.tres'):
    required.update('res://'+p.relative_to(project).as_posix() for p in project.glob(pattern))
(scratch/'c-recursos-literales.json').write_text(json.dumps(sorted(required),ensure_ascii=False,indent=2),encoding='utf8')
for entry in result[:20]:
    print(entry['bytes'],entry['source'],entry['literal_references'])
print('model images',len(images),'embedded',sum(i['bufferView'] is not None for i in images))
