<!-- Un issue es un plan chico y descartable: resuelve un problema puntual, con límites y
     criterios propios. Un spec es otra cosa: el contrato durable de una funcionalidad.
     Un issue cambia un spec sólo si cambia lo que el juego tiene que hacer. -->

# La investigación registra las pistas 2A y 2B y entrega las hipótesis disponibles de jornada 2

## Contexto

- **Objetivo:** registrar una sola vez las pistas decididas de jornada 2 y entregar al cierre únicamente las hipótesis habilitadas por ellas.
- **Tipo:** `feature`
- **Spec:** implementa — `specs/investigation/investigation.md`; implementa — `specs/employment-record/employment-record.md` sólo titularidad del expediente. Ambos contratos ya están aplicados y permanecen `draft` hasta verificar sus AC pendientes.
- **Rama:** `feature/22-el-sistema-de-investigacion`
- **Diseño:** sin pantalla nueva propia; consume la frase lila del [Chat Yasmín](https://www.figma.com/design/SQEAfczyRvyOHokmzPOee7/Manada---UI?node-id=820-287). El cierre muestra las opciones en otro issue.

<!-- `feature` es el único tipo que siempre toca un spec. Un `bugfix` toca uno sólo si el bug
     era una regla que nadie había escrito. La etiqueta sale del tipo: `enhancement`, `bug`,
     `refactor` o `improvement`, y `documentation` o `accessibility` cuando aplica. -->

Este brief sustituye los límites anteriores de #22 y conserva su entrega del motor genérico: pista con canal y exigencias, desenlace con umbral y exigencias, caso validable y expediente reconstruible. El expediente pertenece a `Partida` y el cableado registra pistas desde los gestos reales. No se inventan datos de desenlaces, umbrales ni finales de jornadas 3–5, cuya ficha sigue «A desarrollar». Los AC nuevos vigentes son `AC-INV-043` a `AC-INV-055` y `AC-EMP-069`; también se acota `AC-INV-028` para explicitar la excepción de notas de `BR-INV-040`/`AC-INV-052`; los números 013–018 del brief inicial ya no identifican su contrato actual.

Fuentes: [Sistema de investigación](https://www.notion.so/3de86efecd9d80e1a0dac0b78f25b56b), [pistas e hipótesis](https://www.notion.so/3e586efecd9d809698f2edc3420f4b04), [2A](https://www.notion.so/3e586efecd9d809f89a9ca0776a1498a), [2B](https://www.notion.so/3e586efecd9d80cd9e75dba0f794d4b2), [2P](https://www.notion.so/3fa86efecd9d80c18f2ced503807810e). Consultadas el 16 de octubre. Base preparada: `e6cc0ac4bff25335c0b6a605d85b70cb9014cab0`, rama `feature/429-444-contratos-integrados`. Integra #434 `d647a203`, #430/#425/#428, la final de minnow `10d598ea`, revisiones #366 `2ba7e43b`, #367 `903c0df2` y harness `4402845`. La segunda verificación completa de esta base pasó 7/7 nodos sin salteos, 278/278 suites y 2139/2139 casos, sin fallos, errores de script/parseo ni retenciones al salir. La evidencia íntegra está en base-integrada-02/crudo del registro local del lote; la implementación de los criterios nuevos aún corresponde a sus PR individuales. INV/EMP/CLN ya contienen los contratos de #22/#432, incluido el círculo aprobado de 2A y la excepción de NOTAS en AC-INV-028, y siguen `draft` por AC pendientes de implementación. Código y recursos relevantes de #22/#432 permanecen como en `c49e31c2`: falta implementar el expediente, sus notas, recursos y cableado de pistas. Se conserva el mapa actual de #434 y se mide físicamente el acceso a la colilla cerca del garage. Se siguen las cabezas frescas y se revalidan los archivos afectados si llegan nuevos commits; no se espera convergencia a staging. #430 ya entrega `tramo_de_pista_pedido(identidad)` y la metadata `J2_6`/`falta_algo`/`2A`, con fechas y orden. Se trae su rama como dependencia; no se espera su merge a staging.

Depende de #430: ese cambio entrega J2_6 con la frase lila identificada y el evento de pulsación, sin registrar la pista. Este issue consume ese evento y el levantamiento aceptado de la colilla. El issue #436 consume los datos, consultas y eventos de este motor, y entrega pantalla, elección, reflexiones y persistencia completa de cierre (identidades, mensajes y elección). Este issue entrega los mensajes de pistas en memoria, sin escribir disco. #385 consume la señal de pista nueva para su aviso; no se duplica esa notificación.

Notion dice que sin pistas esa noche se ofrece sólo la predeterminada. Por eso 2P no acompaña a 2A/2B. No hay 2L: la primera jornada carece de pistas y la base no define contenido para 2L. El menú de notas durante el turno aparece desde jornada 3; mostrarlo fijo en cierres anteriores está definido expresamente en Pantalla entre jornadas y corresponde al issue de cierre.


La primera completa de implementación sobre `89310954` ejecutó 288 suites y 2189 casos y salió roja: cuatro errores del control de UV2 al encontrar las mallas primitivas de la colilla con GI estático y dos aserciones de iluminación/volumen. La colilla móvil debe tomar iluminación dinámica. Su cuerpo de 0.082 × 0.015 × 0.015 m baja el corte geométrico del agarrable más pequeño y revela cinco piezas heredadas sin volumen: los dos tableros y tres tapas de tachitos. Esta ampliación incorpora su corrección geométrica dentro de las mallas vigentes, con fuente reproducible y regresión. No se excluye la colilla del cálculo, no se agranda su cuerpo ni se debilitan los oráculos. Se conservan la corrida roja y las mediciones antes/después.

## Criterios de aceptación

<!-- Los de este issue: binarios y con los valores que deciden. Mueren con el issue.
     Si el issue toca un spec, acá van también los `AC-<COD>-###` que agrega o cambia: ésos
     sí duran, y un test los cita. -->

- [ ] Se implementa el contrato ya aplicado: BR-INV-041/AC-INV-053 fijan la imagen aprobada de 2A y se conservan las reglas de identidad/jornada, registro idempotente y consulta de hipótesis; las revelaciones por examen mantienen su canal distinto. Cada AC-INV-043–055 y AC-EMP-069 tiene un test que lo cita; AC-INV-028 también queda a cargo de este issue, además de AC-INV-052. Su caso de aparición del botón en jornada 2 ya está acotado a chats distintos de notas: la excepción de notas permite recibir mensajes J2 sin botón hasta J3. Se conserva el filtro de mensajes por jornada, orden de interlocutores y ausencia de llegadas futuras durante el turno; un test cita AC-INV-028 y contrasta el chat normal con esa excepción. No se renumeran AC existentes por memoria.
- [ ] El caso genérico distingue datos consistentes de identidades repetidas, exigencia inexistente, ciclo y desenlace inalcanzable. Una pista con exigencias sólo se anota cuando están todas; un desenlace exige simultáneamente su umbral y sus pistas y se publica una vez. No se fijan desenlaces narrativos todavía indefinidos.
- [ ] Únicamente pulsar «acá siempre falta algo» de J2_6 de Yasmín registra 2A. Abrir/leer chat o pulsar otra parte no registra; el gesto repetido no vuelve a anotar ni emitir pista nueva.
- [ ] La colilla está al fondo del depósito cerca de la puerta garage y se distingue como colilla, con cuerpo y dato independientes de productos vendibles. Sólo el levantamiento aceptado durante jornada 2 registra 2B; mirar, subtítulo con E desde manos vacías, agarre rechazado o pausa no lo registran. Volver a levantar no duplica. Sus mallas móviles usan GI dinámico. La comprobación de volumen conserva el corte derivado del cuerpo real de la colilla y todas sus aserciones; los volúmenes corregidos de las cinco piezas quedan dentro de la geometría visual, sin paredes invisibles ni nuevas exenciones arbitrarias.
- [ ] Consulta para cierre de jornada 2: ninguna pista → sólo 2P; sólo 2A → sólo 2A; sólo 2B → sólo 2B; ambas → 2A y 2B, sin 2P. Consultar y navegar no mutan expediente.
- [ ] Cada ANOTADA agrega una vez al chat de notas primero la foto y luego el texto de la pista; REPETIDA y DESCONOCIDA no agregan mensajes. Se reutiliza el contrato de foto ampliada con su mensaje siguiente como adjunto. El chat de notas tiene identidad/recurso propios; el consumidor de cierre aplica el fondo distinto definido por Interfaces. Su disponibilidad en el menú durante el turno comienza en jornada 3; puede recibir pistas en memoria en jornada 2 y abrirse fijo en los cierres de jornadas 1 y 2 por el consumidor de cierre.
- [ ] Los recursos entregan el texto y foto descriptos por Notion para cada pista y el título/texto de cada hipótesis. Por decisión explícita del usuario del 16 de octubre, 2A usa el círculo existente de Yasmín del diseño aprobado: Figma `820:343`, dentro del frame `820:287`, 54×54 píxeles. Es la imagen aprobada de 2A aun sin retrato. Se conserva ese export original y su procedencia; no se inventa otro rostro ni se sustituye por Enrique. 2B usa foto de la colilla en el piso. Se incorporan los recursos visuales requeridos; si se generan, su fuente/generador se versiona junto al resultado.
- [ ] 2A: pista «Hoy Yasmín se quejó de que en el local “siempre falta algo o anda todo a medias”.»; hipótesis «SIEMPRE FALTAN COSAS», texto «No me sorprendería tener un jefe inútil. Pero también, ¿no es responsabilidad de Yasmín avisar si faltan cosas esenciales? Si esto va a ser frecuente, tengo que empezar a prestar más atención a las dinámicas internas del local.».
- [ ] 2B: pista «Encontré una colilla de cigarrilo en el depósito. Pero, por lo que me dijeron, ni Enrique ni Yasmín fuman. Raro…»; hipótesis «CIGARRILLO EN EL DEPÓSITO», texto «¿Puede ser que alguien se esté metiendo sin que nos demos cuenta? Debería examinar bien las formas de ingreso al local…». Se preserva la errata fuente «cigarrilo».
- [ ] 2P: título «NO PASA NADA», texto «Solo se acabó un jabón. No me tengo que hacer la cabeza con algo tan poco trascendental.». No genera pista/foto ficticia.
- [ ] El expediente y los mensajes de notas de `Partida` conservan identidades y orden entre aperturas en memoria y reconstruye desde una lista saneada; identidad desconocida no registra. La persistencia de checkpoint y elección la implementa el issue de cierre, con este expediente como único dueño.
- [ ] Una señal tipada de pista nueva se emite sólo tras ANOTADA y entrega identidad/jornada y los datos que el cierre necesita para agregar foto+texto una sola vez. REPETIDA y DESCONOCIDA no emiten ni alteran el orden de hallazgos.

## Contrato

<!-- Sólo si aparecen firmas, señales o datos nuevos. Cada uno con su capa y su tipo de
     retorno. El caso de falla va junto al de éxito. -->

Dominio: pistas e hipótesis como `Resource` exportables, por identidad estable y jornada. `Expediente` es puro, recibe recursos, registra y devuelve ANOTADA/REPETIDA/DESCONOCIDA; entrega copia de identidades y reconstruye sólo las válidas. Consulta de opciones devuelve datos tipados sin mutación. `Partida` posee el expediente; no hay autoload ni expediente propio alternativo en el sistema.

Los datos del caso validan identidad, referencias, ciclos y posibilidad de cada desenlace sin `Node` ni disco. El registro/reconstrucción entrega copias ordenadas de identidades como `PackedStringArray`. La señal de desenlace alcanzado se emite una vez cuando un registro completa sus condiciones, no al consultar ni reconstruir.

Sistemas: `Investigador` no crea expediente propio antes de `usar()`; recibe el expediente de `Partida`, traduce evento de frase y agarre aceptado a registro y emite pista nueva sólo tras ANOTADA y agrega los mensajes de pista a notas en el orden foto/texto. La colilla es `ObjetoDelAlmacen` levantable con identidad de pista. Los recursos de foto y texto son datos; el sistema no abre pantallas ni decide elección. El contrato del consumidor de cierre contempla registro en vivo y reconstrucción desde identidades/mensajes sin duplicarlos. `Conversacion`, `Bandeja` y `Celular` separan disponibilidad en menú por jornada de la apertura fija de un chat con contenido: NOTAS no se filtra al menú de jornadas 1/2 por haber recibido mensajes. Se reutilizan las fechas/orden de mensaje entregados por #430. Cada par foto/texto recibe identidades distintas y estables, jornada 2 y orden de descubrimiento creciente; no se deja que el orden de `Bandeja` separe una foto de su texto. La consulta de disponibilidad de menú no modifica ni elimina mensajes. La jornada y canal se validan en dominio; el cableado bloquea pausa y turno cerrado antes de traducir los eventos. Abrir el celular suspende el control del mundo pero no impide pulsar una pista válida de su chat. La consulta de mensajes devuelve copias y no registra pistas; el guion `Resource` permanece inmutable.

## Límites de archivos

| Categoría | Rutas |
|---|---|
| **Se escribe** | `specs/investigation/investigation.md`, `specs/employment-record/employment-record.md` (contratos ya aplicados; sólo trazabilidad de sus AC y estado al verificarlos, EMP sólo expediente); nuevos `src/dominio/investigacion/pista.gd`, `hipotesis.gd`, `expediente.gd`, `hipotesis_de_la_jornada.gd`, recursos de caso y desenlace genéricos y sus scripts/UID y espejos cuando se separen en archivos; recursos nuevos `assets/investigacion/jornada_2/`; nuevo `src/sistemas/investigacion/investigador.gd` y UID; `src/dominio/empleo/partida.gd`; `src/dominio/investigacion/conversacion.gd`, `bandeja.gd`, `celular.gd`, nuevo `src/dominio/investigacion/conversacion_de_notas.tres`; sus espejos en `test/dominio/investigacion/`; `src/sistemas/investigacion/celular_del_empleado.gd` y espejo; nuevos datos `src/dominio/investigacion/colilla.tres`, escena/script `src/escenas/objetos/colilla.tscn`, `colilla.gd` y UID; recurso visual y fuente/generador de colilla en `assets/props/colilla/`, fotos y fuente/generador en `assets/ui/manada/pistas/`, incluido export original del círculo Figma de Yasmín y documento de procedencia; `src/escenas/almacen.gd`, `src/escenas/puestos/objetos_del_almacen.tscn`, `servicios_del_almacen.tscn`; espejos obligatorios nuevos en `test/dominio/investigacion/`, `test/sistemas/investigacion/` y nueva suite `test/dominio/empleo/expediente_de_la_partida_test.gd` y UID (el espejo actual ya tiene 20 métodos públicos); nueva `test/escenas/pistas_de_la_segunda_jornada_test.gd` y UID; `test/escenas/modelo_integrado_test.gd` sólo si cuenta el nuevo objeto; `export_presets.cfg` sólo inclusión de recursos nuevos; `src/escenas/puestos/estructura_del_almacen.tscn` sólo volúmenes interiores de los dos tableros y tres tapas revelados por el corte nuevo; nueva fuente `.github/scripts/generar_volumenes_para_colilla.gd` y UID; `test/escenas/volumen_de_los_solidos_test.gd` sólo regresión del nuevo corte y volúmenes, conservando todos los casos y oráculos existentes |
| **Sólo lectura** | `src/dominio/investigacion/hallazgos.gd`, `mensaje.gd`; `src/sistemas/marco/agarre.gd`; `src/dominio/almacen/objeto_del_almacen.gd`; `src/escenas/objetos/objeto_agarrable.gd`; `specs/notifications/notifications.md`, `specs/save-and-resume/save-and-resume.md` |
| **No se toca** | `project.godot`, `src/escenas/almacen.tscn`, `src/escenas/puestos/interfaz_del_almacen.tscn`, `src/ui/`, guiones Enrique/Yasmín (salvo consumo de su metadata de pista), escenas de limpieza y ventanilla, GLB y horneado del local (la subescena de estructura sólo admite los volúmenes interiores expresamente autorizados), catálogo vendible, selección de hipótesis y checkpoint, contenido de jornadas 3–5 |

<!-- La tercera fila es una lista negativa y cerrada. Un `.tscn` que otro issue en vuelo edita
     va siempre acá: un merge de tres vías sobre una escena da una escena corrupta. -->

## Verificación

<!-- Comandos que devuelven código de salida 0. El veredicto sale del código de salida,
     nunca de un grep de la salida. -->

1. `python .claude/scripts/verificar.py`
2. `python .claude/scripts/verificar.py --solo specs`
3. Runner completo: expediente/consistencia, cuatro combinaciones de hipótesis y escena real (clic en frase y levantar colilla); conservar salida cruda, suites descubiertas/ejecutadas y capturas en escritorio/web del paquete exportado.
4. Pruebas de escena usan la ruta temporal de guardado existente; validan que no registran mirando, leyendo o rechazando el agarre. Los nuevos tests van en suites separadas donde el espejo ya alcance 20 métodos públicos.

5. Medir las cinco piezas con la misma consulta de corte y volumen de la suite vigente; conservar geometría y resultados anteriores y corregidos. Regenerar desde la fuente versionada, comprobar que cada volumen está dentro de su malla y repetir iluminación y volumen antes de la nueva completa. No se modifica el GLB ni se rehace el horneado.

## Bordes

<!-- El caso feliz lo cubre cualquier implementación. Acá van los límites: cero, uno, el
     máximo, el valor justo antes del corte, el que llega dos veces. -->

- Cero pistas, sólo A, sólo B, ambas; identidad repetida/desconocida; expediente reconstruido con dato retirado.
- Notas ocultas del menú de jornadas 1/2 aunque haya pistas, disponibles al fijar por cierre, visibles en menú desde 3; foto con adjunto siguiente y reabrir sin duplicar.
- Colilla agarrada, soltada, vuelta a levantar y sostenida al cierre; clic doble en frase; nueva partida sin pistas heredadas.
- La cuenta de las revelaciones actuales se conserva y no convierte examen de cualquier objeto en pista de jornada 2.
