import json, os, subprocess, sys
from pathlib import Path

scratch=Path(__file__).parent
out=scratch/'geometria-verde-07'
out.mkdir(exist_ok=True)
sys.path.insert(0,str(Path.cwd()/'.claude/scripts'))
from lib.godot import resolver
godot,origen=resolver(dict(os.environ))
assert godot
cmd=[godot,'--headless','--path',str(Path.cwd()),'--script','res://.github/scripts/generar_volumenes_para_colilla.gd','--',str(out/'volumenes-regenerados.json')]
with (out/'generador.log').open('wb') as log:
    code=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=120).returncode
(out/'generador-comando.json').write_text(json.dumps({'cmd':cmd,'codigo':code,'godot_origen':origen},indent=2),encoding='utf8')
assert code==0,'Generador rojo'
previo=json.loads((scratch/'volumenes-propuestos.json').read_text(encoding='utf8'))
real=json.loads((out/'volumenes-regenerados.json').read_text(encoding='utf8'))
assert real.keys()==previo.keys()
comparacion=[]
for ruta in real:
    assert len(real[ruta])==len(previo[ruta]),ruta
    pendientes=previo[ruta].copy()
    for forma in real[ruta]:
        for indice,candidata in enumerate(pendientes):
            if len(forma)!=len(candidata):continue
            delta=max(min(max(abs(a-b) for a,b in zip(p,q)) for q in candidata) for p in forma)
            if delta<0.000001:break
        else:raise AssertionError('No coincide regeneración '+ruta)
        pendientes.pop(indice)
        comparacion.append({'ruta':ruta,'vertices':len(forma),'delta_maximo':delta})
(out/'regeneracion.json').write_text(json.dumps(comparacion,indent=2),encoding='utf8')
cmd=[sys.executable,str(scratch/'focal-verbose.py'),str(out),'test/escenas/volumen_de_los_solidos_test.gd','test/escenas/iluminacion_horneada_test.gd','test/escenas/pistas_de_la_segunda_jornada_test.gd']
raise SystemExit(subprocess.run(cmd).returncode)
