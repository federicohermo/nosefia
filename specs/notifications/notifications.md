---
schema_version: 1
capability_id: CAP-NTF
status: ratified
owner: por definir
provenance: GDD «Notificaciones»; ficha «Sistema de investigación (pistas e hipótesis)»; GJ-43; decisiones de los issues 309, 385 y 435; ocho jornadas de #526; salida voluntaria de #573; fichas «Notificaciones» y «8. Tarea: Reposición» (#554)
---

# Capacidad: los avisos durante la noche

## Propósito

Hacer visibles la llegada y salida por cansancio de un comprador y el rechazo del lector lleno.
Avisar también una pista nueva, la salida habilitada o vuelta a trabar de las jornadas de prueba
y la proximidad del cierre mientras el jugador reparte su atención entre las tareas.
Avisar además que falta reponer productos mientras el jugador está en una zona con faltantes.
Los avisos acompañan esos sucesos sin cambiar su resultado.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Notificación** | cartel breve con texto y símbolo de un suceso | ventana, diálogo |
| **Tipo** | llegada, salida por cansancio, lectura fallida por renglones llenos, pista nueva, cierre próximo, tareas terminadas, salida vuelta a trabar o falta reponer | prioridad |
| **Zona de reposición** | cada una de las siete regiones del piso del local que declara [`store-stock`](../store-stock/store-stock.md) (BR-STK-052) | sector, pasillo |
| **Zona con faltante** | zona de reposición en la que algún producto de sus muebles es faltante según BR-STK-007 | zona vacía |
| **Visible** | tipo cuyo tiempo todavía no se agotó | historial |
| **Comprador avisado** | la misma identidad que ya disparó su llegada durante el turno | mismo nombre |
| **Pista nueva** | pista cuyo registro acepta investigación por primera vez y desbloquea una hipótesis | objeto revelado, objeto examinado |

## Comportamiento normativo

### BR-NTF-001 — La llegada avisa una vez

CUANDO llega un comprador no avisado, el sistema DEBE mostrar «¡Hay un cliente!» y recordar su
identidad hasta el cierre del turno. SI esa misma identidad vuelve a llegar, ENTONCES el sistema NO
DEBE crear ni renovar la notificación. Una llegada sin comprador no cambia nada.

### BR-NTF-002 — Sólo el lector lleno avisa

CUANDO el lector rechaza una unidad porque sus tres renglones están llenos, el sistema DEBE mostrar
«No se pudo leer». Un rechazo por no ser un producto y una lectura anotada NO DEBEN crear ni renovar
notificaciones. Con el lector ausente en el programa manual tampoco avisa.

### BR-NTF-003 — Tres segundos en ejecución

El sistema DEBE mantener cada notificación durante tres segundos de juego en ejecución.
La llegada de un comprador con horario usa la excepción de BR-NTF-009 y la falta reponer, la
de BR-NTF-016.
MIENTRAS el juego está en pausa, el sistema NO DEBE consumir su tiempo. CUANDO el tiempo
alcanza la duración, el sistema DEBE retirar el tipo, también si un solo avance supera el
límite. Un avance de cero o negativo no cambia el estado.

### BR-NTF-004 — Un tipo visible no se duplica

CUANDO se avisa un tipo ya visible, el sistema DEBE dejarlo una sola vez, primero, con sus tres
segundos completos, sin renovar los otros tipos. La llegada del mismo comprador sigue la excepción
de BR-NTF-001 y la persistencia de BR-NTF-009. El cierre próximo sigue la unicidad
por jornada de BR-NTF-012 y NO DEBE renovarse por entradas sucesivas de tiempo.
Las tareas terminadas siguen la unicidad por jornada de BR-NTF-014. La salida vuelta a
trabar sigue las transiciones de BR-NTF-015. La falta reponer sigue la persistencia de
BR-NTF-016.

### BR-NTF-005 — Los tipos conviven en orden

MIENTRAS hay varios tipos visibles, el sistema DEBE mostrar todos, del más nuevo al más
viejo. Consultar o modificar una copia de la lista de tipos no cambia lo que está visible.

### BR-NTF-006 — El cierre vacía el estado

CUANDO cierra el turno, el sistema DEBE retirar todas las notificaciones y olvidar las identidades
avisadas y el disparo de cierre próximo. Con el turno cerrado la falta reponer NO DEBE
reaparecer aunque el jugador siga dentro de una zona con faltante. La siguiente noche empieza sin avisos de la anterior
y puede volver a avisar su propio cierre próximo.

### BR-NTF-007 — El cartel comunica sin tomar el control

El sistema DEBE dibujar los carteles claros en la esquina superior derecha, con el símbolo
del tipo a la izquierda y su texto en mayúsculas a la derecha. Llegada, lectura y pista van sin
punto final; la salida conserva el punto final de su diseño. El comprador
usa la figura con exclamación, el lector usa la cruz y la pista usa el signo de pregunta del diseño.
MIENTRAS computadora, ventanilla u otra interfaz de la jornada están abiertas, incluyendo los diálogos, el cartel
DEBE verse encima y DEBE dejar pasar el clic. El menú
de pausa DEBE dibujarse por encima del cartel.

TODOS los tipos DEBEN presentar su texto en una sola línea, con el tamaño de letra principal
del tema. El contenedor DEBE ajustar su ancho al símbolo, la separación, el texto y sus
márgenes, sin una franja vacía de ancho fijo. Los carteles DEBEN compartir el borde derecho
y centrar verticalmente símbolo y texto, sin recortarlos al cambiar la resolución.

### BR-NTF-008 — El comprador que vence avisa su salida

CUANDO una compra vence, el sistema DEBE mostrar «El cliente se cansó de esperar» una vez por
identidad y jornada. DEBE usar la duración, pausa, orden y deduplicación de los demás avisos.
Una compra completa NO DEBE producirlo. El cierre DEBE olvidar las identidades de salida.

### BR-NTF-009 — La llegada espera a la conversación

EN las jornadas 1 a 4, el aviso de llegada DEBE permanecer hasta iniciar la conversación con
ese comprador, sin vencer por tiempo. Abrir o cerrar la ventanilla NO DEBE retirarlo.
El primer clic que inicia la conversación DEBE retirarlo una sola vez; reabrir o volver a
hablar NO DEBE recrearlo. Si el comprador vence antes, su salida DEBE retirar la llegada.
Un evento de otra identidad NO DEBE retirar el aviso del comprador que está esperando.
Los avisos de lectura y de cansancio DEBEN conservar su duración. Las jornadas 5 a 8
conservan el recorrido y duración anteriores hasta que tengan diálogos diseñados.

### BR-NTF-010 — Sólo una pista anotada avisa

CUANDO investigación confirma una pista nueva anotada que desbloquea una hipótesis, el sistema
DEBE mostrar «¡NUEVA PISTA!». El disparador es el registro aceptado, según la
[ficha «Notificaciones»](https://app.notion.com/p/3e486efecd9d808bb505c198429d316d).
Un resultado repetido o desconocido NO DEBE crear ni renovar el aviso.
Revelar o examinar un objeto sin registrar una pista NO DEBE producirlo.

El aviso de pista DEBE usar la duración y pausa de BR-NTF-003, la deduplicación de BR-NTF-004,
el orden de BR-NTF-005, el cierre de BR-NTF-006 y la presentación de BR-NTF-007.
Dos pistas distintas anotadas en el mismo cuadro DEBEN dejar un solo cartel de pista.
Una pista nueva con la pausa abierta DEBE aparecer y conservar sus tres segundos hasta reanudar.

### BR-NTF-012 — A las 07:00 avisa una sola vez por jornada

CUANDO el turno está abierto y el tiempo restante alcanza o atraviesa el umbral de
las 07:00 de ficción, el sistema DEBE mostrar un aviso de cierre próximo una sola vez en esa
jornada. El umbral DEBE derivarse de la apertura y duración de BR-SHF-001: duración menos
el intervalo desde la apertura hasta las 07:00 del día siguiente. Con el turno vigente,
equivale a una hora de ficción restante, no a la hora del equipo ni al texto del reloj de mesa.
Antes del umbral, con tiempo no positivo o con turno cerrado NO DEBE dispararse.

Una primera entrada ya dentro de la última hora con turno abierto DEBE dispararlo. Un salto
desde antes de las 07:00 hasta después, pero antes del cierre, DEBE dispararlo también.
Las entradas siguientes NO DEBEN repetirlo ni renovarlo, incluso después de que desaparezca.
El cierre DEBE vaciarlo y suprimir un disparo si ese avance llega directamente al final del
turno. Abrir la noche siguiente DEBE habilitar un nuevo disparo, en cualquiera de las cinco
jornadas. Retomar desde el inicio de la jornada DEBE habilitarlo sin guardar una bandera propia.
La falla del reloj de mesa NO DEBE impedir el aviso.

### BR-NTF-013 — El cierre próximo comunica una hora restante

CUANDO se muestra cierre próximo, el sistema DEBE comunicar que queda una hora de jornada,
con un símbolo que identifique el tiempo restante, usando el fondo claro, fuente principal,
esquina superior derecha, una sola línea y ancho ajustado de BR-NTF-007. DEBE permanecer
durante la duración de BR-NTF-003, conservar su resto en pausa, dejar pasar clics y dibujarse
encima de las interfaces de jornada y debajo del menú de pausa. NO DEBE añadir un reloj
permanente al HUD ni cambiar la duración del turno.
DEBE convivir con los demás tipos conservando orden, deduplicación y duración propia de
cada uno; un aviso persistente NO DEBE adquirir un temporizador por la llegada de éste.

### BR-NTF-014 — Las tareas terminadas avisan una vez por jornada de prueba

CUANDO la jornada habilita por primera vez la salida según BR-SHF-021, el sistema DEBE mostrar
«Ya terminaste tus tareas y podés irte» una sola vez en esa
jornada. El aviso DEBE seguir la duración, pausa, orden y presentación comunes.
Entradas repetidas del mismo cumplimiento NO DEBEN renovarlo, ni recrearlo después de vencer.
Si la salida vuelve a trabarse, el sistema DEBE retirar este aviso para no anunciar un permiso
que ya no vale. Recuperar la salida NO DEBE repetir el aviso inicial.
Cerrar DEBE retirar el aviso y olvidar su disparo. Una jornada nueva de prueba puede avisar
otra vez. Desde la primera jornada completa NO DEBE aparecer este aviso.

MIENTRAS la computadora está abierta, los cambios de permiso NO DEBEN disparar este aviso ni
el de BR-NTF-015. Un aviso previo que sigue vigente conserva su duración al abrirla.
CUANDO el jugador sale de la computadora, el sistema DEBE mostrar el aviso que
corresponde al estado vigente de la salida, como si el cambio ocurriera en ese instante.
SI sale con el mismo permiso con que entró, ENTONCES NO DEBE dispararse un nuevo aviso de salida.
Una habilitación que se pierde antes de salir NO cuenta como avisada. El retiro del aviso
opuesto que ya no vale NO DEBE esperar. SI el turno cierra con la computadora abierta,
ENTONCES salir de ella NO DEBE mostrar un aviso pendiente.

### BR-NTF-015 — Cada nueva traba de salida avisa

CUANDO la salida de prueba pasa de habilitada a trabada porque una obligatoria dejó de
cumplirse según BR-SHF-024, el sistema DEBE mostrar «Ya no podés irte porque una tarea quedó
sin cumplir». El texto es provisorio y DEBE usar el mismo símbolo, estilo y mecanismo del
aviso de tareas terminadas, con duración, pausa, orden, deduplicación y cierre comunes.
Cada nueva transición DEBE dispararlo otra vez, incluso si el aviso anterior ya venció.
Confirmar repetidas veces el mismo estado trabado NO DEBE renovarlo ni recrearlo.
Antes de habilitar la salida por primera vez NO DEBE aparecer este aviso.
Cuando se recupera la salida, el sistema DEBE retirar el aviso de traba para no anunciar una
restricción que ya no vale, sin repetir el aviso inicial. Ninguno de estos cambios DEBE
retirar ni renovar otros tipos. Cerrar DEBE vaciar ambos avisos y olvidar las transiciones.
Desde la primera jornada completa NO DEBE aparecer este aviso. Con la computadora abierta,
este aviso espera a que el jugador salga según BR-NTF-014.

### BR-NTF-016 — Falta reponer dura mientras el jugador está en la zona

MIENTRAS el turno está abierto y el jugador está dentro de una zona con faltante según
BR-STK-052, el sistema DEBE mostrar «Falta reponer productos por acá», según la
[ficha «Notificaciones»](https://app.notion.com/p/3e486efecd9d808bb505c198429d316d) y la
[ficha «8. Tarea: Reposición»](https://app.notion.com/p/3cc86efecd9d81968a25c7cffca4b0dd).
El aviso NO DEBE tener temporizador: NO DEBE vencer por tiempo, también con el juego en
ejecución, y conserva su estado con el juego en pausa.

CUANDO el jugador entra en una zona con faltante, el sistema DEBE mostrarlo. CUANDO la zona deja
de tener faltantes, el jugador sale de ella o cierra el turno, el sistema DEBE retirarlo.
Volver a entrar en una zona con faltante, o que un casillero de la zona se vacíe con el jugador
dentro, DEBE mostrarlo otra vez. Reponer un faltante de otra zona NO DEBE retirarlo. Pasar de una
zona con faltante a otra zona con faltante lo conserva una sola vez, sin renovarlo. Un jugador
fuera de las siete zonas NO DEBE verlo.

SI la jornada no declara reponer, como la jornada 1, ENTONCES el sistema NO DEBE mostrarlo, aunque
falten unidades vendidas (BR-STK-026).

El aviso DEBE seguir la unicidad de BR-NTF-004, el orden de BR-NTF-005 y la presentación de
BR-NTF-007, sin punto final. CUANDO aparece, DEBE quedar primero. Un tipo que se avisa después
DEBE quedar delante de él sin retirarlo, y NO DEBE darle un temporizador. Los avisos temporizados
conservan su duración mientras éste sigue visible.

## Criterios de aceptación

### AC-NTF-001 — Identidad y reapertura *(verifica BR-NTF-001, BR-NTF-004)*

DADO un comprador CUANDO llega ENTONCES hay un aviso de llegada. DADO ese aviso con dos segundos
consumidos CUANDO llega el mismo comprador ENTONCES sigue uno solo y sale al consumir el segundo
restante. Si vuelve después de vencido no avisa. Otro comprador sí renueva el tipo, que sigue
visible 2,9 segundos después de esa llegada.

### AC-NTF-002 — Motivo del rechazo *(verifica BR-NTF-002)*

DADO cero avisos CUANDO el lector rechaza por no ser un producto, está ausente o anota una lectura
ENTONCES siguen siendo cero. CUANDO rechaza por sus tres renglones llenos ENTONCES hay exactamente
un aviso de lectura fallida.

### AC-NTF-003 — Antes, en el límite y después *(verifica BR-NTF-003)*

DADO un aviso nuevo CUANDO se consumen 2,9 segundos ENTONCES sigue visible; al completar 3,0
segundos ya no está. Un único avance de diez segundos retira todos los avisos y deja el estado listo
para que uno nuevo dure sus tres segundos completos.

### AC-NTF-004 — Renovar un tipo conserva el otro *(verifica BR-NTF-004, BR-NTF-005)*

DADO dos tipos con dos segundos consumidos CUANDO se avisa otra lectura fallida ENTONCES hay dos
tipos, la lectura fallida primera. Un segundo después la llegada se retiró y queda la lectura
fallida, que todavía sigue visible a los 2,9 segundos desde su renovación.

### AC-NTF-005 — Dos tipos y una copia *(verifica BR-NTF-005)*

DADO el aviso de llegada CUANDO llega el rechazo por lector lleno ENTONCES la lista visible es
lectura fallida, llegada. Vaciar una copia consultada no retira ninguno de los dos.

### AC-NTF-006 — Cerrar y volver a avisar *(verifica BR-NTF-006, BR-NTF-001)*

DADO dos tipos visibles CUANDO cierra el turno ENTONCES hay cero, también en pantalla. Avisar luego
al mismo comprador vuelve a producir su notificación.

### AC-NTF-007 — Entradas sin efecto *(verifica BR-NTF-001, BR-NTF-003)*

DADO cero avisos CUANDO llega un comprador nulo ENTONCES siguen siendo cero. DADO uno con 2,9
segundos consumidos CUANDO se avanza cero o menos diez ENTONCES sigue uno; completar el 0,1 restante
lo retira.

### AC-NTF-008 — La pausa conserva el resto *(verifica BR-NTF-003)*

DADO un aviso con dos segundos consumidos CUANDO se pausa el juego y transcurren cuadros ENTONCES su
procesamiento queda suspendido y el aviso continúa. Al reanudar, 0,9 segundos no lo retiran y
completar el 0,1 restante sí.

### AC-NTF-009 — Texto, símbolos y esquina *(verifica BR-NTF-007)*

DADO llegada, lectura fallida y pista visibles CUANDO se presentan a 1920 × 1080 y 1280 × 720
ENTONCES sus carteles quedan dentro de la esquina superior derecha, sin recorte.
La cruz corresponde a «NO SE PUDO LEER» y
la figura con exclamación a «¡HAY UN CLIENTE!»; el signo de pregunta corresponde a «¡NUEVA PISTA!».
Los tres símbolos están a la izquierda de su texto. Los tres carteles usan la
fuente del tema de Manada y el fondo claro del diseño.

### AC-NTF-010 — Interfaces y clic *(verifica BR-NTF-007)*

DADO un cartel visible y la computadora abierta CUANDO se hace clic en la esquina que ocupa el
cartel ENTONCES el clic llega a la computadora. La pila se dibuja encima de computadora, ventanilla,
diálogos y programa manual; con la lista desplegable real abierta el aviso sigue visible. Al hacer
Esc en esa lista se abre la pausa, sus listas quedan cerradas y el menú de pausa se dibuja encima de
la pila. Reanudar conserva programa, selección y aviso; no reabre las listas automáticamente. Se
comprueba con capturas anteriores a Esc y durante pausa, a ambas resoluciones; comparar sólo los
índices de dibujo no prueba el orden de las ventanas.

### AC-NTF-011 — Vencimiento, duración y renovación *(verifica BR-NTF-008, BR-NTF-003, BR-NTF-004, BR-NTF-005, BR-NTF-006)*

DADO una compra vencida CUANDO se avisa la salida ENTONCES aparece su texto y símbolo, primero.
Repetir esa identidad no renueva. A los 2,9 segundos sigue; a los 3,0 desaparece.
La pausa conserva el resto. Otra identidad renueva el tipo sin duplicarlo ni renovar los otros.
Cerrar y comenzar otra jornada permite avisar otra vez la misma identidad.

### AC-NTF-012 — Espera y primer clic *(verifica BR-NTF-009, BR-NTF-001, BR-NTF-006)*

DADO un comprador de las jornadas 1 a 4 CUANDO pasan más de tres segundos, se abre o se cierra
la ventanilla ENTONCES la llegada sigue visible. CUANDO el primer clic inicia su conversación
ENTONCES desaparece; avanzar diálogo y reabrir no la repiten. La salida antes de conversar y el
cierre del turno la retiran. Una identidad distinta no puede ocultarla.

### AC-NTF-013 — Una línea y ancho según el contenido *(verifica BR-NTF-007)*

DADO llegada, lectura fallida, cansancio y pista CUANDO se muestran a 1920 × 1080 y 1280 × 720
ENTONCES cada texto ocupa una sola línea con la letra principal del tema, queda completo
junto al símbolo y su cartel ajusta el ancho al contenido. Los cuatro comparten el borde
derecho dentro de la pantalla; el mensaje más largo ocupa un cartel más ancho.

### AC-NTF-014 — Registro nuevo, repetido y desconocido *(verifica BR-NTF-010)*

DADO cero avisos CUANDO se revela un objeto que no es pista, se repite una pista conocida
o se intenta registrar una desconocida ENTONCES no aparece ningún aviso de pista.
CUANDO investigación acepta una pista nueva ENTONCES aparece exactamente un cartel
«¡NUEVA PISTA!» con el signo de pregunta a su izquierda.
DADO ese aviso con dos segundos consumidos CUANDO se repite la pista o se intenta registrar
una desconocida ENTONCES sigue uno solo y desaparece al consumir el segundo restante.

### AC-NTF-015 — Dos pistas renuevan sólo su tipo *(verifica BR-NTF-010, BR-NTF-003, BR-NTF-004, BR-NTF-005)*

DADO cero avisos CUANDO se anotan dos pistas distintas en el mismo cuadro ENTONCES queda
un solo cartel de pista. DADO un aviso de pista y otro de lectura fallida, ambos con dos
segundos consumidos, CUANDO se anota otra pista nueva ENTONCES la lista es pista, lectura
fallida, sin duplicados. Un segundo después sólo queda pista; sigue visible a los 2,9 segundos
desde su renovación y desaparece al completar 3,0.

DADO cero avisos CUANDO se anota una pista, llega un comprador y el lector rechaza por lleno,
en ese orden y sin avance de tiempo, ENTONCES hay tres carteles: lectura fallida, llegada, pista.

### AC-NTF-016 — Pausa, cierre e interfaces con una pista *(verifica BR-NTF-010, BR-NTF-003, BR-NTF-006, BR-NTF-007)*

DADO el juego pausado CUANDO se anota una pista nueva ENTONCES el cartel aparece debajo del
menú de pausa y conserva sus tres segundos completos aunque transcurran cuadros.
CUANDO se reanuda ENTONCES sigue visible tras 2,9 segundos y desaparece al completar 3,0.
Un único avance de diez segundos también lo retira.

DADO el aviso de pista visible CUANDO se abren computadora, ventanilla o diálogos ENTONCES
el cartel se dibuja encima y el clic atraviesa sus controles hasta la interfaz abierta.
CUANDO se anota una pista justo antes del cierre ENTONCES el cierre retira el cartel;
la siguiente jornada comienza sin ningún aviso heredado.

### AC-NTF-020 — Antes, exactamente en el umbral y después *(verifica BR-NTF-012)*

DADO cada jornada de 1 a 5 abierta con el turno de BR-SHF-001 CUANDO el restante es 3601
segundos de ficción —06:59:59— ENTONCES no hay cierre próximo. CUANDO llega a 3600 —07:00:00—
ENTONCES hay exactamente uno. CUANDO llegan más entradas de 3600 y 3599 ENTONCES sigue uno
sin renovar su tiempo. Los valores se derivan de apertura y duración de BR-SHF-001.

### AC-NTF-021 — El salto y la primera entrada dentro de la última hora *(verifica BR-NTF-012)*

DADO turno abierto sin disparo y restante de 3660 segundos de ficción —06:59— CUANDO un
avance deja 3540 —07:01— ENTONCES avisa una vez. DADO otra ejecución abierta sin disparo
CUANDO la primera entrada es 3540 ENTONCES también avisa. DADO restante cero, negativo o
turno ya cerrado ENTONCES hay cero disparos de cierre próximo.

### AC-NTF-022 — La unicidad sobrevive al vencimiento y se reinicia en otra noche *(verifica BR-NTF-012, BR-NTF-013, BR-NTF-003, BR-NTF-006)*

DADO cierre próximo recién disparado CUANDO pasan 2,9 segundos de juego en ejecución
ENTONCES sigue visible; al completar 3,0 desaparece. CUANDO vuelve a entrar tiempo dentro
de la última hora ENTONCES no reaparece. DADO un avance desde 06:59 hasta el cierre
ENTONCES la pila termina vacía y no aparece sobre la devolución. CUANDO comienza la noche
siguiente, o se retoma esa jornada desde su inicio, ENTONCES puede avisar al alcanzar su umbral.

### AC-NTF-023 — La pausa y el reloj averiado no cambian el disparador *(verifica BR-NTF-012, BR-NTF-013, BR-NTF-003)*

DADO el turno justo antes del umbral CUANDO se pausa y pasan cuadros ENTONCES no consume
tiempo ni dispara. DADO aviso con dos segundos consumidos CUANDO se pausa y reanuda
ENTONCES conserva el segundo restante: 0,9 no lo retiran y completar 0,1 sí.
DADO la jornada en que falla el reloj de mesa, con el display apagado CUANDO el turno
alcanza las 07:00 ENTONCES llega exactamente un cierre próximo a la pila de avisos.

### AC-NTF-024 — Una hora legible sin tomar el clic *(verifica BR-NTF-013, BR-NTF-007)*

DADO cierre próximo a 1920×1080 y 1280×720 CUANDO se presenta ENTONCES comunica una hora
restante, con símbolo de tiempo a la izquierda, texto en mayúsculas completo en una línea,
fuente principal y fondo claro. Su ancho se ajusta al contenido y comparte el borde derecho
de la pila. DADO computadora, celular o ventanilla abiertos ENTONCES el aviso queda encima y
deja pasar clics hacia ellos; al abrir pausa, ésta queda encima del aviso. El HUD no incorpora
un reloj permanente y el presupuesto del turno permanece igual.

### AC-NTF-025 — El mismo cuadro conserva los otros tipos *(verifica BR-NTF-012, BR-NTF-013, BR-NTF-004, BR-NTF-005, BR-NTF-009)*

DADO llegada persistente, cansancio y lectura fallida con un segundo consumido CUANDO se
dispara cierre próximo ENTONCES hay cuatro tipos, cierre próximo primero y los otros en su
orden anterior. Una lectura fallida en ese mismo cuadro los conserva y sólo cambia el orden
según la secuencia de recepción. CUANDO vencen los temporizados ENTONCES la llegada
persistente permanece hasta su gesto de retiro; cierre próximo no la temporiza ni se repite.
DADO los cuatro tipos todavía visibles CUANDO cierra el turno ENTONCES retira los cuatro.

### AC-NTF-026 — Un disparo, duración y nueva noche *(verifica BR-NTF-014, BR-NTF-003, BR-NTF-005, BR-NTF-006)*

DADO salida habilitada CUANDO se recibe su confirmación repetidas veces ENTONCES hay un
solo aviso de tareas terminadas, primero entre los otros tipos. A los 2,9 segundos sigue;
al completar 3,0 se retira. Una entrada repetida no renueva su resto ni lo recrea al vencer.
Cerrar retira todos los tipos y permite avisar una vez en la siguiente jornada de prueba.
Pausar conserva el tiempo restante del aviso.

### AC-NTF-027 — Texto completo con la presentación común *(verifica BR-NTF-014, BR-NTF-007)*

DADO el aviso a 1920×1080 y 1280×720 CUANDO se dibuja ENTONCES muestra en mayúsculas
«Ya terminaste tus tareas y podés irte» completo en una línea, con fondo claro, símbolo a la
izquierda y fuente principal. Su cartel ajusta el ancho al contenido, comparte el borde
derecho de la pila, queda dentro de pantalla y deja pasar clics.

### AC-NTF-028 — Sólo al completar las tareas de prueba *(verifica BR-NTF-014)*

DADO por separado las jornadas 1, 2, 3 y la primera jornada completa CUANDO falta una tarea
ENTONCES no hay aviso. CUANDO se completa la última ENTONCES las tres primeras muestran
exactamente uno y la primera completa ninguno. DADO el aviso vencido CUANDO se descumple
y se recupera una tarea ENTONCES el aviso inicial no reaparece; la salida sigue el estado
actual de sus tareas.

### AC-NTF-029 — Cada transición avisa y los estados opuestos se retiran *(verifica BR-NTF-014, BR-NTF-015, BR-NTF-004, BR-NTF-005)*

DADO una jornada de prueba sin salida habilitada todavía CUANDO se confirma que faltan tareas
ENTONCES no hay aviso de traba. DADO el aviso inicial visible CUANDO una tarea se descumple
ENTONCES se retira ese aviso y aparece uno de salida vuelta a trabar. Confirmar otra vez el
mismo estado no lo renueva. CUANDO se recuperan todas las tareas ENTONCES se retira el aviso
de traba sin repetir el inicial. CUANDO otra tarea vuelve a descumplirse ENTONCES aparece
un nuevo aviso de traba con sus tres segundos completos, también si el anterior ya venció.
Los otros tipos conservan su orden relativo y su tiempo restante durante ambos cambios.

### AC-NTF-030 — La nueva traba usa la presentación del aviso de salida *(verifica BR-NTF-015, BR-NTF-007)*

DADO el aviso de salida vuelta a trabar a 1920×1080 y 1280×720 CUANDO se dibuja ENTONCES
muestra en mayúsculas «Ya no podés irte porque una tarea quedó sin cumplir» completo en una
línea, con el mismo símbolo a la izquierda, fondo claro y fuente principal del aviso de tareas
terminadas. El cartel ajusta su ancho al contenido, comparte el borde derecho de la pila,
queda dentro de pantalla, encima de interfaces y debajo de pausa, y deja pasar clics.

### AC-NTF-031 — La nueva traba conserva duración, pausa y cierre *(verifica BR-NTF-015, BR-NTF-003, BR-NTF-006)*

DADO un aviso de traba recién disparado CUANDO se consumen 2,9 segundos ENTONCES sigue visible;
al completar 3,0 desaparece. Confirmar que la salida sigue trabada no lo recrea. DADO dos
segundos consumidos CUANDO se pausa y pasan cuadros ENTONCES conserva el segundo restante;
al reanudar, 0,9 no lo retiran y completar 0,1 sí. Un avance de diez segundos también lo retira.
Cerrar vacía el aviso. Abrir otra jornada de prueba no hereda la traba avisada y permite
un nuevo aviso inicial y posteriores trabas. La primera jornada completa no produce ninguno
de los dos avisos, aunque se cumpla y descumpla una tarea.

### AC-NTF-032 — Los avisos de salida esperan a que se cierre la computadora *(verifica BR-NTF-014, BR-NTF-015)*

DADO una jornada de prueba sin salida habilitada y la computadora abierta CUANDO se completa
la última tarea ENTONCES la salida queda habilitada y no hay aviso; CUANDO el jugador sale de
la computadora ENTONCES aparece el de tareas terminadas con sus tres segundos completos.
DADO ese aviso visible y la computadora abierta CUANDO una tarea se descumple ENTONCES la
salida se traba y el aviso se retira en el instante, sin aviso de traba; al salir aparece el
de traba. DADO la salida trabada y la computadora abierta CUANDO se recupera ENTONCES el aviso
de traba se retira en el instante y al salir no aparece ninguno. DADO la computadora abierta
CUANDO se descumple y se recupera una tarea antes de salir ENTONCES al salir no hay aviso.
DADO una jornada sin salida habilitada CUANDO se cumple y se descumple antes de salir
ENTONCES al salir no hay aviso, y completar después afuera avisa tareas terminadas una vez.
DADO un cambio pendiente CUANDO cierra el turno antes de salir ENTONCES salir no muestra
aviso. Los otros tipos conservan su orden y su tiempo restante durante la espera.
DADO un aviso de salida visible CUANDO se abre y se cierra la computadora sin cambiar el
permiso ENTONCES el aviso conserva su tiempo restante, sin renovarse ni recrearse al vencer.

### AC-NTF-033 — Entrar, quedarse y salir *(verifica BR-NTF-016, BR-NTF-003)*

DADO una jornada 2 con faltantes en la zona 4 y el jugador fuera de las siete zonas CUANDO entra
en la zona 4 ENTONCES hay exactamente un aviso de falta reponer, primero. CUANDO pasan 3,0
segundos y luego 600 segundos de juego en ejecución ENTONCES sigue visible. CUANDO se pausa y
transcurren cuadros ENTONCES sigue visible. CUANDO el jugador sale a una zona sin faltantes
ENTONCES se retira. CUANDO vuelve a entrar en la zona 4 ENTONCES hay otra vez uno solo.
Un jugador fuera de las siete zonas con faltantes en todas ellas ve cero.

### AC-NTF-034 — Sólo importa la zona donde está *(verifica BR-NTF-016)*

DADO el jugador en la zona 4, con un único faltante en la zona 4 y otro en la zona 6, CUANDO se
repone el de la zona 6 ENTONCES sigue visible. CUANDO se repone el último de la zona 4, sin que el
jugador se mueva, ENTONCES se retira. CUANDO se vacía un casillero de la zona 4 con el jugador
dentro ENTONCES aparece otra vez. DADO el jugador en la zona 4 con faltantes en las zonas 4 y 5
CUANDO cruza a la zona 5 ENTONCES hay uno solo, en la misma posición de la lista.

### AC-NTF-035 — La jornada 1 y las jornadas sin reponer no avisan *(verifica BR-NTF-016)*

DADO la jornada 1 con unidades agarradas o vendidas desde las góndolas de la zona 4 CUANDO el
jugador está en la zona 4 ENTONCES hay cero avisos de falta reponer, aunque haya casilleros
vacíos. DADO una jornada que declara reponer y un jugador en una zona sin faltantes ENTONCES hay
cero. DADO el turno cerrado y el jugador dentro de una zona con faltante ENTONCES hay cero.

### AC-NTF-036 — Convive sin darle temporizador ni quitárselo a otros *(verifica BR-NTF-016, BR-NTF-003, BR-NTF-004, BR-NTF-005, BR-NTF-006)*

DADO el aviso de falta reponer visible CUANDO se avisan una lectura fallida y luego un cansancio
ENTONCES la lista es cansancio, lectura fallida, falta reponer. CUANDO se consumen 2,9 segundos
ENTONCES siguen los tres; al completar 3,0 queda sólo falta reponer. DADO que se avisa otra lectura
fallida con falta reponer visible ENTONCES hay un solo aviso de cada tipo. CUANDO cierra el turno
ENTONCES hay cero, y la siguiente noche empieza sin el aviso hasta que el jugador entre en una
zona con faltante.

### AC-NTF-037 — Texto y presentación comunes *(verifica BR-NTF-016, BR-NTF-007)*

DADO el aviso de falta reponer a 1920 × 1080 y 1280 × 720 CUANDO se dibuja ENTONCES muestra en
mayúsculas «Falta reponer productos por acá» completo y sin punto final, en una sola línea, con
símbolo a la izquierda, fondo claro y fuente principal del tema. Su cartel ajusta el ancho al
contenido, comparte el borde derecho de la pila, queda dentro de pantalla, encima de las
interfaces y debajo de la pausa, y deja pasar clics.

## No objetivos

- Esta capacidad NO decide cuándo llegan o se despachan compradores ni acepta lecturas.
- Esta capacidad NO decide el abandono del comprador ni qué es una pista o qué hipótesis desbloquea.
- Esta capacidad NO incorpora logros.
- Esta capacidad NO guarda avisos entre sesiones.

## Contratos

- **Entrada:** identidad de quien llega o vence, motivo de lectura, confirmación de pista nueva
  anotada por investigación, tiempo en ejecución, tiempo restante de ficción del turno abierto,
  salida habilitada o vuelta a trabar, computadora abierta o cerrada, si la zona de reposición
  donde está el jugador tiene faltante y cierre.
- **Salida:** tipos visibles ordenados, texto y símbolo correspondientes.
- **Falla:** identidad nula, motivo que no es lector lleno y tiempo no positivo no cambian nada.
  Una pista repetida o desconocida y una revelación sin pista no crean ni renuevan avisos.
  Una zona inexistente, o el jugador fuera de las siete zonas, cuentan como sin faltante.

## Señales

- Escucha llegada, vencimiento, rechazo, pista nueva anotada, tiempo restante, salida habilitada
  o vuelta a trabar, zona con faltante donde está el jugador y cierre.
  No emite decisiones a las capacidades que los publican.

## Dependencias

- `counter-service` (consume): comprador llegado o vencido y motivo del rechazo del lector.
- `shift-cycle` (consume): apertura, duración, tiempo restante y cierre del turno.
- `player-actions` (consume): suspensión del procesamiento durante la pausa.
- [`investigation`](../investigation/investigation.md) (consume): confirmación de pista nueva
  anotada que desbloquea una hipótesis; una revelación de objeto no reemplaza esa confirmación.
- [`store-stock`](../store-stock/store-stock.md) (consume): la zona de reposición donde está el
  jugador y si tiene faltante (BR-STK-052).

## Preguntas abiertas

Ninguna para estos tipos. Los demás disparadores están fuera de sus objetivos.
El texto del aviso de cierre próximo debe comunicar la hora restante.
El diseño no prescribe una frase literal ni una ilustración específica.
