---
schema_version: 1
capability_id: CAP-EMP
status: ratified
owner: por definir
provenance: GDD «Consecuencias» y «Finales»; fichas «1. Ciclo de jornadas y sistema de puntos», «Pantalla entre jornadas» y «Chat con el jefe»; decisiones de #374, decisión del 2026-09-28 de #299, decisiones de #375 y corrección visual solicitada en #398; migración de los specs 002, 016, 017; metadatos temporales de devoluciones de #430; decisiones de #432 sobre el hecho de uso de Poético y de #22 sobre la titularidad del expediente, 2026-10-15; advertencia por Poético y paso a la reflexión de cierre de #436; ocho jornadas de #526; instrucciones por jornada de #527; cuartito de limpieza de #541; puntos de las jornadas de prueba de #572; devolución desde la jornada 4 y cierres de la ficha del 20/10 de #576; mensajes introductorios de la jornada 4 en pantalla, de la ficha «Chat con el jefe» del 2026-10-21; auditoría de la prueba contra las fichas del 2026-10-22
---

# Capacidad: el legajo del empleado

## Propósito

Llevar la cuenta de lo que el empleado debe y decidir cuándo lo echan. Lo único que tiene que
hacer bien es que las tres bandas **pesen distinto**: dos noches graves seguidas despiden y una
noche impecable suma cero y conserva la deuda acumulada.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Banda** | cómo cerró la noche: ninguna, aviso o grave | nota, puntaje |
| **Apercibimiento** | la unidad de deuda que se arrastra entre noches | strike, falta |
| **Medio** | media unidad de apercibimiento, conservada exactamente entre noches | fracción flotante |
| **Llamado** | un motivo distinto de la noche que suma medio apercibimiento | repetición, banda |
| **Legajo** | el contador de apercibimientos que cruza la noche | racha, historial |
| **Partida** | las ocho jornadas del contrato, con su final | run, sesión |
| **Final** | cómo termina la partida: en curso, contrato cumplido o despedido | game over |
| **Devolución** | los mensajes que Enrique manda por el chat al cerrar cada noche: Saludo, las Tareas y los Retos que correspondan, y Cierre | placa del cierre, parte, reporte |
| **P** | la deuda exacta en apercibimientos, con su medio: los medios del legajo divididos por 2, después de anotar la noche. Elige textos y nunca se muestra | puntaje, puntos visibles |
| **J** | la jornada que acaba de cerrar | noche actual |
| **Prueba** | las tres jornadas de introducción (BR-SHF-005), anteriores a la primera completa | tutorial |
| **Descuido** | lo que suma un apercibimiento en la prueba: un cliente mal atendido, o registrar, reponer o limpiar sin cumplir al cerrar | falla, error |
| **Cliente mal atendido** | uno que llegó a la ventanilla, no se le vendió y se cansó de esperar | cliente perdido |
| **Falla** | una noche que cerró con una obligatoria fija sin cumplir. Se cuenta por obligatoria | error, strike |
| **R** | cuántas noches seguidas terminaron sin sumar medios, contando la que acaba de cerrar | racha |

## Comportamiento normativo

### BR-EMP-001 — Las tres bandas

CUANDO cierra la jornada, el sistema DEBE traducir cuántas obligatorias se cumplieron a una
banda: **todas** las declaradas es `NINGUNA`; **3 o más** y menos que todas es `AVISO`; **menos
de 3** es `GRAVE`. El corte es en tareas y no en porcentaje: no se reescala con las obligatorias.

### BR-EMP-002 — Las bandas pesan distinto

CUANDO se anota una banda de una jornada completa —desde la jornada 4—, el sistema DEBE sumar **1**
apercibimiento por `AVISO`, **2** por `GRAVE`, y DEBE sumar **0** con `NINGUNA`, conservando los
apercibimientos que había. La prueba no suma por banda (BR-EMP-035).

### BR-EMP-003 — A los cuatro lo echan

SI, desde la jornada 4, el legajo llega a **8 medios o más**, equivalentes a 4 apercibimientos,
ENTONCES el sistema DEBE declararlo despedido. Con 7 medios todavía no está despedido. En la
prueba el legajo puede pasar de 8 medios sin despedir: se pierde por BR-EMP-037.

### BR-EMP-004 — El contrato dura ocho noches

El sistema DEBE numerar las jornadas **desde 1** y terminar la partida con contrato cumplido al
cerrar la **octava**.

### BR-EMP-005 — El despido se pregunta primero

CUANDO cierra la última jornada, el sistema DEBE decidir el despido **antes** que el contrato
cumplido. La última noche puede cerrar mal justo cuando el legajo llega al tope, y felicitar a
alguien recién echado es la lectura equivocada de las dos condiciones a la vez.

### BR-EMP-006 — Una partida terminada no sigue

SI la partida terminó, ENTONCES el sistema DEBE rechazar abrir otra jornada y DEBE ignorar un
cierre nuevo. Una partida terminada no DEBE anotar otra noche ni avanzar su jornada.

### BR-EMP-007 — Cerrar dos veces no anota dos veces

SI la jornada no está abierta, ENTONCES el sistema DEBE ignorar el cierre. La puerta es pública
y una pantalla la va a tocar.

### BR-EMP-008 — El legajo se restaura entero

El sistema DEBE poder arrancar una partida con un legajo que viene de un guardado. Una historia
de noches graves repartida entre dos sesiones tiene que despedir igual. El sistema DEBE conservar
exactamente los medios acumulados como entero. Sin ese dato, o con un tipo distinto de entero,
DEBE restaurar cero medios sin perder una jornada válida. Un dato antiguo de apercibimientos
no DEBE sustituir el dato de medios ni migrarse.

### BR-EMP-009 — La devolución de Enrique

CUANDO cierra una jornada que no es de introducción (BR-SHF-005), el sistema DEBE armar la
devolución de esa noche: un mensaje por parte, en este orden: Saludo, Tarea 1, Tarea 2, Tarea 3, Tarea 4, la advertencia por Poético,
Tarea 5, Reto 1, Reto 2, Reto 3, Reto 4 y Cierre. Saludo y Cierre DEBEN ir siempre. La
advertencia DEBE ir sólo según BR-EMP-034.

- Tarea 1 es atender (cobrar en la caja), Tarea 2 registrar, Tarea 3 reponer, Tarea 4 limpiar,
  y Tarea 5 la particular de esa noche. Una Tarea DEBE ir sólo si su obligatoria quedó sin
  cumplir al cerrar (BR-SHF-007).
- Reto 1 es el llamado por papel en el inodoro, Reto 2 por objetos importantes en la basura,
  Reto 3 por objetos afuera y Reto 4 por local desordenado. Un Reto DEBE ir sólo si esa noche se
  anotó su llamado (BR-EMP-012).

CUANDO cierra una jornada de introducción, jornadas 1 a 3, el sistema NO DEBE armar devolución:
ni la pantalla de cierre ni el historial de Enrique reciben un mensaje suyo.

Las condiciones DEBEN leerse **después** de anotar la noche (BR-EMP-025). Los textos DEBEN ser los
de la ficha «Chat con el jefe», sección «Devolución de final de jornada», letra por letra, con
sólo tres correcciones de erratas de la ficha: a la tercera falla de Tarea 2 le falta la «v» de
«otra vez», el Cierre de P = 1,5 repite «tus» antes de «responsabilidades», y el Cierre de P = 0
en la jornada 4 y los dos de P = 2
traen un espacio final que sobra. Ningún mensaje DEBE mostrar P, medios, apercibimientos, la
banda ni un contador.

### BR-EMP-011 — Lo que ofrece la devolución depende del final

CUANDO se arma la devolución, el sistema DEBE decir qué puede elegir el jugador. Con la partida
en curso, ofrece **sólo continuar**. En las jornadas 4 y 5, continuar pasa a la reflexión de
cierre (BR-INV-042) y la entrada de la noche siguiente empieza cuando ésta termina. En las
demás, el celular baja por el margen inferior y después empieza la entrada de la noche
siguiente (BR-SHF-019). Salir al menú pasa por la pausa, como en cualquier
otro momento de la jornada. Con la partida terminada, despedido o contrato cumplido, ofrece sólo
volver al menú: no hay noche siguiente que abrir. La opción DEBE aparecer debajo del último
mensaje, recién cuando ése está a la vista (BR-EMP-030). Elegirla dos veces NO DEBE abrir dos
noches ni pedir dos veces el menú.

### BR-EMP-012 — Los llamados suman medios por motivo

MIENTRAS la jornada está abierta, el sistema DEBE registrar cada motivo de llamado una sola vez.
CUANDO cierra, DEBE sumar un medio por motivo distinto, además del peso de la banda, incluso
con NINGUNA. En la prueba los llamados NO DEBEN sumar medios (BR-EMP-035). Abrir otra jornada
DEBE vaciar los motivos pendientes. Antes de abrir, después de
cerrar y con la partida terminada, anotar un llamado NO DEBE modificar el legajo ni una noche
futura. Los motivos pendientes no DEBEN persistirse ni mostrar un contador nuevo.

### BR-EMP-022 — Enrique introduce cada jornada de introducción

CUANDO abre una jornada de introducción (BR-SHF-005) o la primera jornada completa, por partida
nueva, al seguir desde el cierre anterior o retomada desde el menú, el sistema DEBE presentar las
instrucciones de Enrique Peldaño propias de esa jornada antes de su comienzo jugable, sobre la
persiana baja. CUANDO abre otra jornada, o una de ésas sin instrucciones propias, el sistema NO
DEBE mostrar instrucciones y DEBE anunciar la noche directamente (BR-SHF-019).

Las instrucciones DEBEN ser los doce mensajes introductorios de la ficha «Chat con el jefe»
revisada el 2026-10-21, repartidos así:

| Jornada | En pantalla | Sólo en el chat |
|---|---|---|
| 1 | Intro 1 a 6 | — |
| 2 | El mensaje 1 que elige BR-EMP-040, Intro 7 e Intro 8 | — |
| 3 | El mensaje 1 que elige BR-EMP-042 e Intro 9 | — |
| 4 | El mensaje 1 que elige BR-EMP-043, Intro 10, Intro 11 e Intro 12 | — |

Cada mensaje DEBE decir el texto de la ficha, conservar su orden y los énfasis en amarillo, sin
negrita. DEBE corregir «vas a tener» en Intro 3 e «instrucciones» en Intro 10, mostrar el horario
como «20 a 08» y decir «ocho jornadas» y «los primeros días» en Intro 1. La jornada 1 NO DEBE
pedir reponer: Enrique explica la reposición recién en Intro 7, y también la de los productos que
el jugador saque de las góndolas para vender.

Las nueve fotos DEBEN mostrar el juego y acompañar Intro 2, 3, 4, 6, 7, 9 y 11, cada una en la
jornada de su Intro. Intro 2 DEBE llevar primero el reloj y después la nota de tareas del corcho.
Intro 7 DEBE llevar primero las góndolas y después una estantería con cajas. Las demás DEBEN
conservar una foto cada una: la ventanilla, el lector y la caja registradora, la computadora,
los útiles y notas del cuartito y el depósito con sus cajas en el piso. Las capturas nuevas
DEBEN salir del modelo jugable de la primera jornada sin editar la imagen.
La foto de las góndolas NO DEBE crear huecos ni cambiar la reposición jugable. La foto de la
estantería NO DEBE cambiar la disposición jugable de las cajas de la primera noche. El encuadre
artístico de cada tema es territorio de juicio humano; la correspondencia se verifica en
AC-EMP-047.

### BR-EMP-023 — Las instrucciones avanzan por pasos de contenido

CUANDO se muestran las instrucciones de una jornada, el sistema DEBE presentar una pantalla
independiente por cada texto de esa jornada, en orden, sin desplazamiento ni acumulación de
contenido. Cada «Siguiente» DEBE reemplazar la pantalla actual por la siguiente y «Volver» por
la anterior, sin bajar de uno.

La navegación y el contador DEBEN permanecer fijos abajo, separados del contenido. «Volver»
DEBE estar visible y deshabilitado en la primera pantalla. El contador DEBE indicar la pantalla
actual sobre el total de esa jornada. En la última, «Siguiente» DEBE decir «OK»; retroceder DEBE
restaurar «Siguiente». Con una sola pantalla, la primera es la última. Elegir «OK» DEBE terminar
las instrucciones y pedir una sola entrada a la noche de esa jornada, aunque se repita el gesto.

Cada pantalla DEBE mostrar sus textos antes de las fotos y conservar el separador y las etiquetas
del diseño. El retrato de Enrique y su bocadillo DEBEN permanecer visibles en todas las
pantallas, por aclaración explícita del usuario. La de Intro 4 DEBE acompañar el lector con la
interfaz de caja y el ticket. Las fotos DEBEN cubrir su marco sin franjas negras y
mantener visible el objeto ilustrado. La foto de Intro 11 DEBE acompañar su texto en pantalla
y en el chat, aunque su frame de referencia omita esa foto.

Intro 2 e Intro 7 DEBEN mostrar sus dos fotos después del texto y en el orden declarado.
Provisoriamente, DEBEN ir lado a lado, con igual alto y dentro del ancho del texto, de 1007 px.

Los textos y las nueve fotos DEBEN conservarse como 23 entradas separadas en el chat de
Enrique: 11 de la jornada 1, 5 de la 2, 3 de la 3 y 4 de la 4, más el mensaje 1 de la jornada 4
cuando BR-EMP-043 elige uno. De las jornadas 2, 3 y 4, el chat DEBE tener sólo el mensaje 1 que
eligieron BR-EMP-040, BR-EMP-042 y BR-EMP-043. Cada grupo de fotos DEBE ir inmediatamente
antes del texto de su Intro. Desde que abre su jornada, ese chat DEBE permitir releer cada
entrada y ampliar cada foto con el texto de su propia Intro.

### BR-EMP-024 — La preparación no consume la noche

MIENTRAS se leen las instrucciones, el sistema DEBE conservar la persiana baja, suspender al
jugador y retener todo el presupuesto del turno, aunque la lectura dure minutos. La interfaz
DEBE emerger desde el margen derecho con ease out, encima de la persiana y debajo de avisos y pausa. Esc
DEBE pausarla y reanudarla conservando la pantalla actual. «OK» DEBE retirar las
instrucciones por el margen izquierdo con ease in y, sólo al terminar la salida, dar paso a la
placa y subida de persiana. Repetir «OK» durante la salida NO DEBE anunciar otra noche.
El control y el reloj DEBEN liberarse
sólo cuando termine esa entrada. El fade in de la persiana baja DEBE durar 0,3 segundos reales
y la entrada de las instrucciones DEBE durar 0,3 segundos reales. La persiana de fondo NO DEBE
desplazarse con las instrucciones. Pausar durante la entrada o la salida DEBE congelar el
movimiento y reanudarlo desde el mismo punto, sin cobrar el tiempo pausado. Retomar desde el
menú una jornada con instrucciones DEBE repetir la entrada desde la derecha.
Un cuadro largo NO DEBE adelantar las animaciones más de 1/30 de segundo: el cuadro que abre la partida tarda.

### BR-EMP-025 — Lo que la partida cuenta entre noches

CUANDO se anota una noche desde la primera jornada completa, el sistema DEBE sumar una falla a
cada obligatoria fija —atender,
registrar, reponer y limpiar— que quedó sin cumplir al cerrar, y un llamado a cada motivo anotado
esa noche, una sola vez por noche (BR-EMP-012). Vale el estado al cerrar: una obligatoria que se
cumplió y se descumplió antes del cierre suma una falla (BR-SHF-007). La particular NO DEBE sumar
fallas. El sistema DEBE llevar R: una noche que no sumó medios lo sube en uno, y una que sumó lo
vuelve a 0. DEBE recordar si hubo algún llamado en la partida, contando esta noche. Un cierre
ignorado (BR-EMP-006, BR-EMP-007) NO DEBE contar. Una partida nueva DEBE empezar con cero fallas,
cero llamados, R = 0 y sin llamados en la partida. Las noches de la prueba NO DEBEN cambiar
ninguna de estas cuentas: la devolución las lee desde la jornada 4, y la primera falla que
cuenta es la primera desde ahí (OQ-EMP-012).

### BR-EMP-026 — El Saludo sale de P

El sistema DEBE elegir el Saludo por P:

| Condición | Texto |
|---|---|
| 0 ≤ P < 1 | Buen día! |
| 1 ≤ P < 2 | Buenas |
| 2 ≤ P < 3 | Hola |
| 3 ≤ P < 4 | Buenos días... |
| P ≥ 4 | Che |

P ≥ 4 es el despido de BR-EMP-003.

### BR-EMP-027 — Las Tareas dicen la falla que es

Para Tarea 1 a 4, el sistema DEBE elegir el texto por n, la cantidad de fallas de esa obligatoria
contando esta noche (BR-EMP-025). No hay quinta: cada falla suma por lo menos un apercibimiento
(BR-EMP-002), así que la cuarta llega con P ≥ 4 y despide (BR-EMP-003).

| Parte | n | Texto |
|---|---|---|
| Tarea 1 | 1 | Me llegó un comentario de un vecino que no fue correctamente atendido anoche. |
| Tarea 1 | 2 | Ya es la segunda vez que escucho a un cliente quejarse de la atención nocturna del local. |
| Tarea 1 | 3 | Sigo recibiendo quejas de compradores. Eso no puede pasar. Entendés que la venta de productos es nuestra principal fuente de ingresos? |
| Tarea 1 | 4 | De qué me sirve tenerte de empleado si ni siquiera atendés bien a los clientes? |
| Tarea 2 | 1 | El registro de la computadora no parece concordar con los ingresos de ayer. |
| Tarea 2 | 2 | Otra vez te olvidaste de anotar los productos vendidos. |
| Tarea 2 | 3 | El registro de ventas está mal otra vez. Entendés que después tengo que estar haciendo cálculos revisando qué productos faltan para entender qué vendiste? |
| Tarea 2 | 4 | No puede ser que no puedas hacer algo tan simple como anotar bien unos numeritos en una computadora. |
| Tarea 3 | 1 | Faltó reponer algunas unidades en las góndolas. Como te dije, un único producto ausente puede hacer la diferencia. |
| Tarea 3 | 2 | No podés dejarle a tu compañera la tarea de completar los huecos en las góndolas. A veces hay que ponerse las pilas. |
| Tarea 3 | 3 | De nuevo quedaron algunas góndolas incompletas. Si te pido que queden llenas, es que queden llenas. No con algún que otro huequito. LLENAS. |
| Tarea 3 | 4 | Te lo puedo llegar a entender en las otras tareas, pero no es posible que no puedas hacer bien la reposición. |
| Tarea 4 | 1 | Quedaron algunos rincones sucios en el local. |
| Tarea 4 | 2 | Otra vez el local quedó sucio. |
| Tarea 4 | 3 | No puede ser que siga quedando mugre en el local al momento de irte. |
| Tarea 4 | 4 | De casualidad limpiás tu casa vos? Sabés cómo se usa una mopa? |

Tarea 5 DEBE elegirse por J, no por una cuenta, y sólo existe en las jornadas que declaran una
particular (BR-SHF-005):

| J | Texto |
|---|---|
| 4 | Cuando te pedí que ordenaras las cajas en las estanterías del depósito, lo que quería decir es que pongas TODAS y cada una de las CAJAS de cartón con productos ARRIBA de las ESTANTERÍAS del DEPÓSITO. Ahí se entendió? |
| 5 | De verdad era tan difícil tirar tres bolsas de basura? |

### BR-EMP-028 — Los Retos dicen el llamado que es

Para cada Reto, el sistema DEBE elegir el texto por n, la cantidad de llamados de ese motivo
contando esta noche (BR-EMP-025), y por P cuando la fila lo pide. En Reto 2, las filas de J = 5 y
J = 6 DEBEN ganarle a las de n, y esos llamados DEBEN contar igual para la n de las noches
siguientes. La fila de J = 6 se conserva aunque esa noche no declare una particular de vencidos.

| Parte | Condición | Texto |
|---|---|---|
| Reto 1 | n = 1 | El baño se tapó. Por si no lo leíste, hay un cartelito muy claro diciendo que no se puede tirar papel en el inodoro. |
| Reto 1 | n = 2 | Se tapó el baño de nuevo. Pensé que el cartelito y mi mensaje iban a ser suficientes, pero veo que te lo voy a tener que repetir. El papel se tira EN EL TACHO. |
| Reto 1 | n ≥ 3 y P < 4 | Dejá de tirar papel en el inodoro. Ya no sé cómo pedírtelo. |
| Reto 1 | n ≥ 3 y P ≥ 4 | Una vez más tapaste el baño. Increíble. Yo que vos iría al neurólogo. O al gastroenterólogo, una de dos. |
| Reto 2 | J = 5 | Por si no lo sabías, la "basura" que te pedí que tiraras no incluye productos ni elementos del local. Estamos de acuerdo? |
| Reto 2 | J = 6 | Cuando te pedí que tiraras algunos productos, no me refería a objetos útiles y en buen estado! |
| Reto 2 | n = 1, J distinta de 5 y 6 | Puede ser que hayas estado tirando cosas a la basura? |
| Reto 2 | n = 2, J distinta de 5 y 6 | El contenedor de basura es para BASURA solamente. |
| Reto 2 | n ≥ 3, J distinta de 5 y 6 | Una vez más tuve que sacar cosas de la basura. Te parece gracioso? |
| Reto 3 | n = 1 | Puedo saber por qué hay propiedad del local al pie de la ventana? Del lado de AFUERA? |
| Reto 3 | n = 2 | Ya es la segunda vez que encuentro algo “mágicamente” depositado del otro lado de la ventanilla. Más te vale que no haya sido obra tuya. |
| Reto 3 | n = 3 | En serio, si sigue apareciendo propiedad del local en la vereda, voy a tener que poner una reja en la ventanilla. |
| Reto 3 | n = 4 | BASTA DE TIRAR COSAS POR LA VENTANILLA! |
| Reto 3 | n ≥ 5 | A esta altura del partido, ya estoy considerando tirarte a VOS por la ventanilla. |
| Reto 4 | n = 1 | Más allá de cumplir con los quehaceres, el orden también es importante. |
| Reto 4 | n = 2 y P < 4 | Dejá las cosas donde corresponde. Es una estación de servicio, no un pelotero. |
| Reto 4 | n = 3 y P < 4 | Me parece que no está quedando claro el temita de dejar todo ordenado. En el corcho hay una nota que seguro te va a servir. Pegale una leída, dale? |
| Reto 4 | n = 4 y P < 4 | Y si esta vez dejás ordenado? Sería mucho pedir? |
| Reto 4 | n ≥ 5, o n de 2 a 4 y P ≥ 4 | Realmente me sorprende cómo alguien puede tener tan poca conciencia de lo que es el orden. |

Un llamado se anota una vez por noche y la partida dura ocho, así que n no pasa de 8. La ficha
escribe hasta n = 5: la última fila de cada Reto cubre también las n mayores.

### BR-EMP-029 — El Cierre, y qué fila gana

El sistema DEBE elegir el Cierre con la primera de estas condiciones que se cumple:

1. **P ≥ 4**, en cualquier jornada: el despido. En J = 8 gana sobre el contrato cumplido
   (BR-EMP-005).
2. **J = 8**: la fila final por P. Las filas de R no se usan en J = 8.
3. **P = 0**: la fila de esa jornada, de J = 4 a J = 7.
4. **0 < P < 4 y R ≥ 1**: con R = 1, la fila «terminó la jornada sin sumar puntos»; con R ≥ 2, la
   fila «lleva más de una jornada sin sumar puntos». Cada una distingue P < 2 de P ≥ 2. Reconocen
   la mejora sin mostrar P, y les ganan a las filas por P.
5. **0 < P < 4 y R = 0**: la fila por P. Con P = 2 distingue si hubo algún llamado en la partida.

| Condición | Texto |
|---|---|
| P ≥ 4 | Es absurdo que tenga que estar persiguiéndote con estas cosas tan básicas. No puedo dejar que un desastre como vos siga perjudicando la reputación de mi local. Que ni se te ocurra volver a aparecer por acá, entendiste? |
| J = 8 y P = 0 | La verdad es que estoy impresionado. No hizo falta corregirte ni una sola cosa en las cinco noches. Un trabajo excepcional. Va a ser un placer tenerte trabajando acá. |
| J = 8 y 0 < P ≤ 1 | Bueno, más allá de alguna que otra cosita que te mencioné, no tengo nada para corregirte. Un trabajo bien hecho. Felicitaciones, el puesto es tuyo. |
| J = 8 y 1 < P ≤ 2 | Mirá, hubo un par de veces que la pifiaste, pero como soy generoso, te voy a dar el puesto igual. No aflojes. Desde ahora, espero que des lo mejor de vos. |
| J = 8 y 2 < P ≤ 3 | Honestamente, solo puedo concluir que no sos el empleado ideal, pero tampoco sos un inútil. Decidí darte el puesto. No me hagas cambiar de opinión, ok? |
| J = 8 y 3 < P < 4 | Me parece que quedan muchas cosas para pulir, pero ya te vas a curtir con el tiempo. No voy a negar que conocí peores empleados, así que te voy a dar una oportunidad. El puesto es tuyo, pero te voy a tener cortito para sacarte bien, está claro? |
| P = 0 y J = 4 | Seguiste todas mis instrucciones al pie de la letra. Excelente. Seguí así. |
| P = 0 y J = 5 | Nuevamente, todo en orden. Seguí así! |
| P = 0 y J = 6 | Sin comentarios por mi parte. Dale para adelante. |
| P = 0 y J = 7 | La jornada cerró cuadrada, como de costumbre. Excelente trabajo. |
| 0 < P < 2 y R = 1 | Ahora sí le vas agarrando la mano! Muy bien. Seguí así. |
| 0 < P < 2 y R ≥ 2 | Sin nada para comentar. Adelante con eso. |
| 2 ≤ P < 4 y R = 1 | Esta vez sí cumpliste con todo. Bien. Continuá por este camino. |
| 2 ≤ P < 4 y R ≥ 2 | Sin comentarios. |
| P = 0,5 y R = 0 | Te lo dejo pasar esta vez, pero tené en cuenta que hay ciertas normas básicas que tenés que cumplir además de hacer bien tus tareas. |
| P = 1 y R = 0 | Que no se repita, ok? |
| P = 1,5 y R = 0 | No duermas con tus responsabilidades y prestá atención a no meter la pata con pavadas. Focalizate. |
| P = 2, R = 0 y ningún llamado en la partida | Acordate de chequear que todas las tareas estén cerradas antes de irte, dale? |
| P = 2, R = 0 y algún llamado en la partida | Acordate de hacer bien tu trabajo y respetar las normas básicas de convivencia, dale? |
| P = 2,5 y R = 0 | Puedo perdonar que te mandes alguna, pero tampoco la pavada. Estate atento a tus tareas y no boludees. |
| P = 3 y R = 0 | En serio, mi paciencia tiene un límite... |
| P = 3,5 y R = 0 | Hay un límite en lo que te puedo dejar pasar. Un error más y te podés ir despidiendo de tu puesto. |

Las filas salen de la ficha. P avanza de a medio, así que las filas de R = 0 cubren todo 0 < P < 4.

### BR-EMP-030 — La devolución llega por el chat, mensaje a mensaje

CUANDO cierra la jornada, el sistema DEBE bajar la persiana sobre la pantalla y, sobre ella,
subir el celular al centro del encuadre (BR-INV-027), abierto en el chat de Enrique en modo fijo
(BR-INV-026). MIENTRAS la devolución está en pantalla, Q NO DEBE cerrar el celular; el jugador
DEBE poder desplazar el chat y ampliar sus fotos, y el turno DEBE seguir cerrado, con el control
suspendido.

Con el celular en el centro, el sistema DEBE mostrar los mensajes de la devolución uno por uno,
con un segundo entre cada uno: con t segundos transcurridos se ven mín(total, 1 + ⌊t⌋). El
primero aparece en t = 0. Ese tiempo NO DEBE correr con la pausa en pantalla: reanudar sigue
desde el mismo mensaje. Desplazar el chat NO DEBE saltear ni repetir un mensaje. La persiana DEBE bajar en 1 segundo,
lo mismo que tarda en subir al abrir la noche.

Los intervalos DEBEN empezar con el celular centrado. La fórmula describe el dibujo continuo:
si un cuadro llega tarde, el sistema NO DEBE entregar varios mensajes juntos para recuperar
el tiempo perdido. DEBE entregar como máximo uno y esperar un segundo desde esa entrega
para el siguiente.

### BR-EMP-031 — Las devoluciones conservan el cierre que las produjo

CUANDO se arma una devolución, el sistema DEBE agregar sus mensajes a los de Enrique de la
partida, con identidad estable, la jornada que acaba de cerrar y el orden de cada mensaje
dentro de esa devolución. NO DEBE asignarles la jornada inicial por defecto ni la siguiente.
Los textos, su selección y su ritmo DEBEN conservar BR-EMP-025 a BR-EMP-030.

Desde la noche siguiente, el chat DEBE conservar las entradas de instrucciones recibidas y cada
devolución, intercalada con ellas y con los mensajes de apertura en el orden temporal de
BR-INV-030. Cada devolución DEBE seguir a los mensajes de su jornada y preceder a los de la
siguiente: la devolución de la noche 3 precede a los mensajes de la 4, la de la 4 a la apertura 5,
y la devolución 5 la sigue. Una partida nueva DEBE empezar sin devoluciones; repetir el cierre o elegir
continuar dos veces NO DEBE duplicar sus mensajes ni alterar jornada u orden.

### BR-EMP-032 — El uso de Poético es un hecho de la quinta jornada

CUANDO se acepta teñir el balde con la unidad real de Poético durante jornada 5 abierta, el
sistema DEBE registrar una sola vez ese hecho y ofrecerlo al evaluar su devolución. Repetir
teñidos aceptados DEBE contestar ya registrado, sin sumar otro hecho. Rechazos, pausa, examen,
fuera de jornada abierta o uso de otro objeto NO DEBEN registrarlo. El hecho DEBE conservarse
hasta evaluar esa devolución y NO DEBE heredarse como uso de otra noche. Registrarlo NO DEBE
escribir mensajes ni decidir apercibimientos por sí solo.

### BR-EMP-033 — El expediente pertenece a cada partida

El sistema DEBE conservar un único expediente de investigación y los mensajes de sus notas
por partida, compartidos por quienes registran y consultan. Abrir otra jornada de esa partida
DEBE conservar identidades y orden en memoria. Una partida nueva DEBE empezar sin pistas ni
mensajes heredados. Un consumidor sin expediente recibido NO DEBE crear uno alternativo.
La investigación DEBE registrar sin escribir disco; la capacidad de guardado recibe el estado
que deba cruzar sesiones.

### BR-EMP-034 — Enrique advierte el uso de Poético

CUANDO se arma la devolución de jornada 5 y el hecho de BR-EMP-032 es verdadero, el sistema DEBE
agregar una sola advertencia, después de Tarea 4 si va y antes de Tarea 5 (BR-EMP-009). La
advertencia DEBE ir aunque limpiar se haya cumplido. Su texto DEBE elegirse por P, después de
anotar la noche (BR-EMP-025):

| Condición | Texto |
|---|---|
| P < 4 | Che, si usás un producto del local para la limpieza, me tenés que avisar. No podés hacer esas cosas sin consultarme. Espero que quede claro. |
| P ≥ 4 | Si usás un producto del local para la limpieza, me tenés que avisar. No podés hacer esas cosas sin consultarme. |

Sin el hecho, o en otra jornada, NO DEBE haber advertencia. La advertencia NO DEBE sumar medios
ni llamados, ni cambiar la banda, el final o el Cierre.

### BR-EMP-035 — La prueba suma un apercibimiento por cada descuido

CUANDO cierra una jornada de la prueba, el sistema DEBE sumar **1** apercibimiento por cada
cliente mal atendido y por cada obligatoria de registrar, reponer o limpiar que quedó sin cumplir
al cerrar. Un cliente suma una sola vez. Atender suma por sus clientes y no por la tarea: no suma
dos veces. Limpiar cuenta sólo en la jornada que la declara (BR-SHF-005). Los llamados NO DEBEN
sumar medios (BR-EMP-012), y el sistema NO DEBE traducir esa noche a una banda. Los apercibimientos se acumulan a lo largo de las tres jornadas.

### BR-EMP-036 — Las dos primeras jornadas no se pierden

CUANDO cierra la jornada 1 o la 2, el sistema NO DEBE declarar despedido, cualquiera sea lo
acumulado, y DEBE seguir con la jornada siguiente.

### BR-EMP-037 — La prueba se pierde al cerrar la tercera

CUANDO cierra la jornada 3, SI el legajo suma **5 apercibimientos o más** y alguna obligatoria de
esa jornada quedó sin cumplir, ENTONCES el sistema DEBE declarar despedido al cerrarla y no abrir
la jornada 4. Con 4 o menos, o con todas cumplidas, DEBE seguir.

### BR-EMP-038 — Las jornadas completas arrancan de nuevo

CUANDO cierra la jornada 3 y la partida sigue, el sistema DEBE reiniciar el legajo antes de abrir
la jornada 4: en **0**, o en **1** apercibimiento —2 medios— si la prueba sumó 5 o más. El
sistema DEBE conservar cuántos apercibimientos sumó la prueba y si la jornada 3 cerró con todas
sus obligatorias cumplidas. Desde la jornada 4 DEBE sumar por bandas y llamados y despedir con
4 apercibimientos (BR-EMP-002, BR-EMP-003, BR-EMP-012).

### BR-EMP-039 — La prueba cruza la sesión

Los apercibimientos de la prueba son medios del legajo y DEBEN conservarse como BR-EMP-008. El
sistema DEBE conservar también el resultado de BR-EMP-038: los apercibimientos que sumó la
prueba y si la jornada 3 cerró completa. Sin esos datos, o con otro tipo, DEBE restaurar cero y
no completa sin perder una jornada válida.

### BR-EMP-040 — El mensaje 1 de la jornada 2 sale de cómo cerró la 1

CUANDO la noche 1 cierra y abre la jornada 2, que son una sola transición, el sistema DEBE
mostrar como primer mensaje de sus instrucciones y de su chat uno solo de estos cinco, elegido
por la noche 1 que anotó BR-EMP-041. La noche 1 no tiene devolución de cierre: este mensaje es lo
que Enrique dice de ella. Los textos DEBEN ser los de la ficha «Chat con el jefe» revisada el
2026-10-20:

| Clientes mal atendidos | Registrar | Texto |
|---|---|---|
| 0 | cumplida | Muy bien. Veo que pudiste cumplir con tus tareas correctamente, así que te voy a sumar una más. |
| 0 | sin cumplir | Bueno, por lo visto, pudiste atender bien a todos los clientes, pero el registro de ventas no cuadra. Vas a tener que prestar más atención, especialmente ahora que te voy a sumar una tarea más. |
| 1 | cualquiera | Bueno, por lo visto, el registro de ventas cuadra bien, pero me enteré de que un cliente se fue insatisfecho ayer. Voy a ser considerado con vos porque fue tu primer día, pero vas a tener que ponerte las pilas, especialmente ahora que te voy a sumar una tarea más. |
| 2 o más | cumplida | Che, me enteré de que ayer pasaron dos clientes y no atendiste correctamente a ninguno de los dos. O sea, por culpa tuya no tuvimos ingresos en el turno nocturno. Voy a ser considerado con vos porque fue tu primer día, pero vamos a tener problemas si no te ponés las pilas, especialmente ahora que te voy a sumar una tarea más. |
| 2 o más | sin cumplir | El anterior, con «Y encima anotaste en el registro productos que no se vendieron ¿me estás tomando el pelo?» después de «turno nocturno.» |

Cada texto DEBE partir en dos párrafos donde la ficha los parte. Con dos clientes sin venta, la
planilla cuadra sólo con todo en 0: por eso «registrar cumplida» es la fila «dejó todo en 0» de
la ficha. La ficha no tiene fila para un cliente mal atendido con registrar sin cumplir; mientras
siga OQ-EMP-010, manda la atención. Sin la noche 1 anotada, la jornada 2 NO DEBE mostrar ningún
mensaje 1. Las demás jornadas NO DEBEN cambiar sus mensajes por esta regla.

### BR-EMP-042 — El mensaje 1 de la jornada 3 sale de cómo cerró la 2

CUANDO la noche 2 cierra y abre la jornada 3, el sistema DEBE mostrar como primer mensaje de sus
instrucciones y de su chat uno solo de estos ocho, elegido por la noche 2 que anotó BR-EMP-041.
La ficha no precisa cómo cuentan los clientes que esperan al cerrar ni cómo evaluar la reposición.
Como decisión provisoria, la atención está bien con cero clientes mal atendidos según BR-EMP-041.
El registro y la reposición están bien si registrar y reponer quedaron cumplidas.
Los textos DEBEN ser los de la ficha «Chat con el jefe»
revisada el 2026-10-20:

| Atención | Registro | Reposición | Texto |
|---|---|---|---|
| bien | bien | bien | Excelente. Puedo ver que no tuviste problemas para completar los quehaceres de la jornada. Venís muy bien, pibe. |
| bien | bien | mal | Mmmmmm. Me parece que la reposición anduvo medio floja. / Tampoco es que hay tantos estantes, ¿no? ¿Qué tal si hoy te pegás una vueltita extra a ver si esta vez conseguís ver los espacios vacíos? |
| bien | mal | bien | Mmmmmm. Me parece que el registro de ventas está mal hecho. / Tampoco es que se venden taaaantos productos ¿no? ¿Qué tal si hoy anotás bien en el cuadrito lo que vendés y nos quedamos todos contentos? |
| bien | mal | mal | Mmmmmm. Me parece que la reposición anduvo medio floja. Tampoco es que hay tantos estantes, ¿no? ¿Qué tal si hoy te pegás una vueltita extra a ver si esta vez conseguís ver los espacios vacíos? / Y además, el registro de ventas está mal. Te voy a dar una última oportunidad. Espero que me sorprendas. |
| mal | bien | bien | Che, estuvo floja la atención al cliente. No te olvides de que eso es LO MÁS IMPORTANTE. / Te voy a dar una última oportunidad. Espero que me sorprendas. |
| mal | mal | bien | Che, estuvo floja la atención al cliente. No te olvides de que eso es LO MÁS IMPORTANTE. Además, quedó mal el registro de ventas. / Te voy a dar una última oportunidad. Espero que me sorprendas. |
| mal | bien | mal | Che, estuvo floja la atención al cliente. No te olvides de que eso es LO MÁS IMPORTANTE. Además, no repusiste todos los productos en góndolas. / Te voy a dar una última oportunidad. Espero que me sorprendas. |
| mal | mal | mal | Che, no hiciste ni una cosa bien. ¿Sos o te hacés? / Te voy a dar una última oportunidad. Más te vale que me sorprendas. |

La barra marca dónde la ficha parte el texto en dos párrafos, y el texto DEBE partir ahí. Sin la
noche 2 anotada, la jornada 3 NO DEBE mostrar ningún mensaje 1. El mensaje 2 de la jornada 3 y
las demás jornadas NO DEBEN cambiar por esta regla.

### BR-EMP-041 — La partida recuerda cada noche de prueba

CUANDO se anota una noche anterior a la primera jornada completa (BR-EMP-025), el sistema DEBE
recordar cuántos clientes quedaron mal atendidos y qué obligatorias fijas quedaron sin cumplir
al cerrar. Un cliente mal atendido es el que llegó a la ventanilla, no recibió su venta y se fue.
El que todavía espera al cerrar, o el que nunca llegó, NO DEBE contar. Las noches desde la
primera jornada completa NO DEBEN anotarse acá. Ese dato DEBE cruzar la sesión (BR-SAV-019): al
retomar, los mensajes de BR-EMP-040, BR-EMP-042 y BR-EMP-043 DEBEN ser los mismos. Un cierre
ignorado NO DEBE anotar nada.

### BR-EMP-043 — El mensaje 1 de la jornada 4 sale de las tres noches de prueba

CUANDO la noche 3 cierra, que es la misma transición que abre la jornada 4, Enrique DEBE decir
uno solo de estos cuatro mensajes, elegido por las tres noches que anotó BR-EMP-041, como primer mensaje de las instrucciones de la jornada 4 y de su
chat. La cuenta y
el umbral son los de la ficha «Ciclo de jornadas y sistema de puntos». Cada noche suma una falla
por cada cliente mal atendido, por registrar y por reponer sin cumplir, y por limpiar sin cumplir
en la jornada 3. Los llamados NO DEBEN sumar. «Menos de la mitad de las tareas» de la ficha «Chat
con el jefe» son **5 fallas o más** entre las tres noches. La jornada 3 está «cumplida» si su
noche no tiene fallas. Los textos DEBEN ser los de la ficha «Chat con el jefe» revisada el
2026-10-21:

| Prueba | Texto |
|---|---|
| despedida por BR-EMP-037 | No, no, no. Flaco, no te puedo tomar como empleado si trabajás a medias. Un par de errores los puedo dejar pasar, pero si se repite todos los días... / Hasta acá llegó mi paciencia. Suerte consiguiendo otro trabajo. |
| sin fallas en las tres noches | Muy bien, pibe. Me parece que ya estás capacitado para el trabajo completo. Pero no relajes, ¿eh? Te voy a seguir supervisando para que no bajes el nivel. / A partir de ahora, nada de irse temprano. Te quedás hasta las 8 sí o sí. |
| 5 fallas o más y la jornada 3 cumplida | Mirá, flaco, en tus primeras dos jornadas estuviste mal, pero ayer lograste redimirte. Contra mis instintos, te voy a tomar como capacitado para el trabajo completo. Pero no me hagas arrepentirme, ¿ok? Te voy a seguir supervisando para que subas el nivel. / A partir de ahora, nada de irse temprano. Te quedás hasta las 8 sí o sí. |
| cualquier otra | Bueno, pibe. Concluidos tus tres primeros días de prueba, debo decir que tuviste algunos altibajos. De todas formas, me parece que ya estás capacitado para el trabajo completo. Pero no relajes, ¿eh? Te voy a seguir supervisando para que subas el nivel. / A partir de ahora, nada de irse temprano. Te quedás hasta las 8 sí o sí. |

La barra marca dónde la ficha parte el texto en dos párrafos, y el texto DEBE partir ahí. El
despido lo decide el legajo (BR-EMP-037), no esta tabla: con la prueba perdida, su texto DEBE
ser el único mensaje de la devolución de esa noche, que ofrece volver al menú, y NO DEBE seguir
ningún otro mensaje ni abrirse la jornada 4. En las otras tres filas, el texto DEBE ser la
primera pantalla de las instrucciones de la jornada 4 y el primer mensaje de la jornada 4 en el
chat de Enrique, antes de su mensaje 2. Sin la noche 3
anotada, la jornada 4 NO DEBE mostrar ningún mensaje 1. Con menos de 5 fallas, la jornada 3
cumplida y fallas en la 1 o la 2, la ficha no tiene fila: la de «cualquier otra» es provisoria
(OQ-EMP-011).

## Criterios de aceptación

### AC-EMP-001 — Los tres cortes *(verifica BR-EMP-001)*

DADO 5 obligatorias CUANDO se cumplieron 5 ENTONCES la banda es `NINGUNA`; con 4 y con 3 es
`AVISO`; con 2, con 1 y con 0 es `GRAVE`.

### AC-EMP-002 — El corte no se reescala *(verifica BR-EMP-001)*

DADO 6 obligatorias CUANDO se cumplieron 3 ENTONCES la banda sigue siendo `AVISO`.

### AC-EMP-003 — Los dos pesos *(verifica BR-EMP-002)*

DADO un legajo limpio en la jornada 4 CUANDO cierra una noche de `AVISO` ENTONCES lleva 1
apercibimiento; DADO un legajo limpio en la jornada 4 CUANDO cierra una de `GRAVE` ENTONCES lleva 2.

### AC-EMP-004 — Dos noches graves despiden *(verifica BR-EMP-002, BR-EMP-003)*

DADO un legajo limpio en la jornada 4 CUANDO cierran dos noches de `GRAVE` seguidas ENTONCES está
despedido.

### AC-EMP-005 — Una noche impecable conserva la deuda *(verifica BR-EMP-002, BR-EMP-003)*

DADO un legajo con 3 apercibimientos en la jornada 4 CUANDO cierra una noche con todas cumplidas
ENTONCES el legajo sigue con 3 y no está despedido. CUANDO cierra después una noche de `AVISO` ENTONCES
lleva 4 y está despedido.

### AC-EMP-006 — El umbral se pasa sin pisarlo *(verifica BR-EMP-003)*

DADO un legajo con 3 apercibimientos en la jornada 4 CUANDO cierra una noche de `GRAVE` ENTONCES
lleva 5 y está despedido.

### AC-EMP-007 — Los tres caminos al despido *(verifica BR-EMP-002, BR-EMP-003)*

DADO un legajo limpio en la jornada 4 ENTONCES despiden dos noches graves, una grave más dos
avisos, y cuatro avisos; y ninguna combinación más corta.

### AC-EMP-008 — La octava cierra el contrato *(verifica BR-EMP-004)*

DADO una partida en la jornada 8 CUANDO cierra con todas cumplidas ENTONCES el final es contrato
cumplido, y la jornada no avanza a 9. DADO la jornada 5 CUANDO cierra con todas cumplidas
ENTONCES la partida sigue en curso y la jornada avanza a 6.

### AC-EMP-009 — Despedido gana sobre cumplido *(verifica BR-EMP-005)*

DADO la jornada 8 con 3 apercibimientos CUANDO cierra con menos de 3 cumplidas ENTONCES el final
es despedido y no contrato cumplido.

### AC-EMP-010 — La partida terminada no abre *(verifica BR-EMP-006)*

DADO una partida despedida CUANDO se pide abrir otra jornada ENTONCES no se abre ninguna y el
legajo no cambia.

### AC-EMP-011 — El segundo cierre no anota *(verifica BR-EMP-007)*

DADO una jornada ya cerrada CUANDO se la cierra otra vez ENTONCES los apercibimientos no se
mueven y la jornada no avanza.

### AC-EMP-012 — El legajo restaurado despide *(verifica BR-EMP-008)*

DADO una partida que arranca la jornada 4 con un legajo de 3 apercibimientos CUANDO cierra una
noche de `AVISO` ENTONCES está despedida.

### AC-EMP-016 — La partida terminada no ofrece continuar *(verifica BR-EMP-011)*

DADO una partida que termina al cerrar la noche, despedido o contrato cumplido, CUANDO se arma
la devolución ENTONCES ofrece una sola opción, volver al menú, y no ofrece continuar. DADO la
partida en curso CUANDO se arma la devolución ENTONCES ofrece una sola opción, continuar, y no
ofrece volver al menú.

### AC-EMP-017 — La banda y los motivos se suman *(verifica BR-EMP-002, BR-EMP-012)*

DADO un legajo limpio en la jornada 4 CUANDO cierra impecable con un motivo ENTONCES lleva 1 medio; con dos
motivos distintos, 2; con GRAVE y dos motivos, 6. Repetir el mismo motivo conserva una sola suma.

### AC-EMP-018 — Los motivos pertenecen sólo a la noche abierta *(verifica BR-EMP-006, BR-EMP-007, BR-EMP-012)*

DADO un motivo anotado antes de abrir, durante una jornada ya cerrada o después del final
CUANDO se consulta o abre otra noche ENTONCES no suma deuda. DADO una noche con un motivo
CUANDO se abre la siguiente y cierra sin motivos ENTONCES conserva sólo la deuda anterior.

### AC-EMP-019 — Siete y ocho medios *(verifica BR-EMP-003, BR-EMP-012)*

DADO 6 medios en la jornada 4 CUANDO cierra impecable con un motivo ENTONCES lleva 7 y no está
despedido. DADO 7 medios en la jornada 4 CUANDO cierra impecable con un motivo ENTONCES lleva 8 y está despedido.

### AC-EMP-020 — El guardado conserva el medio *(verifica BR-EMP-008)*

DADO 7 medios CUANDO se guarda, se lee el archivo y se reanuda ENTONCES conserva el entero 7;
una noche impecable sin motivos sigue con 7. DADO el dato ausente, antiguo o con valor 7,0
CUANDO se reanuda ENTONCES restaura 0 medios y conserva una jornada válida. Si también hay un
dato antiguo, el entero 7 de medios sigue prevaleciendo.

### AC-EMP-022 — La octava impecable admite siete medios *(verifica BR-EMP-004, BR-EMP-005, BR-EMP-008)*

DADO la octava jornada con 7 medios CUANDO cierra impecable sin motivos ENTONCES conserva 7
y termina con contrato cumplido. DADO un motivo adicional ENTONCES llega a 8 y termina despedido.

### AC-EMP-045 — Seis pantallas, una pantalla, atrás y OK *(verifica BR-EMP-023)*

DADO las instrucciones de la jornada 1 recién abiertas CUANDO se consulta su estado ENTONCES se
muestra sólo la primera pantalla, el contador dice «1/6» y «Volver» está visible y
deshabilitado; intentar volver conserva 1. CUANDO se avanza cinco veces ENTONCES se muestra sólo
la pantalla 6/6 y el botón dice «OK». CUANDO se vuelve ENTONCES se muestra 5/6 y dice
«Siguiente». CUANDO se llega a 6 y se elige «OK» dos veces ENTONCES las instrucciones terminan y
se pide una sola entrada a la noche 1. Avanzar 3 y volver 3 desde el inicio recupera sólo la
primera pantalla. DADO las de la jornada 2 ENTONCES el contador dice «1/2». CUANDO en la 2 se
llega a 2/2 y se elige «OK» dos veces ENTONCES se pide una sola entrada a la noche 2. DADO las de
la jornada 3 ENTONCES el contador dice «1/1», «Volver» está deshabilitado y el botón dice «OK».
CUANDO se elige «OK» dos veces ENTONCES se pide una sola entrada a la noche 3. DADO las de la
jornada 4 con la noche 3 anotada ENTONCES el contador dice «1/4»; sin ella dice «1/3». CUANDO en
la 4 se llega a 4/4 y se elige «OK» dos veces ENTONCES se pide una sola entrada a la noche 4.
DADO instrucciones
de una sola pantalla ENTONCES la primera es la última: «Volver» está deshabilitado y el botón
dice «OK». Los controles no se mueven al cambiar de pantalla y no existe desplazamiento
del contenido.

### AC-EMP-046 — Las entradas de cada jornada forman sus pantallas *(verifica BR-EMP-022, BR-EMP-023)*

DADO los textos de la ficha revisada, sus énfasis y las nueve fotos CUANDO se agrupan las
entradas de cada jornada ENTONCES la jornada 1 tiene 11 entradas y 6 pantallas, la 2 tiene 4 y
2, la 3 tiene 2 y 1, y la 4 tiene 4 y 3. Las jornadas 5 a 8 no tienen entradas ni pantallas. En la jornada 1, las pantallas 2, 3, 4 y 6 muestran la foto de su Intro
después del texto y la 5 es Intro 5 sin foto. La primera pantalla de la jornada 2 muestra las
fotos de Intro 7, la de la 3 la de Intro 9, y la segunda de la 4 muestra la foto del depósito
después del texto de Intro 11. Intro 2 muestra primero el reloj y después el
corcho; Intro 7 muestra primero las góndolas y después la estantería. Cada par va después del
texto, lado a lado, con igual alto, dentro de los 1007 px y cubriendo sus marcos sin franjas
negras. Las pantallas de una foto conservan su presentación. El chat de la jornada 4 recibe
Intro 10, la foto de Intro 11, Intro 11 e Intro 12, en ese orden.
CUANDO se avanza y vuelve por todas ENTONCES sólo se muestra el contenido de la actual,
el contador coincide y la secuencia original de 21 entradas sigue intacta. El retrato y
bocadillo se mantienen visibles en todas las pantallas. La pantalla de Intro 4 incluye interfaz
de caja y ticket.
Los tres mensajes de prueba previos no aparecen entre los textos de la conversación.

### AC-EMP-047 — Cada foto adjunta su propia Intro *(verifica BR-EMP-022, BR-EMP-023)*

DADO el chat de Enrique en la jornada 4 CUANDO se recorren sus nueve fotos ENTONCES cada grupo
precede inmediatamente al texto de su Intro y ampliar cualquiera muestra ese texto, aunque la
entrada siguiente sea otra foto, nunca el siguiente
paso. CUANDO se valida cada captura ENTONCES existe una imagen con proporción adecuada a su
marco y el rayo central de su encuadre alcanza el tema correspondiente: reloj, corcho con sus dos
notas, ventanilla, lector y caja, computadora,
góndolas, estantería con cajas, útiles y notas del cuartito, y cajas del depósito en el piso.
Las dos capturas nuevas no alteran el reparto ni crean huecos para encuadrar.
Preparar la foto de Intro 7 y después la de Intro 11 deja restaurada la disposición jugable
de la jornada 1. Las cajas en el piso de Intro 11 corresponden a la jornada 4.

### AC-EMP-048 — Leer retiene y comenzar anuncia *(verifica BR-EMP-022, BR-EMP-024)*

DADO una partida nueva preparada CUANDO empiezan las instrucciones ENTONCES la persiana está
baja, se ve Intro 1, «Volver» está deshabilitado y el control está suspendido. CUANDO pasan 120 segundos
reales leyendo ENTONCES queda el mismo presupuesto de turno. CUANDO se llega a 6 y se elige
«OK» ENTONCES las instrucciones salen por la izquierda y, al terminar, aparece «NOCHE 1» sobre la persiana, con
el turno y el control todavía retenidos hasta que termine de subir.

### AC-EMP-049 — Pausar conserva la lectura *(verifica BR-EMP-024)*

DADO las instrucciones en la pantalla 4 CUANDO se pulsa Esc, pasan cuadros y se reanuda
ENTONCES sigue la pantalla 4 y el mismo presupuesto de turno. DADO las instrucciones
en pantalla ENTONCES su orden de dibujo está sobre la persiana y debajo de avisos y pausa;
la interfaz empieza completamente fuera del margen derecho y termina en su lugar en 0,3 segundos
reales con ease out: en intervalos iguales recorre cada vez menos distancia. CUANDO se elige
«OK» ENTONCES sale completamente por el margen izquierdo con ease in: en intervalos iguales
recorre cada vez más distancia. Hasta completar la salida NO aparecen la placa «NOCHE N» ni
la subida de persiana. Repetir «OK» durante la salida anuncia una sola noche.
El fondo de persiana conserva su posición y su fade in de negro a visible en 0,3 segundos reales.
Un cuadro de 150 ms adelanta cada animación sólo 1/30 de segundo.
DADO la entrada o la salida a mitad de recorrido CUANDO se pausa durante 120 segundos y se
reanuda ENTONCES el marco conserva su posición durante la pausa y continúa sin saltar al final.
DADO las instrucciones de la jornada 2 en su pantalla 2 CUANDO se pulsa Esc y se reanuda
ENTONCES sigue la pantalla 2. DADO una jornada 1 a 4 retomada desde el menú CUANDO se muestran
sus instrucciones ENTONCES repiten la entrada desde la derecha y conservan el mismo layout.

### AC-EMP-050 — Todas depende de lo declarado *(verifica BR-EMP-001)*

DADO la jornada 3 con sus cuatro obligatorias declaradas CUANDO cierra con las cuatro cumplidas
ENTONCES la banda es NINGUNA; con tres es AVISO y con dos es GRAVE. El corte conserva las reglas
de las bandas y no inventa una quinta tarea para decidir el cierre.

### AC-EMP-051 — La noche 4 impecable *(verifica BR-EMP-009, BR-EMP-026, BR-EMP-029)*

DADO la noche 4 con todas las obligatorias cumplidas y sin llamados CUANDO se arma la devolución
ENTONCES tiene exactamente dos mensajes: «Buen día!» y «Seguiste todas mis instrucciones al pie
de la letra. Excelente. Seguí así.», sin espacio final.

### AC-EMP-052 — La segunda falla de reponer *(verifica BR-EMP-025, BR-EMP-027)*

DADO la noche 4 con reponer sin cumplir CUANDO se arma la devolución ENTONCES trae la fila
n = 1 de Tarea 3, «Faltó reponer algunas unidades…». DADO la noche 5 con reponer otra vez sin
cumplir CUANDO se arma la devolución ENTONCES trae la fila n = 2, «No podés dejarle a tu
compañera…», y ninguna otra Tarea si las otras obligatorias se cumplieron. DADO la noche 6 con
reponer cumplido ENTONCES Tarea 3 no aparece. DADO la tercera falla de registrar ENTONCES el
texto dice «está mal otra vez».

### AC-EMP-053 — El Reto 2 de la jornada 5 cuenta para después *(verifica BR-EMP-025, BR-EMP-027, BR-EMP-028)*

DADO la jornada 5 con el llamado por objetos importantes en la basura CUANDO se arma la
devolución ENTONCES trae la fila J = 5 de Reto 2, «Por si no lo sabías, la "basura"…». DADO
después la jornada 7 con el mismo llamado ENTONCES trae la fila n = 2, «El contenedor de basura
es para BASURA solamente.». DADO la jornada 4 con el primer llamado de ese motivo ENTONCES trae
«Puede ser que hayas estado tirando cosas a la basura?». DADO la jornada 5 con la basura sin
sacar ENTONCES Tarea 5 es «De verdad era tan difícil tirar tres bolsas de basura?».

### AC-EMP-054 — El Reto 2 de la jornada 6 *(verifica BR-EMP-027, BR-EMP-028)*

DADO la jornada 6 con el llamado por objetos importantes en la basura, sin una particular
declarada CUANDO se arma la devolución ENTONCES trae «Cuando te pedí que tiraras algunos
productos, no me refería a objetos útiles y en buen estado!», sea el primer llamado o el
segundo, y no trae Tarea 5.

### AC-EMP-055 — P = 4 en la octava despide *(verifica BR-EMP-005, BR-EMP-026, BR-EMP-029)*

DADO la jornada 8 que cierra con P = 4 CUANDO se arma la devolución ENTONCES el Saludo es «Che»,
el Cierre es el del despido, «Es absurdo que tenga que estar persiguiéndote…», y ningún mensaje
es un Cierre de J = 8. Con P = 3,5 en la jornada 8 el Saludo es «Buenos días...» y el Cierre
«Me parece que quedan muchas cosas para pulir…».

### AC-EMP-056 — P = 2 con y sin llamados en la partida *(verifica BR-EMP-025, BR-EMP-029)*

DADO J = 5, P = 2 y R = 0 sin ningún llamado en la partida CUANDO se arma la devolución ENTONCES
el Cierre es «Acordate de chequear que todas las tareas estén cerradas antes de irte, dale?».
DADO J = 5, P = 2 y R = 0 con llamados en la jornada 4 y ninguno en la 5 ENTONCES el Cierre es
«Acordate de hacer bien tu trabajo y respetar las normas básicas de convivencia, dale?». Ninguno
de los dos termina en espacio.

### AC-EMP-057 — La mejora gana sobre la advertencia *(verifica BR-EMP-029)*

DADO J = 5, P = 1 y R = 1 CUANDO se arma la devolución ENTONCES el Cierre es «Ahora sí le vas
agarrando la mano! Muy bien. Seguí así.». DADO J = 6, P = 1 y R = 2 ENTONCES es «Sin nada para
comentar. Adelante con eso.». DADO J = 5, P = 0,5 y R = 1 ENTONCES es «Ahora sí le vas
agarrando la mano!…». DADO P = 2 y R = 1 ENTONCES es «Esta vez sí cumpliste con todo. Bien.
Continuá por este camino.»; con R = 2, «Sin comentarios.». DADO J = 4 y P = 1 con R = 0 ENTONCES
es «Que no se repita, ok?»; con J = 5, P = 1,5 y R = 0, «No duermas con tus responsabilidades…», con
un solo «tus».

### AC-EMP-058 — Los cuatro bordes de la octava *(verifica BR-EMP-029)*

DADO la jornada 8 terminada con contrato cumplido CUANDO se arma la devolución ENTONCES con
P = 1 el Cierre es «Bueno, más allá de alguna que otra cosita…»; con P = 1,5 y con P = 2 es
«Mirá, hubo un par de veces que la pifiaste, pero como soy generoso, te voy a dar el puesto
igual. No aflojes. Desde ahora, espero que des lo mejor de vos.»; con P = 2,5 es «Honestamente,
solo puedo concluir…». Con R = 1 en la jornada 8 y P = 2, el Cierre sigue siendo el de P = 2 y
no «Esta vez sí cumpliste…». Hay un solo Cierre por devolución.

### AC-EMP-059 — Las cuentas *(verifica BR-EMP-006, BR-EMP-007, BR-EMP-025)*

DADO una partida nueva ENTONCES tiene cero fallas, cero llamados, R = 0 y ningún llamado en la
partida. DADO la noche 4 con reponer y limpiar sin cumplir, la particular sin cumplir y el
llamado por papel anotado dos veces CUANDO cierra ENTONCES reponer y limpiar tienen 1 falla,
atender y registrar 0, papel 1 llamado, hubo llamados y R = 0. CUANDO la noche 5 cierra
impecable sin llamados ENTONCES R = 1 y las fallas no cambian; la noche 6 igual, R = 2; la noche
7 con un llamado, R = 0. DADO una obligatoria cumplida y después descumplida antes del cierre
ENTONCES suma una falla. DADO un segundo cierre de la misma noche ENTONCES nada cambia. DADO la
noche 1 con un cliente mal atendido y registrar sin cumplir, la 2 sólo con reponer sin cumplir y
la 3 sólo con limpiar sin cumplir, con los cuatro llamados anotados cada noche, CUANDO abre la
jornada 4 ENTONCES la prueba acumuló 4 apercibimientos y las cuentas de la devolución siguen en
cero fallas, cero llamados, R = 0 y ningún llamado en la partida. La primera falla de atender
en la jornada 4 trae la fila n = 1 de Tarea 1. DADO los mismos llamados de la prueba CUANDO se
repiten en la jornada 4 ENTONCES cada motivo cuenta una vez y trae la primera fila de su Reto.

### AC-EMP-060 — Ningún número, y siempre Saludo y Cierre *(verifica BR-EMP-009, BR-EMP-026, BR-EMP-027, BR-EMP-028, BR-EMP-029)*

DADO cada J de 4 a 8, cada P de 0 a 4 de a medio, cada R de 0 a 7, con y sin llamados en la
partida, y cada combinación de fallas con n de 1 a 4 y llamados con n de 1 a 8 CUANDO se arma
la devolución ENTONCES el primer mensaje es un Saludo y el último un Cierre, hay uno de cada uno,
las Tareas y los Retos van en el orden de BR-EMP-009, y ningún mensaje contiene un dígito, un
espacio final ni las palabras «punto», «medio» o «apercibimiento».

### AC-EMP-061 — El despido en la primera noche completa *(verifica BR-EMP-009, BR-EMP-026, BR-EMP-027, BR-EMP-028, BR-EMP-029)*

DADO la noche 4 con P = 3,5 y todas las obligatorias cumplidas CUANDO cierra con el llamado por
papel ENTONCES P = 4 y la devolución es, en orden: «Che», la fila n = 1 de Reto 1 y el Cierre del
despido. DADO P = 4 con atender y reponer sin cumplir y los cuatro llamados, cada uno por primera
vez, ENTONCES la devolución es, en orden: «Che», la fila n = 1 de Tarea 1 y de Tarea 3, la fila
n = 1 de Reto 1, Reto 2, Reto 3 y Reto 4, y el Cierre del despido: ocho mensajes, sin Tarea 2 ni
Tarea 4 ni Tarea 5, y la
única opción es volver al menú.

### AC-EMP-062 — Un mensaje más por segundo *(verifica BR-EMP-011, BR-EMP-030)*

DADO 4 mensajes CUANDO pasaron 0 s, 0,99 s, 1 s, 3 s y 10 s ENTONCES se ven 1, 1, 2, 4 y 4. Con 3
a la vista no hay opción; con 4, la opción está debajo del último.

DADO el celular todavía subiendo CUANDO pasan 5 segundos sin llegar al centro ENTONCES sigue
sólo el primer mensaje. DADO el celular centrado y un mensaje visible CUANDO el cuadro
siguiente llega 5 segundos tarde ENTONCES se ven sólo 2 mensajes; a los 0,99 segundos de esa
entrega siguen 2, y al segundo aparece el tercero.

### AC-EMP-063 — El celular de la devolución no se cierra *(verifica BR-EMP-030)*

DADO la devolución en pantalla con 2 de 4 mensajes a la vista CUANDO se pulsa Q ENTONCES el
celular sigue en el centro, en el chat de Enrique. CUANDO se desplaza el chat hacia arriba y
pasan 2 segundos ENTONCES hay 4 mensajes de la devolución, cada uno una vez y en orden. CUANDO se
pulsa una foto de las instrucciones ENTONCES se amplía, y un clic la cierra en el mismo chat.
DADO 2 mensajes a la vista CUANDO se pausa, pasan 3 segundos y se reanuda ENTONCES siguen 2, y
un segundo después 3.

### AC-EMP-064 — Del cierre a la noche 5, por el celular *(verifica BR-EMP-011, BR-EMP-030, BR-EMP-031)*

DADO el almacén en la noche 4 CUANDO cierra el turno ENTONCES la persiana está baja, el celular
está en el centro con la devolución en el chat de Enrique y el turno sigue cerrado. CUANDO está
el último mensaje a la vista y se elige «continuar» ENTONCES el celular pasa a las notas, sin
bajar; tras los tres «Continuar» de la reflexión, baja y la persiana muestra «NOCHE 5».
CUANDO la noche 5 está abierta y se abre el celular con Q ENTONCES el chat de
Enrique tiene los mensajes de las jornadas 1 a 4 intercalados con las devoluciones 1 a 4, y
después la foto y el texto de apertura 5 definidos por `investigation`. DADO el almacén en la
noche 1 CUANDO cierra el turno y se elige «continuar» ENTONCES el celular baja sin pasar por las
notas, salen las instrucciones de la jornada 2 sobre la persiana y, tras su «OK», la persiana
muestra «NOCHE 2». DADO una partida despedida
CUANDO se elige «volver al menú» ENTONCES se pide el menú una vez y no se anuncia otra noche.

### AC-EMP-065 — Elegir dos veces *(verifica BR-EMP-011)*

DADO la devolución de la noche 4 con la opción a la vista CUANDO se elige «continuar» dos veces
ENTONCES empieza una sola reflexión y no se anuncia ninguna noche; terminada la reflexión, se
anuncia una sola «NOCHE 5» y la jornada es 5. DADO una partida terminada CUANDO se
elige «volver al menú» dos veces ENTONCES el menú se pide una sola vez.

### AC-EMP-066 — Las devoluciones conservan su lugar entre aperturas *(verifica BR-EMP-031)*

DADO una partida nueva ENTONCES no tiene devoluciones. CUANDO cierran las noches 1 a 5
ENTONCES los mensajes de devolución conservan su orden de recepción. CUANDO se abre el chat
en noche 6 ENTONCES muestra las instrucciones de la 1, la devolución 1, las de la 2, la
devolución 2, las de la 3, la devolución 3, los mensajes de la 4, la devolución 4, la foto y el
texto de apertura 5 y la devolución 5, en ese orden; no adelanta la apertura 5 a la devolución 4.

### AC-EMP-067 — Registrar uso una vez y sólo al aceptar *(verifica BR-EMP-032)*

DADO jornada 5 abierta sin uso de Poético CUANDO se rechaza por balde vacío o ya teñido ENTONCES
el hecho sigue falso. CUANDO se acepta un teñido real con Poético ENTONCES registra éxito y la
consulta queda verdadera; aceptar otra mezcla contesta ya registrado y conserva un solo hecho.
El registro no agrega mensajes ni cambia la deuda laboral.

### AC-EMP-068 — La devolución recibe el hecho de su noche *(verifica BR-EMP-032)*

DADO uso aceptado en jornada 5 CUANDO se evalúa su devolución ENTONCES la consulta de esa jornada
es verdadera. CUANDO abre la 6 ENTONCES no registra uso de Poético en esa noche. Un evento antes
de abrir, después del cierre, durante pausa o examen, o en jornadas 1 a 4 y 6 a 8 no crea el
hecho.

### AC-EMP-069 — Dos aperturas comparten un expediente, dos partidas no *(verifica BR-EMP-033)*

DADO una partida con 2B y después 2A, y sus cuatro mensajes de foto/texto CUANDO abre otra jornada
y dos consumidores consultan ENTONCES reciben el mismo expediente con orden 2B/2A y los mismos
cuatro mensajes. Crear otra partida deja cero pistas y cero mensajes. Un consumidor sin
expediente recibido no anota ni emite ni crea un expediente independiente.

### AC-EMP-070 — La devolución lleva la noche cerrada y el orden *(verifica BR-EMP-031, BR-EMP-007)*

DADO una devolución de tres mensajes al cerrar noche 2 CUANDO se consultan sus datos
ENTONCES los tres identifican jornada 2, conservan tres identidades distintas y el orden
Saludo, cuerpo, Cierre de la selección vigente, aunque la partida ya prepare jornada 3.
DADO un texto repetido en otra jornada ENTONCES conserva otra identidad y no se fusiona.
Repetir cierre 2 o elegir continuar dos veces no agrega mensajes ni cambia sus metadatos.
Una partida nueva sigue sin devoluciones.

### AC-EMP-071 — Poético justo debajo del despido y en el despido *(verifica BR-EMP-034, BR-EMP-009)*

DADO jornada 5 con uso aceptado de Poético, limpiar cumplido y P = 3,5 después de anotar la noche
CUANDO se arma la devolución ENTONCES contiene una sola vez «Che, si usás un producto del local
para la limpieza, me tenés que avisar. No podés hacer esas cosas sin consultarme. Espero que
quede claro.», sin Tarea 4. DADO lo mismo con P = 4 ENTONCES contiene una sola vez «Si usás un
producto del local para la limpieza, me tenés que avisar. No podés hacer esas cosas sin
consultarme.» y el Cierre del despido. DADO limpiar y Tarea 5 sin cumplir, con el uso aceptado,
ENTONCES el orden es Tarea 4, advertencia y Tarea 5, cada una una vez. DADO jornada 5 con sólo
teñidos rechazados, o un teñido aceptado en jornada 6, ENTONCES no hay advertencia. Los medios,
la banda y el final son los mismos con y sin el hecho.

### AC-EMP-072 — Dos o tres declaradas no admiten aviso *(verifica BR-EMP-001, BR-EMP-003)*

DADO la jornada 1 con sus dos obligatorias declaradas CUANDO cierra con las dos cumplidas
ENTONCES la banda es NINGUNA; con una y con cero es GRAVE. DADO la jornada 2 con sus tres
obligatorias declaradas CUANDO cierra con las tres cumplidas ENTONCES la banda es NINGUNA;
con dos, con una y con cero es GRAVE.

### AC-EMP-073 — El impecable de las noches del medio *(verifica BR-EMP-029)*

DADO P = 0 CUANDO se arma la devolución de J = 4, 5, 6 y 7 ENTONCES el Cierre es la fila de esa
jornada, sin espacio final: en J = 4, «Seguiste todas mis instrucciones al pie de la letra.
Excelente. Seguí así.»; en J = 5, «Nuevamente, todo en orden. Seguí así!»; en J = 6, «Sin comentarios
por mi parte. Dale para adelante.»; en J = 7, «La jornada cerró cuadrada, como de costumbre.
Excelente trabajo.». DADO P = 0 en J = 8 ENTONCES es «La verdad es que estoy impresionado. No
hizo falta corregirte ni una sola cosa en las cinco noches. Un trabajo excepcional. Va a ser
un placer tenerte trabajando acá.».

### AC-EMP-092 — Las jornadas de introducción cierran sin devolución *(verifica BR-EMP-009)*

DADO la jornada 1, 2 o 3 que cierra CUANDO se arma la devolución ENTONCES no tiene ningún
mensaje, la partida no guarda ninguno de Enrique para esa noche, y la opción ofrecida sigue
siendo la de BR-EMP-011. DADO la jornada 4 que cierra ENTONCES sí tiene mensajes.

### AC-EMP-074 — Los Retos más allá de la ficha *(verifica BR-EMP-028)*

DADO el sexto llamado por papel con P < 4 CUANDO se arma la devolución ENTONCES Reto 1 es «Dejá
de tirar papel en el inodoro. Ya no sé cómo pedírtelo.». DADO el sexto llamado por objetos en la
basura en J = 8 ENTONCES Reto 2 es «Una vez más tuve que sacar cosas de la basura. Te parece
gracioso?». DADO el sexto y el octavo llamado por objetos afuera ENTONCES Reto 3 es «A esta
altura del partido, ya estoy considerando tirarte a VOS por la ventanilla.». DADO el sexto llamado
por desorden con P < 4 ENTONCES Reto 4 es «Realmente me sorprende cómo alguien puede tener tan
poca conciencia de lo que es el orden.».

### AC-EMP-075 — Las jornadas 2, 3 y 4 abren con lo suyo *(verifica BR-EMP-022, BR-EMP-024)*

DADO el cierre de la jornada 1 CUANDO se elige «continuar» ENTONCES la persiana está baja, se ve
el mensaje 1 que eligió la noche 1 (BR-EMP-040) en «1/3», el control está suspendido y no hay
placa. CUANDO pasan 120 segundos reales ENTONCES queda el mismo presupuesto de turno. CUANDO se
elige «OK» en «3/3» ENTONCES aparece una
sola «NOCHE 2», con el turno y el control retenidos hasta que termine de subir la persiana.
DADO el cierre de la jornada 2 CUANDO se elige «continuar» ENTONCES se ve el mensaje 1 que eligió
la noche 2 (BR-EMP-042) en «1/2», y el «OK» en «2/2» anuncia una sola «NOCHE 3». DADO el cierre
de la jornada 3 sin perder la prueba CUANDO se elige «continuar» ENTONCES se ve el mensaje 1 que
eligieron las tres noches (BR-EMP-043) en «1/4», y el «OK» en «4/4» anuncia una sola «NOCHE 4».

### AC-EMP-076 — Retomar repite las instrucciones de su jornada *(verifica BR-EMP-022)*

DADO un guardado en la jornada 2 con la noche 1 anotada CUANDO se elige continuar ENTONCES salen
sus instrucciones desde el mensaje 1 de esa noche, en «1/3», y después de su «OK» se anuncia
«NOCHE 2». DADO un guardado en la jornada 3 sin la noche 2 anotada
ENTONCES sale Intro 9 en «1/1». DADO un guardado en la jornada 4 con la noche 3 anotada ENTONCES
salen sus instrucciones desde el mensaje 1 de esa prueba, en «1/4», y después de su «OK» se
anuncia «NOCHE 4». El chat de Enrique tiene ese mensaje 1, Intro 10, la foto de Intro 11,
Intro 11 e Intro 12 después de la devolución 3. DADO un guardado del cierre 4 con la reflexión pendiente CUANDO se retoma y termina
la reflexión ENTONCES se anuncia «NOCHE 5» sin instrucciones.

### AC-EMP-077 — Sin instrucciones propias, la noche directa *(verifica BR-EMP-022)*

DADO el cierre de cada jornada de la 4 a la 7 CUANDO se elige seguir ENTONCES la noche siguiente
se anuncia sin instrucciones en pantalla. DADO un guion sin mensajes de la jornada 2 CUANDO abre
la jornada 2 ENTONCES se anuncia «NOCHE 2» directamente, sin instrucciones y sin error. DADO la
jornada 0 o la 9 CUANDO se piden sus instrucciones ENTONCES no hay ninguna.

### AC-EMP-078 — Cada descuido suma uno *(verifica BR-EMP-035)*

DADO la jornada 2 con sus tres obligatorias declaradas CUANDO cierra con registrar y reponer sin
cumplir y dos clientes mal atendidos ENTONCES el legajo lleva 4 apercibimientos. DADO la jornada 3
con sólo limpiar sin cumplir ENTONCES suma 1. DADO la jornada 2 con atender sin cumplir por un
cliente mal atendido ENTONCES suma 1 y no 2. DADO un cliente que todavía espera o que nunca llegó
ENTONCES no cuenta. DADO una noche de la prueba con todas cumplidas y los cuatro llamados
anotados ENTONCES el legajo no suma ningún medio, no hay banda que pese y no queda ningún
llamado en la partida.

### AC-EMP-079 — Las dos primeras no despiden *(verifica BR-EMP-036)*

DADO un legajo limpio CUANDO las jornadas 1 y 2 cierran con todo sin cumplir y dos clientes mal
atendidos ENTONCES la partida sigue en curso, el legajo lleva más de 4 apercibimientos y se abre la
jornada 3.

### AC-EMP-080 — El cierre de la tercera *(verifica BR-EMP-037)*

DADO 5 apercibimientos al cerrar la jornada 3 con una obligatoria sin cumplir ENTONCES la partida
termina despedida y no se abre la jornada 4. DADO 4 apercibimientos con la jornada 3 incompleta
ENTONCES sigue y se abre la jornada 4. DADO 5 apercibimientos con la jornada 3 completa ENTONCES
sigue y se abre la jornada 4.

### AC-EMP-081 — La jornada 4 arranca de nuevo *(verifica BR-EMP-038)*

DADO la jornada 3 que cierra con 4 apercibimientos ENTONCES al abrir la jornada 4 el legajo está en
0 y la partida recuerda 4 y la jornada 3 incompleta. DADO la jornada 3 que cierra completa con 5
apercibimientos ENTONCES al abrir la jornada 4 el legajo está en 1 apercibimiento, 2 medios, y la
partida recuerda 5 y la jornada 3 completa. DADO una partida despedida al cerrar la jornada 3
ENTONCES recuerda su resultado y no reinicia el legajo.

### AC-EMP-082 — Desde la jornada 4 suman las bandas *(verifica BR-EMP-038, BR-EMP-002, BR-EMP-003, BR-EMP-012)*

DADO la jornada 4 abierta tras una prueba con 4 apercibimientos CUANDO cierra `GRAVE` con un motivo
ENTONCES el legajo lleva 5 medios. CUANDO la jornada 5 cierra `GRAVE` ENTONCES lleva 9 medios y la
partida termina despedida.

### AC-EMP-083 — La prueba sobrevive al guardado *(verifica BR-EMP-039)*

DADO la jornada 2 cerrada con 3 apercibimientos CUANDO se guarda y se retoma ENTONCES la partida
sigue en la jornada 3 con 3 apercibimientos. DADO la jornada 3 cerrada completa con 5
apercibimientos CUANDO se guarda y se retoma ENTONCES la partida está en la jornada 4 con 1
apercibimiento y recuerda 5 y completa. DADO un guardado sin esos dos datos, o con otros tipos,
ENTONCES la partida recuerda 0 y no completa y conserva su jornada.

### AC-EMP-084 — La noche 1 elige el mensaje 1 de la jornada 2 *(verifica BR-EMP-040)*

DADO la noche 1 cerrada con 0, 1 y 2 clientes mal atendidos, cada uno con registrar cumplida y
sin cumplir, CUANDO abre la jornada 2 ENTONCES su primera pantalla es la fila de BR-EMP-040 que
le corresponde, y el resto son Intro 7 e Intro 8. Con 1 mal atendido sale la misma fila con
registrar cumplida y sin cumplir. Ninguna de las seis combinaciones muestra dos mensajes 1. DADO
una partida sin la noche 1 anotada ENTONCES la jornada 2 abre con Intro 7.

### AC-EMP-085 — El chat guarda sólo el mensaje 1 elegido *(verifica BR-EMP-023, BR-EMP-040)*

DADO cada fila de BR-EMP-040 y una noche 2 cerrada CUANDO el chat de Enrique abre la jornada 4
ENTONCES tiene 23 entradas y, de la jornada 2, el mensaje 1 elegido antes de las fotos de Intro 7.
Las entradas de las jornadas 1, 3 y 4 son las mismas en todas las filas. DADO la jornada 1
ENTONCES ningún mensaje 1 de la jornada 2 está a la vista.

### AC-EMP-086 — Las noches de prueba cruzan la sesión *(verifica BR-EMP-041)*

DADO la noche 1 cerrada con 2 clientes mal atendidos y registrar sin cumplir CUANDO se guarda y
se retoma ENTONCES la jornada 2 abre con la misma fila. DADO un guardado sin ese dato, o con un
valor de otro tipo, ENTONCES la jornada 2 abre con Intro 7 y lo demás se restaura. DADO una
noche cerrada desde la primera jornada completa ENTONCES no se anota. DADO un cliente todavía en
la ventanilla al cerrar ENTONCES no cuenta como mal atendido.

### AC-EMP-087 — La noche 2 elige el mensaje 1 de la jornada 3 *(verifica BR-EMP-042)*

DADO la noche 2 cerrada con 0 y con 1 cliente mal atendido, cada uno con las cuatro
combinaciones de registrar y reponer cumplidas o sin cumplir, CUANDO abre la jornada 3 ENTONCES
su primera pantalla es la fila de BR-EMP-042 que le corresponde, y el resto es Intro 9. Ninguna
de las ocho combinaciones muestra dos mensajes 1, y cada fila sale de una sola. DADO una partida
sin la noche 2 anotada ENTONCES la jornada 3 abre con Intro 9.

### AC-EMP-088 — La jornada 3 retomada repite su mensaje 1 *(verifica BR-EMP-041, BR-EMP-042)*

DADO la noche 2 cerrada con 1 cliente mal atendido, registrar cumplida y reponer sin cumplir
CUANDO se guarda y se retoma ENTONCES la jornada 3 abre con la misma fila, en «1/2». DADO el chat
de Enrique en la jornada 4 de esa partida ENTONCES tiene, de la jornada 3, esa fila antes de la
foto de Intro 9 y ningún otro mensaje 1 de la jornada 3.

### AC-EMP-089 — Las tres noches eligen el mensaje 1 de la jornada 4 *(verifica BR-EMP-043)*

DADO las tres noches sin fallas CUANDO abre la jornada 4 ENTONCES su primera pantalla y su chat
la empiezan con la fila «sin fallas» y siguen con su mensaje 2. DADO 4 fallas en la noche 1 y una en la 2, con la 3 sin
fallas, ENTONCES es la fila de la jornada 3 cumplida. DADO 4 fallas en la noche 1 y la 3 sin
fallas ENTONCES es «cualquier otra». DADO una falla en la noche 1 y limpiar sin cumplir en la 3
ENTONCES es «cualquier otra». Ninguna combinación muestra dos mensajes 1. DADO una partida sin
la noche 3 anotada ENTONCES la jornada 4 abre con su mensaje 2.

### AC-EMP-090 — La prueba perdida termina con el mensaje del despido *(verifica BR-EMP-043, BR-EMP-037)*

DADO la noche 3 que cierra con la prueba perdida CUANDO llega la devolución ENTONCES su único
mensaje es la fila del despido, ofrece sólo volver al menú y la partida no abre la jornada 4.
DADO la noche 3 que cierra sin perder la prueba ENTONCES la devolución no trae ese mensaje.

### AC-EMP-091 — La jornada 4 retomada repite su mensaje 1 *(verifica BR-EMP-041, BR-EMP-043)*

DADO la noche 3 cerrada con 5 fallas en la prueba y la 3 sin fallas CUANDO se guarda y se retoma
ENTONCES la jornada 4 abre con la misma fila.

## No objetivos

- Esta capacidad NO cuenta el tiempo de la noche ni cuántas obligatorias hay: las recibe.
- Esta capacidad NO escribe el guardado: entrega el legajo, la jornada, las cuentas y las
  devoluciones a [`save-and-resume`](../save-and-resume/save-and-resume.md).
- Esta capacidad NO dibuja el celular ni el chat: elige los mensajes, su ritmo y la opción, y
  el celular es de [`investigation`](../investigation/investigation.md).
- Esta capacidad NO muestra la reflexión de cierre que sigue a «continuar» en las jornadas 4 y
  5: es de [`investigation`](../investigation/investigation.md).
- Esta capacidad NO trae la Tarea 5 de las jornadas 1 a 3 ni de las 6 a 8: esas noches no
  declaran particular (BR-SHF-005). Los textos de las 6 a 8 esperan en la ficha mientras siga
  abierta OQ-SHF-006.
- Esta capacidad NO redacta mensajes de apertura: `investigation` consume el guion de cada
  contacto, incluida la apertura de la jornada 5. Entrega a ese historial las devoluciones fechadas.

## Contratos

- **Entrada:** cuántas obligatorias se cumplieron y cuántas se habían declarado, y cuáles
  quedaron sin cumplir; cuántos clientes quedaron mal atendidos; un legajo, las cuentas y las devoluciones, que pueden venir de un
  guardado; motivos de la jornada abierta; el tiempo que pasa con la devolución en pantalla;
  mensajes introductorios con su jornada, la jornada que abre y pedidos de avanzar, volver y
  comenzar; el teñido aceptado con
  identidad y el expediente y mensajes de investigación de esta partida.
- **Salida:** la banda, los apercibimientos que sumó la prueba y si su última jornada cerró completa, los medios exactos y los apercibimientos enteros, si está despedido, qué jornada va, el final,
  las fallas por obligatoria fija, los llamados por motivo, R, si hubo llamados en la partida,
  la devolución con lo que el jugador puede elegir, cuántos de sus mensajes están a la vista, y
  las devoluciones recibidas con identidad, jornada cerrada y orden; pantallas introductorias, índice actual,
  permiso de volver y finalización de las instrucciones; el hecho de uso de Poético por
  jornada y el expediente compartido con sus notas.
- **Falla:** cerrar dos veces o abrir sobre una partida terminada no cambian nada y no avisan.
  Elegir dos veces la opción de la devolución no pide nada otra vez.
- **Falla de las instrucciones:** volver desde la primera pantalla conserva esa pantalla; repetir
  comenzar después de terminarlas no pide otra entrada.

## Señales

- La jornada abierta y la jornada cerrada. El final no es una señal aparte: la devolución lo lee
  al armarse.
- La persiana bajada, y la opción elegida en la devolución, una sola vez.
- Comenzar pedido, una sola vez al terminar las instrucciones.

## Dependencias

- [`shift-cycle`](../shift-cycle/shift-cycle.md) (consume): cuántas obligatorias se cumplieron.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (consume): qué jornadas son de introducción.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (alimenta): tras las instrucciones, anuncia la
  noche que introducen y conserva la retención hasta que termine de subir la persiana.
- [`investigation`](../investigation/investigation.md) (alimenta): las 21 entradas de Enrique
  con la jornada en que llega cada una, y la correspondencia entre cada foto y el texto
  siguiente al grupo para releerlas en el celular.
- [`investigation`](../investigation/investigation.md) (alimenta): las devoluciones, que el chat
  de Enrique intercala con las aperturas por jornada cerrada y orden; el celular en modo fijo durante la devolución.
- [`store-cleanup`](../store-cleanup/store-cleanup.md) (consume): los llamados de la noche.
- [`save-and-resume`](../save-and-resume/save-and-resume.md) (alimenta): el legajo, la jornada,
  las cuentas de la devolución y las devoluciones recibidas, que cruzan la sesión.

- [`store-cleanup`](../store-cleanup/store-cleanup.md) (consume): teñido aceptado e identidad
  de Poético para registrar el hecho de la jornada.
- [`investigation`](../investigation/investigation.md) (consume y alimenta): expediente y
  mensajes de pistas de la partida, conservados entre aperturas sin duplicar su titularidad.

## Preguntas abiertas

- **OQ-EMP-010 — ¿Qué dice el mensaje 1 de la jornada 2 con un cliente mal atendido y el
  registro mal hecho?**
  - Por qué sigue abierta: la ficha «Chat con el jefe» del 2026-10-20 tiene cinco filas y
    ninguna cubre esa combinación.
  - Decide: una persona de game design.
  - Bloquea: nada. Mientras tanto, BR-EMP-040 usa la fila de un cliente mal atendido, porque la
    ficha llama a la atención «LO MÁS IMPORTANTE».

- **OQ-EMP-011 — ¿Qué dice el mensaje 1 de la jornada 4 con menos de 5 fallas, la jornada 3
  cumplida y fallas en la 1 o la 2?**
  - Por qué sigue abierta: la ficha «Chat con el jefe» del 2026-10-20 pide todas las tareas
    cumplidas para la primera fila y la jornada 3 sin cumplir para la segunda. Ninguna fila
    cubre este caso.
  - Decide: una persona de game design.
  - Bloquea: nada. Mientras tanto, BR-EMP-043 usa la fila de «altibajos».

- **OQ-EMP-012 — ¿Las fallas y los llamados de la prueba cuentan para la n de las Tareas y los
  Retos desde la jornada 4?**
  - Por qué sigue abierta: la ficha «Chat con el jefe» numera «1º vez que falla la tarea» sin
    decir desde qué noche. Su devolución rige «desde la jornada 4», el mensaje 4 de esa jornada
    dice «Desde hoy te voy a tener cortito», y la ficha de puntos reinicia los puntos ahí.
  - Decide: una persona de game design.
  - Bloquea: nada. Mientras tanto, BR-EMP-025 cuenta desde la jornada 4: con la prueba
    contada, la primera falla de la jornada 4 podía traer el texto de la cuarta sin despedir.

- **OQ-EMP-009 — ¿Qué dice la devolución cuando la prueba pasa de 4 apercibimientos sin despedir?**
  - Por qué sigue abierta: la devolución elige Saludo y Cierre por P, y P ≥ 4 es hoy el despido
    (BR-EMP-026, BR-EMP-029). En la prueba P llega a 4 o más sin despedir, y al cerrar la jornada 3
    el legajo ya arrancó de nuevo.
  - Decide: una persona de game design.
  - Bloquea: nada. Mientras tanto la devolución lee P como siempre.
