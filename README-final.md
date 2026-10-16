# Góndolas por sectores — entrega final de #434

Fuente final: `d647a2031f5e6ad3862a286ce042b680eaeb8e18`. Base: #428 `3e381d1be90e30589e9c7b38905199a576c43201`.
Los32productos conservan su identidad. Cindolor va a la segunda heladera; Oaaaa y Terminator
van a la cabecera sin frío. Duronga permanece exhibida, provisionalmente, según el mapa y
el comentario completo de Tiago del 15/10/2026 a 18:25:14.413UTC. La consulta completa está
en `entrega-final/procedencia-duronga`; la URL firmada temporal de descarga se omite.

Actroncito y Prongles conservan sus dos hileras ya existentes: la corrección es del contrato
antiguo y del reparto por sectores. No se convierten universalmente todos los productos a
dos filas. Se conserva la lista de cinco y las excepciones por tanda de Amargadito, Fernet
y Oaaaa. No se cambian muebles, alturas ni niveles; OQ-STK-007 sigue fuera de este alcance.

## Verificación definitiva

Segunda completa: **7/7 nodos, 270/270 suites y2080/2080 casos**, 0 fallos, errores, skips,
flaky y huérfanos, en 952.4 s. XML, conteo inmediato, los ocho crudos y revisión ROOT están
en `entrega-final/convergencia`. No hay Script/Parse Error ni fugas. Los 73 diagnósticos se
comparan con 73 del control428: siete cambios de pose/clase de rescate se preservan completos.
Sólo se normalizan contadores @N; no se infiere fase ni causa por concatenar stdout/stderr.
El unittest del harness tiene su skip heredado por plataforma; ningún nodo está salteado.
El spec STK queda ratified, 59/59 criterios citados.

El focal del mapa pasó 77/77 casos. La primera completa se conserva roja: 10 aserciones en
dos tests del borde, 0errores de script/fugas. El fixture seguía a Saladik, que el mapa mueve
a la cabecera opuesta. La corrección localiza el borde frontal reportado por la malla,
mantiene piso y cápsula libres y recoge desde la misma postura de soltar. Conserva gesto,
ambos tamaños, metal visible/físico, 180 cuadros, recogida, inventario/tareas y umbrales.
El focal final del borde pasó 18/18; sus tres focales anteriores y sondas quedan como
incidentes. Observer 02 se rechazó por retención; 03/04 terminaron limpios. La invocación 03
que no pudo crear su script no cuenta como sonda del motor. No hubo cambio de producción.

## Imágenes y procedencia

ROOT abrió las 22 PNG nativas finales (`entrega-final/nativo`) y las 22 PNG web del mapa
(`entrega-final/web-mapa-e-incidente-real01`), once sectores a 1280×720 y 1920×1080.
Son cámaras de observación del almacén real en jornada 2, no prueba de caminar por todos
los sectores. Las suites ejercen alcance e interacción. El primer encuadre nativo cortaba
tres sectores arriba; se conserva y la cámara final abre sólo esos tres encuadres.

La exportación Web usa una instantánea externa del commit29fdc763. El PCK real se exporta
primero, con proyecto, preset y plugins originales. La sonda `--main-pack`, fuera del proyecto,
verifica32mallas/materiales, principales positivas y Duronga exhibida, sin errores/fugas.
Otro PCK cambia sólo la escena principal y agrega la cámara diagnóstica en esa copia.
Los paquetes tienen hashes separados en `entrega-final/export-web/manifiesto02.json`.
Desde 29fdc763 hasta la fuente final sólo cambian el estado del spec y el fixture del borde;
ningún recurso ni código del juego. Lo prueba `revision-visual-root-final.json`.

Chrome 01 conjunto terminó 1 por dos pageerror de pointer lock en el contexto real; no se
declara verde. Su contexto diagnóstico tuvo 0 errores y las22vistas del mapa. Chrome real 02
repite con foco y mouse capturado afirmados: termina 0, sin errores, con el checkpoint real
de Partida J2 precargado desde HTML, sin modificar PCK/main. La entrada a 1920 es legible;
el desplazamiento termina mirando un paredón, y esas últimas dos PNG son diagnóstico,
no fotos de sectores. Los videos, consolas y límites de tiempo se conservan.
El primer export retuvo 162 instancias/111 recursos y fue rechazado. La repetición verbosa,
sin cambios, salió limpia y produjo los mismos cuatro archivos. Ambos registros se conservan.

## Generador y arte

Se conserva la escala local RNA del artista al reparentar/escribir matrices sobre los
marcos rígidos medidos. No hay redondeos nuevos, metadatos ocultos ni cambio de ángulos.
El TDD de la misma fuente original compara el acomodador c780 con la corrección:7 fallos
esperados antes, 32 unidades estables después. Las dos pasadas completas conservaron 40 outputs
cada una; ROOT verificó los 80 archivos y sus hashes. Los cuatro textos y 32 RES son byteidénticos.
La estructura es byteidéntica a 428. Cada pasada conserva su blend, GLB, huella y unwrap aparte.

El pipeline comparativo original terminó 1 por bytes GLB distintos; no se convierte ese
exit en 0 ni se afirma idempotencia de todos los binarios. La comparación demuestra 255 nodos
y transformaciones, 222 mallas con índices/POSITION/NORMAL, las 97 imágenes y todos los materiales iguales;
todo el JSON y metadatos de 994 accessors son iguales. Sólo difieren UV0/UV1 de muebles/vanitory, 
máximo observado 2.384185791e-7, ningún producto. Es la variación del exportador ya documentada
en `blender/exportar.py` de 0989 y en `exportar_modelo.py` paso4; no se introduce tolerancia.
El intento anterior c780 conserva sus hashes y ambos GLB; no se afirma recuperar tres textos
que no se copiaron entonces. La generación final sí conserva todos los outputs de ambas pasadas.

## Compatibilidad con #367 y otras historias

Unión efímera `6eff3f59cc08a175df0a64d21a6667a789c56ad7` con367
`43e3e0ad79f664665afbe7939c3cfcd8bd093183`: **9/9 suites, 66/66 casos**, sin errores/fugas,
en `entrega-final/compatibilidad367/focal04`. Conserva API de cuatro argumentos, compradores
compartidos, 200 semillas J1-J5, guías llenas e interactivas y principal 0 inelegible aunque tenga
guía. Un fixture genérico de Poético sin principal mantiene total positivo y ciclo real de
foco/clic/agarrar/reponer;  no redefine la exhibición real de Poético ni Duronga.
Se conservan ambos specs y el parche de unión. No es un full ni un PR de la unión, y no se
mergea367 al lote. El primer focal comparaba objetos nuevos de Catalogo como si fueran
canónicos; se corrigió a identidad por Id. El segundo falló sólo por el fixture de cabecera.
El tercero se preparó y nunca se encoló; el cuarto es el definitivo.

Siguen registradas las tres colisiones posteriores con 2607fb2b de la historia444:
BR-STK-043, AC-STK-085 y AC-STK-086. #434 conserva sus reservas anteriores. El escenario
extranjero con Duronga 0 es condicional, no una orden de quitarla del mapa actual.
Ambas ampliaciones requieren IDs únicos cuando se integren; no se sobrescribe la rama ajena.

Los 90 blobs de `cc2226d9` permanecen byteidénticos. Sus imágenes son comparación histórica,
no esta entrega final. Los hashes locales anteriores a normalizar LF se distinguen de los
bytes publicados en `entrega-final/procedencia-bytes-locales.json`.
