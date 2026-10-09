<!-- Un issue es un plan chico y descartable: resuelve un problema puntual, con límites y
     criterios propios. Un spec es otra cosa: el contrato durable de una funcionalidad.
     Un issue cambia un spec sólo si cambia lo que el juego tiene que hacer. -->

# Un ticket se tira al inodoro con clic derecho

## Contexto

- **Objetivo:** que se cumpla una frase de la sección «Programa generador de Tickets» de la ficha 🟩 «Interfaces virtuales durante la jornada»: «Los tickets son los únicos objetos levantables que pueden desecharse en el inodoro».
- **Tipo:** `feature`
- **Spec:** modifica — `specs/counter-service/counter-service.md` y `specs/player-actions/player-actions.md`
- **Rama:** `feature/304-ticket-al-inodoro`
- **Depende del issue «El lector anota productos en el programa de tickets, y la caja registradora imprime tickets que se levantan».** Éste necesita el ticket, la caja y el puesto que aquél crea, y escribe los mismos archivos. En la pila del lote sale después de #303, desde su cabeza final certificada; su PR apunta a esa rama antes de integrar a staging.

<!-- `feature` es el único tipo que siempre toca un spec. Un `bugfix` toca uno sólo si el bug
     era una regla que nadie había escrito. La etiqueta sale del tipo: `enhancement`, `bug`,
     `refactor` o `improvement`, y `documentation` o `accessibility` cuando aplica. -->

**Base medida:** cabeza303 `db2ad6ac8a04bf1c475e7bdf348af26487bb8e4a`, PR351. Su primera verificación nativa pasó7/7 sin salteos en706,6s:204/204 suites,1602 casos, cero fallos, errores, salteos e inestables enXML. La salida cruda conserva diagnósticos globales heredados bajo corrección central; no se presenta como limpia. El índice principal atrasado se contrastó con este árbol propio.

La sonda física `a-304-fisica-base-3.log` midió ambos inodoros y lavatorios a1920×1080 y1280×720, con ocho focos y ocho montajes válidos, cero ERROR/ObjectDB/resources y desmontaje confirmado. El piso compuesto del baño está en y=0,102238m; las cuatro poses de actor se apoyan en y=0,122238m. Se reconoce el dueño de forma `VolumenDelPisoDelBano`, además del apoyo existente, sin depender sólo del nombre del collider padre. Las posiciones siguientes documentan la medición, no fijan decoración en tests:

| Artefacto existente | Sitios válidos | Actor medido (x,y,z)m |
|---|---:|---|
| inodoro |6| (10,63885;0,122238;5,071896) |
| bano_inodoro_2 |6| (12,24885;0,122238;5,071896) |
| vanitory |21| (12,4199;0,122238;2,762146) |
| bano_lavatorio_2 |14| (12,4199;0,122238;1,142146) |

La cámara está a1,822238m. La sonda afirma apoyo con normal vertical, cápsula libre, alcance, foco efectivo y proyección dentro del viewport al guardar, comparando pose global e interpolada. Las ocho PNG se abrieron y muestran el artefacto completo contorneado y el ticket en mano. Los dos diagnósticos previos encontraron cero sitios por buscar el piso en el collider padre: se conservan como preliminares, y se corrigió sólo el fixture para consultar el dueño real de la forma.

Después de este issue, el jugador lleva un ticket al baño, da clic derecho en el inodoro y el
ticket deja de existir. Los dos inodoros existentes conservan la limpieza vigente: el balde se vacía y la mopa se enjuaga (AC-CLN-029, incorporado por #300). Ningún otro levantable se desecha: producir su efecto de limpieza no hace desaparecer una herramienta.

**El gesto es el de la ficha 🟩 «5. Formas de interacción con objetos»:** usar lo que se lleva
sobre otro elemento, con clic derecho. Es el mismo con que el balde se vacía en el inodoro.

**El llamado de atención por tirar papel al inodoro no es de este issue.** Es del issue «Llamados
de atención extras», que cuenta la señal `ticket_desechado` que deja éste. La ficha no diseña un
sonido para el inodoro, y este issue no agrega ninguno.

## Criterios de aceptación

<!-- Los de este issue: binarios y con los valores que deciden. Mueren con el issue.
     Si el issue toca un spec, acá van también los `AC-<COD>-###` que agrega o cambia: ésos
     sí duran, y un test los cita. -->

- [x] El spec `counter-service` agrega la regla `BR-CTR-025`: CUANDO se usa el inodoro con un ticket en la mano, el sistema DEBE hacer que el ticket deje de existir, y la mano queda vacía. Ningún otro levantable se desecha en el inodoro.
- [x] El spec agrega AC-CTR-031 a AC-CTR-033, y los escribe `to-spec`:
  - **AC-CTR-031:** DADO dos tickets impresos CUANDO se llevan uno por vez a cada uno de los dos inodoros ENTONCES cada ticket deja de existir y la mano queda vacía, con un aviso por ticket. Repetir con la mano vacía no duplica el descarte; los renglones del programa automático o manual permanecen iguales.
  - **AC-CTR-032:** DADO una unidad, caja, mopa, balde, jabón o bolsa CUANDO se usa cualquiera de los inodoros ENTONCES permanece en la mano y no hay aviso de descarte; balde y mopa conservan su limpieza. DADO un ticket CUANDO se usa cualquiera de los dos lavatorios ENTONCES permanece en la mano, sin descarte. Un objeto del mismo identificador conserva su tipo y no se desecha.
  - **AC-CTR-033:** DADO un ticket desechado y otro todavía en el mundo CUANDO abre la próxima jornada ENTONCES se retira el restante, ambos dejan de existir, la mano y el programa quedan vacíos y no se avisa otro descarte ni se intenta liberar nuevamente el ya desechado.
- [x] `BR-PLY-012` suma el par del ticket con el inodoro. `AC-PLY-014` conserva sus pares anteriores y completa mopa/inodoro → enjuagar (vigente por #300) y ticket/inodoro → desechar; su cláusula de ningún efecto queda referida a pares no declarados.
- [x] AC-PLY-078 verifica RIGHT en ambos inodoros con foco real y cápsula libre; LEFT suelta el ticket conservándolo y E no lo desecha. Con el control suspendido tampoco se produce descarte.
- [x] El balde se sigue vaciando y la mopa se sigue enjuagando sobre ambos inodoros (`store-cleanup`, AC-CLN-029), conservando herramienta y sin emitir `ticket_desechado`.
- [x] Ambos lavatorios conservan el ticket; manos vacías no descartan. La próxima jornada no libera nuevamente un ticket desechado ni deja referencias en la lista/ranura del puesto.
- [x] La sonda física sobre #303 certificado verifica los dos inodoros y los dos lavatorios: piso real, cápsula libre, alcance, foco efectivo, contorno y pose global/interpolada al guardar. No modifica geometría. Capturas1920/1280 antes/después revisadas enPNG.
- [x] CTR031–033, PLY014 y PLY078 citados por tests; full7/7 sin salteos con conteo crudo completo y XML sin fallos, errores, salteos ni huérfanos. La salida cruda completa se conserva y distingue los diagnósticos heredados de errores nuevos del cambio. Todas las suites anteriores permanecen completas.

## Contrato

<!-- Sólo si aparecen firmas, señales o datos nuevos. Cada uno con su capa y su tipo de
     retorno. El caso de falla va junto al de éxito. -->

- **`dominio/almacen` — `Ticket`:**
  `static func se_desecha_en(objeto: ObjetoDelAlmacen, destino: StringName) -> bool`. Contesta
  `true` sólo si el objeto es un `Ticket` y el destino es `ReglasDeLaLimpieza.ID_DEL_INODORO`.
  Con `null`, `false`.
- **`sistemas/tareas` — `CajaRegistradora`:**
  `pedir_desechar(objeto: ObjetoDelAlmacen, destino: StringName) -> bool`, y la señal
  `ticket_desechado` cuando el dominio contesta `true`. Contesta `false` sin señal con null, otro objeto o destino distinto. No requiere ni modifica el programa de renglones: en automático/manual conserva sus selecciones; no agrega audio ni rechazo de lector.
- **`escenas/puestos/caja_registradora.gd`:** suma `@export var agarre: Agarre` y se conecta a
  `jugador.uso_pedido`. Primero comprueba que la mano lleva el dato de un cuerpo válido de su lista de tickets. Si el objetivo tiene `destino_del_uso()` y la caja acepta lo que la mano
  lleva, `agarre.entregar()` saca el ticket de la mano, y el puesto lo libera y lo saca de su
  lista. Si no, no hace nada. Sólo atiende sus cuerpos de tickets: un papel ajeno no se consume ni emite aviso, aunque comparta el mismo dato de un ticket propio. La señal existente `objeto_agarrado` permite reconocer el cuerpo propio sostenido, sin leer el interior privado de Agarre. Cada agarre limpia primero la referencia anterior, sea propio o ajeno; soltar la invalida y antes de pedir descarte se vuelve a comprobar el dato actualmente sostenido. Al aceptar se compara el cuerpo entregado con el propio registrado; no se libera un cuerpo ajeno. La baja saca el nodo de la lista y limpia la referencia de ranura si correspondía. Objetivo null o sin destino no tiene efecto. El resto del clic sigue resolviéndolo la limpieza, sin interceptar ni modificar su cableado.

## Límites de archivos

| Categoría | Rutas |
|---|---|
| **Se escribe** | `specs/counter-service/counter-service.md` y `specs/player-actions/player-actions.md` (los escribe `to-spec`); `src/dominio/almacen/ticket.gd`, `src/sistemas/tareas/caja_registradora.gd`, `src/escenas/puestos/caja_registradora.gd`, `src/escenas/almacen.tscn` (sólo agregar `agarre` al `node_paths` del puesto de la caja y su propiedad `agarre = NodePath("../../../Jugador/Agarre")`), `test/dominio/almacen/ticket_test.gd`, `test/sistemas/tareas/caja_registradora_test.gd`, `test/escenas/puestos/caja_registradora_test.gd` (el caso del inodoro, con el almacén entero) |
| **Sólo lectura** | `src/escenas/puestos/artefacto_del_bano.gd` (`destino_del_uso()`), `src/sistemas/tareas/limpiador.gd` (con un ticket en la mano, `usar()` contesta sin efecto, emite `uso_rechazado` y no suena), `src/dominio/almacen/reglas_de_la_limpieza.gd`, `src/sistemas/marco/agarre.gd` (`entregar()`), `src/escenas/jugador.gd`, `specs/store-cleanup/store-cleanup.md`; `test/escenas/puestos/bano_publico_test.gd`, `test/escenas/jornada_integrada_test.gd`, `test/escenas/agua_sobre_el_piso_test.gd` (revalidar ambas instalaciones y limpieza) |
| **No se toca** | `src/escenas/puestos/limpieza_del_almacen.gd` y `src/escenas/puestos/limpieza_del_almacen.tscn` (trabajo en vuelo), `src/dominio/almacen/uso.gd`, `src/dominio/ambiente/tabla_de_sonidos.tres`, todo `.tscn` salvo `src/escenas/almacen.tscn`, `assets/`, `project.godot` |

<!-- La tercera fila es una lista negativa y cerrada. Un `.tscn` que otro issue en vuelo edita
     va siempre acá: un merge de tres vías sobre una escena da una escena corrupta. -->

## Verificación

<!-- Comandos que devuelven código de salida 0. El veredicto sale del código de salida,
     nunca de un grep de la salida. -->

1. `python .claude/scripts/verificar.py`
2. `git diff --quiet db2ad6ac8a04bf1c475e7bdf348af26487bb8e4a -- src/escenas/puestos/limpieza_del_almacen.gd src/escenas/puestos/limpieza_del_almacen.tscn src/dominio/almacen/uso.gd src/dominio/ambiente/tabla_de_sonidos.tres assets project.godot`
3. La salida cruda de los tests dice `Executed test suites: (N/N)`, con N igual a la cantidad de `*_test.gd`.

## Bordes

<!-- El caso feliz lo cubre cualquier implementación. Acá van los límites: cero, uno, el
     máximo, el valor justo antes del corte, el que llega dos veces. -->

- **Clic derecho en el inodoro con un ticket:** el ticket deja de existir, la mano queda vacía y `ticket_desechado` llega una sola vez.
- **Dos tickets, uno por vez y uno en cada inodoro existente:** dos avisos; repetir RIGHT ya con mano vacía no duplica.
- **Papel ajeno a la lista del puesto:** no se consume ni publica descarte.
- **Mopa seca, teñida o gastada:** inodoro la enjuaga como AC-CLN-029; permanece en la mano sin aviso de descarte.
- **Clic derecho en el inodoro con las manos vacías:** no pasa nada y no se avisa.
- **Clic derecho en el inodoro con el balde lleno:** se vacía como hoy, y no se avisa `ticket_desechado`.
- **Clic derecho en el lavatorio con un ticket:** no pasa nada.
- **Soltar un ticket con clic izquierdo encima del inodoro:** cae como cualquier levantable y sigue existiendo. Sólo el clic derecho lo desecha.
- **Abrir la jornada siguiente después de desechar un ticket:** el puesto no intenta liberar el ticket desechado otra vez.
