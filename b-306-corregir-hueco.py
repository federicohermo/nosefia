from pathlib import Path
import subprocess, json, hashlib
root=Path.cwd(); s=Path(__file__).parent
p=s/'306-whole-final.md'; t=p.read_text(encoding='utf-8')
old='Las pruebas derivan tres soltadas de los bordes libres del hueco (ambos lados y arriba del vidrio), afirman su premisa y verifican apoyo estable; no fijan distancias decorativas ni introducen un piso duplicado.'
new='Las pruebas derivan dos soltadas por ambos laterales físicamente libres del hueco, a partir del vidrio, las jambas y la forma real del objeto; afirman su premisa y verifican apoyo estable. No existe un paso superior: vidrio entre1,04y2,44m y dintel compuesto desde≈2,440001m dejan sólo holgura numérica. Se retira el tercer caso arriba del vidrio, sin sustituirlo por un tiro sobre el techo ni un punto artificial. No fijan distancias decorativas ni introducen un piso duplicado.'
assert old in t; t=t.replace(old,new)
t+='\n## Corrección de la premisa del hueco vigente\n\nLa lectura sobre11301e9d de Ventanilla/Vidrio y almacen/Volumen/local_ventanilla_alto compone sus transforms y verifica vidrio[1,04;2,44] y cara inferior del dintel≈2,440001. Esa holgura numérica no deja pasar ningún cuerpo. Se conserva el arte y se prueban únicamente los dos laterales libres; el comentario heredado que citaba2,84m se corrige como premisa histórica obsoleta. El contrato originalSPECfirst3a0c3b9b permanece en la historia; este ajuste normativo precede tests y fuente de soporte.\n'
p.write_text(t,encoding='utf-8',newline='\n')
subprocess.run(['gh','issue','edit','306','--body-file',str(p)],check=True)
body=json.loads(subprocess.check_output(['gh','issue','view','306','--json','body'],text=True,encoding='utf-8'))['body']
assert body.replace('\r\n','\n').strip()==t.strip()
(s/'b-306-whole-hueco-readback.json').write_text(json.dumps({'whole_readback_exact':True,'sha256_normalized':hashlib.sha256(body.replace('\r\n','\n').strip().encode()).hexdigest(),'lateral_drops':2,'upper_gap_is_numeric_only':True},indent=2),encoding='utf-8')
p=root/'specs/store-cleanup/store-cleanup.md';t=p.read_text(encoding='utf-8')
old='el pavimento y puede recogerse dentro del alcance vigente.'
assert old in t
t=t.replace('hueco real de ventanilla, a ambos lados y arriba del vidrio, ENTONCES cae, se apoya estable en\nel pavimento y puede recogerse dentro del alcance vigente.', 'hueco real de ventanilla por ambos laterales libres, derivados del vidrio, las jambas y la\nforma del cuerpo, ENTONCES cae, se apoya estable en el pavimento y puede recogerse dentro del\nalcance vigente. El espacio numérico entre vidrio y dintel no constituye un paso superior.')
p.write_text(t,encoding='utf-8',newline='\n')
p=root/'test/escenas/almacen_test.gd';t=p.read_text(encoding='utf-8').replace('El hueco medido va de 1,04 a 2,84 m, así que los dos caen bien adentro.', 'El hueco vigente va de 1,04 a 2,44 m: arriba del vidrio empieza el dintel.\n## La lectura superior prueba el vano de la cáscara sin interpretar una abertura sobre el vidrio.');p.write_text(t,encoding='utf-8')
