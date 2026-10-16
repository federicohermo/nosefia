import json,re,subprocess
from pathlib import Path
s=Path(__file__).parent
ids=[f'AC-INV-{n:03}' for n in range(43,56)]+['AC-EMP-069','AC-INV-028']
matriz={i:[] for i in ids}
for p in sorted(Path('test').rglob('*_test.gd')):
    lineas=p.read_text(encoding='utf8').splitlines()
    if not any(i in '\n'.join(lineas) for i in ids):continue
    anterior=subprocess.run(['git','show','6d60f82c16bbbc1f7182e656ebead8df8bf5ad87:'+p.as_posix()],capture_output=True)
    base=anterior.stdout.decode('utf8',errors='replace') if anterior.returncode==0 else ''
    for n,l in enumerate(lineas,1):
        m=re.match(r'func (test_\w+)\(',l)
        if not m:continue
        for i in ids:
            if i in l:
                matriz[i].append({'ruta':p.as_posix(),'linea':n,'caso':m[1],'nuevo_en22':('func '+m[1]+'(') not in base,'limite':'Una cita heredada conserva regresión; sólo los casos nuevos prueban el delta22.'})
assert all(matriz.values())
(s/'matriz-ac-entrega.json').write_text(json.dumps({'head':'fb4236e69c752e6879bb338b80e734e16b211b41','dueño':22,'criterios':matriz},ensure_ascii=False,indent=2),encoding='utf8')
print('15 AC con dueño22; citas nuevas/heredadas diferenciadas.')

inc=json.loads((s/'incidentes-montaje.json').read_text(encoding='utf8'))
inc['incidentes'].extend([
 {'intento':'geometria06','hecho':'El guardia de regeneración detectó hasta4.52e-5 entre vértices GLB e importados por Godot. No llegaron a correr suites.','correccion':'Se conservaron ambos datos y se aplicó salida del generador sobre malla Godot vigente, manteniendo tolerancia1e-6. Geometría07 y09 regeneraron delta0.'},
 {'intento':'geometria07','hecho':'Volumen y nuevo oráculo interior pasaron. GI seguía estático por escritura1; la constante real DYNAMIC es2. Cuatro errores UV2 y cinco fallos (cuatro nuevos GI) conservados.','correccion':'Fuente y resultado usan2; test con enum sin cambios pasó en09.'},
 {'intento':'geometria08','hecho':'Quoting de Python en PowerShell impidió crear wrapper; turno salió2 en0s sin iniciar motor.','correccion':'Wrapper09 creado con lectura/escritura nativa antes de encolar; resultado09 verde.'},
 {'intento':'auditoría geometría09 primera invocación','hecho':'Escape duplicado en regex de consola provocó error del auditor estático.','correccion':'ArchivoPython explícito con split de líneas; revisión posterior válida conservada. No se presentó aquel error como fallo del producto.'}
])
(s/'incidentes-final.json').write_text(json.dumps(inc,ensure_ascii=False,indent=2),encoding='utf8')
