---
schema_version: 1
capability_id: CAP-INV
status: ratified
owner: por definir
provenance: GDD «Investigación» y «La computadora»; ficha «Interfaces virtuales durante la jornada» y decisiones de #373; migración de los specs 006, 009, 018
---

# Capacidad: la investigación

## Propósito

Darle al minuto que no se paga algo que comprar. Lo único que tiene que hacer bien es **no
rendir dos veces**: lo que un objeto esconde se ve sólo al examinarlo, y examinarlo otra vez no
suma. Sin eso, se puede pasar la noche examinando la misma lata.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Revelación** | lo que un objeto esconde y sólo se ve al examinarlo | secreto, lore |
| **Hallazgo** | la primera vez que se ve una revelación. La segunda no lo es | descubrimiento |

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

### BR-INV-005 — La computadora tiene dos apps y los chats están en el celular

El sistema DEBE ofrecer exactamente **caja y notas** en la computadora. Los chats DEBEN leerse
en el celular. Las notas escritas por el jugador DEBEN permanecer en la computadora.

### BR-INV-006 — Leer no cobra tiempo adicional

CUANDO se abre la computadora o se cambia de app, o se abre o cierra el celular, se lee un chat
o se amplía una foto, el sistema NO DEBE descontar tiempo por el gesto. MIENTRAS el celular está
abierto durante la jornada sin pausa, el reloj DEBE seguir descontando el tiempo real de juego.

### BR-INV-007 — Reabrir vuelve donde se dejó

CUANDO se cierra y se vuelve a abrir la computadora, el sistema DEBE mostrar la última app
elegida. Con la computadora cerrada, cambiar de app no hace nada: reabrir en una app que el
jugador nunca eligió sería un salto.

### BR-INV-008 — Lo leído es de la partida, no del guión

El sistema DEBE llevar **fuera del guión de cada conversación** qué está leído. Una marca adentro
del guión sobrevive a la partida entera: el jugador empezaría la noche dos con todo leído.

### BR-INV-009 — Leer un chat es leerlo entero

CUANDO se abre una conversación, el sistema DEBE dejarla en cero mensajes sin leer, y DEBE llevar
la cuenta **por interlocutor**. Con un contador global, leer al jefe apagaría el aviso de los
otros. Los mensajes que llegan después de esa lectura DEBEN contar como no leídos de ese chat,
sin modificar los contadores de los demás.

### BR-INV-010 — Una nota sin título no se guarda

SI el título está vacío o es sólo espacios, ENTONCES el sistema DEBE rechazar la nota. Un renglón
sin título es una entrada que el jugador no va a poder encontrar después. El cuerpo sí puede
estar vacío.

### BR-INV-011 — El cuaderno y la bandeja no son de la pantalla

El sistema DEBE conservar lo anotado al cambiar de app o cerrar la computadora, y lo leído al
cerrar y reabrir el celular. Esos estados NO DEBEN depender de reconstruir su pantalla.

### BR-INV-017 — Pensar no clava al jugador

MIENTRAS se muestra lo que reveló algo no levantable, el sistema DEBE dejar al jugador irse. Es
un pensamiento, no un examen.

### BR-INV-018 — Se examina sólo lo que se lleva

CUANDO se pide examinar con las manos vacías y la mira sobre un levantable, el sistema NO
DEBE arrancar un examen, retener al jugador ni mover lo que se mira. Con algo en la mano,
DEBE examinar lo que se lleva. Sobre algo no levantable, la E sigue siendo el pensamiento
de BR-INV-017, sin retener al jugador.

Mientras no se resuelva OQ-INV-002, pedir examinar un levantable con las manos vacías NO
DEBE revelar ni registrar un hallazgo (BR-INV-001).

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
modo libre, Q DEBE cerrarlo. Con el turno cerrado, otra interfaz al control, un examen o una
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
interlocutores. Cada botón DEBE mostrar nombre, imagen y cantidad de no leídos cuando es mayor
que cero; sin imagen, DEBE mostrar un círculo liso del tema. La jornada NO DEBE programar nuevas
llegadas durante su transcurso. Al continuar desde un guardado, los mensajes del guión DEBEN
reconstruirse según esa jornada, todos sin leer; los recibidos fuera del guión NO DEBEN guardarse.

### BR-INV-024 — Recibir agrega sin alterar el guión

CUANDO se recibe un mensaje válido para una conversación existente, el sistema DEBE agregarlo
al final de ese chat y avisar la recepción una sola vez, incluso con el celular cerrado. Si
ese chat está a la vista, el mensaje DEBE aparecer al final. La recepción NO DEBE alterar el
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
El celular DEBE dibujarse sobre HUD, computadora y cierre, y debajo de avisos y pausa. La
duración completa de subir y de bajar DEBE ser de 0,25 segundos reales por recorrido.

### BR-INV-028 — Pausa y cierre conservan estados distintos

CUANDO se pausa con el celular abierto, el sistema DEBE mostrar la pausa encima, ignorar Q y
reanudar en la misma pantalla del celular. CUANDO cierra el turno, el celular DEBE cerrarse,
soltar su modo fijo y dejar el control suspendido por el cierre. CUANDO se abre otra jornada,
el celular DEBE empezar cerrado y preparado para abrir en el menú.

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

### AC-INV-006 — Dos apps y un celular *(verifica BR-INV-005)*

DADO la computadora y el celular CUANDO se enumeran sus opciones ENTONCES la computadora tiene
exactamente caja y notas, y los chats se ofrecen en el celular.

### AC-INV-007 — Abrir no descuenta *(verifica BR-INV-006)*

DADO un turno entero CUANDO se abre la computadora y se cambia de app, o se abre el celular,
se lee un chat, se amplía una foto y se cierra el celular en el mismo instante ENTONCES el turno
no bajó un solo segundo. CUANDO pasan 30 segundos reales con el celular abierto, sin pausa,
ENTONCES descuenta exactamente lo mismo que 30 segundos sin el celular.

### AC-INV-008 — Reabrir vuelve a la última app *(verifica BR-INV-007)*

DADO la computadora abierta en notas CUANDO se cierra y se vuelve a abrir ENTONCES está en notas;
y con la computadora cerrada, cambiar de app no cambia nada.

### AC-INV-009 — Lo leído no vive en el guión *(verifica BR-INV-008)*

DADO una conversación leída CUANDO se la vuelve a cargar de disco en otra partida ENTONCES está
sin leer.

### AC-INV-010 — Leer apaga sólo su pestaña *(verifica BR-INV-009)*

DADO tres conversaciones con mensajes sin leer CUANDO se lee una ENTONCES ésa queda en 0 y las
otras dos conservan los suyos. CUANDO llegan dos mensajes más a la conversación leída ENTONCES
ésta tiene 2 sin leer y las otras conservan los suyos; abrirla de nuevo la deja en 0.

### AC-INV-011 — La nota sin título se rechaza *(verifica BR-INV-010)*

DADO un título de sólo espacios CUANDO se escribe la nota ENTONCES no se guarda y el cuaderno
sigue con las que tenía; con título y cuerpo vacío, se guarda.

### AC-INV-012 — Cambiar de app no borra *(verifica BR-INV-011)*

DADO dos notas escritas y un chat leído CUANDO se cambia de app, se cierra y reabre la computadora,
y se cierra y reabre el celular ENTONCES siguen las dos notas y ese chat sigue leído.

### AC-INV-019 — El pensamiento no retiene *(verifica BR-INV-017)*

DADO lo que reveló algo no levantable, de una sola entrada, CUANDO todavía no se avanzó
ENTONCES ya se puede abandonar.

### AC-INV-020 — Las manos vacías no examinan *(verifica BR-INV-018, BR-INV-001)*

DADO las manos vacías y la mira sobre un levantable CUANDO se pide examinar dos veces
ENTONCES no hay examen, el jugador no queda retenido, el levantable sigue en su lugar, las
manos siguen vacías y no se registra hallazgo ni se avisa que empezó o terminó un examen.
DADO algo en la mano y la mira sobre otro levantable ENTONCES se examina lo que se lleva.


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
ENTONCES muestra sólo el primero; en la 3 muestra los dos, en ese orden. DADO otro chat con todo
en jornada 2 ENTONCES no tiene botón en la 1 y sí en la 2. Los botones visibles conservan el orden
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
mide cada recorrido completo de 0,25 segundos; una inversión conserva la posición actual.

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

### AC-INV-036 — Pausar conserva, cerrar limpia *(verifica BR-INV-028)*

DADO el celular con una foto ampliada CUANDO se pulsa Esc, luego Q, y se reanuda ENTONCES vuelve
la misma foto. DADO el celular abierto CUANDO cierra el turno ENTONCES queda cerrado y el control
permanece suspendido por el cierre. CUANDO abre otra jornada ENTONCES sigue cerrado y el primer
Q permitido abre el menú.

### AC-INV-037 — Retomar reconstruye los chats *(verifica BR-INV-023, BR-INV-008)*

DADO un guardado en jornada 3, con chats que antes se leyeron y mensajes recibidos fuera del guión,
CUANDO se retoma ENTONCES se ven los mensajes del guión de jornada menor o igual a 3, todos sin
leer, y ninguno de los recibidos fuera de él. Abrir y cerrar sin entrar a un chat conserva los
contadores.

### AC-INV-038 — Un botón por chat y una imagen de reemplazo *(verifica BR-INV-023)*

DADO dos chats visibles, uno con imagen y dos no leídos y otro sin imagen ni no leídos, CUANDO
se muestra el menú ENTONCES hay dos botones: el primero con nombre, imagen y contador 2, y el
segundo con nombre y círculo liso del tema, sin contador cero.

## No objetivos

- Esta capacidad NO escribe el contenido: qué revela cada objeto y qué dice cada chat es
  contenido, y entra como dato.
- Esta capacidad NO descuenta tiempo del turno.
- Esta capacidad NO define aquí contactos, mensajes de jornadas futuras ni hipótesis; consume
  el contenido decidido para cada conversación. Las notas de la computadora conservan su uso.

## Contratos

- **Entrada:** el objeto examinado, la entrada de movimiento y los segundos del cuadro, el
  arrastre del mouse, la app elegida, la conversación abierta, y el título y el
  cuerpo de una nota; la jornada, Q, el estado del control y los pedidos de recibir mensajes,
  navegar chats, ampliar fotos, fijar y soltar el celular.
- **Salida:** el texto visible, si fue hallazgo, cuántos mensajes sin leer hay y las notas;
  celular abierto o cerrado, menú, chat o foto, modo fijo y listas visibles de chats y mensajes.
- **Falla:** una revelación vacía y una nota sin título se rechazan sin cambiar nada.
- **Falla del celular:** Q bloqueado, chat inexistente, recepción inválida, ampliación sin foto
  y soltar sin modo fijo conservan el estado. Una conversación sin mensajes visibles se omite
  del menú; una foto sin texto siguiente se amplía sin adjunto.

## Señales

- El hallazgo nuevo y la computadora abierta.
- El celular abierto o cerrado, menú mostrado, chat abierto, foto ampliada o cerrada, cambios
  de no leídos y mensaje recibido. Un gesto rechazado no publica cambio de estado.

## Dependencias

- [`player-actions`](../player-actions/player-actions.md) (consume): qué objeto se está
  examinando.
- [`ambience`](../ambience/ambience.md) (alimenta): cada recepción aceptada dispara el sonido
  de mensaje del celular; escribir una nota en la computadora no es recibir un mensaje.

## Preguntas abiertas

- **OQ-INV-002 — ¿La E con las manos vacías revela un levantable o sólo lo nombra?**
  - Por qué sigue abierta: la ficha de interacciones pide un subtítulo, y la ficha
    «Subtítulos» todavía no decide si cuenta como hallazgo. Mientras tanto no revela ni
    registra: mirar no revela (BR-INV-001).
  - Decide: una persona de game design junto con la ficha «Subtítulos».
  - Bloquea: nada de esta regla; condiciona el futuro subtítulo de manos vacías.
