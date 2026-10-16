import hashlib
import json
from pathlib import Path
import re
import subprocess

p=Path(__file__).parent
out=p/'434-entrega-final'
new=out/'entrega-final'
manifest=new/'procedencia-bytes-locales.json'
records=json.loads(manifest.read_bytes())
head='d647a2031f5e6ad3862a286ce042b680eaeb8e18'
runtime='29fdc763871c5833b9d28b5c6d71d71d3aeac03f'
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==head
assert not subprocess.check_output(['git','status','--porcelain']).strip()
full=json.loads((p/'434-full02/revision-root.json').read_bytes())
assert full['head']==head and full['exit_verificar']==full['exit_conteo']==0
assert full['suites']==270 and full['casos']==2080 and not full['script_parse_fugas']
changed=subprocess.check_output(['git','diff','--name-only',runtime,head],text=True).splitlines()
assert changed==['specs/store-stock/store-stock.md','test/escenas/objetos/apoyos_de_bordes_de_cajas_test.gd']
visual=json.loads((p/'434-revision-visual-root.json').read_bytes())
visual['head_final']=head
visual['diferencias_desde_runtime']=changed
visual.pop('diferencia_solo_estado_spec')
visual['limite']+=' Entre29fdc763 y d647a203 sólo cambian estado del spec y fixture del borde; ningún recurso ni código del juego.'
(p/'434-revision-visual-root-final.json').write_bytes(json.dumps(visual,ensure_ascii=False,indent=2).encode())
def copy_file(src,dst):
    original=src.read_bytes()
    published=original
    if src.suffix in {'.py','.gd','.md','.json','.log','.xml','.txt'}:
        original.decode('utf-8')
        published=original.replace(b'\r\n',b'\n')
    rel=dst.relative_to(out).as_posix()
    assert not any(x['publicado']==rel for x in records),rel
    dst.parent.mkdir(parents=True,exist_ok=True)
    dst.write_bytes(published)
    records.append({'local':str(src),'publicado':rel,'sha256_local':hashlib.sha256(original).hexdigest(),'sha256_publicado':hashlib.sha256(published).hexdigest(),'normalizado_lf':original!=published})
for f in (p/'434-full02').rglob('*'):
    if f.is_file():
        copy_file(f,new/'convergencia'/f.relative_to(p/'434-full02'))
copy_file(p/'434-revision-visual-root-final.json',new/'revision-visual-root-final.json')
copy_file(Path(__file__),new/'protocolo/434_finalizar_paquete.py')
spec=Path('specs/store-stock/store-stock.md').read_text(encoding='utf-8')
ids=set(re.findall(r'^### (AC-STK-\d{3})',spec,re.M))
cited=set()
for folder in ['test','.claude/scripts/tests']:
    for f in Path(folder).rglob('*'):
        if f.suffix in ['.gd','.py']:
            cited.update(re.findall(r'AC-STK-\d{3}',f.read_text(encoding='utf-8')))
assert len(ids)==59 and ids<=cited
readme=f'''# Góndolas por sectores — entrega final de #434

Fuente final: `{head}`. Base: #428 `{ '3e381d1be90e30589e9c7b38905199a576c43201' }`.
Los32productos conservan su identidad. Cindolor va a la segunda heladera; Oaaaa y Terminator
van a la cabecera sin frío. Duronga permanece exhibida, provisionalmente, según el mapa y
el comentario completo de Tiago del15/10/2026 a18:25:14.413UTC. La consulta completa está
en `entrega-final/procedencia-duronga`; la URL firmada temporal de descarga se omite.

Actroncito y Prongles conservan sus dos hileras ya existentes: la corrección es del contrato
antiguo y del reparto por sectores. No se convierten universalmente todos los productos a
dos filas. Se conserva la lista de cinco y las excepciones por tanda de Amargadito, Fernet
y Oaaaa. No se cambian muebles, alturas ni niveles; OQ-STK-007 sigue fuera de este alcance.

## Verificación definitiva

Segunda completa: **7/7 nodos,270/270suites y2080/2080casos**,0fallos,errores,skips,
flaky y huérfanos, en952.4s. XML, conteo inmediato, los ocho crudos y revisión ROOT están
en `entrega-final/convergencia`. No hay Script/Parse Error ni fugas. Los73diagnósticos se
comparan con73del control428: siete cambios de pose/clase de rescate se preservan completos.
Sólo se normalizan contadores@N; no se infiere fase ni causa por concatenarstdout/stderr.
El unittest del harness tiene su skip heredado por plataforma; ningún nodo está salteado.
El spec STK queda ratified,59/59criterios citados.

El focal del mapa pasó77/77casos. La primera completa se conserva roja:10aserciones en
dos tests del borde,0errores de script/fugas. El fixture seguía a Saladik, que el mapa mueve
a la cabecera opuesta. La corrección localiza el borde frontal reportado por la malla,
mantiene piso y cápsula libres y recoge desde la misma postura de soltar. Conserva gesto,
ambos tamaños,metal visible/físico,180cuadros,recogida,inventario/tareas y umbrales.
El focal final del borde pasó18/18; sus tres focales anteriores y sondas quedan como
incidentes. Observer02 se rechazó por retención;03/04 terminaron limpios. La invocación03
que no pudo crear su script no cuenta como sonda del motor. No hubo cambio de producción.

## Imágenes y procedencia

ROOT abrió las22PNG nativas finales (`entrega-final/nativo`) y las22PNG web del mapa
(`entrega-final/web-mapa-e-incidente-real01`), once sectores a1280×720 y1920×1080.
Son cámaras de observación del almacén real en jornada2, no prueba de caminar por todos
los sectores. Las suites ejercen alcance e interacción. El primer encuadre nativo cortaba
tres sectores arriba; se conserva y la cámara final abre sólo esos tres encuadres.

La exportación Web usa una instantánea externa del commit29fdc763. El PCK real se exporta
primero, con proyecto,preset y plugins originales. La sonda `--main-pack`,fuera del proyecto,
verifica32mallas/materiales,principales positivas y Duronga exhibida, sin errores/fugas.
Otro PCK cambia sólo la escena principal y agrega la cámara diagnóstica en esa copia.
Los paquetes tienen hashes separados en `entrega-final/export-web/manifiesto02.json`.
Desde29fdc763 hasta la fuente final sólo cambian el estado del spec y el fixture del borde;
ningún recurso ni código del juego. Lo prueba `revision-visual-root-final.json`.

Chrome01 conjunto terminó1 por dos pageerror de pointer lock en el contexto real; no se
declara verde. Su contexto diagnóstico tuvo0errores y las22vistas del mapa. Chrome real02
repite con foco y mouse capturado afirmados: termina0,sin errores,con el checkpoint real
de PartidaJ2 precargado desdeHTML, sin modificar PCK/main. La entrada1920es legible;
el desplazamiento termina mirando un paredón, y esas últimas dosPNG son diagnóstico,
no fotos de sectores. Los videos,consolas y límites de tiempo se conservan.
El primer export retuvo162instancias/111recursos y fue rechazado. La repetición verbosa,
sin cambios, salió limpia y produjo los mismos cuatro archivos. Ambos registros se conservan.

## Generador y arte

Se conserva la escala local RNA del artista al reparentar/escribir matrices sobre los
marcos rígidos medidos. No hay redondeos nuevos,metadatos ocultos ni cambio de ángulos.
El TDD de la misma fuente original compara el acomodador c780 con la corrección:7fallos
esperados antes,32unidades estables después. Las dos pasadas completas conservaron40outputs
cada una; ROOT verificó los80archivos y sus hashes. Los cuatro textos y32RES son byteidénticos.
La estructura es byteidéntica a428. Cada pasada conserva su blend,GLB,huella y unwrap aparte.

El pipeline comparativo original terminó1 por bytes GLB distintos; no se convierte ese
exit en0 ni se afirma idempotencia de todos los binarios. La comparación demuestra255nodos
y transformaciones,222mallas con índices/POSITION/NORMAL,97imágenes y materiales iguales;
todo elJSON y metadatos de994accessors son iguales. Sólo difieren UV0/UV1 de muebles/vanitory,
máximo observado2.384185791e-7,ningún producto. Es la variación del exportador ya documentada
en `blender/exportar.py` de0989 y en `exportar_modelo.py` paso4; no se introduce tolerancia.
El intento anterior c780 conserva sus hashes y ambosGLB; no se afirma recuperar tres textos
que no se copiaron entonces. La generación final sí conserva todos los outputs de ambas pasadas.

## Compatibilidad con #367 y otras historias

Unión efímera `{ '6eff3f59cc08a175df0a64d21a6667a789c56ad7' }` con367
`43e3e0ad79f664665afbe7939c3cfcd8bd093183`: **9/9suites,66/66casos**,sin errores/fugas,
en `entrega-final/compatibilidad367/focal04`. Conserva API de cuatro argumentos,compradores
compartidos,200semillas J1-J5,guías llenas e interactivas y principal0inelegible aunque tenga
guía. Un fixture genérico de Poético sin principal mantiene totalpositivo y ciclo real de
foco/clic/agarrar/reponer; no redefine la exhibición real de Poético ni Duronga.
Se conservan ambos specs y el parche de unión. No es un full ni un PR de la unión, y no se
mergea367 al lote. El primer focal comparaba objetos nuevos de Catalogo como si fueran
canónicos; se corrigió a identidad porId. El segundo falló sólo por el fixture de cabecera.
El tercero se preparó y nunca se encoló; el cuarto es el definitivo.

Siguen registradas las tres colisiones posteriores con2607fb2b de la historia444:
BR-STK-043,AC-STK-085 yAC-STK-086. #434 conserva sus reservas anteriores. El escenario
extranjero con Duronga0 es condicional, no una orden de quitarla del mapa actual.
Ambas ampliaciones requieren IDs únicos cuando se integren; no se sobrescribe la rama ajena.

Los90blobs decc2226d9permanecen byteidénticos. Sus imágenes son comparación histórica,
no esta entrega final. Los hashes locales anteriores a normalizarLF se distinguen de los
bytes publicados en `entrega-final/procedencia-bytes-locales.json`.
'''
(out/'README-final.md').write_bytes(readme.encode())
manifest.write_bytes(json.dumps(records,ensure_ascii=False,indent=2).encode())
files={f.relative_to(out).as_posix():{'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in out.rglob('*') if f.is_file() and f.name!='manifest-final.json'}
(out/'manifest-final.json').write_bytes(json.dumps({'head':head,'runtime':runtime,'criterios_stk':sorted(ids),'archivos':files},ensure_ascii=False,indent=2).encode())
print('434_PAQUETE_FINAL',len(files)+1,'archivos; fuente',head)
