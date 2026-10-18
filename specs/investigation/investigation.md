---
schema_version: 1
capability_id: CAP-INV
status: draft
owner: por definir
provenance: GDD «Investigación» y «La computadora»; ficha «Interfaces virtuales durante la jornada» y decisiones de #373, #375 y #376; migración de los specs 006, 009, 018; fichas Chat con el jefe, Chat con compañera y 2A revisadas el 2026-10-15; decisiones de #430; «Sistema de investigación», fichas 2A/2B/2P y decisiones de #22 del 2026-10-15; decisión del usuario del 2026-10-16 sobre el círculo de Yasmín para 2A; decisión del usuario del 2026-10-17 de retirar las notas de la computadora y usar el diseño del registro de productos; ficha «Pantalla entre jornadas», reflexión de jornada 1, encabezado de jornada 2 y decisiones de #436; decisiones del usuario del 2026-10-18 sobre el recorrido lateral, la elección sin límite de tiempo y la reanudación del cierre
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
| **Reflexión de cierre** | el paso que sigue a la devolución de las jornadas 1 y 2: el celular en notas y un recuadro con textos o hipótesis | pantalla de hipótesis aparte |
| **Elección** | la hipótesis que el jugador fijó al cerrar una jornada; una sola por jornada | hipótesis desbloqueada |

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
modo libre, Q DEBE cerrarlo, y también un clic izquierdo por fuera del celular. Con el turno cerrado, otra interfaz al control, un examen o una
pausa, Q NO DEBE abrirlo ni alterar el estado existente. Abrir o cerrar NO DEBE cambiar lo que
se lleva en la mano. Otro Q durante la subida DEBE iniciar la bajada desde la posición actual,
sin duplicar el celular ni dejarlo detenido a mitad de camino.

### BR-INV-022 — Cada apertura libre empieza en el menú

CUANDO se abre el celular en modo libre, el sistema DEBE mostrar el menú de chats, aunque se
haya cerrado viendo un chat o una foto. Clic izquierdo en un botón DEBE abrir su chat y marcarlo
leído; la flecha del encabezado DEBE volver al menú. Abrir un chat DEBE mostrar su último mensaje
y permitir desplazarlo con la rueda hacia los anteriores. Un menú sin chats DEBE verse vacío,
sin error; un chat de un solo mensaje NO DEBE exigir desplazamiento para verlo.

### BR-INV-023 — La jornada decide los mensajes disponibles

CUANDO se abre la jornada N, el sistema DEBE mostrar sólo los mensajes del guión cuya jornada
de llegada es menor o igual que N, en su orden y con el más reciente abajo. El menú DEBE listar
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
mensaje siguiente si es texto sin foto. Sin siguiente o con otra foto después, DEBE ampliarse
sin adjunto. Pedir ampliar un mensaje sin foto NO DEBE cambiar nada. Cualquier clic izquierdo
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
MIENTRAS el turno está abierto, el sistema DEBE mostrar en la esquina inferior izquierda un
ícono de celular con «Q», incluso con el celular arriba; con el turno cerrado NO DEBE mostrarlo.
MIENTRAS la computadora está abierta, el sistema DEBE ocultar ese recordatorio. Al cerrarla,
DEBE volver a mostrarlo sólo si la jornada todavía lo permite.
El celular DEBE dibujarse sobre HUD, computadora y cierre, y debajo de avisos y pausa. La
duración completa de subir y de bajar DEBE ser de 0,25 segundos reales por recorrido.
Un cuadro largo NO DEBE adelantar el movimiento más de 1/30 de segundo. Si el dibujo se
interrumpe, el recorrido DEBE conservar sus pasos visibles aunque termine más tarde.

### BR-INV-028 — Pausa y cierre conservan estados distintos

CUANDO se pausa con el celular abierto, el sistema DEBE mostrar la pausa encima, ignorar Q y
reanudar en la misma pantalla del celular. CUANDO cierra el turno, el celular DEBE cerrarse,
soltar su modo fijo y dejar el control suspendido por el cierre. CUANDO se abre otra jornada,
el celular DEBE empezar cerrado y preparado para abrir en el menú.

### BR-INV-029 — La segunda jornada incorpora a Yasmín y la tarea de Enrique

CUANDO abre la jornada 1, el sistema DEBE ofrecer sólo el chat de Enrique. CUANDO abre la
jornada 2, por transición o desde un checkpoint, DEBE ofrecer Enrique y Yasmín. El rol de
Enrique DEBE leerse «Jefe» y el de Yasmín «Compañera de trabajo», como dato del contacto,
independiente de su imagen. Sin retrato aprobado, DEBE usar el círculo liso de BR-INV-023.

Enrique DEBE incorporar dos mensajes de apertura de la jornada 2: primero una foto del
contenedor de basura del local, después el texto literal «Buen día, pibe. Hoy te pido que tires
la basura de todos los tachos del local en el contenedor. Saludos». La foto NO DEBE mostrar
un tacho interior en lugar del contenedor; ampliarla DEBE usar ese texto como adjunto.
Yasmín DEBE incorporar exactamente los siguientes quince mensajes independientes, con estas
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
| J2_8 | p ejemplo hoy parece que se acabo uno de los jabones para la limpieza y no había ningún repuesto |
| J2_9 | no le reclames a enrique porque no va a hacer nada y encima se va a irritar |
| J2_10 | creo que lo podes reemplazar con chorrito del producto ese de limpieza que vendemos |
| J2_11 | no creo que enrique se de cuenta si usás uno |
| J2_12 | pero nada |
| J2_13 | quería darte la bienvenida |
| J2_14 | quedamos en contacto p cualquier cosa |
| J2_15 | exitos con eso!  💪 |

Los mensajes DEBEN estar disponibles al abrir la jornada, sin arribos programados durante
el turno. Mensajes de jornada 3 o posteriores NO DEBEN adelantarse a la 2. Reabrir el celular,
volver al menú o repetir la apertura NO DEBE duplicar el guion ni alterar sus recursos.
Leer DEBE conservar el transcurso del turno de BR-INV-006 y las marcas de BR-INV-008/009.

### BR-INV-030 — El historial mezcla guion y devoluciones en orden temporal

El sistema DEBE ordenar los mensajes por jornada, momento de apertura o cierre y orden
dentro del bloque, sin ordenarlos por texto ni inventar horas. En Enrique, el orden DEBE ser
instrucciones de jornada 1, devolución del cierre 1, foto y texto de apertura 2, devolución
del cierre 2, y los bloques posteriores cuando estén disponibles. Cada mensaje DEBE conservar
su identidad; dos textos iguales con identidades distintas NO DEBEN fusionarse por su texto.

Cada devolución nueva DEBE aportar explícitamente la jornada que cerró y el orden de sus
mensajes (BR-EMP-031). Los mensajes legados sin jornada DEBEN conservar texto y orden relativo,
sin recibir una jornada ni hora inventada. Su intercalado con bloques fechados depende de
OQ-INV-005. La vista cronológica y sus consultas NO DEBEN mutar el guion compartido ni sus
marcas de lectura. Retomar DEBE reconstruir el guion y conservar las devoluciones guardadas
con esos metadatos, con los mensajes del guion sin leer según BR-INV-023.

### BR-INV-031 — Sólo el tramo de pista emite su identidad

El sistema DEBE mostrar en J2_6 sólo «acá siempre falta algo» en lila y el resto del texto
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

### BR-INV-038 — Dos gestos concretos descubren las pistas de la segunda noche

MIENTRAS jornada 2 está abierta, CUANDO se pulsa la frase lila «acá siempre falta algo» del
mensaje J2_6 de Yasmín, el sistema DEBE registrar 2A. Abrir o leer ese chat, o pulsar otra parte,
NO DEBE registrarla. CUANDO se acepta levantar la colilla del fondo del depósito cerca de la
puerta garage, el sistema DEBE registrar 2B. La colilla DEBE distinguirse visualmente como tal,
ser levantable y tener identidad propia independiente de los productos vendibles. Mirarla,
mostrar su subtítulo con E y manos vacías, un agarre rechazado o durante pausa NO DEBEN anotarla.
Soltarla y volver a levantarla NO DEBE duplicarla. Las pistas 2A y 2B NO DEBEN registrarse por
esos gestos fuera de jornada 2.

### BR-INV-039 — Las hipótesis de la segunda noche salen de sus pistas

CUANDO se consultan las hipótesis del cierre de jornada 2, el sistema DEBE devolver exactamente:

| Pistas de jornada 2 | Hipótesis disponibles |
|---|---|
| ninguna | sólo 2P |
| sólo 2A | sólo 2A |
| sólo 2B | sólo 2B |
| 2A y 2B | 2A y 2B |

La predeterminada NO DEBE acompañar una hipótesis desbloqueada. Consultar y navegar NO DEBEN
mutar expediente ni elegir una opción. La primera jornada no tiene pistas; el sistema NO DEBE
inventar 2L ni una pista o foto para 2P.

### BR-INV-040 — Cada pista agrega foto y texto una vez al chat de notas

CUANDO una pista de jornada 2 resulta ANOTADA, el sistema DEBE agregar al chat de notas primero
su foto y después su texto, una sola vez, conservando el orden de descubrimiento entre pistas.
REPETIDA y DESCONOCIDA NO DEBEN agregar mensajes ni publicar pista nueva. La foto DEBE ampliarse
con el texto siguiente como adjunto según BR-INV-025. El chat DEBE tener identidad y contenido
propios, y sus mensajes DEBEN conservarse en memoria entre aperturas.
El menú durante el turno DEBE ocultarlo en jornadas 1 y 2, aun con mensajes, y ofrecerlo desde
la 3 cuando tenga contenido. Esa disponibilidad NO DEBE impedir su apertura fija por el cierre
en jornadas 1 y 2. Consultar mensajes DEBE devolver copias sin alterar el guion compartido ni
registrar pistas. Reconstruir identidades y mensajes NO DEBE duplicar el contenido ya recibido.

### BR-INV-041 — El contenido de 2A, 2B y 2P procede de sus fichas

El sistema DEBE entregar para cada identidad los siguientes datos, según las fichas «2A», «2B»
y «2P» de la lista de pistas e hipótesis. Por decisión del usuario del 2026-10-16,
la imagen de 2A DEBE ser el círculo existente del contacto de Yasmín, aun sin retrato:

| Identidad | Foto de pista | Texto de pista | Título de hipótesis |
|---|---|---|---|
| 2A | círculo existente del contacto de Yasmín | Hoy Yasmín se quejó de que en el local “siempre falta algo o anda todo a medias”. | SIEMPRE FALTAN COSAS |
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

### BR-INV-042 — El cierre de las jornadas 1 y 2 pasa a las notas

CUANDO se elige continuar al terminar la devolución de jornada 1 o 2 con la partida en curso
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

Una partida terminada NO DEBE mostrar reflexión. Las jornadas 3 a 5 no declaran reflexión
mientras siga OQ-INV-004: su continuar sigue BR-EMP-011 sin pasar por las notas.

### BR-INV-043 — La primera jornada reflexiona en tres textos

La reflexión de jornada 1 DEBE mostrar el encabezado «Primera jornada terminada…» y estos
textos, de a uno por vez y en este orden, cada uno con el botón «Continuar»:

1. «Bueno, no será el mejor trabajo del mundo, pero es algo. Por lo menos, con lo que tengo me
   alcanza para cubrir los gastos hasta que Enrique me empiece a pagar.»
2. «Mi psicólogo tenía razón. Mudarme acá sin duda fue la decisión correcta. Desde que llegué,
   no volví a tener ningún episodio de paranoia.»
3. «Está claro que el problema era el estrés de la ciudad. Creo que la vida de pueblo me sienta
   mejor.»

CUANDO se pulsa «Continuar», el sistema DEBE agregar el texto actual al chat de notas una sola
vez y reemplazar el recuadro por el texto siguiente. El recuadro NO DEBE acumular textos; las
notas sí. CUANDO se recibe el tercero, la reflexión DEBE terminar y pedir una sola entrada a
«NOCHE 2» (BR-SHF-019). Un pedido repetido sobre un texto ya recibido, o fuera de la reflexión,
NO DEBE avanzar otro texto ni agregar otra nota. Cada texto DEBE tener identidad propia, y
recibirlo NO DEBE registrar una pista ni contar como hipótesis elegida.

### BR-INV-044 — La segunda jornada se cierra eligiendo una hipótesis

La reflexión de jornada 2 DEBE mostrar el encabezado «Hoy faltabo uno de los jabones para la
limpieza del local. No me quiero empezar a perseguir, pero…», con la errata «faltabo» de la
fuente. El recuadro DEBE mostrar una opción por vez, entre las que habilita BR-INV-039, con su
título y su texto de hipótesis de BR-INV-041. La primera mostrada DEBE ser la primera de esa
lista. Con una opción DEBE ofrecer sólo «Elegir». Con dos DEBE ofrecer «Anterior», «Siguiente»
y «Elegir»; «Anterior» y «Siguiente» DEBEN mostrar la otra opción. Navegar NO DEBE elegir,
agregar notas ni modificar el expediente.

CUANDO se elige la opción mostrada, el sistema DEBE contestar ACEPTADA, agregar su texto de
hipótesis al chat de notas una sola vez y fijar su identidad como la elección de jornada 2 de la
partida. Una identidad desconocida, de otra noche o no habilitada por el expediente DEBE
contestar NO_DISPONIBLE. Un pedido después de una elección aceptada DEBE contestar REPETIDA. Un
pedido fuera de la etapa de elegir DEBE contestar FUERA_DE_ETAPA. Esas tres respuestas NO DEBEN
agregar notas, cambiar la elección ni pedir una noche. Pausar o salir al menú NO DEBE elegir por
el jugador. Consultar la elección DEBE devolver su identidad, o ninguna antes de elegir.

### BR-INV-045 — La tercera noche espera a la elección

CUANDO la elección de jornada 2 resulta ACEPTADA, el sistema DEBE terminar la reflexión después
de una espera cuya duración fija OQ-INV-006, y entonces pedir una sola entrada a «NOCHE 3»
(BR-SHF-019). Antes de una elección aceptada, NO DEBE empezar ninguna entrada. MIENTRAS corre la
espera, el recuadro NO DEBE responder a navegar ni a elegir. La espera DEBE correr con el tiempo
real del juego en ejecución y NO DEBE correr con la pausa. Un cuadro largo NO DEBE pedir dos
entradas. La espera NO DEBE reutilizar los tiempos de la placa ni de la persiana.

### BR-INV-046 — La pausa congela cada etapa del cierre

CUANDO se pulsa Esc durante la devolución, el desplazamiento lateral, la reflexión, la elección o
la espera, el sistema DEBE abrir la pausa encima (BR-SAV-016). MIENTRAS la pausa está en
pantalla, ningún botón del cierre DEBE responder, y el recorrido, la entrega de mensajes y la
espera NO DEBEN avanzar. Reanudar DEBE conservar la etapa, el desplazamiento del chat, la foto
ampliada, el texto o la opción mostrada, la posición del celular y lo que falta de la espera.

### BR-INV-047 — Las notas conservan el cierre en orden

El chat de notas DEBE conservar, en el orden en que los recibió, los textos de la reflexión de
jornada 1, la foto y el texto de cada pista (BR-INV-040) y el texto de la hipótesis elegida. DEBE
tener un fondo propio, distinto del de los demás chats. Desde jornada 3, el menú DEBE ofrecerlo
con todo ese historial (BR-INV-040), y sus fotos DEBEN ampliarse según BR-INV-025. El historial
de notas cruza la sesión por el guardado (BR-SAV-021); reconstruirlo NO DEBE duplicar mensajes,
publicar pistas ni elegir una hipótesis.

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
ambas veces muestra el menú. CUANDO se pulsa un botón ENTONCES abre ese chat en su último
mensaje y con cero no leídos; la rueda permite llegar al primero y la flecha vuelve al menú.
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
sin texto; la cuarta conserva la pantalla. DADO una foto ampliada CUANDO se hace clic izquierdo
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
celular arriba CUANDO se hace clic izquierdo por fuera de él ENTONCES pide cerrarse; adentro, no.

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

DADO el celular con una foto ampliada CUANDO se pulsa Esc, luego Q, y se reanuda ENTONCES vuelve
la misma foto. DADO el celular abierto CUANDO cierra el turno ENTONCES queda cerrado y el control
permanece suspendido por el cierre. CUANDO abre otra jornada ENTONCES sigue cerrado y el primer
Q permitido abre el menú.

### AC-INV-037 — Retomar reconstruye los chats *(verifica BR-INV-023, BR-INV-008)*

DADO un guardado en jornada 3, con chats que antes se leyeron y mensajes recibidos fuera del guión,
CUANDO se retoma ENTONCES se ven los mensajes del guión de jornada menor o igual a 3, todos sin
leer, y ninguno de los recibidos fuera de él salvo las devoluciones de Enrique de las jornadas 1
y 2, intercaladas con las aperturas: instrucciones, devolución 1, foto y texto de apertura 2,
devolución 2. Los registros legados sin jornada conservan su orden sin fechas inventadas.
Abrir y cerrar sin entrar a un chat conserva los contadores.

### AC-INV-038 — Un botón por chat y una imagen de reemplazo *(verifica BR-INV-023)*

DADO dos chats visibles, uno con imagen y dos no leídos y otro sin imagen ni no leídos, CUANDO
se muestra el menú ENTONCES hay dos botones: el primero con nombre, imagen y contador 2, y el
segundo con nombre y círculo liso del tema, sin contador cero.

### AC-INV-039 — La entrada exacta en jornada 2 ofrece sus dos chats *(verifica BR-INV-029, BR-INV-023, BR-INV-008, BR-INV-009)*

DADO jornada 1 CUANDO se abre el menú ENTONCES sólo ofrece Enrique. DADO apertura de jornada 2
por transición y, por separado, checkpoint CUANDO se consulta ENTONCES ofrece Enrique y Yasmín,
con los roles Jefe y Compañera de trabajo. Yasmín tiene exactamente las quince identidades
J2_1 a J2_15 con los textos de BR-INV-029, incluido el doble espacio antes de 💪, sin mensajes
de jornada 3. Leer Yasmín deja su contador en cero sin cambiar el de Enrique ni el guion.

### AC-INV-040 — La apertura queda entre las devoluciones *(verifica BR-INV-030, BR-INV-029)*

DADO cierre 1 y apertura 2 CUANDO se recorre Enrique ENTONCES están las 19 entradas de las
instrucciones, los mensajes de devolución 1, la foto del contenedor y su texto, en ese orden.
CUANDO cierra la 2 ENTONCES su devolución queda después de ese texto, cada mensaje una vez.
Reabrir celular, volver al menú y repetir apertura 2 no cambian identidades, contenido u orden.
Los quince mensajes de Yasmín tampoco se duplican al repetir esos recorridos.

### AC-INV-041 — El clic de pista tiene un borde exacto *(verifica BR-INV-031)*

DADO J2_6 visible CUANDO se mide el texto ENTONCES sólo «acá siempre falta algo» está en lila
y las palabras anteriores y posteriores siguen blancas y literales. CUANDO se abre o lee,
o se pulsa fuera del tramo ENTONCES hay cero pedidos de 2A. Un clic dentro emite exactamente
un pedido de 2A y dos clics válidos pueden emitir dos, con cero cambios directos del expediente.
Una identidad o tramo inexistente no emite. Se ejerce en escritorio y paquete web.

### AC-INV-042 — La foto del contenedor usa el adjunto de su apertura *(verifica BR-INV-029, BR-INV-025, BR-INV-027)*

DADO Enrique en jornada 2 CUANDO se pulsa su foto de apertura ENTONCES se amplía completa,
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

DADO jornada 2 sin pistas CUANDO se abre y lee el chat de Yasmín o se pulsa otra parte de J2_6
ENTONCES no hay pista nueva. CUANDO se pulsa «acá siempre falta algo» ENTONCES anota sólo 2A;
repetir la pulsación no la duplica ni emite otro aviso. En jornada 1 o 3 ese gesto no registra 2A.

### AC-INV-049 — La colilla exige un levantamiento aceptado *(verifica BR-INV-038, BR-INV-037)*

DADO jornada 2 y la colilla visible al fondo del depósito cerca de la puerta garage CUANDO se
mira o se pide E con manos vacías ENTONCES sigue sin 2B. Agarre rechazado o pausa tampoco anota.
CUANDO el agarre se acepta ENTONCES la misma colilla queda en mano y se anota 2B. Soltarla y
volver a levantarla no duplica pista ni mensajes; sostenerla al cierre conserva el hallazgo.
La colilla es reconocible visualmente y no pertenece al catálogo vendible. En otra jornada,
levantarla no registra 2B.

### AC-INV-050 — Cuatro combinaciones y ninguna opción extra *(verifica BR-INV-039)*

DADO expedientes de jornada 2 con cero pistas, sólo 2A, sólo 2B y ambas, CUANDO se consultan
las opciones ENTONCES son respectivamente [2P], [2A], [2B] y [2A, 2B]. Repetir la consulta y
navegar conserva identidades y mensajes. Nunca aparece 2L y 2P no crea foto ni pista ficticia.

### AC-INV-051 — Orden de descubrimiento y pares de mensajes *(verifica BR-INV-040, BR-INV-032, BR-INV-025)*

DADO notas vacías CUANDO se anota 2B y después 2A ENTONCES hay exactamente cuatro mensajes:
foto 2B, texto 2B, foto 2A y texto 2A. Repetir ambas pistas y registrar una desconocida conserva
esos cuatro. Ampliar cada foto usa sólo su texto siguiente; cerrarla conserva chat y posición.
Reabrir otra jornada y reconstruir las mismas identidades y mensajes no duplica el contenido.

### AC-INV-052 — Menú y modo fijo tienen permisos distintos *(verifica BR-INV-040, BR-INV-026, BR-INV-023)*

DADO notas con dos mensajes de 2A CUANDO se abre el menú durante jornadas 1 y 2 ENTONCES notas
no tiene botón; en la 3 sí. DADO cierre de jornada 1 o 2 CUANDO se fija notas ENTONCES abre su
chat propio sin pasar por el menú, aun vacío en la 1, permite leer y ampliar, y Q no lo cierra.

### AC-INV-053 — Datos exactos y fotos propias *(verifica BR-INV-041)*

DADO las identidades 2A, 2B y 2P CUANDO se consultan sus datos ENTONCES títulos, textos de pista
y de hipótesis coinciden exactamente con BR-INV-041, incluida «cigarrilo». La foto 2A corresponde
al círculo existente del contacto de Yasmín, aprobado por el usuario, y 2B muestra la colilla
en el piso; 2P no tiene foto ni texto de pista.
Las tres opciones conservan sus identidades al volver a consultar.

### AC-INV-054 — Revelación y pista no comparten contador *(verifica BR-INV-037, BR-INV-032, BR-INV-001)*

DADO un objeto con revelación ajena a las pistas del caso CUANDO se lo examina dos veces ENTONCES
su cuenta de hallazgos es 1 y el expediente sigue vacío. DADO la colilla levantada en jornada 2
ENTONCES 2B está anotada por el agarre, sin exigir examen ni convertir los demás subtítulos en
pistas. DADO una pista de objeto no levantable o diálogo de comprador declarada en un caso de
prueba CUANDO se usa otro canal ENTONCES no se anota; el gesto declarado sí la anota una vez.

### AC-INV-055 — Consultar notas entrega copias *(verifica BR-INV-040, BR-INV-036)*

DADO 2A anotada y una copia de sus identidades y mensajes CUANDO se vacían o reordenan esas
copias ENTONCES el expediente conserva 2A, notas conserva foto/texto en ese orden y el guion
compartido permanece intacto. Las consultas no registran pistas ni emiten pista nueva.

### AC-INV-056 — El historial fechado vuelve igual y no fusiona textos *(verifica BR-INV-030, BR-INV-023, BR-INV-008)*

DADO checkpoint de apertura 2 con devolución 1 fechada CUANDO se retoma ENTONCES muestra
instrucciones, devolución 1 y apertura 2 en ese orden, y los quince mensajes de Yasmín están
sin leer. DADO dos devoluciones de distintas jornadas con el mismo texto CUANDO se reconstruyen
ENTONCES permanecen dos mensajes con sus identidades y posiciones distintas; modificar una
lista consultada no cambia el historial ni el guion.

### AC-INV-057 — Del centro a la izquierda sin bajar *(verifica BR-INV-042)*

DADO la devolución de jornada 1 terminada, a 1920 × 1080 y a 1280 × 720, CUANDO se elige
continuar ENTONCES la persiana sigue baja y en cada cuadro el borde inferior del celular queda
dentro del encuadre. Su centro horizontal nunca aumenta y, a los 0,25 segundos, termina a la
izquierda del centro del encuadre; a los 0,125 segundos todavía no llegó. Al final, el chat de notas está abierto en modo fijo y el recuadro está entero a la
derecha del centro, sin intersección con el celular. DADO el recorrido empezado CUANDO un cuadro
llega 2 segundos tarde ENTONCES avanzó lo que corresponde a 1/30 de segundo. DADO la reflexión en
pantalla CUANDO se pulsa Q o se pide volver al menú de chats ENTONCES sigue fija en notas; la
rueda desplaza y una foto se amplía y se cierra. El turno no descuenta y el jugador no se mueve.

### AC-INV-058 — Sin reflexión, y la apertura siguiente al centro *(verifica BR-INV-042)*

DADO un despido en jornada 1 o 2 CUANDO termina su devolución ENTONCES sólo se ofrece volver al
menú y no aparece la reflexión. DADO el cierre de jornada 3 con la partida en curso CUANDO se
elige continuar ENTONCES el celular baja y empieza «NOCHE 4», sin reflexión. DADO la reflexión de
jornada 1 terminada CUANDO empieza la entrada ENTONCES el celular está cerrado, sin modo fijo, y
el recuadro no está; CUANDO se pulsa Q en la noche 2 ENTONCES sube al centro y abre el menú.

### AC-INV-059 — Tres textos, tres notas *(verifica BR-INV-043)*

DADO la reflexión de jornada 1 con notas vacías ENTONCES el recuadro dice «Primera jornada
terminada…» y el texto 1. CUANDO se pulsa «Continuar» ENTONCES las notas son [texto 1], el
recuadro muestra sólo el texto 2 y no hay entrada. CUANDO se repite el pedido del texto 1
ENTONCES las notas siguen [texto 1] y el recuadro sigue en el texto 2. CUANDO se pulsa
«Continuar» dos veces más ENTONCES las notas son [texto 1, texto 2, texto 3], hay una sola
entrada «NOCHE 2» y otro pedido no agrega nada. El expediente sigue vacío y no hay elección.

### AC-INV-060 — Cuatro combinaciones en el recuadro *(verifica BR-INV-044, BR-INV-039)*

DADO el cierre de jornada 2 ENTONCES el encabezado es «Hoy faltabo uno de los jabones para la
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
desconocida ENTONCES contesta NO_DISPONIBLE. DADO la devolución o la reflexión de jornada 1 en
pantalla CUANDO se pide elegir ENTONCES contesta FUERA_DE_ETAPA. En esos tres casos no hay nota,
elección ni entrada. Antes de elegir, consultar la elección no devuelve ninguna. DADO la
elección de jornada 2 o el texto 2 de jornada 1 en pantalla CUANDO pasan 10 minutos ENTONCES
siguen en pantalla, sin nota nueva, sin elección y sin entrada.

### AC-INV-062 — La espera retiene la tercera noche *(verifica BR-INV-045)*

DADO la elección de jornada 2 aceptada CUANDO pasa la espera declarada menos un cuadro
ENTONCES no hay entrada; CUANDO pasa el cuadro siguiente ENTONCES hay exactamente una entrada
«NOCHE 3». DADO la espera empezada CUANDO un cuadro llega 10 segundos tarde ENTONCES hay a lo
sumo una entrada. DADO la espera a mitad CUANDO se pausa, pasan 3 segundos y se reanuda
ENTONCES falta lo mismo que antes de pausar. Navegar o elegir durante la espera no cambia nada.
Ni la espera ni la entrada descuentan el turno de la jornada 3.

### AC-INV-063 — La pausa congela cada etapa *(verifica BR-INV-046)*

DADO cada etapa por separado —la devolución con 2 de 4 mensajes, el recorrido lateral a mitad,
la reflexión de jornada 1 en el texto 2 con las notas desplazadas, la elección mostrando 2B y la
espera a mitad— CUANDO se pulsa Esc, se pulsan los botones del cierre, pasan 3 segundos y se
reanuda ENTONCES la etapa, los mensajes visibles, la posición del celular, el desplazamiento, el
texto u opción mostrada y lo que falta de la espera son los mismos, y los botones pulsados
durante la pausa no tuvieron efecto.

### AC-INV-064 — Las notas de la tercera noche *(verifica BR-INV-047, BR-INV-040)*

DADO una partida que recibió los tres textos de jornada 1, anotó 2B y eligió 2B CUANDO se abre
el menú en jornada 3 ENTONCES ofrece el chat de notas; CUANDO se abre ENTONCES muestra texto 1,
texto 2, texto 3, foto 2B, texto de pista 2B y texto de hipótesis 2B, en ese orden, y la foto 2B
se amplía con su texto. Su fondo difiere del fondo del chat de Enrique. En jornadas 1 y 2, el
menú no lo ofrece.

## No objetivos

- Esta capacidad NO inventa el contenido: consume los guiones decididos; la apertura de
  jornada 2 y su tramo de pista están fijados en BR-INV-029 y BR-INV-031.
- Esta capacidad NO descuenta tiempo del turno.
- Esta capacidad NO inventa contactos, pistas, hipótesis o desenlaces de jornadas futuras:
  consume el contenido decidido.
- Esta capacidad NO elige una hipótesis por el jugador ni escribe checkpoints: entrega opciones,
  identidades, la reflexión pendiente, la elección y los mensajes al cierre y al guardado.

## Contratos

- **Entrada:** el objeto examinado, la entrada de movimiento y los segundos del cuadro, el
  arrastre del mouse y la conversación abierta; caso, pistas, exigencias y desenlaces,
  expediente recibido, identidades para reconstrucción y gestos de pista con canal y jornada;
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
  elección de la partida; el pedido de la entrada siguiente, una sola vez.
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

- **OQ-INV-004 — ¿Qué pistas, hipótesis y desenlaces definen las jornadas 3 a 5?**
  - Por qué sigue abierta: las fichas de ese contenido siguen «A desarrollar» y no fijan
    exigencias ni umbrales de los finales. Los ejemplos de aceptación son casos de prueba,
    no contenido para el juego.
  - Decide: game design.
  - Bloquea: publicar ese contenido y sus finales; no bloquea el motor ni las pistas de jornada 2.
- **OQ-INV-006 — ¿Cuánto dura la espera entre elegir la hipótesis de jornada 2 y «NOCHE 3»?**
  - Por qué sigue abierta: la ficha «Pantalla entre jornadas» dice «después de unos segundos»,
    sin cifra. Los tiempos de la placa y de la persiana son otra cosa.
  - Decide: el dueño de diseño.
  - Bloquea: fijar la duración de BR-INV-045; no bloquea la elección, las notas ni el guardado.
- **OQ-INV-005 — ¿Dónde se intercalan las devoluciones legadas sin jornada?**
  - Por qué sigue abierta: los guardados antiguos sólo contienen textos y orden de recepción;
    no permiten reconstruir qué cierre produjo cada bloque ni su relación con una apertura.
    La compatibilidad exige conservarlos sin inventar una fecha, pero no está decidida su
    posición entre bloques fechados.
  - Decide: el dueño del repo con diseño narrativo.
  - Bloquea: fijar un intercalado cronológico entre registros legados sin fecha y aperturas;
    no bloquea conservar sus textos y orden relativo ni ordenar los registros nuevos fechados.
