---
schema_version: 1
capability_id: CAP-INV
status: draft
owner: por definir
provenance: GDD «Investigación» y «La computadora»; ficha «Interfaces virtuales durante la jornada» y decisiones de #373, #375 y #376; migración de los specs 006, 009, 018; fichas Chat con el jefe, Chat con compañera y 2A revisadas el 2026-10-15; decisiones de #430; «Sistema de investigación», fichas 2A/2B/2P y decisiones de #22 del 2026-10-15; decisión del usuario del 2026-10-18 de usar la captura del mensaje de Yasmín como foto de 2A; decisión del usuario del 2026-10-17 de retirar las notas de la computadora y usar el diseño del registro de productos; ficha «Pantalla entre jornadas», reflexión de jornada 1, encabezado de jornada 2 y decisiones de #436; decisiones del usuario del 2026-10-18 sobre el recorrido lateral, la elección sin límite de tiempo, la reanudación del cierre y la espera de 1 segundo; ocho jornadas de #526; instrucciones por jornada de #527; la colilla sólo en su jornada, de #536; ficha Chat con compañera, jornada 5, de #458; ficha «Caminos narrativos y finales» y cuadro de pistas e hipótesis de #766 y la ficha «5B» de la lista de pistas e hipótesis y decisiones del usuario del 2026-10-30 sobre su foto y su texto, de #731; la fila «6C» de la lista de pistas e hipótesis, la ficha «Caminos narrativos y finales» y decisiones del usuario del 2026-11-03 sobre Yasmín y la textura de la nota, de #741; encabezado de la jornada 5 y ficha «5P» de la lista de pistas e hipótesis y decisión del usuario del 2026-11-04 sobre la 5L, de #740; quejas de la jornada 7, captura de la transferencia y pantalla conjunta de #759, ficha «Particulares de cada jornada» y comentario de Notion del 2026-11-04; ficha «Especificar animaciones», el chat que entra y sale deslizándose, de #627; GJ-62, el chat que abre en el primer mensaje sin leer, de #568; encabezado de la jornada 6 y fichas «6P» y «6L» de la lista de pistas e hipótesis, de #742; el chat de Hernán y el pedido al proveedor, de #691
---

# Capacidad: la investigación

## Propósito

Conservar las pistas descubiertas y consultar las hipótesis que habilitan, sin duplicar progreso.
Darle al minuto que no se paga algo que comprar. Lo único que tiene que hacer bien es **no
rendir dos veces**: lo que un objeto esconde se ve sólo al examinarlo, y examinarlo otra vez no
suma. Sin eso, se puede pasar la noche examinando la misma lata.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Revelación** | lo que un objeto esconde y sólo se ve al examinarlo | secreto, lore |
| **Hallazgo** | la primera vez que se ve una revelación. La segunda no lo es | descubrimiento |
| **Pista** | dato narrativo con identidad estable, jornada, canal y posibles exigencias | revelación automática |
| **Expediente** | identidades de pistas descubiertas de una partida, en orden | estado global |
| **Hipótesis** | opción de interpretación disponible al cierre de una jornada | final |
| **Desenlace** | resultado que declara umbral y pistas exigidas | hipótesis de jornada |
| **Caso** | conjunto declarado de pistas, exigencias y desenlaces | reglas dentro de la pantalla |
| **Chat de notas** | conversación del protagonista consigo mismo que recibe fotos y textos de pistas, reflexiones e hipótesis elegidas | editor de notas manuales |
| **Reflexión de cierre** | el paso que sigue a la devolución de las jornadas 3 y 4: el celular en notas y un recuadro con textos o hipótesis | pantalla de hipótesis aparte |
| **Elección** | la hipótesis que el jugador fijó al cerrar una jornada; una sola por jornada | hipótesis desbloqueada |
| **Camino** | las pistas de la jornada siguiente que desbloquea una hipótesis | rama, final |
| **Pistas activas** | las pistas de una jornada que el expediente puede anotar | pistas presentes |
| **Sorteo** | la hipótesis de la jornada anterior que se toma al azar cuando esa jornada termina sin pistas, para fijar el camino de la siguiente | elección |

## Comportamiento normativo

### BR-INV-001 — Examinar revela, mirar no

El sistema DEBE mostrar la revelación de un objeto **sólo al examinarlo**. Un objeto sin nada
abajo contesta lo mismo las dos veces. Si la revelación se viera sin examinar, examinar no
costaría tiempo.

### BR-INV-002 — Una revelación en blanco no revela

SI el texto de la revelación está vacío o es sólo espacios, ENTONCES el sistema DEBE tratarla
como si no existiera. El jugador pagó el minuto igual.

### BR-INV-003 — Repetir no rinde

CUANDO se examina un objeto ya visto, el sistema DEBE decir que no es un hallazgo nuevo y no
mover la cuenta. La identidad es la del objeto y no la de la instancia: dos latas iguales de la
misma góndola son el mismo secreto.

### BR-INV-004 — Preguntar no registra

El sistema DEBE ofrecer preguntar si algo ya se vio **sin marcarlo como visto**. Si preguntarlo
lo registrara, mirar la pantalla cerraría el hallazgo.

### BR-INV-005 — La computadora ofrece el registro y los chats están en el celular

El sistema DEBE ofrecer únicamente el registro de ventas en la computadora, sin una app de notas
manuales. Los chats, incluido el de notas de pistas, DEBEN leerse en el celular.

### BR-INV-006 — Leer no cobra tiempo adicional

CUANDO se abre o cierra la computadora, o se abre o cierra el celular, se lee un chat o se amplía
una foto, el sistema NO DEBE descontar tiempo por el gesto. MIENTRAS el celular está abierto
durante la jornada sin pausa, el reloj DEBE seguir descontando el tiempo real de juego.

### BR-INV-007 — Reabrir conserva el registro

CUANDO se cierra y se vuelve a abrir la computadora durante la jornada, el sistema DEBE mostrar
el registro con las mismas unidades anotadas y el mismo total.

### BR-INV-008 — Lo leído es de la partida, no del guión

El sistema DEBE llevar **fuera del guión de cada conversación** qué está leído. Una marca adentro
del guión sobrevive a la partida entera: el jugador empezaría la noche dos con todo leído.

### BR-INV-009 — Leer un chat es leerlo entero

CUANDO se abre una conversación, el sistema DEBE dejarla en cero mensajes sin leer, y DEBE llevar
la cuenta **por interlocutor**. Con un contador global, leer al jefe apagaría el aviso de los
otros. Los mensajes que llegan después de esa lectura DEBEN contar como no leídos de ese chat,
sin modificar los contadores de los demás.

### BR-INV-011 — Lo leído no depende de la pantalla

El sistema DEBE conservar lo leído al cerrar y reabrir el celular. Ese estado NO DEBE depender
de reconstruir su pantalla.

### BR-INV-017 — Pensar no clava al jugador

MIENTRAS se muestra lo que reveló algo no levantable, el sistema DEBE dejar al jugador irse. Es
un pensamiento, no un examen.

### BR-INV-018 — Se examina sólo lo que se lleva

CUANDO se pide examinar con las manos vacías y la mira sobre un levantable, el sistema DEBE
mostrar su subtítulo como pensamiento (BR-SUB-002). NO DEBE arrancar un examen, retener al
jugador, mover lo que se mira, revelar ni registrar un hallazgo (BR-INV-001): el subtítulo no
es la revelación. Con algo en la mano, DEBE examinar lo que se lleva. Sobre algo no levantable,
la E sigue siendo el pensamiento de BR-INV-017, sin retener al jugador.

### BR-INV-019 — Lo examinado gira a pedido

MIENTRAS se examina algo, el sistema DEBE girarlo con las teclas de movimiento: los costados
sobre el eje vertical, adelante y atrás sobre el horizontal, a una velocidad fija por segundo.
El mouse DEBE girarlo sólo mientras se arrastra con el clic apretado. Sin tecla y sin arrastre,
lo examinado NO DEBE girar.

El jugador termina el examen sólo con la tecla de examinar. Durante el examen, el clic NO DEBE
terminarlo, ni agarrar, ni soltar, ni colocar.

### BR-INV-020 — La jornada nueva no hereda un examen

CUANDO se abre una jornada con un examen en curso, el sistema DEBE terminarlo antes de vaciar
las manos. Lo que se llevaba queda a los pies y el jugador no queda retenido.

### BR-INV-021 — Q alterna el celular sólo cuando corresponde

CUANDO se pulsa Q durante una jornada con el celular cerrado, el sistema DEBE abrirlo sólo si
ninguna otra interfaz tiene el control y no hay examen en curso. Con el celular abierto en
modo libre, Q o Esc DEBEN cerrarlo, y Esc NO DEBE abrir la pausa en ese caso. Un clic izquierdo
por fuera del celular NO DEBE cerrarlo, haya o no una foto ampliada. Con una foto ampliada en
modo libre, Esc DEBE cerrar primero la foto; el Esc siguiente cierra el celular y el
siguiente pausa. Con el turno cerrado, otra interfaz al control, un examen o una
pausa, Q NO DEBE abrirlo ni alterar el estado existente. Abrir o cerrar NO DEBE cambiar lo que
se lleva en la mano. Otro Q o Esc durante la subida DEBE iniciar la bajada desde la posición
actual, sin duplicar el celular ni dejarlo detenido a mitad de camino. La pantalla conjunta de la jornada 7 es la excepción: con la computadora
abierta, Q DEBE alternarla (BR-INV-115).

### BR-INV-022 — Cada apertura libre empieza en el menú

CUANDO se abre el celular en modo libre, el sistema DEBE mostrar el menú de chats, aunque se
haya cerrado viendo un chat o una foto. Clic izquierdo en un botón DEBE abrir su chat y marcarlo
leído; la flecha del encabezado DEBE volver al menú. Abrir un chat sin mensajes sin leer DEBE
mostrar su último mensaje y permitir desplazarlo con la rueda hacia los anteriores; con mensajes
sin leer, BR-INV-120 decide dónde empieza. Un menú sin chats DEBE verse vacío,
sin error; un chat de un solo mensaje NO DEBE exigir desplazamiento para verlo.

### BR-INV-023 — La jornada decide los mensajes disponibles

CUANDO se abre la jornada N, el sistema DEBE mostrar sólo los mensajes del guión cuya jornada
de llegada es menor o igual que N, en su orden y con el más reciente abajo. Un mensaje que
sale de cómo cerró una noche anterior DEBE mostrarse sólo si la partida lo eligió (BR-EMP-040, BR-EMP-042). El menú DEBE listar
un botón por conversación con al menos un mensaje visible, en el orden declarado de
interlocutores, salvo el chat de notas cuyo permiso de menú lo fija BR-INV-040.
Cada botón DEBE mostrar nombre, imagen y cantidad de no leídos cuando es mayor
que cero; sin imagen, DEBE mostrar un círculo liso del tema. La jornada NO DEBE programar nuevas
llegadas durante su transcurso. Al continuar desde un guardado, los mensajes del guión DEBEN
reconstruirse según esa jornada, todos sin leer. Las devoluciones de Enrique de las noches ya
cerradas DEBEN volver a su chat intercaladas con las aperturas en orden cronológico
(BR-INV-030, BR-EMP-031, BR-SAV-019), y el chat de notas DEBE volver con su historial
(BR-INV-047, BR-SAV-021); los demás recibidos fuera del guión NO DEBEN guardarse.

### BR-INV-024 — Recibir agrega sin alterar el guión

CUANDO se recibe un mensaje válido para una conversación existente, el sistema DEBE agregarlo
a ese chat en su posición cronológica (BR-INV-030) y avisar la recepción una sola vez,
incluso con el celular cerrado. SI ese chat está a la vista, ENTONCES el mensaje DEBE
aparecer en su posición cronológica. La recepción NO DEBE alterar el
guión compartido. Un mensaje nulo o un interlocutor sin conversación DEBEN rechazarse sin
alterar contenido ni contadores ni emitir aviso. Consultar conversaciones o mensajes DEBE
entregar una copia de la lista, sin permitir vaciar la bandeja al modificarla.

### BR-INV-025 — Una foto se amplía con el texto siguiente

CUANDO se pulsa una foto de un chat, el sistema DEBE ampliarla para que entre completa en la
pantalla del celular, con su texto adjunto sobre ella. El adjunto DEBE ser exclusivamente el
primer mensaje siguiente con texto sin foto, salteando sólo fotos sin texto de la misma jornada
y momento. Una foto con texto, otra jornada u otro momento DEBEN cortar esa búsqueda.
Sin texto siguiente en ese grupo, DEBE ampliarse sin adjunto.
Pedir ampliar un mensaje sin foto NO DEBE cambiar nada. Cualquier clic izquierdo
en la pantalla DEBE cerrar la ampliación y volver al mismo chat y posición de desplazamiento.

### BR-INV-026 — El modo fijo retiene un chat

CUANDO se pide el modo fijo para una conversación existente, el sistema DEBE abrir el celular
directamente en ese chat, incluso fuera de una jornada. Q NO DEBE cerrarlo y NO DEBE ofrecerse
volver al menú; sí DEBE permitir desplazar el chat, ampliar una foto y cerrarla. Soltar el modo
fijo DEBE cerrar el celular. Soltarlo cuando no está fijo NO DEBE cambiar nada.

### BR-INV-027 — El celular ocupa el centro y deja libre la lectura

CUANDO se abre, el celular DEBE subir desde fuera del margen inferior hasta el centro del
encuadre y conservar una proporción 9:16 al cambiar la resolución. El resto de la visión DEBE
verse desenfocado y oscuro, y la pantalla del celular DEBE permanecer nítida e iluminada, tanto
en escritorio como en web. Al cerrarlo, DEBE bajar fuera del margen inferior y retirar ese velo.
Subir y bajar DEBEN seguir un resorte suave tipo «Gentle»: al subir pasa levemente de su
posición final y se asienta en el centro; al bajar usa el mismo resorte y termina fuera del
margen inferior (OQ-INV-006). La bajada DEBE emitir su señal de fin una sola vez, cuando el
movimiento termina.
MIENTRAS el turno está abierto, el sistema DEBE mostrar en la esquina inferior izquierda un
ícono de celular con «Q», incluso con el celular arriba; con el turno cerrado NO DEBE mostrarlo.
MIENTRAS la computadora está abierta, el sistema DEBE ocultar ese recordatorio. Al cerrarla,
DEBE volver a mostrarlo sólo si la jornada todavía lo permite.
El celular DEBE dibujarse sobre HUD, computadora y cierre, y debajo de avisos y pausa. La
duración completa de subir y de bajar, rebote incluido, DEBE ser de 0,25 segundos reales por
recorrido (OQ-INV-006).
Un cuadro largo NO DEBE adelantar el movimiento más de 1/30 de segundo. Si el dibujo se
interrumpe, el recorrido DEBE conservar sus pasos visibles aunque termine más tarde.

### BR-INV-028 — Pausa y cierre conservan estados distintos

CUANDO se pausa con el celular abierto, el sistema DEBE mostrar la pausa encima, ignorar Q y
reanudar en la misma pantalla del celular. CUANDO cierra el turno, el celular DEBE cerrarse,
soltar su modo fijo y dejar el control suspendido por el cierre. CUANDO se abre otra jornada,
el celular DEBE empezar cerrado y preparado para abrir en el menú.

### BR-INV-029 — La cuarta jornada incorpora a Yasmín y la tarea de Enrique

CUANDO abre una jornada de la 1 a la 3, el sistema DEBE ofrecer sólo el chat de Enrique. CUANDO
abre la jornada 4, por transición o desde un checkpoint, DEBE ofrecer Enrique y Yasmín. El rol de
Enrique DEBE leerse «Jefe» y el de Yasmín «Compañera de trabajo», como dato del contacto,
independiente de su imagen. Sin retrato aprobado, DEBE usar el círculo liso de BR-INV-023.

Enrique DEBE incorporar dos mensajes de apertura de la jornada 4: primero una foto del
contenedor de basura del local, después el texto literal «Buenas tardes, pibe. Hoy te pido que tires
la basura de todos los tachos del local en el contenedor. Saludos». La foto NO DEBE mostrar
un tacho interior en lugar del contenedor; ampliarla DEBE usar ese texto como adjunto.
Yasmín DEBE incorporar exactamente los siguientes dieciséis mensajes independientes, con estas
identidades estables y en este orden:

| Identidad | Texto literal |
|---|---|
| J2_1 | holuuu ✨ |
| J2_2 | que onda compa? |
| J2_3 | soy Yas del turno diurno |
| J2_4 | la otra esclavita de enrique jsjsj |
| J2_5 | el chabon es bastante denso pero ya te vas a acostumbrar |
| J2_6 | y te aviso q acá siempre falta algo o anda todo a medias |
| J2_7 | para que te vayas acostumbrando también |
| J2_8 | p ejemplo el wifi anda medio mal y a veces hay que apagarlo y volverlo a prender para que funcione |
| J2_9 | y hoy parece que se acabo uno de los jabones para la limpieza y no había ningún repuesto |
| J2_10 | no le reclames a enrique porque no va a hacer nada y encima se va a irritar |
| J2_11 | creo que lo podes reemplazar con un chorrito del producto ese de limpieza que vendemos |
| J2_12 | no creo que enrique se de cuenta si usás uno |
| J2_13 | pero nada |
| J2_14 | quería darte la bienvenida |
| J2_15 | quedamos en contacto p cualquier cosa |
| J2_16 | exitos con eso!  💪 |

Los mensajes DEBEN estar disponibles al abrir la jornada, sin arribos programados durante
el turno. Mensajes de jornada 5 o posteriores NO DEBEN adelantarse a la 4. Las identidades
J2_1 a J2_16 conservan su nombre: son identidades, no la jornada. Reabrir el celular,
volver al menú o repetir la apertura NO DEBE duplicar el guion ni alterar sus recursos.
Leer DEBE conservar el transcurso del turno de BR-INV-006 y las marcas de BR-INV-008/009.

### BR-INV-030 — El historial mezcla guion y devoluciones en orden temporal

El sistema DEBE ordenar los mensajes por jornada, momento de apertura o cierre y orden
dentro del bloque, sin ordenarlos por texto ni por hora. En Enrique, cada devolución
DEBE ir después de los mensajes de su jornada y antes de los de la siguiente: instrucciones de
jornada 1, devolución 1, instrucciones de jornada 2, devolución 2, mensajes de jornada 3,
devolución 3, foto y texto de apertura 4, devolución 4, foto y texto de apertura 5, y
los bloques posteriores cuando estén disponibles. Cada mensaje DEBE conservar
su identidad; dos textos iguales con identidades distintas NO DEBEN fusionarse por su texto.

Cada devolución nueva DEBE aportar explícitamente la jornada que cerró y el orden de sus
mensajes (BR-EMP-031). Los mensajes legados sin jornada DEBEN conservar texto y orden relativo,
sin recibir una jornada ni una hora. Su intercalado con bloques fechados depende de
OQ-INV-005. La vista cronológica y sus consultas NO DEBEN mutar el guion compartido ni sus
marcas de lectura. Retomar DEBE reconstruir el guion y conservar las devoluciones guardadas
con esos metadatos, con los mensajes del guion sin leer según BR-INV-023.

### BR-INV-031 — Sólo el tramo de pista emite su identidad

El sistema DEBE mostrar en J2_6 sólo «acá siempre falta algo» en rojo y el resto del texto
en blanco. CUANDO se pulsa ese tramo, DEBE emitir un pedido identificado con 2A, sin deducir
la identidad del texto visible ni registrar por ese gesto un hallazgo o hipótesis.
Leer el mensaje, abrir el chat, pulsar otro tramo o una identidad inexistente NO DEBE emitir
ese pedido. Repetir el clic válido PUEDE repetir el pedido; la aceptación e idempotencia
del hallazgo corresponden a quien registra la pista.

### BR-INV-032 — Las pistas se registran por identidad una sola vez

CUANDO se registra una pista conocida y habilitada, el sistema DEBE contestar ANOTADA, agregar
su identidad una sola vez al final del expediente y publicar una pista nueva con identidad,
jornada y sus datos. Si ya está registrada DEBE contestar REPETIDA, sin alterar orden ni emitir
otra pista nueva. Una identidad ajena al caso DEBE contestar DESCONOCIDA y conservar el estado.
Las pistas DEBEN ser datos con identidad estable y jornada; una revelación de examen NO DEBE
convertirse por sí misma en una pista de jornada.

### BR-INV-033 — Las exigencias son datos y se cumplen juntas

SI una pista declara otras pistas exigidas y falta alguna, ENTONCES el sistema DEBE contestar
DESCONOCIDA sin registrarla. Con todas descubiertas DEBE permitir ANOTADA. El sistema DEBE
recibir las exigencias como datos del caso, sin depender de una pantalla ni del gesto que lo
consulta.

### BR-INV-034 — El desenlace exige umbral y pistas a la vez

CUANDO se consulta un desenlace, el sistema DEBE declararlo alcanzado sólo si la cantidad de
pistas descubiertas alcanza su umbral declarado y están todas sus pistas exigidas. Sin pistas
exigidas DEBE bastar el umbral. El sistema DEBE publicar cada desenlace alcanzado al registrar
la pista que completa sus condiciones, una sola vez. Consultar o repetir una pista NO DEBE
emitir otro alcance. Los umbrales y exigencias DEBEN proceder del caso declarado, sin inventar
finales ni valores para contenido no definido.

### BR-INV-035 — Un caso inconsistente se rechaza explícitamente

El sistema DEBE declarar inconsistente un caso con identidades de pista repetidas, una
exigencia inexistente, un ciclo de exigencias o un desenlace inalcanzable por cantidad o por
sus exigencias. Un caso consistente DEBE poder ejercerse independientemente de la presentación.

### BR-INV-036 — Reconstruir sanea sin volver a descubrir

CUANDO se entrega lo descubierto, el sistema DEBE ofrecer una copia ordenada de sus identidades.
CUANDO se reconstruye desde una lista, el sistema DEBE conservar las identidades conocidas una
sola vez, en su orden, e ignorar las desconocidas. Reconstruir y consultar NO DEBEN publicar
pista nueva ni duplicar mensajes. Registrar y reconstruir DEBEN operar sobre el expediente
recibido de la partida, sin escribir disco ni crear un expediente global alternativo.

### BR-INV-037 — Cada canal exige su gesto

El sistema DEBE distinguir pistas por levantar un objeto, examinar algo no levantable, pulsar
una frase de chat y pulsar un fragmento de diálogo de comprador. El gesto DEBE coincidir con
el canal y la jornada declarados. Mirar, leer sin pulsar el fragmento y un agarre rechazado NO
DEBEN registrar. Las revelaciones de examen de BR-INV-001 a BR-INV-004 DEBEN conservar su cuenta
independiente: el subtítulo con mano vacía NO DEBE registrar una pista levantable.

### BR-INV-038 — Dos gestos concretos descubren las pistas de la cuarta noche

MIENTRAS jornada 4 está abierta, CUANDO se pulsa la frase roja «acá siempre falta algo» del
mensaje J2_6 de Yasmín, el sistema DEBE registrar 2A. Abrir o leer ese chat, o pulsar otra parte,
NO DEBE registrarla. CUANDO se acepta levantar la colilla del fondo del depósito cerca de la
puerta garage, el sistema DEBE registrar 2B. La colilla DEBE distinguirse visualmente como tal,
ser levantable y tener identidad propia independiente de los productos vendibles. Mirarla,
mostrar su subtítulo con E y manos vacías, un agarre rechazado o durante pausa NO DEBEN anotarla.
Soltarla y volver a levantarla NO DEBE duplicarla. La pista 2A NO DEBE registrarse por ese
gesto fuera de jornada 4.

La colilla DEBE estar en el depósito sólo mientras está abierta la jornada de 2B, en su lugar
de origen. Fuera de esa jornada NO DEBE verse, la mira NO DEBE enfocarla y NO DEBE poder
levantarse. CUANDO se abre otra jornada, la colilla DEBE salir de la mano y del local, aunque
la noche anterior haya quedado en la mano o en el contenedor. La jornada de la colilla DEBE
salir de la pista 2B, sin repetirse en otro lugar.

### BR-INV-039 — Las hipótesis de la cuarta noche salen de sus pistas

CUANDO se consultan las hipótesis del cierre de jornada 4, el sistema DEBE devolver exactamente:

| Pistas de jornada 4 | Hipótesis disponibles |
|---|---|
| ninguna | sólo 2P |
| sólo 2A | sólo 2A |
| sólo 2B | sólo 2B |
| 2A y 2B | 2A y 2B |

La predeterminada NO DEBE acompañar una hipótesis desbloqueada. Consultar y navegar NO DEBEN
mutar expediente ni elegir una opción. Las jornadas 1 a 3 no tienen pistas; el sistema NO DEBE
inventar 2L ni una pista o foto para 2P.

### BR-INV-040 — Cada pista agrega foto y texto una vez al chat de notas

CUANDO una pista resulta ANOTADA, el sistema DEBE agregar al chat de notas primero
su foto y después su texto, una sola vez, conservando el orden de descubrimiento entre pistas.
REPETIDA y DESCONOCIDA NO DEBEN agregar mensajes ni publicar pista nueva. La foto DEBE ampliarse
con el texto siguiente como adjunto según BR-INV-025. El chat DEBE tener identidad y contenido
propios, y sus mensajes DEBEN conservarse en memoria entre aperturas.
El menú durante el turno DEBE ocultarlo en jornadas 1 a 4, aun con mensajes, y ofrecerlo desde
la 5 cuando tenga contenido. Esa disponibilidad NO DEBE impedir su apertura fija por el cierre
en jornadas 3 y 4. Consultar mensajes DEBE devolver copias sin alterar el guion compartido ni
registrar pistas. Reconstruir identidades y mensajes NO DEBE duplicar el contenido ya recibido.

### BR-INV-041 — El contenido de 2A, 2B y 2P procede de sus fichas

El sistema DEBE entregar para cada identidad los siguientes datos, según las fichas «2A», «2B»
y «2P» de la lista de pistas e hipótesis. Por decisión del usuario del 2026-10-18,
la imagen de 2A DEBE ser una captura del mensaje de Yasmín que dispara la pista, tal como
lo dibuja el chat:

| Identidad | Foto de pista | Texto de pista | Título de hipótesis |
|---|---|---|---|
| 2A | captura del mensaje de Yasmín con la queja | Hoy Yasmín se quejó de que en el local “siempre falta algo o anda todo a medias”. | SIEMPRE FALTAN COSAS |
| 2B | colilla de cigarrillo en el piso | Encontré una colilla de cigarrilo en el depósito. Pero, por lo que me dijeron, ni Enrique ni Yasmín fuman. Raro… | CIGARRILLO EN EL DEPÓSITO |
| 2P | ninguna | ninguno | NO PASA NADA |

Los textos de hipótesis DEBEN ser:

- **2A:** «No me sorprendería tener un jefe inútil. Pero también, ¿no es responsabilidad de Yasmín
  avisar si faltan cosas esenciales? Si esto va a ser frecuente, tengo que empezar a prestar más
  atención a las dinámicas internas del local.»
- **2B:** «¿Puede ser que alguien se esté metiendo sin que nos demos cuenta? Debería examinar bien
  las formas de ingreso al local…»
- **2P:** «Solo se acabó un jabón. No me tengo que hacer la cabeza con algo tan poco trascendental.»

La errata «cigarrilo» DEBE conservarse como aparece en la fuente. Las fotos DEBEN representar
los motivos indicados; NO DEBEN reemplazarse por imágenes de otro personaje u objeto.

### BR-INV-042 — El cierre de las jornadas 3, 4, 5 y 6 pasa a las notas

CUANDO se elige continuar al terminar la devolución de jornada 3, 4, 5 o 6 con la partida en curso
(BR-EMP-011), el sistema DEBE pasar a la reflexión de cierre sobre la misma persiana baja. El
celular DEBE desplazarse desde el centro hasta la mitad izquierda del encuadre sin salir por el
margen inferior, y abrir el chat de notas en modo fijo (BR-INV-026). Un recuadro con el
encabezado de la jornada y su texto actual DEBE aparecer en la mitad derecha, sin superponerse
con el celular. El recorrido DEBE ser continuo y conservar el contenido y el desplazamiento del
chat, y DEBE durar 0,25 segundos reales, como subir y bajar (BR-INV-027). Un cuadro largo NO
DEBE adelantarlo más de 1/30 de segundo.

MIENTRAS dura la reflexión, el jugador DEBE poder desplazar las notas, ampliar sus fotos y
cerrarlas. Q, volver al menú de chats y el movimiento del jugador NO DEBEN responder, y el
turno DEBE seguir cerrado, con el control suspendido. La reflexión NO DEBE tener límite de
tiempo: NO DEBE avanzar un texto ni elegir una hipótesis por el jugador, pase el tiempo que
pase. CUANDO termina la reflexión, el celular
DEBE cerrarse y soltar su modo fijo (BR-INV-028), el recuadro DEBE retirarse y recién entonces
DEBE pedirse la entrada de la noche siguiente. La apertura libre siguiente DEBE subir al centro
(BR-INV-027) y empezar en el menú (BR-INV-022).

Una partida terminada NO DEBE mostrar reflexión. Las jornadas 1 y 2 no declaran reflexión: su
cierre es sólo la devolución. La jornada 7 tampoco la declara mientras siga OQ-INV-004.
En todas ellas, continuar sigue BR-EMP-011 sin pasar por las notas.

### BR-INV-043 — La tercera jornada reflexiona en tres textos

La reflexión de jornada 3 DEBE mostrar el encabezado «Tercera jornada terminada…» y estos
textos, de a uno por vez y en este orden, cada uno con el botón «Continuar»:

1. «Bueno, no será el mejor trabajo del mundo, pero es algo. Por lo menos, con lo que tengo me
   alcanza para cubrir los gastos hasta que Enrique me empiece a pagar.»
2. «Mi psicólogo tenía razón. Mudarme acá sin duda fue la decisión correcta. Desde que llegué,
   no volví a tener ningún episodio de paranoia.»
3. «Está claro que el problema era el estrés de la ciudad. Creo que la vida de pueblo me sienta
   mejor.»

CUANDO se pulsa «Continuar», el sistema DEBE agregar el texto actual al chat de notas una sola
vez y reemplazar el recuadro por el texto siguiente. El recuadro NO DEBE acumular textos; las
notas sí. CUANDO se recibe el tercero, la reflexión DEBE esperar 1,5 segundos y entonces
terminar y pedir una sola entrada a «NOCHE 4» (BR-SHF-019). MIENTRAS corre esa espera, el recuadro
DEBE seguir mostrando el tercer texto, sin responder a «Continuar». La espera DEBE correr con el
tiempo real del juego en ejecución y NO DEBE correr con la pausa. Un cuadro largo NO DEBE pedir
dos entradas. Un pedido repetido sobre un texto ya recibido, o fuera de la reflexión, NO DEBE
avanzar otro texto ni agregar otra nota. Cada texto DEBE tener identidad propia, y
recibirlo NO DEBE registrar una pista ni contar como hipótesis elegida.

### BR-INV-044 — La cuarta jornada se cierra eligiendo una hipótesis

La reflexión de jornada 4 DEBE mostrar el encabezado «Hoy faltaba uno de los jabones para la
limpieza del local. No me quiero empezar a perseguir, pero…». El recuadro DEBE mostrar una
opción por vez, entre las que habilita BR-INV-039, con su título y su texto de hipótesis de
BR-INV-041. La primera mostrada DEBE ser la primera de esa lista. Con una opción DEBE ofrecer sólo «Elegir». Con dos DEBE ofrecer «Anterior», «Siguiente»
y «Elegir»; «Anterior» y «Siguiente» DEBEN mostrar la otra opción. Navegar NO DEBE elegir,
agregar notas ni modificar el expediente.

CUANDO se elige la opción mostrada, el sistema DEBE contestar ACEPTADA, agregar su texto de
hipótesis al chat de notas una sola vez y fijar su identidad como la elección de jornada 4 de la
partida. Una identidad desconocida, de otra noche o no habilitada por el expediente DEBE
contestar NO_DISPONIBLE. Un pedido después de una elección aceptada DEBE contestar REPETIDA. Un
pedido fuera de la etapa de elegir DEBE contestar FUERA_DE_ETAPA. Esas tres respuestas NO DEBEN
agregar notas, cambiar la elección ni pedir una noche. Pausar o salir al menú NO DEBE elegir por
el jugador. Consultar la elección DEBE devolver su identidad, o ninguna antes de elegir.

### BR-INV-045 — La quinta noche espera a la elección

CUANDO la elección de jornada 4 resulta ACEPTADA, el sistema DEBE terminar la reflexión después
de una espera de 1 segundo, y entonces pedir una sola entrada a «NOCHE 5»
(BR-SHF-019). Antes de una elección aceptada, NO DEBE empezar ninguna entrada. MIENTRAS corre la
espera, el recuadro NO DEBE responder a navegar ni a elegir. La espera DEBE correr con el tiempo
real del juego en ejecución y NO DEBE correr con la pausa. Un cuadro largo NO DEBE pedir dos
entradas. La espera NO DEBE reutilizar los tiempos de la placa ni de la persiana.

### BR-INV-046 — La pausa congela cada etapa del cierre

CUANDO se pulsa Esc durante la devolución, el desplazamiento lateral, la reflexión, la elección o
la espera, el sistema DEBE abrir la pausa encima (BR-SAV-016). MIENTRAS la pausa está en
pantalla, ningún botón del cierre DEBE responder, y el recorrido, la entrega de mensajes y cada
espera (la del tercer texto de jornada 3 y la de la elección de jornada 4) NO DEBEN avanzar. Reanudar DEBE conservar la etapa, el desplazamiento del chat, la foto
ampliada, el texto o la opción mostrada, la posición del celular y lo que falta de la espera.

### BR-INV-047 — Las notas conservan el cierre en orden

El chat de notas DEBE conservar, en el orden en que los recibió, los textos de la reflexión de
jornada 3, la foto y el texto de cada pista (BR-INV-040) y el texto de la hipótesis elegida. DEBE
tener un fondo propio, distinto del de los demás chats. Desde jornada 5, el menú DEBE ofrecerlo
con todo ese historial (BR-INV-040), y sus fotos DEBEN ampliarse según BR-INV-025. El historial
de notas cruza la sesión por el guardado (BR-SAV-021); reconstruirlo NO DEBE duplicar mensajes,
publicar pistas ni elegir una hipótesis.

### BR-INV-048 — La quinta jornada suma los diez mensajes de Yasmín sobre el lector

CUANDO abre la jornada 5, por transición o desde un checkpoint, el chat de Yasmín DEBE tener,
después de los dieciséis mensajes de BR-INV-029, exactamente los siguientes diez mensajes
independientes, con estas identidades estables y en este orden:

| Identidad | Texto literal |
|---|---|
| J3_1 | che que onda el lector?? wtf |
| J3_2 | tenés idea de q pasó? |
| J3_3 | para mi lo sacó enrique |
| J3_4 | xq hace unas semanas mencioné q el lector a veces andaba mal |
| J3_5 | seguro pasó por el local para tratar de arreglarlo lo empeoró y lo sacó para que no nos diéramos cuenta de que la cagó xd |
| J3_6 | y lo peor es que no deja un aviso ni nada lpm |
| J3_7 | tuve que usar el modo manual para hacer los tickets 💀 una paja |
| J3_8 | igual te recomiendo hacerte el boludo y no decirle nada porque se pone re pesado si le tocás el ego |
| J3_9 | esperemos que consiga otro rápido 😬 |
| J3_10 | igual con lo rata que es seguro que no lo va a hacer |

Los diez mensajes DEBEN estar disponibles al abrir la jornada, sin arribos programados durante
el turno, y NO DEBEN aparecer en las jornadas 1 a 4. Desde la jornada 5 DEBEN permanecer en el
chat. Las identidades J3_1 a J3_10 conservan su nombre: son identidades, no la jornada. 💀 y 😬
DEBEN verse como glifos, sin caracteres ausentes. Sólo J3_3 tiene tramo de pista (BR-INV-060):
los otros nueve mensajes NO DEBEN emitir un pedido de pista, registrar un hallazgo ni elegir una
hipótesis, ni agregar al chat de notas. Reabrir el celular, volver al menú o repetir la apertura NO DEBE duplicar el
bloque ni alterar el guion compartido. Los mensajes llegan sin leer según BR-INV-023; leer
Yasmín conserva el transcurso del turno de BR-INV-006 y las marcas de BR-INV-008/009. El bloque
cruza la sesión como el resto del guion de apertura (BR-SAV-020): un guardado de una jornada
anterior abre la jornada 5 con el bloque una sola vez.

### BR-INV-049 — Cada hipótesis abre un camino

Cada hipótesis desbloqueable DEBE declarar, como dato del caso, las pistas de la jornada siguiente
que desbloquea: su camino. Las hipótesis predeterminadas (P y L) NO DEBEN tener camino. La ficha
fija la forma: 4A abre 5A y 5B; 4B abre 5C y 5D; 5A abre 6A y 6B; 5B, 6C y 6D; 5C, 6E y 6F; 5D,
6G y 6H; y cada hipótesis de la jornada 6 abre una única pista de la jornada 7 (6A abre 7A, y así
hasta 6H, que abre 7H). Cuáles son esas pistas e hipótesis queda en OQ-INV-004.

### BR-INV-050 — Sólo se anotan las pistas del camino activo

El sistema DEBE calcular, para cada jornada, qué pistas están activas. En la primera jornada con
pistas del caso, la que no tiene hipótesis en la jornada anterior, DEBEN estar activas todas las
de esa jornada. En las siguientes, SI la jornada anterior tiene una hipótesis elegida, ENTONCES
DEBEN estar activas sólo las pistas de su camino. SI se sorteó el camino (BR-INV-051), DEBEN estar
activas las del camino de la hipótesis sorteada. Sin elección con camino ni sorteo, NO DEBE haber
ninguna. Calcularlas NO DEBE alterar el expediente. Registrar una pista inactiva, también por el
gesto de su canal, DEBE contestar DESCONOCIDA y conservar el estado, aunque el jugador interactúe
con su origen.

### BR-INV-051 — Sin pistas, la jornada siguiente sortea un camino de la rama

CUANDO una jornada que sortea la siguiente termina sin ninguna pista encontrada y tenía pistas
activas, el sistema DEBE sortear al azar, una sola vez, una de las hipótesis que esas pistas
activas habilitan, y activar en la jornada siguiente el camino de la sorteada. El caso DEBE
declarar qué jornadas sortean; la ficha lo fija para las jornadas 4 y 5, hacia la 5 y la 6. Con 4A
elegida y ninguna pista en la 5, las pistas activas de la 5 son 5A y 5B, y la 6 activa 6A y 6B (si
sale 5A) o 6C y 6D (si sale 5B), nunca mezcladas. Lo mismo vale en la raíz, donde no hay rama
elegida: sin pistas en la 4, sus pistas activas son 4A y 4B, y la 5 activa 5A y 5B (si sale 4A) o
5C y 5D (si sale 4B). Con una semilla fija el sorteo DEBE dar siempre lo mismo.

El sorteo DEBE quedar guardado en el expediente: repetir el pedido, aun con otra semilla, NO DEBE
cambiarlo ni sortear otra vez, y reconstruir desde lo guardado DEBE conservarlo. Un dato guardado
sin sorteos DEBE cargar sin sorteos, y uno que nombra una hipótesis ajena a esa jornada DEBE
descartarse. SI la jornada anterior encontró alguna pista, ENTONCES NO DEBE sortear. Sortear NO
DEBE elegir una hipótesis por el jugador, agregar notas ni registrar pistas.

### BR-INV-052 — Sin pistas en la 6 no hay en la 7, y sin pistas en la 4 y la 5 no hay en la 6

SI una jornada que no sortea la siguiente termina sin pistas, ENTONCES la siguiente NO DEBE activar
ninguna pista: sin pistas en la jornada 6 no hay pistas en la 7. SI las pistas activas de
la jornada 5 salieron de un sorteo, o no hubo ninguna, y la 5 también termina sin pistas, ENTONCES
la 6 NO DEBE sortear ni activar ninguna: sin pistas en la 4 ni en la 5 no hay pistas en la 6.

### BR-INV-053 — Sin pistas, la hipótesis es P o L

CUANDO una jornada con hipótesis termina sin ninguna pista encontrada, el sistema DEBE ofrecer
sólo la hipótesis P si el jugador nunca encontró una pista en la partida, o sólo la L si encontró
al menos una en una jornada anterior. P y L DEBEN ser datos del caso. SI el caso no declara la L,
ENTONCES el sistema NO DEBE ofrecer otra en su lugar ni inventar su texto: los de 5L y 7L
siguen en OQ-INV-004. Esto no cambia BR-INV-039: en la jornada 4 nunca hay una pista anterior,
así que sin pistas ofrece sólo 2P. Salvedad: mientras la ficha 5L no tenga texto, la hipótesis 5P
DEBE hacer también de 5L en la jornada 5 (BR-INV-062), para que nadie quede sin poder elegir. En la jornada 6 la L es la ficha 6L (BR-INV-116).

### BR-INV-060 — El mensaje J3_3 es el tramo de la pista 5B

El sistema DEBE mostrar en J3_3 el texto entero «para mi lo sacó enrique» en rojo, con el mismo
gesto y la misma marca que el tramo de BR-INV-031. CUANDO se pulsa ese tramo, DEBE emitir un
pedido identificado con 5B, sin deducir la identidad del texto visible ni registrar por ese
gesto un hallazgo o hipótesis. Leer el mensaje, abrir el chat o pulsar otro mensaje del bloque
NO DEBE emitir ese pedido. Repetir el clic válido PUEDE repetir el pedido; la aceptación e
idempotencia del hallazgo corresponden a quien registra la pista (BR-INV-032).

### BR-INV-061 — El contenido de 5B procede de su ficha

CUANDO se registra 5B con la jornada 5 abierta y el canal de chat, el sistema DEBE contestar
ANOTADA y agregar al chat de notas primero su foto y después su texto (BR-INV-040). La pista 5B
DEBE ser de la jornada 5, del canal de chat y del camino de la hipótesis 2A (BR-INV-049). La hipótesis 5B DEBE estar disponible al cierre de
la jornada 5 si y sólo si 5B está registrada. Los datos DEBEN ser, según la ficha «5B» de la lista
de pistas e hipótesis:

| Identidad | Foto de pista | Texto de pista | Título de hipótesis |
|---|---|---|---|
| 5B | foto de perfil de Yasmín | Ya es la segunda vez que Yasmín le echa la culpa a Enrique y me dice que no lo contacte… | INCOMPETENCIA |

El texto de la hipótesis 5B DEBE ser: «¿Será posible que Enrique tenga TAN mal gestionado su
local? ¿O Yasmín está tratando de hacerse la inocente? De lo único que puedo estar seguro es de
que estas cosas raras se deben a la incompetencia de alguno de ellos. Necesito verificar cuál de
los dos es el verdadero responsable…»

Por decisión del usuario del 2026-10-30, la foto DEBE ser la de perfil de Yasmín que entregó el
artista, sin redibujar, y NO DEBE ser la captura de un mensaje. Por decisión del usuario del
2026-10-30, el doble espacio de la ficha entre «la» e «incompetencia» DEBE quedar como un solo
espacio; el mismo criterio vale para el «que que» de la ficha en el texto de la pista. Las pistas
y las hipótesis 2A, 2B y 2P NO DEBEN cambiar.

### BR-INV-062 — La quinta jornada se cierra eligiendo una hipótesis

La reflexión de jornada 5 DEBE mostrar el encabezado «Esta vez desapareció el lector de la
caja…». SI se registró 5B, ENTONCES la única opción DEBE ser la hipótesis 5B (BR-INV-061), sin
la predeterminada. SI no se registró 5B, ENTONCES la única opción DEBE ser la hipótesis 5P, haya o
no pistas en noches anteriores (BR-INV-053). Los datos de 5P DEBEN ser, según la ficha «5P» de la
lista de pistas e hipótesis:

| Identidad | Título de hipótesis | Texto de hipótesis |
|---|---|---|
| 5P | NO HAY PROBLEMA | Está claro que ese aparato estaba viejito y había que jubilarlo. Me tendré que adaptar a trabajar sin él hasta que Enrique consiga otro. |

5P NO DEBE tener pista ni exigencias ni camino (BR-INV-049). Elegir, navegar y pedir una identidad
ajena DEBEN responder como en BR-INV-044, con la elección fijada para la jornada 5. CUANDO la
elección resulta ACEPTADA, el sistema DEBE terminar la reflexión después de la misma espera de
BR-INV-045 y entonces pedir una sola entrada a «NOCHE 6» (BR-SHF-019). Antes de una elección
aceptada, NO DEBE empezar ninguna entrada. Una reflexión restaurada a mitad de la elección DEBE
volver a la elección, y pausar o salir al menú NO DEBE elegir por el jugador. La 5L sigue sin
texto: queda en OQ-INV-004.

### BR-INV-070 — El contenido de 6C procede de su ficha

CUANDO se registra 6C con la jornada 6 abierta y el canal de levantar, el sistema DEBE contestar
ANOTADA y agregar al chat de notas primero su foto y después su texto (BR-INV-040). La pista 6C
DEBE ser de la jornada 6, del canal de levantar y del camino de la hipótesis 5B (BR-INV-049,
BR-INV-050): está activa si la 5B se eligió en la jornada 5, o si la 5 terminó sin pistas y el sorteo de la 6
(BR-INV-051) cayó en el camino de la 5B. Con la 5P elegida y sin sorteo, o con un sorteo que cayó en
otro camino, no lo está (BR-INV-062). La hipótesis 6C DEBE estar disponible al cierre de la
jornada 6 si y sólo si 6C está registrada. Los datos DEBEN ser, según la fila «6C» de la lista de
pistas e hipótesis:

| Identidad | Foto de pista | Texto de pista | Título de hipótesis |
|---|---|---|---|
| 6C | la nota examinada | Encontré un papel asomando por la puerta de la oficina de Enrique. Parece ser una nota que le dejó Yasmín. | NOTA BAJO LA PUERTA |

El texto de la hipótesis 6C DEBE ser: «Me siento mal por haber dudado de Yasmín. Está claro que los
dos somos víctimas de la ineptitud de nuestro jefe y que, sin nuestro trabajo, la estación se
caería a pedazos. ¿Qué otras cosas estará descuidando Enrique? Seguramente encuentre más
información si consigo acceder a su oficina.»

Por decisión del usuario del 2026-11-03, donde la ficha dice «Jazmín» DEBE decir «Yasmín», en el
texto de la pista y en la firma de la nota, y la errata «conisgo» DEBE quedar «consigo». La
hipótesis 5B suma el camino de 6C y 6D (BR-INV-049). Las pistas y las hipótesis 2A, 2B, 2P y 5B, y la colilla, NO DEBEN cambiar.

### BR-INV-071 — La nota asoma bajo la puerta de la oficina de Enrique

La jornada 6 DEBE tener, en el piso, asomando por debajo de la puerta de la oficina de Enrique, una
nota levantable con identidad propia, independiente de los productos vendibles, y distinguible
como un papel manuscrito. Examinada, DEBE poder leerse su texto: «Hola, Enrique. Te dejo esto por
escrito porque no me estás contestando los mensajes. En serio, hace falta revisar si hay un cable
pelado en el local o algo, porque se sigue cortando la luz. Por favor, respondé. Saludos,
Yasmín.» CUANDO se acepta levantarla, el sistema DEBE registrar 6C y avisar la pista nueva, como
con la colilla (BR-INV-038). Mirarla, mostrar su subtítulo con E y manos vacías, un agarre
rechazado o durante pausa NO DEBEN anotarla. Soltarla y volver a levantarla NO DEBE duplicar la
pista ni sus notas.

La nota DEBE estar en el local sólo CUANDO 6C está activa en la jornada abierta (BR-INV-050). En
cualquier otro caso —otra jornada, otra elección o ninguna— NO DEBE verse, NO DEBE ser enfocada
por la mira ni poder levantarse. Una partida guardada en la jornada 6 DEBE conservarla según las
elecciones guardadas. La nota en la mano al abrir la jornada siguiente DEBE salir de la mano y del
local, como la colilla.

### BR-INV-116 — La sexta jornada se cierra eligiendo una hipótesis

La reflexión de jornada 6 DEBE mostrar el encabezado «Un apagón me agarró desprevenido esta
noche…». SI se registró 6C, ENTONCES la única opción DEBE ser la hipótesis 6C (BR-INV-070), sin la
predeterminada. SI no se registró 6C, ENTONCES la única opción DEBE ser la hipótesis 6P si el
jugador nunca encontró una pista en la partida, o la 6L si encontró al menos una en una jornada
anterior (BR-INV-053). Los datos DEBEN ser, según las fichas «6P» y «6L» de la lista de pistas e
hipótesis:

| Identidad | Título de hipótesis | Texto de hipótesis |
|---|---|---|
| 6P | NADA DE OTRO MUNDO | Seguramente fue una sobrecarga o algún cortocircuito de una instalación defectuosa que hizo saltar una térmica. Tengo que dejar de sobrepensar estos asuntos de una vez por todas. |
| 6L | INVESTIGACIÓN INCONCLUSA | No logré encontrar ninguna pista nueva. Me parece que perdí el rastro que me podía ayudar a entender qué es lo que está pasando… |

6P y 6L NO DEBEN tener pista ni exigencias ni camino (BR-INV-049). Elegir, navegar y pedir una
identidad ajena DEBEN responder como en BR-INV-044, con la elección fijada para la jornada 6.
CUANDO la elección resulta ACEPTADA, el sistema DEBE terminar la reflexión después de la misma
espera de BR-INV-045 y entonces pedir una sola entrada a «NOCHE 7» (BR-SHF-019). Antes de una
elección aceptada, NO DEBE empezar ninguna entrada. Una reflexión restaurada a mitad de la
elección DEBE volver a la elección, y pausar o salir al menú NO DEBE elegir por el jugador. Las
reflexiones de las jornadas 3, 4 y 5 NO DEBEN cambiar.

### BR-INV-100 — La quinta jornada abre con la foto de las Cindolor y el aviso del olor

CUANDO abre la jornada 5, por transición o desde un checkpoint, Enrique DEBE incorporar, a
continuación de la devolución de la jornada 4, dos mensajes de apertura con identidades
estables: primero una foto de las Cindolor dentro de la heladera del local, después el texto
literal «Buenas. No sé si habrás notado que hay un olor medio feo en la zona de las heladeras.
Sospecho que algunas de las Cindolor se deben haber echado a perder.». Ampliar la foto DEBE
usar ese texto como adjunto (BR-INV-025). La apertura de la jornada 5 NO DEBE llevar un tercer
mensaje de Enrique. Las jornadas 1 a 4 NO DEBEN mostrar esos mensajes, y retomar una partida en
la jornada 5 DEBE mostrarlos una sola vez, sin leer (BR-INV-023).

### BR-INV-101 — Cada mensaje fechado lleva su hora

El sistema DEBE dar a cada mensaje fechado una hora con forma `H:MM` o `HH:MM`. Un mensaje
recibido lleva la hora que define su ficha: los de Yasmín, las devoluciones del jefe y los
mensajes que el jefe manda al iniciar una jornada. Los introductorios del jefe, a los que la
ficha no les pone hora, llevan la hora que decidió el usuario el 2026-10-26, todas antes de las 20:00 de su
noche: **reemplazar si la ficha las define**. Ningún mensaje recibido DEBE quedar entre las
20:00 y las 08:00 de su noche, porque los mensajes nunca se reciben durante la jornada. La
devolución de una jornada empieza en el minuto que fija la ficha y cada mensaje siguiente suma
un minuto a su orden.

Una nota DEBE llevar la hora del reloj del juego: la de la pista, en el momento en que se
encontró, y la de la hipótesis y la reflexión, en el momento en que empieza el cierre. Esa hora
NO DEBE cambiar al guardar y cargar. Un dato guardado sin hora DEBE cargar sin hora y sin fallar.
Un mensaje legado sin jornada NO DEBE recibir hora. La hora es un dato del mensaje: ninguna
pantalla la calcula ni la inventa.

### BR-INV-102 — El separador marca el día y el momento del día

El sistema DEBE separar el historial en tandas y rotular cada una con el día relativo («HOY»,
«AYER», …) y, debajo, la hora de su primer mensaje. Una tanda cambia cuando cambia el día o el
momento del día: antes del mediodía es la mañana, y desde el mediodía es la tarde. Una
devolución es de la mañana siguiente a su jornada, así que su día es el de la jornada que sigue.
Una tanda cuyo primer mensaje no tiene hora DEBE rotularse sin hora. Un mensaje legado sin
jornada NO DEBE abrir una tanda ni aportar hora.

### BR-INV-103 — Sin ninguna pista en toda la partida, el final es «Empleado estresado»

SI la partida termina con el contrato cumplido y el expediente no registró ninguna pista en
ninguna jornada, ENTONCES el final DEBE ser «Empleado estresado» (final 1) y la devolución DEBE
llevar a su pantalla (BR-SHF-027). Una sola pista registrada, de cualquier jornada, DEBE bastar para
que no lo sea. Elegir una hipótesis sin pista, P o L, NO DEBE contar como pista. SI la partida termina
despedida, ENTONCES el final NO DEBE ser éste, aunque no haya pistas.

### BR-INV-104 — El chat entra y sale deslizándose
CUANDO el jugador abre un chat desde el menú de chats, el chat DEBE entrar desde el borde derecho
del teléfono y tapar la lista hasta quedar en su lugar. CUANDO el jugador vuelve al menú desde
un chat, el chat DEBE salir hacia la derecha y descubrir la lista, que DEBE quedar quieta debajo.
Un chat en modo fijo (BR-INV-026) NO DEBE deslizarse: aparece en su lugar. La duración y la curva
del deslizamiento DEBEN ser las mismas en la entrada y en la salida (OQ-INV-007).

### BR-INV-120 — Un chat se abre en su primer mensaje sin leer
CUANDO se abre un chat en modo libre con uno o más mensajes sin leer, el primero de ellos DEBE
quedar en el borde superior de la lista visible y los demás debajo, en su orden. Los que no
entren DEBEN alcanzarse con la rueda. SI el primero sin leer es el último mensaje, ENTONCES DEBE
quedar arriba aunque debajo sobra espacio. SI todo el chat entra a la vista, ENTONCES NO DEBE
exigir desplazamiento. CUANDO el chat no tiene mensajes sin leer, DEBE abrirse en su último
mensaje (BR-INV-022).

CUANDO el celular está fijo en el chat de Enrique durante el cierre de la jornada (BR-INV-026),
el primer mensaje que llega DEBE quedar en el borde superior y cada siguiente DEBE aparecer
debajo. La lista DEBE bajar sólo lo necesario para que el último mensaje, y la opción que lo
sigue, queden a la vista. CUANDO llega un mensaje a un chat libre que se abrió sin mensajes sin
leer y la lista está en su último mensaje, la lista DEBE bajar hasta el nuevo.

### BR-INV-105 — El deslizamiento no deja la pantalla a medias
MIENTRAS un chat se desliza, un pedido de volver o de abrir otro chat NO DEBE dejar la pantalla
a medio camino ni abrir dos chats: el celular DEBE terminar mostrando un solo destino, el último
pedido. CUANDO el celular baja o se cierra con un deslizamiento en curso, el deslizamiento DEBE
saltar a su estado final, de modo que la próxima apertura empiece desde el menú o desde el chat
que le toque y no desde un punto intermedio.

### BR-INV-110 — La séptima jornada trae cinco chats de compradores que se quejan de un cobro

CUANDO abre la jornada 7, por transición o desde un checkpoint, el sistema DEBE ofrecer, además de
los chats de Enrique y Yasmín, un chat por cada uno de cinco compradores, con su nombre: El Seba,
Suko Yañez, Lucas Ortega, Flavio Balbín y Myriam Melano. Cada chat DEBE tener un solo mensaje del
comprador, con el texto de la ficha «Jornada 7: Responder a quejas» de «Particulares de cada
jornada» y la captura de una transferencia bancaria (BR-INV-113), sin leer. Los mensajes de El
Seba, Suko Yañez y Lucas Ortega DEBEN nombrar el valor cobrado de su queja; los de Flavio Balbín y
Myriam Melano NO DEBEN nombrarlo: sólo la captura lo dice. El valor del texto y el de la captura
DEBEN ser el mismo. Los productos de cada compra son fijos: El Seba, un Amargadito y un Oremos;
Suko Yañez, dos Poético, un Laysnnt y un Zucarachas; Lucas Ortega, una Pura-Cola, un Arvecor y
dos Durextra; Flavio Balbín, un Fernet God, un Burbaloo, un Progres y un Cindolor; Myriam Melano,
un Terminator, un Actroncito y un Marolini. El total correcto de cada compra DEBE salir de los
precios del catálogo. Las jornadas 1 a 6 NO DEBEN mostrar estos chats.

### BR-INV-111 — El valor cobrado se sortea al abrir la noche y la semilla de la partida lo conserva

CUANDO abre la jornada 7, el sistema DEBE sortear el valor cobrado de cada queja. Entre una y
cuatro de las cinco quejas DEBEN tener un valor incorrecto; las otras DEBEN tener exactamente el
total correcto de su compra. Un valor incorrecto DEBE ser el total de la misma compra con uno o
dos de sus productos reemplazados por otros productos del catálogo de esa noche, elegidos al
azar, y NO DEBE coincidir nunca con el total correcto. El sorteo DEBE depender sólo de la semilla
de la partida y de la jornada: con la misma semilla DEBE dar los mismos valores, y retomar un
guardado NO DEBE volver a sortear. Una partida nueva DEBE sortear con su propia semilla.

### BR-INV-112 — Cada queja se responde una vez, dándole la razón o rechazándola

MIENTRAS una queja no tiene respuesta, su chat DEBE ofrecer dos botones: «DARLE LA RAZÓN» y
«RECHAZAR QUEJA». CUANDO el jugador pulsa uno, el chat DEBE mostrar la respuesta del jugador y
retirar los dos botones. Darle la razón DEBE responder, letra por letra de la ficha: «Mil
disculpas. Está claro que hubo un error de nuestra parte. Te descontamos la diferencia en tu
próxima compra». Rechazar DEBE responder: «Perdón, pero no hubo ningún error. El valor que se
cobró coincide con los precios de los productos. Buenas noches». La respuesta DEBE aparecer como
mensaje del jugador, sin el aviso ni el sonido de un mensaje recibido. Una queja respondida NO DEBE
poder responderse otra vez. La respuesta es correcta SI el jugador le da la razón a una queja con
valor incorrecto, o rechaza una con el valor correcto. Responder NO DEBE descontar tiempo
(BR-INV-006). La jornada que se retoma empieza con las cinco sin respuesta.

### BR-INV-113 — La captura de la transferencia lleva el valor y las cuentas

La captura de cada queja DEBE seguir el diseño «Captura de transferencia (jornada 7)» de Figma:
un comprobante del banco ABBA, con el importe en la forma `$ 30.000` (punto de mil), el destino
«ENRIQUE PELDAÑO S.A. ****4689» y el origen «Cuenta de ahorro ****NNNN». El importe DEBE ser el
valor cobrado de esa queja. Los cuatro dígitos del origen DEBEN ser fijos, distintos para cada
uno de los cinco compradores, y NO DEBEN sortearse. Ampliar la captura DEBE mostrarla entera,
como cualquier foto (BR-INV-025).

### BR-INV-114 — Enrique avisa de las quejas al abrir la jornada 7

CUANDO abre la jornada 7, por transición o desde un checkpoint, Enrique DEBE incorporar, a
continuación de la devolución de la jornada 6, tres mensajes de apertura con identidades
estables, en este orden y letra por letra de la ficha «Chat con el jefe»: «Hola, flaco.»; «Mirá,
hay algunos compradores diurnos que están dele que dele insistiendo con que les cobraron mal. No
tengo mucho tiempo para contestarles, así que puse tu número como contacto para quejas.»; y
«Fijate bien si los reclamos tienen sentido o no. A veces les gusta quejarse porque sí.». Las
jornadas 1 a 6 NO DEBEN mostrarlos, y retomar una partida en la jornada 7 DEBE mostrarlos una sola
vez, sin leer.

### BR-INV-115 — La pantalla conjunta muestra el registro y el celular juntos

MIENTRAS la computadora está abierta en la jornada 7, el sistema DEBE ofrecer un botón arriba a
la derecha de su pantalla que abre la pantalla conjunta: el registro de ventas y el celular, lado
a lado y a la vez, cada uno con su propio desplazamiento. En la pantalla conjunta el botón DEBE
volver a la pantalla normal. Apretar Q con la computadora abierta DEBE hacer lo mismo que el
botón, en un sentido y en el otro. La pantalla conjunta DEBE mostrar el menú de chats al abrir. El
celular de la pantalla conjunta NO DEBE tapar ni desenfocar el registro, y el registro DEBE
conservar sus unidades al pasar de una pantalla a la otra. CUANDO la computadora se abre, DEBE
arrancar en la pantalla normal, y al cerrarla el celular DEBE cerrarse con ella. En las
jornadas 1 a 6 NO DEBE haber botón, y Q con la computadora abierta NO DEBE cambiar la pantalla
(BR-INV-021). Pasar de una pantalla a la otra NO DEBE descontar tiempo (BR-INV-006).

### BR-INV-123 — Desde la jornada 6 el celular tiene el chat de Hernán

CUANDO se abre la jornada 6, por transición o desde un checkpoint, el celular DEBE listar el chat
del proveedor, Hernán, después del de Enrique y con su foto, y NO DEBE listarlo en las jornadas 1
a 5. El chat DEBE abrir sin ningún mensaje previo y DEBE tener un botón «Hacer pedido» que no es un
mensaje. Un chat sin mensajes NO DEBE contar como no leído. Leerlo y volver al menú se rige por
BR-INV-009.

### BR-INV-124 — El botón abre la lista de productos

CUANDO el jugador pulsa «Hacer pedido», el sistema DEBE abrir una lista con los treinta y nueve
productos pedibles: los treinta y dos del catálogo y los siete que existen sólo como caja
(BR-STK-054), cada uno con una casilla para marcarlo. La lista DEBE llevar el texto
«Seleccioná los productos que faltan.», el aviso «* Seleccioná uno o varios productos para enviar.»
y el botón «Enviar». Marcar y desmarcar un producto DEBE ser libre. «Enviar» DEBE estar
deshabilitado MIENTRAS no haya ninguno marcado. Cerrar la lista sin enviar NO DEBE dejar ningún
mensaje, y reabrirla DEBE mostrarla sin ninguno marcado.

### BR-INV-125 — El pedido sale con o sin wifi

CUANDO el jugador envía, el sistema DEBE dejar en el chat un único mensaje suyo con el texto «Hola,
¿cómo estás? Te hablo de la estación de servicio. Necesito estos productos:» seguido, dentro del
mismo mensaje, de la lista de los productos elegidos, y cerrar la lista. SI hay wifi al enviar,
ENTONCES, tres segundos de juego después, DEBE llegar el mensaje de Hernán «Hola, buenas noches!
Qué lindo no tener que hablar directamente con Enrique» y, un segundo de juego después de ése, «Dale,
te preparo los productos para mañana. Estaré pasando por allá antes del mediodía». SI no hay wifi
al enviar, ENTONCES el mensaje DEBE quedar en rojo con el texto «Error en la red» y NO DEBE llegar
ninguna respuesta, aunque el wifi vuelva después; el jugador DEBE poder abrir la lista y enviar
otro pedido. El estado del wifi se lee al enviar, y no cambia un mensaje ya enviado. El tiempo en
pausa no cuenta para las respuestas. La primera respuesta es texto normal, sin color de pista.

### BR-INV-126 — La sexta jornada abre con la foto de las estanterías y el aviso del pedido

CUANDO abre la jornada 6, por transición o desde un checkpoint, Enrique DEBE incorporar, a
continuación de la devolución de la jornada 5, dos mensajes de apertura con identidades
estables y la hora 19:48 (BR-INV-101): primero una foto de las estanterías del depósito, después
el texto literal «Buenas tardes. Nos estamos quedando cortos de stock, así que hoy te toca a vos
hacerle el pedido al proveedor. Fijate en las cajas del depósito qué productos se nos acabaron y
mandale un mensaje para que nos los reponga. Ahí te mandé su contacto.». Ampliar la foto DEBE
usar ese texto como adjunto (BR-INV-025). Las jornadas 1 a 5 NO DEBEN mostrar esos mensajes, y
retomar una partida en la jornada 6 DEBE mostrarlos una sola vez, sin leer (BR-INV-023).

## Criterios de aceptación

### AC-INV-001 — Examinar revela *(verifica BR-INV-001)*

DADO un objeto con revelación CUANDO se lo mira sin examinar ENTONCES se lee sólo su nombre; al
examinarlo, el nombre y el texto.

### AC-INV-002 — El texto en blanco no cuenta *(verifica BR-INV-002)*

DADO un objeto con una revelación de un espacio CUANDO se lo examina ENTONCES se lee sólo el
nombre y no es un hallazgo.

### AC-INV-003 — La segunda vez no suma *(verifica BR-INV-003)*

DADO un objeto ya examinado CUANDO se lo examina otra vez ENTONCES no es un hallazgo nuevo y la
cuenta sigue en 1.

### AC-INV-004 — Dos objetos con la misma identidad *(verifica BR-INV-003)*

DADO dos instancias con la misma identidad CUANDO se examinan las dos ENTONCES la cuenta es 1.

### AC-INV-005 — Consultar no marca *(verifica BR-INV-004)*

DADO un objeto sin examinar CUANDO se pregunta dos veces si ya se vio ENTONCES las dos contestan
que no, y la cuenta sigue en 0.

### AC-INV-006 — Un registro y un celular *(verifica BR-INV-005)*

DADO la computadora y el celular CUANDO se enumeran sus opciones ENTONCES la computadora ofrece
sólo el registro de ventas, sin una app de notas manuales, y los chats se ofrecen en el celular.

### AC-INV-007 — Abrir no descuenta *(verifica BR-INV-006)*

DADO un turno entero CUANDO se abre y cierra la computadora, o se abre el celular, se lee un
chat, se amplía una foto y se cierra el celular en el mismo instante ENTONCES el turno no bajó
un solo segundo. CUANDO pasan 30 segundos reales con el celular abierto, sin pausa, ENTONCES
descuenta exactamente lo mismo que 30 segundos sin el celular.

### AC-INV-008 — Reabrir conserva lo anotado *(verifica BR-INV-007)*

DADO el registro abierto con 2 unidades de un producto y 3 de otro CUANDO se cierra y se vuelve
a abrir la computadora ENTONCES siguen esas cantidades y el mismo total.

### AC-INV-009 — Lo leído no vive en el guión *(verifica BR-INV-008)*

DADO una conversación leída CUANDO se la vuelve a cargar de disco en otra partida ENTONCES está
sin leer.

### AC-INV-010 — Leer apaga sólo su pestaña *(verifica BR-INV-009)*

DADO tres conversaciones con mensajes sin leer CUANDO se lee una ENTONCES ésa queda en 0 y las
otras dos conservan los suyos. CUANDO llegan dos mensajes más a la conversación leída ENTONCES
ésta tiene 2 sin leer y las otras conservan los suyos; abrirla de nuevo la deja en 0.

### AC-INV-012 — Cerrar el celular conserva lo leído *(verifica BR-INV-011)*

DADO un chat leído CUANDO se cierra y reabre el celular ENTONCES ese chat sigue leído.

### AC-INV-019 — El pensamiento no retiene *(verifica BR-INV-017)*

DADO lo que reveló algo no levantable, de una sola entrada, CUANDO todavía no se avanzó
ENTONCES ya se puede abandonar.

### AC-INV-020 — Las manos vacías no examinan *(verifica BR-INV-018, BR-INV-001)*

DADO las manos vacías y la mira sobre la mopa, con una revelación, CUANDO se pide examinar dos
veces ENTONCES la línea de subtítulo muestra «Una mopa para limpiar las manchas del local.» y
ningún texto de la revelación; no hay examen, el jugador no queda retenido, la mopa sigue en su
lugar, las manos siguen vacías, la cuenta de hallazgos sigue en 0 y no se avisa que empezó o
terminó un examen. DADO algo en la mano y la mira sobre otro levantable ENTONCES se examina lo
que se lleva.

### AC-INV-022 — Las teclas giran lo examinado *(verifica BR-INV-019)*

DADO algo en examen CUANDO se aprieta el costado derecho medio segundo ENTONCES gira sobre el
eje vertical la velocidad fija por medio segundo, y adelante lo gira sobre el horizontal. Sin
entrada, o con dos teclas opuestas, no gira.

### AC-INV-023 — El mouse gira sólo arrastrando *(verifica BR-INV-019)*

DADO algo en examen CUANDO se mueve el mouse sin clic ENTONCES no gira; con el clic apretado,
gira.

### AC-INV-024 — El clic no cierra el examen *(verifica BR-INV-019)*

DADO algo en examen CUANDO se hace clic ENTONCES sigue en examen y las manos no cambian. La
tecla de examinar lo termina.

### AC-INV-025 — La jornada abre sin examen *(verifica BR-INV-020)*

DADO un examen en curso CUANDO se abre la jornada ENTONCES no hay nada en examen y el jugador no
está retenido. Sin examen en curso, no se avisa que terminó un examen.

### AC-INV-026 — Cinco estados ante Q *(verifica BR-INV-021)*

DADO, por turno, (1) celular cerrado y jornada libre, (2) celular abierto libre, (3) celular
cerrado con otra interfaz al control, (4) celular cerrado durante un examen y (5) celular cerrado
con el turno cerrado CUANDO se pulsa Q ENTONCES los estados resultan, respectivamente, abierto
en menú, cerrado, cerrado con la otra interfaz intacta, cerrado con el examen intacto y cerrado.

### AC-INV-027 — Reabrir y navegar *(verifica BR-INV-022)*

DADO el celular cerrado desde un chat y, por separado, desde una foto CUANDO se reabre ENTONCES
ambas veces muestra el menú. CUANDO se pulsa un botón ENTONCES abre ese chat con cero no leídos y,
si no tenía ninguno sin leer, en su último mensaje (BR-INV-120); la rueda permite llegar al primero
y la flecha vuelve al menú.
DADO un menú sin chats ENTONCES no hay botones ni error; con un chat de un mensaje, éste queda
a la vista sin desplazar.

### AC-INV-028 — El corte por jornada incluye el límite *(verifica BR-INV-023)*

DADO un chat con un mensaje de jornada 1 y otro de jornada 3 CUANDO se abren las jornadas 1 y 2
ENTONCES muestra sólo el primero; en la 3 muestra los dos, en ese orden. DADO otro chat distinto
del de notas, con todo en jornada 2, ENTONCES no tiene botón en la 1 y sí en la 2. Los botones
visibles conservan el orden
de interlocutores. Dejar correr una jornada no agrega mensajes del guión de la siguiente.

### AC-INV-029 — Recibir tiene efecto local y avisa una vez *(verifica BR-INV-024, BR-INV-009)*

DADO un chat leído CUANDO recibe un mensaje con el celular cerrado ENTONCES se agrega al final,
hay 1 no leído y se emite un solo aviso. DADO ese chat abierto CUANDO recibe otro ENTONCES
aparece al final y cuenta como nuevo no leído. DADO otra bandeja del mismo guión ENTONCES no
contiene ninguno de los recibidos. Modificar las listas consultadas no altera la bandeja.

### AC-INV-030 — Una recepción inválida no avisa *(verifica BR-INV-024)*

DADO una bandeja CUANDO se intenta recibir un mensaje nulo o uno para un interlocutor sin
conversación ENTONCES no cambian mensajes ni no leídos y se emiten cero avisos de recepción.

### AC-INV-031 — Los cuatro casos de foto *(verifica BR-INV-025)*

DADO, por turno, una foto seguida de texto sin foto, una foto final, dos fotos consecutivas y un
mensaje sólo de texto CUANDO se pide ampliar el primero ENTONCES: la primera muestra su foto y
exactamente el texto siguiente; la segunda se amplía sin texto; la tercera amplía sólo la primera
sin texto si el grupo termina ahí; la cuarta conserva la pantalla. DADO dos fotos sin texto
seguidas por texto sin foto en la misma jornada y momento ENTONCES ambas amplían con ese texto.
Una foto con texto, otra jornada u otro momento intermedios impiden tomar un texto posterior.
DADO una foto ampliada CUANDO se hace clic izquierdo
en cualquier lugar ENTONCES vuelve al chat conservando su desplazamiento anterior.

### AC-INV-032 — El fijo sólo se suelta explícitamente *(verifica BR-INV-026)*

DADO el turno cerrado CUANDO se fija una conversación existente ENTONCES el celular abre ese
chat. CUANDO se pulsa Q o se intenta volver al menú ENTONCES sigue fijo en el chat. CUANDO se
amplía y cierra una foto ENTONCES vuelve al chat fijo; al soltarlo queda cerrado. Soltar otra
vez no cambia nada.

### AC-INV-033 — Subir, invertir y bajar *(verifica BR-INV-021, BR-INV-027)*

DADO el celular cerrado CUANDO se pulsa Q ENTONCES parte fuera del margen inferior y avanza
hacia el centro. CUANDO se pulsa Q durante la subida ENTONCES baja desde su posición actual,
sin salto de posición ni duplicado, y termina fuera del encuadre con el velo retirado. La prueba
mide cada recorrido completo de 0,25 segundos; una inversión conserva la posición actual. DADO el
celular empezando a subir CUANDO un cuadro llega 2 segundos tarde ENTONCES sigue entre el
margen inferior y el centro, y continúa moviéndose: no aparece ya centrado. DADO el
celular arriba CUANDO se hace clic izquierdo por fuera de él ENTONCES no pide cerrarse; adentro,
tampoco.

### AC-INV-034 — Proporción, velo y orden de dibujo *(verifica BR-INV-027)*

DADO el celular completamente arriba, tanto en escritorio como en web, CUANDO se mide su
rectángulo en resoluciones 1920×1080 y 1280×720 ENTONCES su ancho dividido por su alto es 9/16
y su centro coincide con el del encuadre. DADO el mismo cuadro con y sin celular CUANDO se
comparan regiones exteriores de bordes contrastados ENTONCES el velo reduce la luminancia y
ensancha la transición de esos bordes aun normalizando su luminancia: oscurecer por sí solo no
satisface el desenfoque. Los bordes del texto del celular conservan su nitidez con el velo
presente, porque el celular se dibuja después de él.
Su orden de dibujo está encima del HUD, computadora y cierre, y debajo de avisos y pausa.

### AC-INV-035 — El recordatorio depende del turno *(verifica BR-INV-027)*

DADO el turno abierto CUANDO el celular está cerrado o abierto ENTONCES se ve un único ícono
con «Q» en la esquina inferior izquierda. CUANDO cierra el turno ENTONCES el ícono no se ve.
DADO el recordatorio visible CUANDO se abre la computadora ENTONCES se oculta; al cerrarla
reaparece. SI el turno cierra con la computadora abierta, ENTONCES cerrar la computadora NO
DEBE volver a mostrarlo.

### AC-INV-036 — Pausar conserva, cerrar limpia *(verifica BR-INV-028)*

DADO el celular fijo con una foto ampliada CUANDO se pulsa Esc, luego Q, y se reanuda ENTONCES
vuelve la misma foto. DADO el celular abierto CUANDO cierra el turno ENTONCES queda cerrado y el control
permanece suspendido por el cierre. CUANDO abre otra jornada ENTONCES sigue cerrado y el primer
Q permitido abre el menú.

### AC-INV-037 — Retomar reconstruye los chats *(verifica BR-INV-023, BR-INV-008)*

DADO un guardado en jornada 5, con chats que antes se leyeron y mensajes recibidos fuera del guión,
CUANDO se retoma ENTONCES se ven los mensajes del guión de jornada menor o igual a 5, todos sin
leer, y ninguno de los recibidos fuera de él salvo las devoluciones de Enrique de las jornadas 1
a 4, intercaladas con los mensajes de cada jornada: cada devolución después de los de su
jornada y antes de los de la siguiente, hasta la devolución 4. Los registros legados sin jornada conservan su orden sin fechas inventadas.
Abrir y cerrar sin entrar a un chat conserva los contadores.

### AC-INV-038 — Un botón por chat y una imagen de reemplazo *(verifica BR-INV-023)*

DADO dos chats visibles, uno con imagen y dos no leídos y otro sin imagen ni no leídos, CUANDO
se muestra el menú ENTONCES hay dos botones: el primero con nombre, imagen y contador 2, y el
segundo con nombre y círculo liso del tema, sin contador cero.

### AC-INV-039 — La entrada exacta en jornada 4 ofrece sus dos chats *(verifica BR-INV-029, BR-INV-023, BR-INV-008, BR-INV-009)*

DADO las jornadas 1 y 3 CUANDO se abre el menú ENTONCES sólo ofrece Enrique. DADO apertura de jornada 4
por transición y, por separado, checkpoint CUANDO se consulta ENTONCES ofrece Enrique y Yasmín,
con los roles Jefe y Compañera de trabajo. Yasmín tiene exactamente las dieciséis identidades
J2_1 a J2_16 con los textos de BR-INV-029, incluido el doble espacio antes de 💪, sin mensajes
de jornada 5. Leer Yasmín deja su contador en cero sin cambiar el de Enrique ni el guion.

### AC-INV-040 — La apertura queda entre las devoluciones *(verifica BR-INV-030, BR-INV-029)*

DADO cierre 3 y apertura 4 CUANDO se recorre Enrique ENTONCES están las entradas de las
jornadas 1 a 3, cada bloque seguido por la devolución de su cierre, y después la foto del
contenedor y su texto, en ese orden. CUANDO cierra la 4 ENTONCES su devolución queda después de ese texto, cada mensaje una
vez. Reabrir celular, volver al menú y repetir apertura 4 no cambian identidades, contenido u orden.
Los dieciséis mensajes de Yasmín tampoco se duplican al repetir esos recorridos.

### AC-INV-041 — El clic de pista tiene un borde exacto *(verifica BR-INV-031)*

DADO J2_6 visible CUANDO se mide el texto ENTONCES sólo «acá siempre falta algo» está en rojo
y las palabras anteriores y posteriores siguen blancas y literales. CUANDO se abre o lee,
o se pulsa fuera del tramo ENTONCES hay cero pedidos de 2A. Un clic dentro emite exactamente
un pedido de 2A y dos clics válidos pueden emitir dos, con cero cambios directos del expediente.
Una identidad o tramo inexistente no emite. Se ejerce en escritorio y paquete web.

### AC-INV-042 — La foto del contenedor usa el adjunto de su apertura *(verifica BR-INV-029, BR-INV-025, BR-INV-027)*

DADO Enrique en jornada 4 CUANDO se pulsa su foto de apertura ENTONCES se amplía completa,
muestra el contenedor del local y adjunta exactamente el texto de BR-INV-029, no la devolución
anterior ni un tacho interior. CUANDO se cierra ENTONCES vuelve al mismo chat y desplazamiento.
El recorrido de ambos chats, foto y tramo de pista a 1920×1080 y 1280×720, en escritorio y
web, conserva textos completos dentro del celular, sin recortes ni errores.
DADO Yasmín sin retrato aprobado ENTONCES muestra el círculo liso, conservando nombre y rol.

### AC-INV-043 — Nueva, repetida y ajena *(verifica BR-INV-032)*

DADO un caso consistente con una pista A sin exigencias CUANDO se registra A dos veces y luego
una identidad ajena ENTONCES responde ANOTADA, REPETIDA y DESCONOCIDA; el expediente contiene
sólo A y se publica una pista nueva con su identidad y jornada, sin cambios por los otros intentos.

### AC-INV-044 — Una exigencia pendiente no registra *(verifica BR-INV-033)*

DADO pistas A y B con B exigiendo A CUANDO se registra B antes de A ENTONCES responde DESCONOCIDA
y quedan cero pistas. CUANDO se registra A y después B ENTONCES ambas resultan ANOTADA y el orden
es A/B. DADO una pista C que exige A y B ENTONCES tener sólo A no basta para registrarla.

### AC-INV-045 — Umbral exacto y condición adicional *(verifica BR-INV-034)*

DADO un caso de prueba con tres pistas A/B/C sin exigencias, un desenlace con umbral 2 sin
exigencias y otro con umbral 2 que exige C CUANDO se registran A y B ENTONCES sólo se alcanza
el primero; con una pista no se alcanza ninguno. CUANDO se registra C ENTONCES se alcanza el
segundo. Consultar y repetir B/C no repite avisos; cada desenlace se publica una vez.

### AC-INV-046 — Cuatro inconsistencias se distinguen del caso válido *(verifica BR-INV-035)*

DADO, por turno, un caso con A repetida, B que exige una pista inexistente, A/B que se exigen
entre sí, y un desenlace cuyo umbral supera la cantidad de pistas posibles CUANDO se valida
ENTONCES los cuatro son inconsistentes. Un desenlace que exige una identidad inexistente
también es inconsistente. El caso A/B sin ciclos con desenlace alcanzable sí es consistente.

### AC-INV-047 — Reconstrucción saneada y sin mensajes nuevos *(verifica BR-INV-036)*

DADO un caso con A/B y la lista B/A/B/ajena CUANDO se reconstruye ENTONCES el expediente entrega
B/A, sin duplicados ni desconocidas y sin publicar pista nueva. Modificar la copia entregada
no altera el expediente. Consultar no escribe disco ni reconstruye un expediente alternativo.

### AC-INV-048 — La frase exacta es el disparador *(verifica BR-INV-038, BR-INV-037, BR-INV-032)*

DADO jornada 4 sin pistas CUANDO se abre y lee el chat de Yasmín o se pulsa otra parte de J2_6
ENTONCES no hay pista nueva. CUANDO se pulsa «acá siempre falta algo» ENTONCES anota sólo 2A;
repetir la pulsación no la duplica ni emite otro aviso. En jornada 3 o 5 ese gesto no registra 2A.

### AC-INV-049 — La colilla exige un levantamiento aceptado *(verifica BR-INV-038, BR-INV-037)*

DADO jornada 4 y la colilla visible al fondo del depósito cerca de la puerta garage CUANDO se
mira o se pide E con manos vacías ENTONCES sigue sin 2B. Agarre rechazado o pausa tampoco anota.
CUANDO el agarre se acepta ENTONCES la misma colilla queda en mano y se anota 2B. Soltarla y
volver a levantarla no duplica pista ni mensajes; sostenerla al cierre conserva el hallazgo.
La colilla es reconocible visualmente y no pertenece al catálogo vendible. DADO las jornadas 1,
3 y 5 abiertas ENTONCES la colilla no se ve, no tiene colisión, la mira no la enfoca y no se
puede agarrar. DADO la colilla en la mano o en el contenedor al cerrar la jornada 4 CUANDO se
abre la 5 ENTONCES no queda en la mano, no se ve y no está en el contenedor. DADO una partida
guardada en la jornada 4 CUANDO se continúa, una o dos veces seguidas, ENTONCES hay una sola
colilla, visible y levantable en su lugar de origen.

### AC-INV-050 — Cuatro combinaciones y ninguna opción extra *(verifica BR-INV-039)*

DADO expedientes de jornada 4 con cero pistas, sólo 2A, sólo 2B y ambas, CUANDO se consultan
las opciones ENTONCES son respectivamente [2P], [2A], [2B] y [2A, 2B]. Repetir la consulta y
navegar conserva identidades y mensajes. Nunca aparece 2L y 2P no crea foto ni pista ficticia.

### AC-INV-051 — Orden de descubrimiento y pares de mensajes *(verifica BR-INV-040, BR-INV-032, BR-INV-025)*

DADO notas vacías CUANDO se anota 2B y después 2A ENTONCES hay exactamente cuatro mensajes:
foto 2B, texto 2B, foto 2A y texto 2A. Repetir ambas pistas y registrar una desconocida conserva
esos cuatro. Ampliar cada foto usa sólo su texto siguiente; cerrarla conserva chat y posición.
Reabrir otra jornada y reconstruir las mismas identidades y mensajes no duplica el contenido.

### AC-INV-052 — Menú y modo fijo tienen permisos distintos *(verifica BR-INV-040, BR-INV-026, BR-INV-023)*

DADO notas con dos mensajes de 2A CUANDO se abre el menú durante jornadas 1 a 4 ENTONCES notas
no tiene botón; en la 5 sí. DADO cierre de jornada 3 o 4 CUANDO se fija notas ENTONCES abre su
chat propio sin pasar por el menú, aun vacío en la 3, permite leer y ampliar, y Q no lo cierra.

### AC-INV-053 — Datos exactos y fotos propias *(verifica BR-INV-041)*

DADO las identidades 2A, 2B y 2P CUANDO se consultan sus datos ENTONCES títulos, textos de pista
y de hipótesis coinciden exactamente con BR-INV-041, incluida «cigarrilo». La foto 2A es la captura
del mensaje de Yasmín con la queja, no la imagen de su contacto, y 2B muestra la colilla
en el piso; 2P no tiene foto ni texto de pista.
Las tres opciones conservan sus identidades al volver a consultar.

### AC-INV-054 — Revelación y pista no comparten contador *(verifica BR-INV-037, BR-INV-032, BR-INV-001)*

DADO un objeto con revelación ajena a las pistas del caso CUANDO se lo examina dos veces ENTONCES
su cuenta de hallazgos es 1 y el expediente sigue vacío. DADO la colilla levantada en jornada 4
ENTONCES 2B está anotada por el agarre, sin exigir examen ni convertir los demás subtítulos en
pistas. DADO una pista de objeto no levantable o diálogo de comprador declarada en un caso de
prueba CUANDO se usa otro canal ENTONCES no se anota; el gesto declarado sí la anota una vez.

### AC-INV-055 — Consultar notas entrega copias *(verifica BR-INV-040, BR-INV-036)*

DADO 2A anotada y una copia de sus identidades y mensajes CUANDO se vacían o reordenan esas
copias ENTONCES el expediente conserva 2A, notas conserva foto/texto en ese orden y el guion
compartido permanece intacto. Las consultas no registran pistas ni emiten pista nueva.

### AC-INV-056 — El historial fechado vuelve igual y no fusiona textos *(verifica BR-INV-030, BR-INV-023, BR-INV-008)*

DADO checkpoint de apertura 4 con las devoluciones 1 a 3 fechadas CUANDO se retoma ENTONCES
muestra los mensajes de las jornadas 1 a 3 intercalados con las devoluciones 1 a 3, y después
la apertura 4, y los dieciséis mensajes de Yasmín están
sin leer. DADO dos devoluciones de distintas jornadas con el mismo texto CUANDO se reconstruyen
ENTONCES permanecen dos mensajes con sus identidades y posiciones distintas; modificar una
lista consultada no cambia el historial ni el guion.

### AC-INV-057 — Del centro a la izquierda sin bajar *(verifica BR-INV-042)*

DADO la devolución de jornada 3 terminada, a 1920 × 1080 y a 1280 × 720, CUANDO se elige
continuar ENTONCES la persiana sigue baja y en cada cuadro el borde inferior del celular queda
dentro del encuadre. Su centro horizontal nunca aumenta y, a los 0,25 segundos, termina a la
izquierda del centro del encuadre; a los 0,125 segundos todavía no llegó. Al final, el chat de notas está abierto en modo fijo y el recuadro está entero a la
derecha del centro, sin intersección con el celular. DADO el recorrido empezado CUANDO un cuadro
llega 2 segundos tarde ENTONCES avanzó lo que corresponde a 1/30 de segundo. DADO la reflexión en
pantalla CUANDO se pulsa Q o se pide volver al menú de chats ENTONCES sigue fija en notas; la
rueda desplaza y una foto se amplía y se cierra. El turno no descuenta y el jugador no se mueve.

### AC-INV-058 — Sin reflexión, y la apertura siguiente al centro *(verifica BR-INV-042)*

DADO un despido en jornada 3, 4, 5 o 6 CUANDO termina su devolución ENTONCES sólo se ofrece volver al
menú y no aparece la reflexión. DADO el cierre de la jornada 1 o 2 con la partida en curso
CUANDO se elige continuar ENTONCES el celular baja y empieza la noche siguiente, sin reflexión.
DADO la reflexión de jornada 3 terminada CUANDO empieza la entrada ENTONCES el celular está
cerrado, sin modo fijo, y el recuadro no está; CUANDO se pulsa Q en la noche 4 ENTONCES sube al centro y abre el menú.

### AC-INV-059 — Tres textos, tres notas *(verifica BR-INV-043)*

DADO la reflexión de jornada 3 con notas vacías ENTONCES el recuadro dice «Tercera jornada
terminada…» y el texto 1. CUANDO se pulsa «Continuar» ENTONCES las notas son [texto 1], el
recuadro muestra sólo el texto 2 y no hay entrada. CUANDO se repite el pedido del texto 1
ENTONCES las notas siguen [texto 1] y el recuadro sigue en el texto 2. CUANDO se pulsa
«Continuar» una vez más ENTONCES las notas son [texto 1, texto 2], el recuadro muestra el
texto 3. CUANDO se pulsa «Continuar» sobre el texto 3 ENTONCES las notas son [texto 1, texto 2,
texto 3] y todavía no hay entrada. CUANDO pasa la espera declarada menos un cuadro ENTONCES sigue
sin haber entrada y el recuadro sigue en el texto 3, sin responder a otro «Continuar» ni agregar
una nota. CUANDO pasa el cuadro siguiente ENTONCES hay exactamente una entrada «NOCHE 4», y otro
pedido no agrega nada. DADO la espera empezada CUANDO un cuadro llega 10 segundos tarde ENTONCES
hay a lo sumo una entrada. DADO la espera a mitad CUANDO se pausa, pasan 3 segundos y se reanuda
ENTONCES falta lo mismo que antes de pausar. Los textos 1 y 2 se reemplazan en el acto, sin
espera. El expediente sigue vacío y no hay elección.

### AC-INV-060 — Cuatro combinaciones en el recuadro *(verifica BR-INV-044, BR-INV-039)*

DADO el cierre de jornada 4 ENTONCES el encabezado es «Hoy faltaba uno de los jabones para la
limpieza del local. No me quiero empezar a perseguir, pero…». DADO cero pistas, sólo 2A y sólo
2B ENTONCES se muestran 2P, 2A y 2B con su título y su texto, y sólo «Elegir». DADO 2A y 2B
ENTONCES se muestra 2A con «Anterior», «Siguiente» y «Elegir»; «Siguiente» muestra 2B,
«Siguiente» otra vez muestra 2A, y «Anterior» muestra 2B. Navegar no cambia las notas, el
expediente ni la elección.

### AC-INV-061 — Elegir una sola vez *(verifica BR-INV-044)*

DADO 2A y 2B anotadas, con sus cuatro mensajes en notas, CUANDO se muestra 2B y se elige
ENTONCES contesta ACEPTADA, las notas tienen cinco mensajes con el texto de hipótesis 2B al
final, y la elección es 2B. CUANDO se pide elegir otra vez, 2B o 2A, ENTONCES contesta REPETIDA y
las notas siguen con cinco. DADO sólo 2A anotada CUANDO se pide 2B, 2P o una identidad
desconocida ENTONCES contesta NO_DISPONIBLE. DADO la devolución o la reflexión de jornada 3 en
pantalla CUANDO se pide elegir ENTONCES contesta FUERA_DE_ETAPA. En esos tres casos no hay nota,
elección ni entrada. Antes de elegir, consultar la elección no devuelve ninguna. DADO la
elección de jornada 4 o el texto 2 de jornada 3 en pantalla CUANDO pasan 10 minutos ENTONCES
siguen en pantalla, sin nota nueva, sin elección y sin entrada.

### AC-INV-062 — La espera retiene la quinta noche *(verifica BR-INV-045)*

DADO la elección de jornada 4 aceptada CUANDO pasa la espera declarada menos un cuadro
ENTONCES no hay entrada; CUANDO pasa el cuadro siguiente ENTONCES hay exactamente una entrada
«NOCHE 5». DADO la espera empezada CUANDO un cuadro llega 10 segundos tarde ENTONCES hay a lo
sumo una entrada. DADO la espera a mitad CUANDO se pausa, pasan 3 segundos y se reanuda
ENTONCES falta lo mismo que antes de pausar. Navegar o elegir durante la espera no cambia nada.
Ni la espera ni la entrada descuentan el turno de la jornada 5.

### AC-INV-063 — La pausa congela cada etapa *(verifica BR-INV-046)*

DADO cada etapa por separado —la devolución con 2 de 4 mensajes, el recorrido lateral a mitad,
la reflexión de jornada 3 en el texto 2 con las notas desplazadas, la espera del texto 3 a mitad,
la elección mostrando 2B y la espera de la elección a mitad— CUANDO se pulsa Esc, se pulsan los botones del cierre, pasan 3 segundos y se
reanuda ENTONCES la etapa, los mensajes visibles, la posición del celular, el desplazamiento, el
texto u opción mostrada y lo que falta de la espera son los mismos, y los botones pulsados
durante la pausa no tuvieron efecto.

### AC-INV-064 — Las notas de la quinta noche *(verifica BR-INV-047, BR-INV-040)*

DADO una partida que recibió los tres textos de jornada 3, anotó 2B y eligió 2B CUANDO se abre
el menú en jornada 5 ENTONCES ofrece el chat de notas; CUANDO se abre ENTONCES muestra texto 1,
texto 2, texto 3, foto 2B, texto de pista 2B y texto de hipótesis 2B, en ese orden, y la foto 2B
se amplía con su texto. Su fondo difiere del fondo del chat de Enrique. En jornadas 1 a 4, el
menú no lo ofrece.

### AC-INV-065 — Las instrucciones llegan con su jornada *(verifica BR-INV-030, BR-INV-023)*

DADO la jornada 1 abierta CUANDO se recorre Enrique ENTONCES tiene 11 entradas y ninguna de las
jornadas 2 y 3. DADO el cierre 1 y la jornada 2 abierta ENTONCES tiene las 11 de la jornada 1,
los mensajes de la devolución 1 y los de la jornada 2, en ese orden. DADO la jornada 3 tras el
cierre 2 ENTONCES siguen la devolución 2, Intro 10, la foto de Intro 11 e Intro 11. DADO un
guardado de la jornada 3 CUANDO se retoma ENTONCES el orden es el mismo.

### AC-INV-066 — La entrada exacta en jornada 5 suma los diez mensajes *(verifica BR-INV-048, BR-INV-023, BR-INV-008, BR-INV-009)*

DADO la apertura de la jornada 5 por transición, tras leer el chat de Yasmín en la jornada 4,
CUANDO se consulta Yasmín ENTONCES tiene 26 entradas: J2_1 a J2_16 con los textos de
BR-INV-029, leídas, y después J3_1 a J3_10 con los textos de BR-INV-048, en ese orden, sin leer;
su contador es 10. DADO la apertura de la jornada 5 desde un checkpoint ENTONCES tiene las mismas
26 entradas, todas sin leer. Leer Yasmín deja su contador en cero sin cambiar el de Enrique ni el
guion compartido.

### AC-INV-067 — Antes de la jornada 5 el bloque no existe *(verifica BR-INV-048, BR-INV-029, BR-INV-023)*

DADO cada jornada de la 1 a la 4 CUANDO se consulta el menú y el chat de Yasmín, si lo ofrece,
ENTONCES ninguna identidad J3_1 a J3_10 está en ningún chat, y en la jornada 4 Yasmín tiene
exactamente las dieciséis identidades de BR-INV-029. DADO una partida nueva ENTONCES empieza en la
jornada 1 sin Yasmín y sin ese bloque. Los mensajes de Enrique de la jornada 5 son los mismos
con o sin el bloque de Yasmín.

### AC-INV-068 — El bloque no concede pistas y muestra sus glifos *(verifica BR-INV-048, BR-INV-031, BR-INV-060)*

DADO la jornada 5 abierta, sin pistas anotadas, CUANDO se miden los diez mensajes ENTONCES
sólo J3_3 tiene tramo en rojo, y abrir, leer o pulsar cualquier parte de J3_1, J3_2 y J3_4 a
J3_10 emite cero pedidos de pista y deja intactos el expediente y el chat de notas. DADO J3_7 y J3_9 CUANDO se
muestran a 1920×1080 y a 1280×720, en escritorio y en paquete web, ENTONCES 💀 y 😬 se dibujan
como glifos, sin caracteres ausentes, y los textos completos quedan dentro del celular, sin
recortes ni errores.

### AC-INV-069 — Repetir la apertura no duplica el bloque *(verifica BR-INV-048, BR-INV-030)*

DADO la jornada 5 abierta CUANDO se reabre el celular, se vuelve al menú, se repite la apertura
5 y se consulta Yasmín dos veces ENTONCES tiene 26 entradas con identidades distintas, en el
mismo orden, y modificar una lista consultada no cambia el guion. DADO la jornada 6 abierta
ENTONCES Yasmín conserva esas 26 entradas, sin mensajes nuevos.

### AC-INV-070 — Q o Esc cierran el celular libre *(verifica BR-INV-021)*

DADO el celular abierto en modo libre y, por separado, a mitad de la subida CUANDO se pulsa Q
ENTONCES baja desde su posición actual. CUANDO se pulsa Esc en esos mismos estados ENTONCES baja
igual y la pausa no se abre, tampoco cuando el navegador suelta el cursor junto con ese Esc.
DADO el celular cerrado CUANDO se pulsa Esc ENTONCES se abre la
pausa. DADO el celular abierto CUANDO se pulsa Esc dos veces seguidas, con la bajada del primero
terminada, ENTONCES el primero lo cierra y el segundo abre la pausa.

### AC-INV-071 — Un clic afuera no cierra, y la foto cede el primer Esc *(verifica BR-INV-021, BR-INV-025)*

DADO el celular abierto en modo libre, con y sin foto ampliada, CUANDO se hace clic izquierdo
por fuera del teléfono ENTONCES el celular sigue abierto y no pide cerrarse; con la foto ampliada,
el clic la cierra y vuelve al mismo chat, como antes. DADO una foto ampliada en modo libre
CUANDO se pulsa Esc ENTONCES se cierra la foto, el celular sigue abierto y la pausa no se abre;
CUANDO se pulsa Esc otra vez ENTONCES el celular baja y la pausa no se abre; CUANDO se pulsa un
tercero ENTONCES se abre la pausa.

### AC-INV-072 — El modo fijo ignora Q y deja pausar con Esc *(verifica BR-INV-021, BR-INV-026)*

DADO el celular fijo entre jornadas CUANDO se pulsa Q ENTONCES sigue abierto en el chat fijo.
CUANDO se pulsa Esc ENTONCES sigue abierto y se abre la pausa por encima (BR-SAV-016); al
reanudar sigue en el mismo chat.

### AC-INV-073 — Un resorte suave al subir y al bajar *(verifica BR-INV-027)*

DADO el celular cerrado CUANDO se pulsa Q ENTONCES, en algún cuadro de la subida, su posición
vertical pasa levemente de la del centro y termina asentada en el centro a los 0,25 segundos.
DADO el celular arriba CUANDO se pulsa Q ENTONCES baja con el mismo resorte, sin que su posición
vuelva a subir más allá de la que tenía, y termina fuera del margen inferior a los 0,25
segundos con la señal de fin emitida una sola vez. DADO una subida interrumpida por Q o Esc
CUANDO empieza la bajada ENTONCES parte de la posición del cuadro anterior, sin salto.

### AC-INV-074 — La hipótesis elegida fija las pistas de la jornada siguiente *(verifica BR-INV-049, BR-INV-050)*

DADO un caso de prueba con la forma de la ficha (pistas 4A y 4B; 5A a 5D; 6A a 6H; 7A a 7H; el
camino de cada hipótesis como en BR-INV-049) CUANDO se elige 4A ENTONCES las pistas activas de la
jornada 5 son exactamente 5A y 5B; con 4B, 5C y 5D. CUANDO se elige 5A ENTONCES las de la 6 son
6A y 6B; con 5B, 6C y 6D; con 5C, 6E y 6F; con 5D, 6G y 6H. CUANDO se elige 6B ENTONCES la única
activa de la 7 es 7B. DADO ninguna elección en la jornada 4 ENTONCES las activas de la 4 son 4A y
4B, y consultarlas deja el expediente igual.

### AC-INV-075 — Una pista fuera del camino no se anota *(verifica BR-INV-050)*

DADO el caso de AC-INV-074 con 4A elegida CUANDO se registra 5C, por identidad y por el gesto de
su canal, ENTONCES contesta DESCONOCIDA, el expediente conserva sus identidades, no hay pista
nueva y las notas no crecen. CUANDO se registra 5A ENTONCES contesta ANOTADA.

### AC-INV-076 — Sin pistas en la jornada 5 se sortea uno de los dos caminos de la rama *(verifica BR-INV-051)*

DADO el caso de AC-INV-074 con 4A elegida y ninguna pista en la 5 CUANDO se sortea la jornada 6
ENTONCES las pistas activas son 6A y 6B, o 6C y 6D, y nunca otra combinación; con otras dos
semillas conocidas salen una y otra. DADO 4B elegida ENTONCES salen 6E y 6F, o 6G y 6H. DADO una
semilla fija ENTONCES sale siempre el mismo camino. DADO una pista encontrada en la jornada 5
ENTONCES sortear no guarda nada.

### AC-INV-077 — El sorteo se hace una vez y se guarda *(verifica BR-INV-051)*

DADO un sorteo hecho para la jornada 6 CUANDO se pide otra vez con otra semilla ENTONCES las
activas de la 6 no cambian. CUANDO se reconstruye un expediente nuevo desde las identidades, las
elecciones y los sorteos guardados ENTONCES conserva el sorteo, y pedirlo con otra semilla no lo
cambia. CUANDO se reconstruye sin sorteos ENTONCES carga sin fallar y sin sorteo. CUANDO el dato
nombra una hipótesis que no es de la jornada anterior ENTONCES se descarta. Sortear no elige
hipótesis, no agrega notas y no registra pistas.

### AC-INV-078 — Los cortes de la ficha *(verifica BR-INV-052)*

DADO el caso de AC-INV-074, sin pistas en la jornada 4 (elegida 4P) y con la 5 sorteada, ni en la 5
ENTONCES las activas de la 6 son ninguna y sortear la 6 no guarda nada. DADO 4A y 5A elegidas y
ninguna pista en la 6 ENTONCES las activas de la 7 son ninguna y sortear la 7 no guarda nada.

### AC-INV-079 — Sin pistas la hipótesis es P o L *(verifica BR-INV-053, BR-INV-039)*

DADO el caso de AC-INV-074 con una hipótesis P y una L por jornada CUANDO una jornada termina sin
pistas y nunca se encontró una ENTONCES sólo se ofrece su P. CUANDO termina sin pistas habiendo
encontrado una en una jornada anterior ENTONCES sólo se ofrece su L. CUANDO se encontró alguna pista
de la jornada ENTONCES no se ofrece ni P ni L. DADO un caso sin L ENTONCES ofrece una lista vacía.

### AC-INV-080 — La cuarta jornada del juego sigue igual *(verifica BR-INV-050, BR-INV-053, BR-INV-039)*

DADO el caso de la partida CUANDO se registran 2A y 2B en la jornada 4, con o sin elección ENTONCES
contestan ANOTADA, y las hipótesis de la 4 son las de AC-INV-050. Registrar 2A en cualquier otra
jornada se rechaza como antes.

### AC-INV-081 — Sin pistas en la jornada 4 se sortea uno de los dos caminos de la raíz *(verifica BR-INV-051, BR-INV-050)*

DADO el caso de AC-INV-074 y ninguna pista en la 4 (elegida 4P) ENTONCES, antes de sortear, las
activas de la 5 son ninguna. CUANDO se sortea la 5 ENTONCES las activas son 5A y 5B, o 5C y 5D, y
nunca otra combinación; con otras dos semillas conocidas salen una y otra, y con una semilla fija
sale siempre el mismo camino. CUANDO se registra una pista del camino sorteado ENTONCES contesta
ANOTADA, y una del otro camino, DESCONOCIDA. CUANDO se pide otra vez con otra semilla, o se
reconstruye desde lo guardado, ENTONCES el sorteo no cambia. DADO una pista encontrada en la 4
ENTONCES sortear la 5 no guarda nada.

### AC-INV-090 — Sólo el mensaje entero de J3_3 pide 5B *(verifica BR-INV-060, BR-INV-031)*

DADO la jornada 5 abierta CUANDO se muestra J3_3 ENTONCES «para mi lo sacó enrique» está entero
en rojo y el mensaje no tiene otro tramo; pulsarlo emite exactamente un pedido con la identidad
5B, y pulsarlo dos veces emite dos pedidos iguales. DADO el mismo chat CUANDO se lee o se abre
Yasmín, o se pulsa J3_2 o J3_4 ENTONCES se emiten cero pedidos y el expediente queda intacto.
DADO la jornada 4 abierta ENTONCES J2_6 sigue pidiendo 2A con «acá siempre falta algo».

### AC-INV-091 — Registrar 5B agrega foto y texto una vez *(verifica BR-INV-061, BR-INV-032, BR-INV-040, BR-INV-037, BR-INV-050)*

DADO el caso de la partida con 2A registrada y elegida en la jornada 4 CUANDO se pide 5B por el
canal de chat en la jornada 5 ENTONCES contesta ANOTADA, el expediente es [2A, 5B], se publica una
pista nueva de jornada 5 con su foto y su texto, y el chat de notas recibe primero la foto y
después el texto, sin cambiar las notas de 2A. CUANDO se repite el pedido ENTONCES contesta
REPETIDA y no agrega mensajes ni publica otra pista. CUANDO se pide 5B por el canal de chat en la
jornada 4, o por otro canal en la 5, ENTONCES contesta DESCONOCIDA y el expediente queda intacto.
DADO 2B elegida en la jornada 4, o ninguna elección, CUANDO se pide 5B ENTONCES contesta
DESCONOCIDA, porque 5B es del camino de 2A (BR-INV-049, BR-INV-050).

### AC-INV-092 — El contenido de 5B es el de su ficha *(verifica BR-INV-061)*

DADO el caso de la partida CUANDO se consulta 5B ENTONCES su texto de pista, su título de
hipótesis y su texto de hipótesis coinciden con BR-INV-061, con un solo espacio entre «la» e
«incompetencia» y un solo «que» en «que no lo contacte», y su foto es una imagen distinta de la
de 2A y de la de 2B. Las identidades 2A, 2B y 2P conservan los datos de BR-INV-041.

### AC-INV-093 — La hipótesis 5B depende de la pista 5B *(verifica BR-INV-061, BR-INV-039)*

DADO el caso de la partida CUANDO se consultan las hipótesis de la jornada 5 con 5B registrada
ENTONCES devuelve exactamente la hipótesis 5B; con el expediente vacío o con sólo 2A devuelve
exactamente la hipótesis 5P. DADO la jornada 4 CUANDO se consultan las hipótesis con 5B registrada ENTONCES las cuatro
combinaciones de BR-INV-039 no cambian.

### AC-INV-110 — Sin la pista 5B se ofrece 5P *(verifica BR-INV-062, BR-INV-053)*

DADO el cierre de jornada 5 con el expediente vacío ENTONCES el encabezado es «Esta vez desapareció
el lector de la caja…», la única opción es 5P «NO HAY PROBLEMA» con su texto de la ficha, y ofrece
sólo «Elegir». DADO 2A anotada y elegida en la jornada 4, sin 5B, ENTONCES la única opción también
es 5P. DADO 2B anotada, sin 5B, ENTONCES la única opción es 5P.

### AC-INV-111 — Con la pista 5B se ofrece sólo 5B *(verifica BR-INV-062, BR-INV-061)*

DADO 2A elegida en la jornada 4 y 5B registrada en la 5 ENTONCES la única opción del cierre es 5B
«INCOMPETENCIA», sin 5P, y ofrece sólo «Elegir». CUANDO se pide elegir 5P ENTONCES contesta
NO_DISPONIBLE, sin nota ni elección. DADO el expediente sin 5B CUANDO se pide elegir 5B ENTONCES
contesta NO_DISPONIBLE.

### AC-INV-112 — Elegir en la quinta jornada pide la noche 6 *(verifica BR-INV-062, BR-INV-045)*

DADO el cierre de jornada 5 con la opción 5P CUANDO se elige ENTONCES contesta ACEPTADA, las notas
reciben su texto una sola vez y la elección de la jornada 5 es 5P. CUANDO se pide elegir otra vez
ENTONCES contesta REPETIDA y las notas no cambian. DADO la elección aceptada CUANDO pasa la espera
declarada menos un cuadro ENTONCES no hay entrada; CUANDO pasa el cuadro siguiente ENTONCES hay
exactamente una entrada «NOCHE 6». DADO la reflexión sin elegir CUANDO pasan 10 minutos ENTONCES no
hay entrada, nota nueva ni elección. DADO una reflexión restaurada con la elección vacía ENTONCES
vuelve a la elección. Pasa igual con 5B elegida.

### AC-INV-113 — Las reflexiones de las jornadas 3 y 4 no cambian *(verifica BR-INV-062, BR-INV-043, BR-INV-044)*

DADO el cierre de la jornada 3 ENTONCES sigue con su encabezado y sus tres textos, y pide «NOCHE 4».
DADO el cierre de la jornada 4 ENTONCES sigue con su encabezado y las cuatro combinaciones de
BR-INV-039, y pide «NOCHE 5». DADO el cierre de la jornada 7 ENTONCES no hay reflexión.

### AC-INV-100 — La apertura de la jornada 4 saluda de tarde *(verifica BR-INV-029, BR-INV-030)*

DADO la apertura de la jornada 4 por transición y, por separado, desde un checkpoint CUANDO se
recorre Enrique ENTONCES, después de la devolución de la jornada 3, están la foto del
contenedor y su texto «Buenas tardes, pibe. Hoy te pido que tires la basura de todos los
tachos del local en el contenedor. Saludos», en ese orden, con las mismas identidades que
antes del cambio. DADO una partida guardada con la foto y el texto de la jornada 4 leídos
CUANDO se retoma ENTONCES siguen leídos.

### AC-INV-101 — La apertura de la jornada 5 trae dos mensajes *(verifica BR-INV-100, BR-INV-025, BR-INV-030)*

DADO la apertura de la jornada 5 por transición y, por separado, desde un checkpoint CUANDO se
recorre Enrique ENTONCES, después de la devolución de la jornada 4, hay exactamente dos
mensajes nuevos, sin leer: una foto de las Cindolor en la heladera y el texto de BR-INV-100,
en ese orden, sin un tercero. CUANDO se amplía la foto ENTONCES muestra ese texto como
adjunto. Reabrir el celular, volver al menú y repetir la apertura no duplican las identidades.

### AC-INV-102 — Antes de la jornada 5 los mensajes no existen *(verifica BR-INV-100)*

DADO cada jornada de la 1 a la 4 CUANDO se recorre Enrique ENTONCES ninguno de los dos
mensajes de BR-INV-100 está en su chat. DADO una partida retomada en la jornada 5 ENTONCES los
dos aparecen una sola vez, y el contador de Enrique cuenta sólo los que no leyó.

### AC-INV-103 — Yasmín lleva la hora de su ficha *(verifica BR-INV-101)*

DADO el guion de Yasmín CUANDO se leen las horas ENTONCES J2_1 a J2_4 tienen 17:34, J2_5 a J2_7
17:35, J2_8 a J2_10 17:36, J2_11 a J2_13 17:37 y J2_14 a J2_16 17:38; J3_1 a J3_4 tienen 09:11,
J3_5 a J3_7 09:12 y J3_8 a J3_10 09:13. Ninguna queda entre las 20:00 y las 08:00.

### AC-INV-104 — Los introductorios del jefe quedan antes de las 20:00 *(verifica BR-INV-101)*

DADO el guion del jefe CUANDO se leen los mensajes de jornada 1 ENTONCES J1_Intro01 tiene 19:40;
J1_FotoReloj, J1_Foto02 y J1_Intro02, 19:41; J1_Foto03 y J1_Intro03, 19:42; J1_Foto04, J1_Intro04 y
J1_Intro05, 19:43; J1_Foto06 y J1_Intro06, 19:44. CUANDO se leen los de jornada 2 ENTONCES cada
variante de J2_Mensaje1 tiene 19:40; J2_FotoGondolas y J1_Foto07, 19:41; J1_Intro07 y J1_Intro08,
19:42; J1_Foto09 y J1_Intro09, 19:43. CUANDO se leen los de jornada 3 ENTONCES cada variante de
J3_Mensaje1 tiene 19:40; J1_Intro10 y J1_Foto11, 19:41; J1_Intro11 y J1_Intro12, 19:42. Ninguno
queda entre las 20:00 y las 08:00.

### AC-INV-105 — Las devoluciones y las aperturas llevan la hora de la ficha *(verifica BR-INV-101)*

DADO la devolución de la jornada 3 CUANDO se leen sus mensajes ENTONCES salen a las 8:26, 8:27,
8:28… en su orden. DADO las devoluciones de las jornadas 4, 5, 6 y 7 ENTONCES su primer mensaje
sale a las 8:38, 9:05, 8:42 y 9:11, y cada siguiente suma un minuto. DADO el mensaje de apertura
de la jornada 4 ENTONCES J2_CONTENEDOR_FOTO y J2_CONTENEDOR_TEXTO tienen 19:31. Cada mensaje de
apertura de las jornadas 5, 6 y 7 que exista lleva la hora de la ficha: 19:20, 19:48, y 15:57,
15:58 y 15:59 en la 7.

### AC-INV-106 — Una nota lleva la hora del reloj del juego *(verifica BR-INV-101)*

DADO una pista encontrada con 3630 segundos del turno gastados ENTONCES su nota lleva 21:00, la
hora del reloj truncada al minuto, y cargar la partida guardada no la cambia.
DADO una pista encontrada con el turno recién abierto ENTONCES su nota lleva 20:00. DADO una
hipótesis o una reflexión CUANDO empieza el cierre con el turno cumplido ENTONCES su nota lleva
08:00, y CUANDO empieza antes ENTONCES lleva la hora del reloj en ese momento. DADO un guardado de
una nota sin hora CUANDO se carga ENTONCES la nota existe, con el mismo texto y sin hora.

### AC-INV-107 — El separador corta por día y por momento del día *(verifica BR-INV-102)*

DADO una devolución con hora de la mañana y mensajes de Yasmín con hora de la tarde del día
siguiente a su jornada CUANDO se ordena el historial ENTONCES quedan en dos tandas, cada una con
su rótulo de día y la hora de su primer mensaje debajo. DADO dos mensajes de la misma jornada y
del mismo momento del día ENTONCES quedan en una tanda. DADO un mensaje a las 11:59 y otro a las
12:00 del mismo día ENTONCES quedan en dos tandas. DADO el mensaje de la mañana de la devolución
de la jornada N CUANDO la referencia es la jornada N+1 ENTONCES su rótulo es «HOY».

### AC-INV-108 — Sin hora no hay hora ni tanda inventada *(verifica BR-INV-101, BR-INV-102)*

DADO un mensaje fechado sin hora al frente de una tanda ENTONCES el rótulo no lleva hora. DADO un
mensaje legado sin jornada ENTONCES no abre tanda, no muestra hora y no cambia las tandas de los
fechados.

### AC-INV-114 — Abrir un chat lo hace entrar por la derecha *(verifica BR-INV-104)*

DADO el menú de chats abierto CUANDO se abre un chat ENTONCES, al empezar el deslizamiento, el
chat está fuera del borde derecho del teléfono y la lista sigue visible; durante el
deslizamiento el chat avanza hacia la izquierda; al terminar, el chat ocupa el teléfono entero
y tapa la lista.

### AC-INV-115 — Volver hace salir el chat por la derecha *(verifica BR-INV-104)*

DADO un chat abierto desde el menú CUANDO se vuelve ENTONCES, durante el deslizamiento, el chat
avanza hacia la derecha y la lista queda en su lugar sin moverse; al terminar, el chat está fuera
del teléfono y sólo se ve la lista.

### AC-INV-116 — Un chat fijo aparece sin deslizarse *(verifica BR-INV-104, BR-INV-026)*

DADO un chat en modo fijo CUANDO se muestra ENTONCES ocupa el teléfono entero en el mismo
cuadro, sin deslizamiento, y no hay botón de volver.

### AC-INV-117 — Un pedido durante el deslizamiento no deja dos chats *(verifica BR-INV-105)*

DADO un chat que está entrando CUANDO se pide volver ENTONCES el celular termina mostrando el
menú y ningún chat queda a medias. DADO un chat que está entrando CUANDO se pide abrir otro
chat ENTONCES el celular termina mostrando sólo el último pedido, y hay un solo chat abierto.
DADO un chat que está saliendo CUANDO se pide abrir un chat ENTONCES termina mostrando ese chat
y ningún otro.

### AC-INV-118 — Bajar el celular durante el deslizamiento lo termina *(verifica BR-INV-105)*

DADO un chat que está entrando CUANDO el celular baja ENTONCES el deslizamiento salta a su
estado final, y CUANDO el celular vuelve a subir ENTONCES se ve el estado que le toca, sin el
deslizamiento a medias. DADO un chat que está saliendo CUANDO el celular baja ENTONCES, al subir,
se ve la lista sola.

### AC-INV-120 — La nota está sólo si 6C está activa *(verifica BR-INV-071, BR-INV-050)*

DADO el caso de la partida CUANDO se consulta si la nota está en el local ENTONCES contesta que
sí sólo en la jornada 6 y sólo con 6C entre las pistas activas: con 2A elegida en la jornada 4 y
5B elegida en la 5, o con 2A elegida en la 4, la 5 sin pistas y el sorteo de la 6 en el camino de la
5B. Contesta que no en las demás jornadas con esas mismas elecciones; con 2B elegida en la 4; con 2A
elegida en la 4 y 5P elegida en la 5 sin sorteo de la 6; con 2A elegida en la 4 y ninguna
elección en la 5; con ninguna elección en la 4 ni en la 5; y con 2P elegida en la 4, que no abre
ningún camino. Los objetos que no levantan una pista siguen en el local.

### AC-INV-121 — Fuera de su condición la nota no se ve ni se levanta *(verifica BR-INV-071)*

DADO una partida que eligió 2A en la 4 y 5B en la 5, o que eligió 2A en la 4 y no encontró pistas
en la 5 (el sorteo de la 6 cae en el camino de la 5B) CUANDO se abre la jornada 6 ENTONCES la nota
es visible, la mira la enfoca y se puede levantar. CUANDO se abre cualquier otra jornada, o la
jornada 6 con otra elección, ENTONCES la nota no es visible, no tiene colisión, la mira no la
enfoca ni la mano la sostiene. CUANDO se la deja en la mano y se abre la jornada 7 ENTONCES sale de
la mano y del contenedor y no está en el local.

### AC-INV-122 — Levantar la nota registra 6C una vez *(verifica BR-INV-070, BR-INV-071, BR-INV-032, BR-INV-040, BR-INV-037)*

DADO la jornada 6 abierta con 6C activa CUANDO se levanta la nota ENTONCES contesta ANOTADA, el
expediente suma 6C, se publica una pista nueva de la jornada 6 con su foto y su texto, y el chat de
notas recibe primero la foto y después el texto. CUANDO se la suelta y se la vuelve a levantar
ENTONCES contesta REPETIDA y no agrega mensajes ni publica otra pista. CUANDO se la mira, se la
examina con las manos vacías, se rechaza el agarre o hay pausa ENTONCES el expediente queda
intacto. CUANDO se registra 6C por el canal de levantar en otra jornada, o por otro canal en la
6, ENTONCES contesta DESCONOCIDA y el expediente queda intacto.

### AC-INV-123 — El contenido de 6C es el de su ficha *(verifica BR-INV-070)*

DADO el caso de la partida CUANDO se consulta 6C ENTONCES su pista es de la jornada 6, del canal de
levantar y de la nota; su texto de pista nombra a Yasmín y no a Jazmín; su título de hipótesis es
«NOTA BAJO LA PUERTA»; su texto de hipótesis nombra a Yasmín, dice «consigo» y no «conisgo»; y
su foto es una imagen distinta de la de 2A, 2B y 5B. Las identidades 2A, 2B, 2P y 5B conservan sus
datos, y 5B suma el camino de 6C y 6D.

### AC-INV-124 — La hipótesis 6C depende de la pista 6C *(verifica BR-INV-070, BR-INV-039)*

DADO el caso de la partida CUANDO se consultan las hipótesis de la jornada 6 con 6C registrada
ENTONCES devuelve exactamente la hipótesis 6C; con el expediente vacío devuelve exactamente la 6P,
y con sólo 2A y 5B, exactamente la 6L (BR-INV-116). DADO las jornadas 4 y 5 CUANDO se consultan las hipótesis ENTONCES las combinaciones de
BR-INV-039 y BR-INV-061 no cambian.

### AC-INV-125 — Con 2A y 5B elegidas, o con la 5 sin pistas y el sorteo de la 6, la nota se levanta; con 2A y 5P sin sorteo, no *(verifica BR-INV-070, BR-INV-062, BR-INV-051)*

DADO el caso de la partida con 2A registrada y elegida en la jornada 4, 5B registrada y la única
hipótesis ofrecida en la 5 elegida CUANDO se consultan las pistas activas de la 6 ENTONCES incluyen
6C, la nota está en el local y registrar 6C contesta ANOTADA. DADO el mismo caso sin 5B y con la
única hipótesis ofrecida en la 5 elegida (5P) y sin sorteo de la 6 ENTONCES las pistas activas de la
6 no incluyen 6C, la nota no está en el local y registrar 6C contesta DESCONOCIDA. CUANDO, en ese
mismo caso, se sortea la 6 con una semilla fija ENTONCES las pistas activas de la 6 incluyen 6C, la
nota está en el local y registrar 6C contesta ANOTADA.

### AC-INV-126 — La nota es un papel manuscrito propio *(verifica BR-INV-071)*

DADO la nota del local ENTONCES su identidad no es la de ningún producto ni la de la colilla, es
levantable, tiene subtítulo, se dibuja con una textura de papel distinta de la de las cajas, y su
cara escrita usa la textura de la nota con texto.

### AC-INV-127 — Sin ninguna pista, estresado *(verifica BR-INV-103)*

DADO la jornada 7 cerrada con el contrato cumplido y el expediente sin pistas, aunque la hipótesis P
se haya elegido en las jornadas 4 a 6, ENTONCES el final es «Empleado estresado». DADO el mismo
cierre con la pista 4A registrada en la jornada 4 y ninguna otra ENTONCES no lo es. DADO el mismo
cierre con una única pista registrada en la jornada 7 ENTONCES tampoco.

### AC-INV-128 — El despido no es estresado *(verifica BR-INV-103)*

DADO una partida despedida al cerrar la jornada 5 con el expediente sin pistas ENTONCES el final es
el despido y no «Empleado estresado». DADO una partida en curso sin pistas ENTONCES no hay final.

### AC-INV-150 — Con la pista 6C se ofrece sólo 6C *(verifica BR-INV-116, BR-INV-070)*

DADO 2A elegida en la jornada 4, 5B elegida en la 5 y 6C registrada en la 6 ENTONCES el cierre de la
jornada 6 lleva el encabezado «Un apagón me agarró desprevenido esta noche…», la única opción es 6C
«NOTA BAJO LA PUERTA», sin 6P ni 6L, y ofrece sólo «Elegir». CUANDO se pide elegir 6P o 6L ENTONCES
contesta NO_DISPONIBLE, sin nota ni elección. DADO el expediente sin 6C CUANDO se pide elegir 6C
ENTONCES contesta NO_DISPONIBLE.

### AC-INV-151 — Sin la pista 6C se ofrece 6P o 6L *(verifica BR-INV-116, BR-INV-053)*

DADO el cierre de jornada 6 con el expediente vacío ENTONCES la única opción es 6P «NADA DE OTRO
MUNDO» con su texto de la ficha, y ofrece sólo «Elegir». DADO 5B registrada en la jornada 5, sin 6C,
ENTONCES la única opción es 6L «INVESTIGACIÓN INCONCLUSA» con su texto de la ficha, sin 6P. DADO 2A
anotada en la jornada 4 y la 5P elegida, sin 6C, ENTONCES la única opción también es 6L. CUANDO en
cualquiera de los tres casos se pide elegir la identidad que no se ofrece ENTONCES contesta
NO_DISPONIBLE.

### AC-INV-152 — Elegir en la sexta jornada pide la noche 7 *(verifica BR-INV-116, BR-INV-045)*

DADO el cierre de jornada 6 con la opción 6P CUANDO se elige ENTONCES contesta ACEPTADA, las notas
reciben su texto una sola vez y la elección de la jornada 6 es 6P. CUANDO se pide elegir otra vez
ENTONCES contesta REPETIDA y las notas no cambian. DADO la elección aceptada CUANDO pasa la espera
declarada menos un cuadro ENTONCES no hay entrada; CUANDO pasa el cuadro siguiente ENTONCES hay
exactamente una entrada «NOCHE 7». DADO la reflexión sin elegir CUANDO pasan 10 minutos ENTONCES no
hay entrada, nota nueva ni elección. DADO una reflexión restaurada con la elección vacía ENTONCES
vuelve a la elección. Pasa igual con 6C o con 6L como única opción.

### AC-INV-153 — Las reflexiones de las jornadas 3, 4 y 5 no cambian *(verifica BR-INV-116, BR-INV-043, BR-INV-044, BR-INV-062)*

DADO el cierre de la jornada 3 ENTONCES sigue con su encabezado y sus tres textos, y pide «NOCHE 4».
DADO el cierre de la jornada 4 ENTONCES sigue con su encabezado y las cuatro combinaciones de
BR-INV-039, y pide «NOCHE 5». DADO el cierre de la jornada 5 ENTONCES sigue con su encabezado y sus
opciones 5B o 5P, y pide «NOCHE 6».
### AC-INV-169 — El chat de Hernán aparece en la jornada 6 *(verifica BR-INV-123)*

DADO el celular de cada jornada de la 1 a la 5 ENTONCES el menú no lista a Hernán. DADO la
jornada 6, por transición y por separado desde un checkpoint, ENTONCES lo lista después de
Enrique, su chat no tiene ningún mensaje y su contador de no leídos no se muestra. DADO esa
jornada ENTONCES el botón «Hacer pedido» existe en su chat.

### AC-INV-170 — La lista tiene los treinta y nueve y exige uno marcado *(verifica BR-INV-124)*

DADO la lista abierta ENTONCES muestra treinta y nueve productos distintos, los treinta y dos del
catálogo y los siete que existen sólo como caja, todos desmarcados, con «Enviar» deshabilitado. CUANDO se marca uno
ENTONCES «Enviar» se habilita, y CUANDO se lo desmarca ENTONCES se deshabilita. CUANDO se cierra la
lista y se reabre ENTONCES no hay ninguno marcado y el chat no recibió ningún mensaje.

### AC-INV-171 — Enviar con wifi deja el pedido y las dos respuestas *(verifica BR-INV-125)*

DADO el wifi encendido y tres productos marcados CUANDO se envía ENTONCES el chat tiene un mensaje
del jugador con el saludo y los tres productos en el mismo mensaje, y la lista se cierra. CUANDO
pasan 2,9 segundos de juego ENTONCES no hay respuesta; con 3 segundos llega la primera de Hernán;
con 3,9 todavía no llega la segunda; con 4 segundos llega la segunda. CUANDO el juego está en
pausa ENTONCES ese tiempo no corre.

### AC-INV-172 — Enviar sin wifi deja el mensaje en rojo y nada más *(verifica BR-INV-125)*

DADO el wifi apagado y un producto marcado CUANDO se envía ENTONCES el mensaje del jugador queda
en rojo con «Error en la red» y, pasados 10 segundos de juego, Hernán no respondió. CUANDO el wifi
vuelve ENTONCES el mensaje sigue en rojo y sigue sin respuesta.

### AC-INV-173 — Se puede enviar más de un pedido *(verifica BR-INV-125)*

DADO un pedido enviado sin wifi CUANDO el wifi vuelve y se abre la lista y se envía otro pedido
ENTONCES hay dos mensajes del jugador, el primero en rojo y el segundo normal con sus dos
respuestas. DADO un pedido enviado con wifi CUANDO se envía otro ENTONCES el chat tiene dos
mensajes del jugador y cada uno recibe sus respuestas.

### AC-INV-174 — La sexta jornada abre con la foto y el aviso *(verifica BR-INV-126, BR-INV-025, BR-INV-101)*

DADO la apertura de la jornada 6 por transición y, por separado, desde un checkpoint CUANDO se
recorre Enrique ENTONCES, después de la devolución de la jornada 5, hay exactamente dos mensajes
nuevos, sin leer, ambos a las 19:48: una foto de las estanterías del depósito y el texto de
BR-INV-126, en ese orden, sin un tercero. CUANDO se amplía la foto ENTONCES muestra ese texto como
adjunto. DADO cada jornada de la 1 a la 5 ENTONCES ninguno de los dos está en su chat. Retomar la
jornada 6 los muestra una sola vez.

### AC-INV-140 — Enrique avisa de las quejas en la jornada 7 *(verifica BR-INV-114)*

DADO la jornada 7 abierta CUANDO se recorre el chat de Enrique ENTONCES, a continuación de la
devolución de la jornada 6, hay tres mensajes de apertura, en el orden de BR-INV-114 y con las
horas 15:57, 15:58 y 15:59. DADO cada jornada de la 1 a la 6 ENTONCES ninguno de los tres está en
su chat. DADO una partida retomada en la jornada 7 ENTONCES aparecen una sola vez y el contador
de Enrique cuenta sólo los que no leyó.

### AC-INV-141 — Los cinco chats de compradores *(verifica BR-INV-110)*

DADO la jornada 7 abierta CUANDO se lista el menú del celular ENTONCES hay un chat por cada uno
de los cinco compradores, con su nombre, cada uno con un solo mensaje sin leer del comprador que
trae la captura de BR-INV-113. DADO cada jornada de la 1 a la 6 ENTONCES ninguno de esos cinco
chats está en el menú. DADO la compra de cada comprador ENTONCES su total correcto es la suma de los
precios del catálogo de sus productos fijos.

### AC-INV-142 — El valor del texto es el de la captura *(verifica BR-INV-110, BR-INV-113)*

DADO el mensaje de El Seba, el de Suko Yañez y el de Lucas Ortega CUANDO se lee su texto ENTONCES
contiene el valor cobrado con el formato de la captura, y la captura lleva el mismo importe.
DADO el mensaje de Flavio Balbín y el de Myriam Melano ENTONCES su texto no contiene ningún
importe y la captura lleva el valor cobrado.

### AC-INV-143 — Entre una y cuatro quejas incorrectas, y nunca el total correcto *(verifica BR-INV-111)*

DADO 200 semillas distintas CUANDO se sortea la jornada 7 ENTONCES en cada una entre 1 y 4
quejas tienen un valor incorrecto y las otras tienen el total correcto; se observan cantidades
de 1 y de 4 incorrectas. DADO cada queja incorrecta ENTONCES su valor es el total de su compra con
uno o dos productos reemplazados por otros del catálogo de la noche, y nunca es el total
correcto.

### AC-INV-144 — La semilla fija el sorteo *(verifica BR-INV-111)*

DADO la misma semilla y la jornada 7 CUANDO se sortea dos veces ENTONCES los cinco valores son
iguales. DADO semillas distintas ENTONCES los valores difieren en alguna de las quejas.

### AC-INV-145 — Dar la razón o rechazar *(verifica BR-INV-112)*

DADO una queja con valor incorrecto CUANDO el jugador le da la razón ENTONCES la respuesta es
correcta, y rechazarla es incorrecta. DADO una con el valor correcto ENTONCES rechazarla es
correcto y darle la razón es incorrecto. DADO una queja ya respondida CUANDO se responde otra vez,
en cualquier sentido, ENTONCES se rechaza y la respuesta anterior no cambia. DADO un índice que no
existe ENTONCES se rechaza sin cambiar nada.

### AC-INV-146 — La respuesta aparece en el chat y retira los botones *(verifica BR-INV-112)*

DADO el chat de una queja sin responder CUANDO se abre ENTONCES ofrece los dos botones. CUANDO el
jugador pulsa uno ENTONCES el chat muestra una respuesta del jugador con el texto de ese botón
tras el mensaje del comprador, sin los botones y sin avisar un mensaje recibido, y los
no leídos de los demás chats no cambian. DADO el chat respondido CUANDO se vuelve a abrir
ENTONCES no ofrece los botones.

### AC-INV-147 — Sin respuestas no se cumple y lo respondido no se retoma *(verifica BR-INV-112, BR-INV-111)*

DADO las cinco quejas CUANDO ninguna tiene respuesta ENTONCES no está cumplida. DADO cuatro
respondidas bien ENTONCES no está cumplida; con las cinco bien, sí; con una equivocada, no.
DADO la jornada 7 retomada de un guardado ENTONCES los valores son los de la partida y las cinco
quejas empiezan sin respuesta.

### AC-INV-148 — La captura lleva el diseño y cuentas fijas *(verifica BR-INV-113)*

DADO los cinco compradores CUANDO se leen los cuatro dígitos de la cuenta de origen ENTONCES son
cinco números distintos, iguales en todo sorteo, y el destino de Enrique es siempre el mismo. DADO
un valor de 4200 ENTONCES el importe se escribe `$ 4.200`, y uno de 30000 se escribe `$ 30.000`.

### AC-INV-149 — La pantalla conjunta alterna con el botón y con Q *(verifica BR-INV-115)*

DADO la jornada 7 con la computadora recién abierta CUANDO se mira ENTONCES está en la pantalla
normal y ofrece el botón. CUANDO se pulsa el botón ENTONCES pasa a la conjunta, con el celular
abierto en el menú, y pulsarlo otra vez la devuelve a la normal con el celular cerrado. DADO la
computadora abierta CUANDO se aprieta Q ENTONCES alterna igual. DADO la conjunta CUANDO se cierra la
computadora y se vuelve a abrir ENTONCES arranca en la pantalla normal con el celular cerrado.
DADO cualquier jornada de la 1 a la 6 con la computadora abierta ENTONCES no ofrece el botón y Q
no cambia la pantalla. DADO que pasan los cuadros de una alternancia ENTONCES el turno descuenta
sólo el tiempo real, sin sumar ni restar nada por el cambio.

### AC-INV-160 — Con mensajes sin leer, el primero queda arriba *(verifica BR-INV-120, BR-INV-022)*

DADO un chat con 30 mensajes de los cuales los 3 últimos están sin leer CUANDO se abre ENTONCES el
mensaje 28 queda en el borde superior de la lista, el 29 y el 30 debajo, y los no leídos pasan a
cero. DADO el mismo chat con 40 sin leer, de modo que no entran en pantalla, ENTONCES el primero
sin leer queda arriba y la rueda alcanza el último.

### AC-INV-161 — Sin mensajes sin leer, se abre al final *(verifica BR-INV-120, BR-INV-022)*

DADO un chat de 30 mensajes sin ninguno sin leer CUANDO se abre ENTONCES muestra el último mensaje
abajo y la rueda alcanza el primero. DADO el mismo chat cerrado y vuelto a abrir sin que haya
llegado nada ENTONCES se repite el resultado.

### AC-INV-162 — Un único sin leer que es el último queda arriba, y un chat corto no se desplaza *(verifica BR-INV-120)*

DADO un chat de 30 mensajes con sólo el último sin leer CUANDO se abre ENTONCES ese mensaje queda
en el borde superior y debajo sobra espacio. DADO un chat de un mensaje sin leer ENTONCES queda a
la vista sin desplazar, igual que uno con todos sus mensajes dentro de la pantalla.

### AC-INV-163 — En el cierre, el primer mensaje del jefe queda arriba *(verifica BR-INV-120, BR-INV-026)*

DADO el celular fijo en el chat de Enrique con un historial que ocupa más que la pantalla CUANDO
llega el primer mensaje de la devolución ENTONCES queda en el borde superior. CUANDO llegan el
segundo y el tercero ENTONCES aparecen debajo y el primero sigue arriba. CUANDO los mensajes y la
opción ya no entran ENTONCES la lista baja lo justo para ver el último y la opción.

### AC-INV-164 — Un mensaje que llega con el chat abajo baja hasta él *(verifica BR-INV-120)*

DADO un chat libre abierto sin mensajes sin leer y con la lista en su último mensaje CUANDO llega
un mensaje ENTONCES la lista baja hasta el nuevo. DADO el mismo chat con la lista desplazada hacia
arriba ENTONCES la lista no se mueve.

## No objetivos

- Esta capacidad NO inventa el contenido: consume los guiones decididos; la apertura de
  jornada 4 y su tramo de pista están fijados en BR-INV-029 y BR-INV-031.
- Esta capacidad NO descuenta tiempo del turno.
- Esta capacidad NO inventa contactos, pistas, hipótesis o desenlaces de jornadas futuras:
  consume el contenido decidido.
- Esta capacidad NO elige una hipótesis por el jugador ni escribe checkpoints: entrega opciones,
  identidades, la reflexión pendiente, la elección y los mensajes al cierre y al guardado.

## Contratos

- **Entrada:** el objeto examinado, la entrada de movimiento y los segundos del cuadro, el
  arrastre del mouse y la conversación abierta; caso, pistas, exigencias y desenlaces,
  expediente recibido, identidades para reconstrucción y gestos de pista con canal y jornada;
  el camino de cada hipótesis, el azar para sortear y el sorteo guardado;
  la jornada, Q, el estado del control
  y los pedidos de recibir mensajes, navegar chats, ampliar fotos, fijar y soltar el celular;
  identidad y metadatos temporales de mensajes y el tramo de pista pulsado; continuar, navegar
  y elegir en la reflexión de cierre, y la reflexión y la elección restauradas.
- **Salida:** el texto visible, si fue hallazgo, cuántos mensajes sin leer hay y las notas de pistas;
  celular abierto o cerrado, menú, chat o foto, modo fijo, historial cronológico, listas
  visibles de chats y mensajes, y pedido identificado del tramo de pista;
  ANOTADA/REPETIDA/DESCONOCIDA, expediente ordenado, consistencia, desenlaces alcanzados e
  hipótesis disponibles con sus datos. Una exigencia pendiente no registra. Etapa de la
  reflexión, texto u opción mostrada, ACEPTADA/REPETIDA/NO_DISPONIBLE/FUERA_DE_ETAPA y la
  elección de la partida; el pedido de la entrada siguiente, una sola vez. Las pistas activas de
  cada jornada y el sorteo de la partida, que se entrega al guardar y se recibe al reconstruir,
  como la elección.
- **Falla:** una revelación vacía se rechaza sin cambiar nada.
- **Falla del celular:** Q bloqueado, chat inexistente, recepción inválida, ampliación sin foto
  y soltar sin modo fijo conservan el estado. Una conversación sin mensajes visibles se omite
  del menú; una foto sin texto siguiente se amplía sin adjunto.

## Señales

- El hallazgo nuevo y la computadora abierta.
- El tramo de pista pedido con su identidad; pedirlo no registra por sí solo un hallazgo.
- La pista nueva con identidad, jornada y datos, sólo tras ANOTADA; cada desenlace alcanzado
  una sola vez. Repetidas, desconocidas y consultas no publican progreso.
- El celular abierto o cerrado, menú mostrado, chat abierto, foto ampliada o cerrada, cambios
  de no leídos y mensaje recibido. Un gesto rechazado no publica cambio de estado.

## Dependencias

- [`player-actions`](../player-actions/player-actions.md) (consume): qué objeto se está
  examinando.
- [`employment-record`](../employment-record/employment-record.md) (consume): identidad,
  jornada cerrada y orden de los mensajes de devolución.
- [`save-and-resume`](../save-and-resume/save-and-resume.md) (consume): devoluciones restauradas
  con sus metadatos disponibles; el guion se reconstruye según la jornada guardada.
- [`ambience`](../ambience/ambience.md) (alimenta): cada recepción aceptada dispara el sonido
  de mensaje del celular.
- [`subtitles`](../subtitles/subtitles.md) (alimenta): cuándo arranca y termina el examen de lo
  que se lleva, que deja su texto fijo en la línea de subtítulo.

- [`employment-record`](../employment-record/employment-record.md) (consume y alimenta): el
  expediente y las notas pertenecen a cada partida y conservan orden entre aperturas en memoria.
- [`save-and-resume`](../save-and-resume/save-and-resume.md) (alimenta): entrega identidades y
  mensajes para reconstruir; investigación no escribe disco.
- [`notifications`](../notifications/notifications.md) (alimenta): pista nueva aceptada, sin
  duplicar desde investigación la presentación del aviso.

## Preguntas abiertas

- **OQ-INV-007 — ¿Cuánto dura y qué curva tiene el deslizamiento del chat?**
  - Por qué sigue abierta: la ficha «Especificar animaciones» pide que el chat entre desde el
    margen derecho «como Instagram» y no da duración ni curva. El juego usa valores provisionales
    con nombre, que se ajustan sin tocar este contrato.
  - Decide: game design, con el prototipo de Figma si lo tiene armado.
  - Bloquea: fijar los valores finales; no bloquea el deslizamiento.
- **OQ-INV-006 — ¿Cuánto rebota, cuánto dura y dónde se ve el rebote del celular?**
  - Por qué sigue abierta: la ficha pide un resorte «Gentle» con «leve bounce» y no da masa,
    rigidez, amortiguación ni duración; un resorte así suele asentarse después de los 0,25
    segundos fijados antes. Hacia abajo, el rebote del final queda fuera del encuadre, y la
    ficha no dice si debe verse dentro de él.
  - Decide: game design, con el prototipo de Figma si lo tiene armado.
  - Bloquea: fijar los valores finales del rebote y la duración; no bloquea el movimiento.
- **OQ-INV-004 — ¿Qué pistas, hipótesis y desenlaces definen las jornadas 5 a 7?**
  - Por qué sigue abierta: las fichas de ese contenido siguen «A desarrollar» y no fijan
    exigencias ni umbrales de los finales. La forma de los caminos ya está fijada
    (BR-INV-049 a BR-INV-053); falta el texto de cada pista e hipótesis, incluidas 5L y 7L (la 5L usa el texto de 5P por BR-INV-053).
    Los ejemplos de aceptación son casos de prueba, no contenido para el juego.
  - Decide: game design.
  - Bloquea: publicar ese contenido y sus finales; no bloquea el motor ni las pistas de jornada 4.
- **OQ-INV-005 — ¿Dónde se intercalan las devoluciones legadas sin jornada?**
  - Por qué sigue abierta: los guardados antiguos sólo contienen textos y orden de recepción;
    no permiten reconstruir qué cierre produjo cada bloque ni su relación con una apertura.
    La compatibilidad exige conservarlos sin inventar una fecha, pero no está decidida su
    posición entre bloques fechados.
  - Decide: el dueño del repo con diseño narrativo.
  - Bloquea: fijar un intercalado cronológico entre registros legados sin fecha y aperturas;
    no bloquea conservar sus textos y orden relativo ni ordenar los registros nuevos fechados.
