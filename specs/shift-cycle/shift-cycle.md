---
schema_version: 1
capability_id: CAP-SHF
status: ratified
owner: por definir
provenance: GDD «Ciclo de jornadas»; fichas «Pantalla entre jornadas» y «Particulares de cada jornada»; decisiones de #364, #369, #436, #526, #527, #573, #691 y #693; migración de los specs 001, 007, 011, 016, 027, 031; quejas de la jornada 7 de #759, ficha «Particulares de cada jornada»; la ficha «Caminos narrativos y finales» y la fila «7B» de la lista de pistas e hipótesis, de #790; la sección «Epílogos» de la ficha «Caminos narrativos y finales», leída el 2026-11-05, de #836; cajas del proveedor de #788, filas «Caja de cartón del proveedor» y «Caja de madera» de «Objetos interactuables» leídas el 2026-11-04; hora del celular de #613, decisiones del 2026-10-29, 2026-10-30 y 2026-11-02; pantalla de final con tip y botones de #827, ficha «Pantalla de fin de juego» leída el 2026-11-05; textos de cierre de los finales 4 y 5 de #872, misma ficha leída el 2026-11-06
---

# Capacidad: el ciclo de la jornada

## Propósito

Repartir una noche de tiempo finito entre las tareas del jefe y la investigación. Lo único
que tiene que hacer bien es la resta: el tiempo pasa igual, se haga lo que se haga, y **cada
minuto investigando es un minuto que no se dedica a las tareas**.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Turno** | el presupuesto de tiempo de una noche, en segundos de ficción | nivel, ronda |
| **Jornada** | una noche de la partida, numerada desde 1 | día, nivel |
| **Obligatoria** | una de las tareas que el jefe pide esta noche | misión, objetivo |
| **Ritmo** | cuántos segundos de turno consume un segundo real | escala, velocidad |
| **Hora** | la hora de ficción de la noche, de la apertura al cierre | tiempo restante, cuenta regresiva |
| **Reloj** | el reloj de pared del local; con la barra de estado del celular, los dos únicos lugares donde se lee la hora en vivo (el ticket guarda la hora en que se imprimió) | HUD |

## Comportamiento normativo

### BR-SHF-001 — La noche dura doce horas de ficción

El sistema DEBE dar a cada jornada un turno de **43 200 segundos** de ficción, de las 20:00 a las
08:00.

### BR-SHF-002 — La sesión dura lo mismo en toda jornada

El sistema DEBE convertir el tiempo real a tiempo de turno con un ritmo tal que **la duración
real de la jornada cubra el turno entero**: 720 segundos reales, un minuto real por hora de
ficción, el mismo en toda jornada. El ritmo vale `43 200 ÷ 720`. Cumplir las tareas NO DEBE
cambiar ese ritmo.

### BR-SHF-003 — El tiempo entra, no se busca

CUANDO pasa tiempo real de juego, el sistema DEBE recibir cuántos segundos pasaron y descontarlos
del turno. El turno nunca lee un reloj propio. Un valor que no es positivo no descuenta nada. El
tiempo real es lo único que descuenta del turno: cumplir una obligatoria no lo mueve. El tiempo
en pausa no es tiempo de juego y NO DEBE descontar. Cambiar de pestaña, minimizar o pasar a otra
ventana no es una pausa: ese tiempo DEBE descontarse, también si el navegador suspendió los
cuadros y sólo permite actualizar la jornada al volver. La entrada de la noche, desde que aparece
la placa hasta que termina de subir la persiana, NO DEBE descontar turno, tampoco al cambiar de
pestaña. Soltar esa retención DEBE continuar desde el presupuesto conservado, sin cobrar el
intervalo retenido. Las instrucciones previas a una noche tampoco son tiempo de juego.

### BR-SHF-004 — El turno no baja de cero

MIENTRAS queda turno, el sistema DEBE descontar hasta cero y no más. Con cero o menos, el turno
está cerrado.

### BR-SHF-005 — Las obligatorias de cada jornada

CUANDO se abre una jornada, el sistema DEBE pedir las obligatorias que esa jornada declara. Las
cuatro fijas son cobrar en la caja, registrar, limpiar y reponer. Las dos primeras jornadas
son de introducción: las tareas entran de a poco.

| Jornada | Obligatorias |
|---|---|
| 1 | cobrar en la caja, registrar y reponer |
| 2 | las cuatro fijas |
| 3 | las cuatro fijas y ordenar las cajas del depósito |
| 4 | las cuatro fijas y tirar la basura |
| 5 | las cuatro fijas y desechar los Cindolor vencidos |
| 6 | las cuatro fijas y hacerle un pedido al proveedor |
| 7 | las cuatro fijas y responder a las quejas de los compradores |

Una jornada sin fila propia DEBE declarar sólo las cuatro fijas. Cada apertura DEBE crear tareas
nuevas, sin cumplir.

La jornada 1 declara reposición: los casilleros que el jugador vacía al vender son huecos que
repone. La nota de tareas DEBE listar sólo las obligatorias declaradas para esa noche.

### BR-SHF-007 — Una obligatoria cuenta mientras su condición vale, y antes del cierre

MIENTRAS queda turno, el sistema DEBE contar la obligatoria que se cumple, sin importar cuánto
turno quede, y DEBE dejar de contarla si su condición deja de valer. SI la tarea ya está
cumplida, ENTONCES cumplirla otra vez NO DEBE contarla dos veces. SI la tarea no está cumplida,
ENTONCES descumplirla NO DEBE descontar nada. SI el turno está cerrado, ENTONCES el sistema DEBE
rechazar cumplir y descumplir: el cierre cuenta el estado de ese instante.

### BR-SHF-008 — Sólo cuentan las declaradas

El sistema DEBE contar como cumplidas sólo las obligatorias que la jornada declaró. Una tarea
cumplida fuera de esa lista no cuenta.

### BR-SHF-026 — Desechar los vencidos cuenta cuando están los cinco en el contenedor

MIENTRAS queda turno y la jornada declara desechar los Cindolor vencidos, el sistema DEBE contar
esa obligatoria cuando los cinco Cindolor vencidos de la noche (BR-STK-052) están en el
contenedor, y no antes. Un vencido que sigue en la góndola, que se lleva en la mano, que quedó
suelto en el local o que se tiró por la ventana NO DEBE contar como desechado. Tirar al
contenedor además un Cindolor sano u otro objeto NO DEBE impedir ni deshacer el cumplimiento; el
llamado que eso suma es de [`employment-record`](../employment-record/employment-record.md).
Reponer los casilleros que dejaron los vencidos no interviene en esta obligatoria, pero sí en
reponer (BR-STK-052).

### BR-SHF-031 — La jornada 6 pide el pedido al proveedor

CUANDO se abre la jornada 6, el sistema DEBE declarar, además de las cuatro fijas, hacerle un
pedido al proveedor, y la nota de tareas DEBE listarla como «Hacerle un pedido al proveedor». Las
demás jornadas NO DEBEN declararla.

### BR-SHF-032 — El pedido cuenta cuando es exacto y salió con wifi

MIENTRAS queda turno y la jornada declara el pedido al proveedor, el sistema DEBE contar esa
obligatoria cuando el último pedido enviado con wifi (BR-INV-125) tiene exactamente los productos
de las cinco cajas vacías de la noche (BR-STK-055): ni uno más ni uno menos, en cualquier orden.
Un pedido enviado sin wifi NO DEBE contar ni reemplazar al último enviado con wifi. SI después de
cumplida sale con wifi otro pedido que no es exacto, ENTONCES el sistema DEBE dejarla sin cumplir;
SI sale con wifi uno exacto, ENTONCES vuelve a contar. Sin ningún pedido enviado con wifi, queda
sin cumplir. Un pedido que sale con el turno cerrado NO DEBE cambiar el cierre (BR-SHF-007).

### BR-SHF-027 — Al terminar la partida, la devolución lleva a la pantalla de final

CUANDO la partida termina despedida, o termina con el contrato cumplido (BR-INV-103), el sistema
DEBE llevar la única opción de la devolución del cierre a una pantalla de final, y no al menú. La
pantalla DEBE mostrar su encabezado, su título, lo que lleva entre el título y los botones
(BR-SHF-070) y sus dos botones (BR-SHF-071).

- El despido DEBE llevar el encabezado «/ FIN DEL JUEGO» y el título «DESPEDIDO». Vale para todos
  los despidos, incluido el de la prueba.
- El contrato cumplido sin ninguna pista DEBE llevar el encabezado «/ FINAL 1» y el título
  «EMPLEADO EXPLOTADO».
- El contrato cumplido con al menos una pista, de cualquier jornada, DEBE llevar el encabezado
  «/ FINAL 2» y el título «LOCURA PARANOICA».
- SI la partida termina despedida, ENTONCES la pantalla DEBE ser la del despido aunque haya o no
  pistas.
- La partida en curso NO DEBE mostrar pantalla de final: la única opción de la devolución sigue a
  la jornada siguiente. Los finales 4 y 5 no pasan por la devolución (BR-SHF-060, BR-SHF-061).
- Los finales 1 y 2 DEBEN mostrar antes su epílogo (BR-SHF-072); el despido no.

Elegir la opción de la devolución dos veces NO DEBE mostrar dos pantallas. El guardado se borra
igual que sin la pantalla (BR-SAV-002).

### BR-SHF-070 — El despido lleva un tip y los finales su texto de cierre

CUANDO se muestra la pantalla del despido, el sistema DEBE mostrar entre el título y los botones
uno de los cinco tips de la tabla, con su texto literal, elegido al azar al mostrar la pantalla. El
tip NO DEBE cambiar mientras esa pantalla sigue a la vista.

| Nº | Tip |
|---|---|
| 1 | Prestá atención a las pautas anotadas en el corcho. Dejar el local desordenado va a hacer que Enrique esté más inclinado a despedirte. |
| 2 | Tené en cuenta que podés agarrar directamente del depósito los productos que vendas. Así, no vas a necesitar reponerlos después. |
| 3 | Buscá manchas de suciedad en todos los rincones. A veces, pueden estar en los lugares que menos esperás. |
| 4 | ¡No dejes de anotar los productos vendidos en la computadora! Podés hacerlo antes de dárselos al cliente, para no olvidarte. |
| 5 | ¡Priorizá la atención al cliente! Tenés toda la noche para hacer las demás tareas, pero los compradores pueden cansarse e irse. |

CUANDO se muestra la pantalla de un final narrativo, el sistema NO DEBE mostrar ningún tip: DEBE
mostrar en su lugar el texto de cierre de ese final, con su texto literal, en los renglones que
indica la tabla.

| Final | Texto de cierre |
|---|---|
| 1 | Conseguiste ignorar tus instintos paranoicos. / ¿Pero a qué costo? ¿Es esta la “cordura” que querías preservar? |
| 2 | Perdiste el rastro. No pudiste encontrar suficientes pistas como para elaborar una hipótesis sólida. Tal vez la próxima… |
| 4 | La unión hace la fuerza. Pero no garantiza la estabilidad laboral… |
| 5 | El pueblo unido jamás será vencido. |

La barra «/» de la tabla separa los dos renglones del final 1.

### BR-SHF-071 — La pantalla de final ofrece comenzar de nuevo o volver al menú

La pantalla de final DEBE ofrecer, abajo de todo, dos botones: «COMENZAR NUEVA PARTIDA» arriba y
«VOLVER AL MENÚ» abajo. Al mostrarse, el foco DEBE estar en «COMENZAR NUEVA PARTIDA». Vale para el
despido y para todos los finales con pantalla.

- CUANDO se pulsa «COMENZAR NUEVA PARTIDA», el sistema DEBE borrar el guardado y arrancar una
  partida nueva en la jornada 1, igual que «Nuevo juego» del menú de inicio, sin pasar por el menú.
- CUANDO se pulsa «VOLVER AL MENÚ», el sistema DEBE salir al menú, sin abrir ninguna jornada.
- Pulsar un botón dos veces, o pulsar uno y después el otro, NO DEBE pedir una segunda salida.

### BR-SHF-060 — Abrir la puerta del jefe con la palanca termina la partida en el final 4

CUANDO la puerta de la oficina de Enrique se abre con la palanca en la jornada 7 (BR-PLY-060,
BR-INV-142), el sistema DEBE terminar en ese momento la jornada y la partida con el final 4, sin
devolución del jefe, sin cierre de la jornada y sin elección de hipótesis. La jornada NO DEBE
evaluarse: las tareas pendientes, el turno que queda y los llamados no deciden nada, y la partida
no puede terminar despedida ni con el contrato cumplido por esa jornada.

La pantalla de final DEBE mostrarse en ese mismo paso, con el encabezado «/ FINAL 4», el título
«JEFE SABOTEADOR» y sus dos botones (BR-SHF-071). Accionar otra vez la puerta NO DEBE mostrar dos
pantallas. El guardado se borra (BR-SAV-002). El epílogo de este final (BR-SHF-072) va entre la
puerta y la pantalla; mientras ninguna de sus placas tenga texto, NO DEBE intercalarse nada.

### BR-SHF-061 — Abrir la puerta del jefe con la llave termina la partida en el final 5

CUANDO la puerta de la oficina de Enrique se abre con la llave en la jornada 7 (BR-PLY-060,
BR-INV-145), el sistema DEBE terminar en ese momento la jornada y la partida con el final 5, con
las mismas garantías que el final 4 (BR-SHF-060): sin devolución del jefe, sin cierre de la
jornada, sin elección de hipótesis y sin evaluar la noche.

La pantalla de final DEBE mostrarse después del epílogo de este final (BR-SHF-072), con el
encabezado «/ FINAL 5», el título «JEFE INCOMPETENTE» y sus dos botones (BR-SHF-071). Accionar otra
vez la puerta NO DEBE mostrar dos pantallas. El guardado se borra (BR-SAV-002).

### BR-SHF-072 — Los finales narrativos pasan por su epílogo antes de su pantalla

CUANDO la partida termina en un final con epílogo, el sistema DEBE mostrar ese epílogo antes de la
pantalla de final, y llevar de ahí a la pantalla. Un final tiene epílogo si al menos una de sus
placas tiene texto. Los finales 1, 2 y 5 lo tienen; el final 4 no lo tiene mientras ninguna de sus
placas tenga texto; el despido nunca lo tiene.

- La transición hacia cada placa DEBE ser un fundido a negro de 1 segundo seguido de un fundido de
  entrada de 1 segundo. La misma transición DEBE llevar de la última placa a la pantalla de final.
- SI el final no tiene epílogo, ENTONCES el sistema DEBE ir directo a la pantalla de final, sin
  fundido ni pantalla intermedia.
- El epílogo DEBE mostrar sus placas en el orden de la ficha «Caminos narrativos y finales». Una
  placa sin texto NO DEBE mostrarse; cuando la ficha le cargue texto, pasa a mostrarse sin otro
  cambio.

### BR-SHF-073 — Cada placa trae su fondo, su texto y SIGUIENTE

CADA placa DEBE mostrar la imagen de fondo de su final, su texto y un botón «SIGUIENTE» debajo del
texto. El texto DEBE ser el de la ficha, con los saltos de renglón que la ficha marca. CUANDO se
acciona «SIGUIENTE», el sistema DEBE pasar a la placa siguiente, o a la pantalla de final si era
la última. Un final con una sola placa lleva de su única placa a la pantalla de final.

- El final 1 DEBE tener 6 placas, el final 2 DEBE tener 2 y el final 5 DEBE tener 7.
- Las placas de un mismo final DEBEN compartir su imagen de fondo; cada final usa la suya.

### BR-SHF-074 — Mientras se ve el epílogo, el juego queda quieto

MIENTRAS se ve el epílogo, incluidos sus fundidos, el jugador NO DEBE moverse ni accionar nada del
almacén, el reloj de la noche NO DEBE avanzar y la tecla de pausa NO DEBE abrir el menú de pausa.
«SIGUIENTE» DEBE poder accionarse con el mouse, con el teclado y con el joystick.

Accionar «SIGUIENTE» durante un fundido, o dos veces seguidas, NO DEBE saltear ni repetir una
placa, ni mostrar la pantalla de final antes de tiempo.

### BR-SHF-030 — Responder a las quejas cuenta cuando las cinco tienen respuesta correcta

MIENTRAS queda turno y la jornada declara responder a las quejas, el sistema DEBE contar esa
obligatoria cuando las cinco quejas de la noche tienen respuesta y todas son correctas
(BR-INV-112), y no antes. Una queja sin responder o una respuesta equivocada NO DEBE contar:
una respuesta no se corrige, así que con una equivocada la obligatoria queda sin cumplir hasta
el cierre. Una jornada que cierra antes de tiempo cuenta las quejas sin responder como falla.
CUANDO la noche cierra con esta obligatoria sin cumplir, la devolución del jefe DEBE traer su
Tarea 5 (BR-EMP-027). Las jornadas 1 a 6 NO DEBEN declarar esta obligatoria.

### BR-SHF-011 — La hora se lee en el reloj de pared y en el celular

El sistema DEBE mostrar la hora del turno en vivo sólo en el reloj de pared del local y en la barra
de estado del celular (BR-SHF-040): ni en el HUD, ni en la computadora. El ticket impreso conserva
la hora de su impresión (AC-PLY-107). SI es la sexta jornada y la hora de ficción alcanzó las
20:58, ENTONCES el reloj DEBE leer `20:58` hasta el cierre, también después de restablecer la
electricidad, y el turno DEBE seguir descontando con su presupuesto y su ritmo. El reloj NO DEBE
quedar en blanco en ningún momento de ninguna noche. Las otras jornadas, incluida la que todavía
no se declaró, y la sexta antes de las 20:58, el reloj DEBE leer la hora.

### BR-SHF-012 — La lectura trunca y no miente

CUANDO se lee la hora, el sistema DEBE truncar al minuto y nunca redondear hacia arriba. Con cero
o menos de turno, DEBE leer la hora de cierre: nunca una hora pasada del cierre.

### BR-SHF-014 — La lectura es la hora de la noche

CUANDO se lee el reloj, el sistema DEBE contestar la hora de apertura más lo que ya pasó del
turno, en `HH:MM` de 24 horas. La hora de apertura y la duración viven una sola vez en las
reglas del juego.

### BR-SHF-040 — El celular lee la hora del turno y no se detiene con el reloj

MIENTRAS el turno corre, el celular DEBE leer la hora de la noche con la misma lectura que el
reloj de pared (BR-SHF-012 y BR-SHF-014): truncada al minuto y en `HH:MM` de 24 horas, sin saltos
al pasar la medianoche. La hora del celular NO DEBE detenerse con el reloj de pared: la sexta
noche, con el reloj leyendo `20:58` hasta el cierre (BR-SHF-011), el celular DEBE seguir
avanzando con el turno. MIENTRAS el turno no descuenta (BR-SHF-003), la hora del celular NO DEBE
cambiar.

### BR-SHF-041 — Entre jornadas el celular lee la hora de cierre

CUANDO el turno cierra, y hasta que se abre otra jornada, el celular DEBE leer la hora de cierre
(BR-SHF-012), y NO DEBE quedar en blanco ni leer la hora en que el jugador se fue.

### BR-SHF-019 — La persiana anuncia la noche antes de jugar

CUANDO se entra a una jornada desde el menú o al seguir desde el cierre, el sistema DEBE mostrar
la persiana baja con la placa «NOCHE N», donde N es la jornada que se abre, sin puntos suspensivos.
La placa DEBE desaparecer con un fade de opacidad 1 a 0 y la persiana DEBE subir de apertura 0 a
1, sin invertir ninguno de los avances. Hasta terminar la subida, el control del jugador DEBE
estar suspendido; al terminar, la entrada DEBE desaparecer y devolver el control una sola vez.
Un tiempo real no positivo NO DEBE avanzar la entrada. La pausa DEBE congelarla y reanudarla
desde el mismo punto. Cambiar de pestaña NO DEBE saltearla. SI el cierre tiene una reflexión
pendiente (BR-INV-042), ENTONCES la entrada NO DEBE empezar hasta que esa reflexión termine, y
MIENTRAS tanto el turno de la jornada siguiente NO DEBE descontar.

La entrada DEBE dibujarse encima del HUD, las interfaces diegéticas y el cierre, y debajo de
los avisos y la pausa. Un segundo pedido de seguir el mismo cierre NO DEBE anunciar otra noche.
Una partida terminada que vuelve al menú NO DEBE anunciar una noche nueva. La placa DEBE
permanecer entera 1 segundo y desaparecer durante los siguientes 0,5 segundos. Sólo después
DEBE subir la persiana durante 1 segundo, sin superponer ambos movimientos: la entrada completa
DEBE durar 2,5 segundos reales.

### BR-SHF-021 — Las jornadas de prueba permiten irse al completar todas las tareas

MIENTRAS está abierta una jornada anterior a la primera jornada completa, CUANDO todas sus
obligatorias declaradas están cumplidas, el sistema DEBE habilitar la salida por la entrada
principal en ese instante y producir el aviso de BR-NTF-014, que espera a que el jugador
salga de la computadora si está abierta. Registrar DEBE estar cumplido igual que las demás.
Un registro que sólo quedaría cumplido al cierre NO DEBE sustituir su cumplimiento durante
la noche, salvo en el caso de abajo.

La atención al cliente cuenta para esta salida cuando ya no queda comprador por atender: todos
llegaron y cada uno quedó vendido o se fue. Atender a alguno mal NO DEBE trabar la salida. Un
comprador que no llegó o que está en la ventanilla SÍ DEBE trabarla. En ese mismo momento,
registrar también cuenta si su planilla coincide con lo vendido, aunque sin ventas ese cero
sólo se cumpla al cierre. Esas dos tareas siguen incumplidas para la devolución y el puntaje de
la noche: esta regla sólo decide el permiso.

Cumplir las tareas NO DEBE acelerar el reloj ni cerrar la jornada automáticamente. Si el
jugador no sale, el turno DEBE continuar a su ritmo normal hasta el cierre habitual.
Desde la primera jornada completa, el sistema NO DEBE ofrecer esta salida ni producir su aviso.

### BR-SHF-024 — La salida sigue el cumplimiento actual

MIENTRAS sigue abierta una jornada de prueba, SI alguna obligatoria deja de estar cumplida
después de habilitar la salida, ENTONCES el sistema DEBE volver a trabar la entrada en ese
instante y retirar el aviso de BR-NTF-014. Cuando todas vuelven a estar cumplidas, el sistema DEBE habilitar la
salida otra vez. Una confirmación repetida del mismo estado NO DEBE producir otra transición.

El aviso de salida NO DEBE fijar el cumplimiento de las tareas ni impedir los gestos que las
modifican. La planilla DEBE conservar sus operaciones de sumar y restar según BR-STK-020.
El cierre, por la puerta o por tiempo, DEBE contar el cumplimiento vigente de BR-SHF-007.
Abrir o retomar una jornada DEBE evaluar sus tareas propias sin heredar el permiso anterior.

### BR-SHF-025 — La salida voluntaria mira y abre antes de bajar la persiana

CUANDO el jugador sale por la entrada habilitada de BR-SHF-021 en las jornadas 1 y 2,
el sistema DEBE tomar el control de la vista y llevar la cámara suavemente desde su pose
visible hasta una pose frontal al vano de entrada, sin saltos y con un giro de como máximo
180 grados. La pose frontal DEBE estar centrada entre las dos hojas, sobre la perpendicular
al vano del lado del interior, con la mirada horizontal y perpendicular al vano, y a una
distancia desde la que se ven las dos hojas, el marco y la calle. La entrada DEBE tener dos
hojas, cada una con su bisagra en el canto exterior del vano. Sólo después de terminar ese
recorrido DEBE abrir ambas
hojas hacia el mismo lado del vano, cada una sobre su bisagra, con la animación y el sonido
habituales. Ninguna hoja DEBE desprenderse de su marco ni cruzar el vidrio fijo. Sólo después
de que ambas hojas alcancen su apertura completa DEBE bajar la persiana y continuar la
devolución y el guardado del cierre habitual.

MIENTRAS transcurre la salida, el jugador NO DEBE caminar, controlar la mirada ni interactuar,
y DEBE conservar lo sostenido. La pausa DEBE congelar la secuencia y reanudarla desde el
mismo punto, sin devolver el control al jugador. Pedidos repetidos de salida o de cierre
NO DEBEN repetir la secuencia, la devolución ni el guardado. El cierre por tiempo sin salir
por la puerta DEBE conservar su recorrido habitual sin girar la vista ni abrir la entrada.
Al comenzar cada jornada, incluidas la jornada 3 y las posteriores, ambas hojas DEBEN estar
cerradas, tanto al continuar desde la anterior como al retomar desde el menú o reintentar la
noche. Desde la jornada 3 la entrada NO DEBE permitir salir.

### BR-SHF-050 — En la jornada 7 el proveedor deja dos cajas junto al portón

CUANDO se abre la jornada 7, el sistema DEBE poner en el depósito dos objetos fijos: una caja de
cartón del proveedor y una caja de madera de Fernet God. La caja de cartón DEBE quedar junto al
portón del depósito, ligeramente en diagonal y casi pegada a la pared contraria a la del
contenedor de basura. La caja de madera DEBE quedar entre la caja de cartón y la estantería más
cercana, también casi pegada a esa pared, con su tapa apoyada sobre ella. Las jornadas 1 a 6
NO DEBEN tener ninguna de las dos.

Las dos DEBEN estar en la jornada 7 aunque no se haya hecho el pedido al proveedor, y también al
retomar una partida guardada en esa jornada: salen de la jornada, no de un estado.

Ninguna DEBE poder levantarse ni empujarse, y las dos DEBEN poder examinarse (BR-SUB-010 de
[`subtitles`](../subtitles/subtitles.md)). Lo levantable DEBE poder apoyarse encima, como en el
resto de lo fijo. Tocarlas NO DEBE sonar. Ninguna es una caja de productos del depósito: NO DEBE
contar para ordenar las cajas, para la reposición ni para la revisión del depósito.

Dónde queda cada una, su diagonal y que la tapa se vea apoyada son territorio de juicio humano.

## Criterios de aceptación

### AC-SHF-001 — El turno de la noche *(verifica BR-SHF-001)*

DADO una jornada que se abre CUANDO se mira su turno ENTONCES el presupuesto es `43200.0`
segundos.

### AC-SHF-002 — La duración de cada jornada *(verifica BR-SHF-002)*

DADO el ritmo de cada jornada CUANDO se escala su duración real ENTONCES el resultado es
exactamente la duración del turno: `720.0` segundos en la 1, en la 2 y en la 7. Un segundo real
escala a `60.0` en todas. Una jornada sin fila, como la 0, escala un segundo real a `60.0`.

### AC-SHF-003 — El tiempo negativo no mueve nada *(verifica BR-SHF-003)*

DADO un turno de `100.0` CUANDO se consumen `-5.0` segundos ENTONCES quedan `100.0`.

### AC-SHF-004 — El piso es cero *(verifica BR-SHF-004)*

DADO un turno de `100.0` CUANDO se consumen `250.0` segundos ENTONCES quedan `0.0` y el turno
está cerrado.

### AC-SHF-005 — Fijas y particular, con instancias nuevas *(verifica BR-SHF-005)*

DADO las jornadas 1 a 7 CUANDO cada una pide sus obligatorias ENTONCES la 1 recibe 3:
cobrar, registrar y reponer, sin limpiar ni particular; la 2 recibe las 4 fijas; la 3 recibe 5,
con ordenar las cajas y sin basura; la 4 recibe 5, con basura y sin ordenar; la 5 recibe 5, con
desechar los Cindolor vencidos y sin ordenar ni basura; la 6 recibe 5, con el pedido al proveedor y sin ordenar, basura ni vencidos; la 7 recibe 5, con responder a las quejas y sin ordenar, basura ni vencidos. DADO dos aperturas seguidas CUANDO se comparan sus tareas ENTONCES ninguna instancia se
comparte y todas las de la segunda están sin cumplir. DADO la jornada 1 recién abierta ENTONCES la
nota de tareas lista atención, registro y reposición, sin limpieza.

### AC-SHF-059 — Los vencidos cuentan al llegar el quinto al contenedor *(verifica BR-SHF-026)*

DADO la jornada 5 con sus cinco Cindolor vencidos CUANDO se tiran al contenedor uno por uno
ENTONCES con uno, dos, tres y cuatro tirados la obligatoria sigue sin cumplir, y con el quinto
queda cumplida. DADO que el quinto ya está tirado CUANDO se tira cualquier otro objeto ENTONCES
sigue cumplida y la cuenta de cumplidas no sube dos veces.

### AC-SHF-060 — Tirar de más no impide cumplir *(verifica BR-SHF-026)*

DADO la jornada 5 con los cinco vencidos y un Cindolor sano tirados al contenedor ENTONCES
desechar los vencidos está cumplida. DADO un Cindolor sano tirado y sólo cuatro vencidos ENTONCES
sigue sin cumplir: el sano no suple al quinto.

### AC-SHF-061 — Fuera del contenedor no cuenta *(verifica BR-SHF-026)*

DADO la jornada 5 con cuatro vencidos en el contenedor CUANDO el quinto queda en su casillero
de la góndola, en la mano, suelto en el local o tirado por la ventana, y cierra el turno
ENTONCES desechar los vencidos queda sin cumplir. DADO ese quinto tirado después al contenedor
antes del cierre ENTONCES queda cumplida.

### AC-SHF-007 — El borde del cierre *(verifica BR-SHF-007)*

DADO un turno con `1.0` segundo restante CUANDO se cumple cualquiera de las obligatorias declaradas
ENTONCES cuenta, y quedan `1.0`. DADO un turno con `0.0` restantes, cerrado, CUANDO se cumple una
ENTONCES se rechaza y las cumplidas no suben.

### AC-SHF-008 — Cumplir dos veces *(verifica BR-SHF-007)*

DADO una obligatoria ya cumplida CUANDO se la vuelve a cumplir ENTONCES se rechaza, el turno no
baja y la cuenta de cumplidas no sube.

### AC-SHF-009 — La tarea de afuera no cuenta *(verifica BR-SHF-008)*

DADO una jornada con dos obligatorias declaradas CUANDO se cumple una tercera tarea que no
estaba declarada ENTONCES no cuenta, las cumplidas siguen siendo las de la lista y el turno
restante no cambió.

### AC-SHF-014 — La lectura trunca *(verifica BR-SHF-012)*

DADO una jornada que no es la sexta con `43141.0` segundos restantes ENTONCES el reloj lee `"20:00"`; con `43140.0`, `"20:01"`; con
`-10.0`, `"08:00"`.

### AC-SHF-016 — La hora de la noche *(verifica BR-SHF-014)*

DADO una jornada que no es la sexta CUANDO se lee el reloj ENTONCES:

| Quedan | Se lee |
|---|---|
| `43200.0` | `"20:00"` |
| `28801.0` | `"23:59"` |
| `28799.0` | `"00:00"` |
| `21600.0` | `"02:00"` |
| `14400.0` | `"04:00"` |
| `0.0` | `"08:00"` |

### AC-SHF-017 — Un solo reloj *(verifica BR-SHF-011)*

DADO el local armado CUANDO se recorren los nodos del local ENTONCES hay exactamente una lectura
de la hora, cuelga del reloj de pared y no gira hacia la cámara. La otra lectura de la hora es la
barra de estado del celular (AC-SHF-120).

### AC-SHF-018 — Cumplir no mueve el turno *(verifica BR-SHF-003)*

DADO un turno de `43200.0` CUANDO se cumplen todas las obligatorias declaradas en el mismo cuadro
ENTONCES cuentan todas las declaradas y quedan `43200.0`.

### AC-SHF-019 — Descumplir *(verifica BR-SHF-007)*

DADO una obligatoria cumplida con el turno abierto CUANDO se descumple ENTONCES las cumplidas
bajan en 1 y el turno restante no cambia; cumplirla de nuevo las deja como antes de descumplir.
DADO una obligatoria sin cumplir CUANDO se descumple ENTONCES se rechaza y las cumplidas no
cambian. DADO una obligatoria cumplida con el turno cerrado CUANDO se descumple ENTONCES se
rechaza y sigue contando.

### AC-SHF-020 — La pausa detiene el turno *(verifica BR-SHF-003)*

DADO un turno abierto CUANDO el juego está en pausa y pasan cuadros ENTONCES el tiempo restante
no cambia. CUANDO se reanuda ENTONCES el turno sigue descontando desde ese mismo valor.

### AC-SHF-021 — Cambiar de pestaña no regala tiempo *(verifica BR-SHF-003)*

DADO un turno abierto sin pausa manual CUANDO pasan 10 segundos reales sin cuadros por cambiar
de pestaña ENTONCES al volver se descuentan esos 10 segundos, sin repetirlos en el cuadro
siguiente. DADO el mismo turno en pausa manual CUANDO pasan 10 segundos y se reanuda ENTONCES
esos 10 segundos no se descuentan. DADO menos tiempo restante que la ausencia CUANDO se vuelve
ENTONCES el turno cierra una sola vez y el tiempo restante es cero.

### AC-SHF-022 — La entrada progresa hasta su duración *(verifica BR-SHF-019)*

DADO la entrada de la jornada 3 CUANDO han pasado 1 segundo ENTONCES la placa anuncia
«NOCHE 3», su opacidad es 1, la persiana está baja y la entrada no terminó. A los 1,25 segundos
la opacidad es 0,5 y la persiana sigue baja. A los 1,5 segundos la opacidad es 0 y la apertura
es 0; a los 2 segundos la apertura es 0,5 y la entrada no terminó; a los 2,5 segundos la apertura
es 1 y terminó. Al muestrear el avance, la opacidad nunca sube y la apertura nunca baja, ambas
entre 0 y 1. Avanzar 0 o −1 segundos conserva ambos valores.

### AC-SHF-023 — Retener no cobra al soltar *(verifica BR-SHF-003)*

DADO un turno abierto retenido en su entrada CUANDO pasan cuadros durante 10 segundos reales,
incluido un intervalo sin foco, ENTONCES el tiempo restante no cambia. CUANDO termina la entrada
y pasa un segundo de juego ENTONCES se descuenta sólo ese segundo escalado al ritmo del turno,
sin cobrar los 10 retenidos ni descontarlos en el cuadro siguiente.

### AC-SHF-024 — Seguir anuncia la jornada siguiente una vez *(verifica BR-SHF-019, BR-SHF-003)*

DADO el cierre de la jornada 3 con su reflexión terminada CUANDO se pide seguir dos veces
ENTONCES aparece una sola entrada
«NOCHE 4», la persiana empieza baja, el control está suspendido y los cuadros no descuentan turno.
CUANDO termina de subir ENTONCES la entrada ya no está visible, el control está activo y el turno
descuenta desde el valor conservado. DADO una partida terminada CUANDO vuelve al menú ENTONCES
no aparece una entrada nueva.

### AC-SHF-025 — El menú anuncia la jornada que abre *(verifica BR-SHF-019)*

DADO un juego nuevo CUANDO termina su preparación previa ENTONCES la entrada dice «NOCHE 1».
DADO continuar con la jornada 5 guardada CUANDO se entra ENTONCES dice «NOCHE 5».

### AC-SHF-026 — Pausar congela la entrada y conserva la pila visual *(verifica BR-SHF-019, BR-SHF-003)*

DADO la entrada a mitad de su avance CUANDO se pulsa Esc y pasan cuadros ENTONCES opacidad,
apertura y turno conservan sus valores. CUANDO se reanuda ENTONCES la entrada sigue desde esos
valores. DADO HUD, interfaces, cierre, entrada, avisos y pausa superpuestos CUANDO se compara
su orden de dibujo ENTONCES la entrada está sobre los tres primeros y debajo de los dos últimos.

### AC-SHF-028 — La reflexión retiene la entrada *(verifica BR-SHF-019)*

DADO el cierre de la jornada 3 con la reflexión en el texto 2 CUANDO pasan 30 segundos
ENTONCES no hay entrada y el turno de la jornada 4 conserva su valor inicial. DADO el cierre de
la jornada 4 en la elección CUANDO pasan 30 segundos ENTONCES tampoco hay entrada. CUANDO
termina la reflexión ENTONCES empieza una sola entrada, y el turno empieza a descontar recién al
terminar esa entrada.

### AC-SHF-029 — El borde de la noche *(verifica BR-SHF-002, BR-SHF-004)*

DADO la jornada 1 recién abierta CUANDO pasan 719 segundos reales ENTONCES el turno sigue
abierto y quedan `60.0`. CUANDO pasa 1 segundo real más ENTONCES el turno cierra una sola vez y
quedan `0.0`. DADO la jornada 1 con 1 segundo real restante CUANDO llega un cuadro de 5 segundos
ENTONCES el turno cierra una sola vez y quedan `0.0`. DADO la jornada 1 CUANDO pasan 660
segundos reales ENTONCES quedan `3600.0`: una hora de ficción, las 07:00.

### AC-SHF-036 — Todas las tareas, incluidas atención y registro *(verifica BR-SHF-021)*

DADO cada jornada de prueba CUANDO todas sus obligatorias están cumplidas ENTONCES permite
salir. DADO por separado cada obligatoria pendiente, incluidas atención y registro, ENTONCES
no permite salir. DADO atención sin cumplir por un comprador que no llegó o que espera ENTONCES
no permite salir, aunque lo demás esté hecho y el registro coincida.
DADO la primera jornada completa y la última CUANDO todas están cumplidas ENTONCES no permite salir.

### AC-SHF-038 — La puerta conserva el cierre habitual y su unicidad *(verifica BR-SHF-021, BR-SHF-024, BR-SHF-004)*

DADO cada jornada de prueba con la salida habilitada CUANDO se acciona la entrada con el
primario ENTONCES el turno llega a cero, baja la persiana, aparece la devolución por el chat
y se guarda el avance por el mismo recorrido del cierre habitual. Repetir la acción NO
DEBE cerrar dos veces ni avanzar otra noche. DADO que el jugador no sale CUANDO agota el
tiempo normal ENTONCES cierra una sola vez contando el estado actual de sus tareas, también
si alguna se descumplió después del aviso.

### AC-SHF-039 — La noche nueva no conserva la autorización *(verifica BR-SHF-021, BR-SHF-024)*

DADO una jornada de prueba que permitió salir CUANDO se abre la siguiente, o se retoma
desde el inicio, ENTONCES la entrada no ofrece salida por el permiso anterior y sus tareas
pueden volver a cumplirse y descumplirse. Al completar las de una nueva jornada de prueba
puede producir su propio aviso. La primera jornada completa no lo produce.

### AC-SHF-041 — Descumplir vuelve a trabar y recuperar habilita *(verifica BR-SHF-021, BR-SHF-024, BR-SHF-007, BR-SHF-003)*

DADO cada jornada de prueba abierta CUANDO se cumple su última obligatoria ENTONCES habilita
la salida sin consumir turno ni cambiar el ritmo. CUANDO se descumple por separado cada una
de sus obligatorias ENTONCES deja de contar y la entrada vuelve a trabarse. Recuperar todas
habilita de nuevo sin adelantar el reloj. Un segundo real sigue descontando el ritmo del turno. DADO la góndola completa después del aviso CUANDO se retira una unidad
ENTONCES reponer queda pendiente y no se permite salir; reponerla habilita otra vez.

### AC-SHF-042 — La planilla permite equivocarse y corregir después del aviso *(verifica BR-SHF-024)*

DADO una jornada de prueba con todas sus tareas cumplidas y la computadora abierta CUANDO
se pulsa «+» en una fila que admite sumar ENTONCES cambia su cantidad, registrar se descumple
y la entrada vuelve a trabarse. CUANDO se pulsa «−» en esa fila ENTONCES se recupera la
cantidad correcta, registrar se cumple y la salida se habilita. Cerrar y reabrir la computadora
conserva ambas operaciones disponibles. Abrir la jornada siguiente entrega su planilla nueva
con las operaciones habituales.

### AC-SHF-043 — Girar, abrir y después bajar *(verifica BR-SHF-025)*

DADO cada jornada 1 y 2 con la salida habilitada y la entrada cerrada CUANDO se solicita
salir ENTONCES la vista empieza en su orientación visible y ambas hojas y la persiana no se
mueven durante el giro. CUANDO termina el giro ENTONCES la vista apunta al centro del vano,
entre las dos hojas, y ambas comienzan su apertura con un solo sonido habitual. Cada hoja
gira sobre la bisagra de su canto exterior hacia el mismo lado del vano, conserva ese canto
en el marco y no cruza el vidrio fijo durante todo el recorrido. Mientras cualquiera de las
dos hojas no haya alcanzado la apertura completa, la persiana sigue arriba. Sólo al terminar
ambas empieza a bajar la persiana.

### AC-SHF-044 — La vista toma el camino corto con suavizado *(verifica BR-SHF-025)*

DADO una vista a 179 grados y un destino a -179 grados CUANDO avanza el giro ENTONCES recorre
2 grados, sin completar una vuelta. DADO el sentido inverso ENTONCES también recorre 2 grados.
DADO un destino opuesto ENTONCES recorre como máximo 180 grados. Al muestrear el movimiento
desde una inclinación vertical distinta, ambos ángulos progresan sin sobrepasar su destino,
con suavizado al iniciar y terminar. Un avance nulo o negativo no mueve la vista. DADO un
jugador desplazado respecto del centro del vano CUANDO termina el giro ENTONCES mira al
punto medio entre las dos hojas cerradas, sin apuntar al centro de una sola hoja.

### AC-SHF-045 — La pausa conserva cada etapa de salida *(verifica BR-SHF-025)*

DADO la salida, por separado durante el giro y durante la apertura de las dos hojas, CUANDO se
pausa y pasan cuadros ENTONCES la vista, ambas hojas y la persiana conservan su posición y no
comienza la devolución. CUANDO se reanuda ENTONCES continúa desde ese punto, sin movimiento
ni interacción del jugador, y completa un solo cierre.

### AC-SHF-046 — La salida cierra una vez y el tiempo conserva su recorrido *(verifica BR-SHF-025, BR-SHF-024)*

DADO una salida en curso CUANDO se repite el primario o llega otro pedido de cierre ENTONCES
no se reinicia la secuencia y se produce una sola devolución y un solo guardado, con el
cumplimiento vigente al solicitar salir. DADO una jornada que agota el tiempo sin usar la
entrada ENTONCES comienza el cierre habitual, sin giro de vista ni apertura de las hojas.
DADO una salida completada en la jornada 2 CUANDO comienza la jornada 3 ENTONCES las dos
hojas están cerradas. DADO la jornada 3, tanto al retomar desde el menú como al reintentar
la noche, ENTONCES ambas hojas comienzan cerradas. DADO cualquier jornada desde la 3 CUANDO
se intenta salir por cualquiera de las hojas ENTONCES ninguna se abre ni termina la noche.

### AC-SHF-047 — La salida termina de frente al vano *(verifica BR-SHF-025)*

DADO cada jornada 1 y 2 con la salida habilitada y el jugador en cualquier lugar del
interior, de frente, de costado o de espaldas al vano CUANDO termina el recorrido de la salida
ENTONCES la cámara está sobre la perpendicular al vano que pasa por el punto medio entre las
dos bisagras, del lado del interior, con una tolerancia de 1 cm lateral y de 0,1 grados de
yaw respecto de esa perpendicular. La mirada es horizontal. La distancia al vano es la misma
desde cualquier punto de partida y encuadra ambas hojas completas. DADO el recorrido en curso
ENTONCES la posición y la orientación avanzan sin saltos, y una pausa las conserva y la
reanudación continúa desde ese punto. DADO un jugador que ya empieza sobre la pose frontal
ENTONCES el recorrido no lo mueve.

### AC-SHF-048 — Un comprador mal atendido no traba la salida *(verifica BR-SHF-021)*

DADO cada jornada de prueba con las demás obligatorias cumplidas CUANDO se va el último
comprador y alguno, o todos, se fueron sin comprar ENTONCES permite salir y produce el aviso,
y la atención sigue incumplida para el puntaje, aunque la planilla en cero no sea todavía una
tarea cumplida. DADO que el último comprador compra y el anterior se fue mal atendido ENTONCES
permite salir al vender. DADO un comprador que no llegó o que está en la ventanilla ENTONCES no
permite salir. DADO que falta cualquier otra obligatoria, o que la planilla no coincide con lo
vendido, ENTONCES no permite salir. DADO la primera jornada completa ENTONCES no permite salir
aunque no quede comprador por atender. El subtítulo de la puerta usa esta misma regla.

### AC-SHF-049 — El reloj de la sexta noche se detiene en las 20:58 *(verifica BR-SHF-011)*

DADO la jornada 6 CUANDO han transcurrido 58 minutos de ficción menos un segundo ENTONCES el
reloj lee `"20:57"`; con 58 minutos exactos, `"20:58"`. Con 2 horas transcurridas sigue leyendo
`"20:58"`, y no `"22:00"`. Con `21600.0` y con `0.0` segundos restantes la jornada 6 lee `"20:58"`, nunca
`""`, y la 7 lee `"08:00"` con `0.0`.

### AC-SHF-062 — Fuera de la sexta el reloj nunca falta *(verifica BR-SHF-011)*

DADO las jornadas 0, 2, 5 y 7 CUANDO quedan `43200.0`, `21600.0` y `1.0` segundos ENTONCES el
reloj lee la hora, y no `""`.

### AC-SHF-050 — Restablecer la luz no descongela el reloj *(verifica BR-SHF-011)*

DADO la jornada 6 con el corte cortado y con el corte restaurado, a las 22:00 y a las 01:00
CUANDO se lee el reloj ENTONCES lee `"20:58"` en los dos estados. Hacer clic sobre el
panel otra vez no cambia la lectura, y el turno descuenta lo mismo que antes de la hora del corte.

### AC-SHF-120 — El celular lee la hora de la noche *(verifica BR-SHF-040, BR-SHF-012, BR-SHF-014)*

DADO una jornada que no es la sexta con el turno corriendo CUANDO quedan `43200.0`, `43141.0`,
`43140.0`, `28801.0`, `28799.0` y `14400.0` segundos ENTONCES el celular lee `"20:00"`, `"20:00"`,
`"20:01"`, `"23:59"`, `"00:00"` y `"04:00"`, y en cada caso lo mismo que el reloj de pared.

### AC-SHF-121 — La sexta noche el celular sigue andando con el reloj detenido *(verifica BR-SHF-040, BR-SHF-011)*

DADO la jornada 6 CUANDO han transcurrido 58 minutos exactos ENTONCES el reloj y el celular leen
`"20:58"`. CUANDO han transcurrido 2 horas ENTONCES el reloj sigue leyendo `"20:58"` y el celular
lee `"22:00"`, con el corte cortado y con el corte restaurado. CUANDO quedan `14400.0` segundos
ENTONCES el reloj lee `"20:58"` y el celular `"04:00"`.

### AC-SHF-122 — En pausa la hora del celular no cambia *(verifica BR-SHF-040, BR-SHF-003)*

DADO el celular leyendo una hora CUANDO se pausa y pasa tiempo real ENTONCES el turno conserva su
tiempo restante y el celular lee la misma hora. CUANDO se reanuda ENTONCES sigue desde esa hora.

### AC-SHF-123 — Entre jornadas el celular lee la hora de cierre *(verifica BR-SHF-041, BR-SHF-012)*

DADO un turno agotado ENTONCES el celular lee la hora de cierre, `"08:00"`. DADO un turno que el
jugador cierra antes de tiempo ENTONCES el celular lee también la hora de cierre y no la de
su salida. DADO la jornada 6 con el reloj leyendo `"20:58"` CUANDO el turno cierra ENTONCES el
celular lee la hora de cierre. La hora sigue siendo ésa hasta que se abre otra jornada.

### AC-SHF-124 — El despido muestra uno de los cinco tips *(verifica BR-SHF-070)*

DADO la pantalla del despido CUANDO se muestra ENTONCES entre el título y los botones hay uno solo de
los cinco tips de BR-SHF-070, con su texto literal. DADO el despido mostrado muchas veces ENTONCES
cada uno de los cinco sale alguna vez, y ningún otro texto. DADO la pantalla ya mostrada ENTONCES el
tip no cambia aunque pase el tiempo.

### AC-SHF-125 — Los finales 1 y 2 muestran su texto de cierre y ningún tip *(verifica BR-SHF-070)*

DADO la pantalla del final 1 CUANDO se muestra ENTONCES entre el título y los botones está su texto
de cierre, en dos renglones, y ninguno de los cinco tips. DADO la pantalla del final 2 ENTONCES está
su texto de cierre y ninguno de los cinco tips. DADO el mismo final mostrado varias veces ENTONCES el
texto es siempre el mismo.

### AC-SHF-141 — Los finales 4 y 5 muestran su texto de cierre y ningún tip *(verifica BR-SHF-070)*

DADO la pantalla del final 4 CUANDO se muestra ENTONCES entre el título y los botones está su texto
de cierre y ninguno de los cinco tips. DADO la pantalla del final 5 ENTONCES está su texto de cierre
y ninguno de los cinco tips. DADO el mismo final mostrado varias veces ENTONCES el texto es siempre
el mismo.

### AC-SHF-127 — Los dos botones y el foco *(verifica BR-SHF-071)*

DADO la pantalla de cada final con pantalla —el despido y los finales 1, 2, 4 y 5— CUANDO se muestra
ENTONCES hay exactamente dos botones, «COMENZAR NUEVA PARTIDA» arriba y «VOLVER AL MENÚ» abajo, y el
foco está en el de arriba.

### AC-SHF-128 — Comenzar nueva partida borra el guardado y abre la jornada 1 *(verifica BR-SHF-071)*

DADO la pantalla de final con un guardado en disco CUANDO se pulsa «COMENZAR NUEVA PARTIDA» ENTONCES
el guardado se borra, se pide una partida nueva una sola vez y el menú no se pide. DADO el guardado
borrado ENTONCES la partida que se carga está en la jornada 1.

### AC-SHF-129 — Volver al menú sale al menú y nada más *(verifica BR-SHF-071)*

DADO la pantalla de final CUANDO se pulsa «VOLVER AL MENÚ» ENTONCES se pide el menú y no se pide una
partida nueva. CUANDO se pulsa dos veces ENTONCES el menú se pide una sola vez.

### AC-SHF-130 — Un botón y el otro no piden dos salidas *(verifica BR-SHF-071)*

DADO la pantalla de final CUANDO se pulsa «COMENZAR NUEVA PARTIDA» y después «VOLVER AL MENÚ»
ENTONCES se pide sólo la partida nueva. DADO el orden inverso ENTONCES se pide sólo el menú. DADO
«COMENZAR NUEVA PARTIDA» pulsado dos veces ENTONCES se pide una sola partida nueva.

### AC-SHF-063 — El despido muestra su pantalla *(verifica BR-SHF-027)*

DADO una partida despedida al cerrar la jornada 5 CUANDO el jugador elige la opción de la devolución
ENTONCES aparece la pantalla con «/ FIN DEL JUEGO», «DESPEDIDO» y sus dos botones, y el menú todavía
no se pidió. CUANDO se pulsa «VOLVER AL MENÚ» ENTONCES se pide el menú. DADO el despido de la
prueba, en la jornada 1 o en la 2, ENTONCES la pantalla es la misma.

### AC-SHF-064 — El contrato cumplido sin pistas muestra su pantalla *(verifica BR-SHF-027)*

DADO la jornada 7 cerrada con el contrato cumplido y ninguna pista registrada en toda la partida
CUANDO el jugador elige la opción de la devolución y recorre su epílogo (BR-SHF-072) ENTONCES
aparece la pantalla con «/ FINAL 1», «EMPLEADO EXPLOTADO» y sus dos botones. CUANDO se pulsa
«VOLVER AL MENÚ» ENTONCES se pide el menú.

### AC-SHF-065 — El despido gana sobre la falta de pistas *(verifica BR-SHF-027)*

DADO una partida despedida al cerrar la jornada 4 sin ninguna pista registrada CUANDO el jugador elige
la opción de la devolución ENTONCES la pantalla es la del despido, con «DESPEDIDO», y no la de
«EMPLEADO EXPLOTADO».

### AC-SHF-066 — Con alguna pista aparece el final 2 *(verifica BR-SHF-027)*

DADO la jornada 7 cerrada con el contrato cumplido y una sola pista registrada, en cualquier jornada,
CUANDO el jugador elige la opción de la devolución y recorre su epílogo (BR-SHF-072) ENTONCES
aparece la pantalla con «/ FINAL 2», «LOCURA PARANOICA» y sus dos botones, y el menú todavía no se
pidió. CUANDO se pulsa «VOLVER AL MENÚ» ENTONCES se pide el menú. DADO una partida en curso ENTONCES
la devolución no lleva a ninguna
pantalla de final.

### AC-SHF-067 — Elegir dos veces no repite nada *(verifica BR-SHF-027)*

DADO la pantalla de final del despido, la del contrato sin pistas y la del final 2 CUANDO se elige dos
veces la opción de la devolución ENTONCES se muestra una sola pantalla, o un solo epílogo antes de
ella.

### AC-SHF-100 — Las dos cajas del proveedor están sólo en la jornada 7 *(verifica BR-SHF-050)*

DADA cada jornada de 1 a 6 abierta CUANDO se arma el depósito ENTONCES no hay caja de cartón del
proveedor ni caja de madera. DADA la jornada 7 abierta ENTONCES hay una de cada una, se haya hecho
el pedido al proveedor o no. DADA una partida guardada en la jornada 7 CUANDO se retoma ENTONCES
siguen las dos, una de cada una.

### AC-SHF-101 — Fijas, mudas y ajenas al depósito *(verifica BR-SHF-050)*

DADA la jornada 7 abierta CUANDO se intenta levantar, y después empujar, cada una de las dos
cajas ENTONCES no se mueve ni queda en la mano. DADA una caja levantable CUANDO se apoya sobre
cada una ENTONCES queda apoyada. CUANDO se las toca ENTONCES no suena ningún sonido. DADA la
jornada 7 con las dos cajas CUANDO se cuentan las cajas del depósito para ordenar, para reponer
y para la revisión ENTONCES ninguna de las dos entra en la cuenta.

### AC-SHF-110 — Abrir la puerta con la palanca termina la partida sin devolución *(verifica BR-SHF-060)*

DADO la jornada 7 abierta tras elegir 6B, con tareas pendientes y turno por delante, y la palanca en
la mano CUANDO se abre la puerta del jefe ENTONCES la partida termina con el final 4, el expediente
suma 7B, no se arma la devolución del jefe, no hay reflexión de cierre ni elección de hipótesis, y la
jornada no se evalúa. DADO el mismo caso con todas las obligatorias cumplidas ENTONCES el resultado es
el mismo, y no termina despedida ni con el contrato cumplido. DADO la jornada 7 sin la palanca en la
mano CUANDO se acciona la puerta ENTONCES la partida sigue en curso.

### AC-SHF-111 — El final 4 muestra su pantalla *(verifica BR-SHF-060, BR-SHF-027)*

DADO el final 4 CUANDO termina la partida ENTONCES aparece, sin otra pantalla antes, la pantalla con
«/ FINAL 4», «JEFE SABOTEADOR» y sus dos botones, y el menú todavía no se pidió. CUANDO se acciona
otra vez la puerta ENTONCES se sigue mostrando una sola pantalla. DADO el
despido o el contrato cumplido sin pistas ENTONCES sus pantallas siguen como en AC-SHF-063 y
AC-SHF-064.

### AC-SHF-112 — Abrir la puerta con la llave termina la partida sin devolución *(verifica BR-SHF-061)*

DADO la jornada 7 abierta tras elegir 6C, con tareas pendientes y turno por delante, y la llave en
la mano CUANDO se abre la puerta del jefe ENTONCES la partida termina con el final 5, el expediente
suma 7C, no se arma la devolución del jefe, no hay reflexión de cierre ni elección de hipótesis, y la
jornada no se evalúa. DADO el mismo caso con todas las obligatorias cumplidas ENTONCES el resultado es
el mismo, y no termina despedida ni con el contrato cumplido. DADO la jornada 7 sin la llave en la
mano CUANDO se acciona la puerta ENTONCES la partida sigue en curso.

### AC-SHF-113 — El final 5 muestra su pantalla *(verifica BR-SHF-061, BR-SHF-027)*

DADO el final 5 CUANDO termina la partida y se recorre su epílogo (BR-SHF-072) ENTONCES aparece la
pantalla con «/ FINAL 5», «JEFE INCOMPETENTE» y sus dos botones, y el menú todavía no se pidió. CUANDO
se acciona otra vez la puerta ENTONCES se sigue mostrando una sola pantalla. Su
encabezado y su título no son los del final 4 ni los de ningún otro final.

### AC-SHF-134 — El final 1 pasa por sus seis placas *(verifica BR-SHF-072, BR-SHF-073, BR-SHF-027)*

DADO el contrato cumplido sin ninguna pista CUANDO el jugador elige la opción de la devolución
ENTONCES no aparece la pantalla de final: tras el fundido de salida y el de entrada aparece la placa
1 del final 1, con su imagen de fondo, su texto y «SIGUIENTE». CUANDO se acciona «SIGUIENTE» cinco
veces, esperando cada fundido, ENTONCES se ven las placas 2 a 6 en ese orden, siempre con la misma
imagen de fondo. CUANDO se acciona en la placa 6 ENTONCES, tras el fundido, aparece la pantalla con
«/ FINAL 1» y el menú todavía no se pidió. El texto de la placa 1 tiene tres renglones y el de la
placa 2, uno.

### AC-SHF-135 — El final 2 pasa por sus dos placas *(verifica BR-SHF-072, BR-SHF-073, BR-SHF-027)*

DADO el contrato cumplido con una sola pista, en cualquier jornada, CUANDO el jugador elige la
opción de la devolución ENTONCES aparece la placa 1 del final 2, con una imagen de fondo distinta de
la del final 1. CUANDO se acciona «SIGUIENTE» ENTONCES aparece la placa 2, y CUANDO se acciona de
nuevo ENTONCES, tras el fundido, aparece la pantalla con «/ FINAL 2». El texto de la placa 1 tiene
dos renglones.

### AC-SHF-136 — El final 5 pasa por sus siete placas *(verifica BR-SHF-072, BR-SHF-073, BR-SHF-061)*

DADO la jornada 7 con la llave en la mano CUANDO se abre la puerta del jefe ENTONCES, tras los
fundidos, aparece la placa 1 del final 5 y no la pantalla de final. CUANDO se acciona «SIGUIENTE»
seis veces, esperando cada fundido, ENTONCES se ven las placas 2 a 7 en orden, y la pantalla con
«/ FINAL 5» no aparece antes de accionarlo en la placa 7. CUANDO se acciona en la placa 7
ENTONCES, tras el fundido, aparece la pantalla con «/ FINAL 5». El texto de la placa 1 tiene dos
renglones y el de la placa 7, dos.

### AC-SHF-137 — Sin epílogo, directo a la pantalla *(verifica BR-SHF-072, BR-SHF-027, BR-SHF-060)*

DADO una partida despedida, en cualquier jornada, CUANDO el jugador elige la opción de la devolución
ENTONCES aparece la pantalla «/ FIN DEL JUEGO» sin fundido ni placa antes. DADO el final 4, cuyas
placas no tienen texto, CUANDO se abre la puerta del jefe con la palanca ENTONCES aparece la
pantalla «/ FINAL 4» en ese mismo paso, sin fundido ni placa antes. DADO un final con una placa con
texto y otra sin él ENTONCES el epílogo muestra sólo la primera.

### AC-SHF-138 — Los fundidos duran un segundo cada uno *(verifica BR-SHF-072)*

DADO el final 1 CUANDO se elige la opción de la devolución ENTONCES la pantalla se oscurece durante
1 segundo, se ve negro, y vuelve la luz durante 1 segundo hasta mostrar la placa 1; con medio
segundo transcurrido la pantalla está a medio oscurecer. CUANDO se accionó «SIGUIENTE» en la última
placa ENTONCES la transición hacia la pantalla de final dura lo mismo. DADO un final con una sola
placa CUANDO se acciona «SIGUIENTE» ENTONCES se pasa a la pantalla de final y no a otra placa.

### AC-SHF-139 — El epílogo detiene el juego *(verifica BR-SHF-074)*

DADO el epílogo en pantalla, también durante un fundido, CUANDO se mueve el mouse, se pulsan las
teclas de movimiento o se acciona cualquier otro gesto del almacén ENTONCES el jugador no se mueve ni
acciona nada; CUANDO pasa tiempo real ENTONCES el reloj de la noche no avanza; CUANDO se pulsa la
tecla de pausa ENTONCES no se abre el menú de pausa.

### AC-SHF-140 — «SIGUIENTE» se acciona de tres maneras y no se adelanta *(verifica BR-SHF-074, BR-SHF-073)*

DADO una placa con su fundido de entrada terminado CUANDO se acciona «SIGUIENTE» con el mouse, con
el teclado o con el joystick ENTONCES pasa a la placa siguiente, en las tres. CUANDO se acciona dos
veces seguidas, o una vez en mitad de un fundido, ENTONCES se pasa de a una placa y ninguna se
saltea ni se repite; tampoco se muestra la pantalla de final antes de accionarlo en la última placa.

### AC-SHF-080 — La jornada 7 declara responder a las quejas *(verifica BR-SHF-005, BR-SHF-030)*

DADO la jornada 7 recién abierta CUANDO se piden sus obligatorias ENTONCES son las cuatro fijas
más responder a las quejas, todas sin cumplir, y la nota de tareas lista esa obligatoria con su
nombre después de las fijas. DADO cada jornada de la 1 a la 6 ENTONCES ninguna declara responder
a las quejas ni su nota la lista.

### AC-SHF-081 — Cuentan las cinco, y todas correctas *(verifica BR-SHF-030)*

DADO la jornada 7 con las cinco quejas CUANDO se responden bien cuatro ENTONCES la obligatoria
sigue sin cumplir, y con la quinta correcta queda cumplida. DADO cinco respondidas con una
equivocada ENTONCES queda sin cumplir, y una respuesta posterior sobre esa queja se rechaza y no la
cumple. DADO cinco respondidas bien CUANDO el turno ya cerró ENTONCES la obligatoria no se cumple
ni se descumple después del cierre.

### AC-SHF-082 — Con una queja mal respondida la devolución trae la Tarea 5 *(verifica BR-SHF-030)*

DADO la jornada 7 que cierra con una queja equivocada, o con una sin responder, y las demás
obligatorias cumplidas CUANDO se arma la devolución del jefe ENTONCES trae como Tarea 5 «Te
encargué ocuparte de las quejas y ahora recibo quejas sobre la gestión de las quejas.». DADO la
jornada 7 con las cinco quejas bien respondidas ENTONCES la devolución no trae Tarea 5.

### AC-SHF-083 — El pedido exacto con wifi cumple *(verifica BR-SHF-032)*

DADO la jornada 6 con las cinco cajas vacías de la noche CUANDO se envía con wifi un pedido con
exactamente esos cinco productos ENTONCES el pedido está cumplido y la cuenta de cumplidas sube
uno. CUANDO el pedido lista los mismos cinco en otro orden ENTONCES también cuenta.

### AC-SHF-084 — Uno de más, uno de menos o uno cambiado no cumple *(verifica BR-SHF-032)*

DADO la jornada 6 con cinco cajas vacías CUANDO se envía con wifi un pedido con cuatro de ellas
ENTONCES sigue sin cumplir. CUANDO se envía con wifi un pedido con las cinco y un producto más
ENTONCES sigue sin cumplir. CUANDO se envía con wifi un pedido con cuatro de las cinco y un
producto que no está vacío ENTONCES sigue sin cumplir. DADO ningún pedido enviado ENTONCES sigue
sin cumplir.

### AC-SHF-085 — Sin wifi no cumple ni deshace *(verifica BR-SHF-032)*

DADO el pedido exacto enviado sin wifi ENTONCES sigue sin cumplir. DADO el pedido exacto cumplido
con wifi CUANDO sale sin wifi un pedido distinto ENTONCES sigue cumplido: el último enviado con
wifi es el exacto.

### AC-SHF-086 — Cuenta el último pedido enviado con wifi *(verifica BR-SHF-032, BR-SHF-007)*

DADO el pedido exacto cumplido CUANDO sale con wifi un pedido distinto ENTONCES queda sin cumplir
y la cuenta de cumplidas baja uno. CUANDO sale con wifi el exacto otra vez ENTONCES vuelve a
cumplirse una sola vez. DADO el turno cerrado CUANDO sale con wifi un pedido ENTONCES el cierre no
cambia.

### AC-SHF-087 — Sólo la jornada 6 lo declara *(verifica BR-SHF-031)*

DADO las jornadas 1 a 7 CUANDO cada una pide sus obligatorias ENTONCES sólo la 6 incluye el pedido
al proveedor, y la nota de tareas de la 6 lo lista como «Hacerle un pedido al proveedor» a
continuación de las cuatro fijas. DADO dos aperturas seguidas de la 6 ENTONCES el pedido es una
instancia nueva y sin cumplir.

## No objetivos

- Esta capacidad NO decide **cómo** se cumple cada obligatoria: eso es de la capacidad de cada
  tarea.
- Esta capacidad NO anota la noche en el legajo ni decide el final: eso es de
  [`employment-record`](../employment-record/employment-record.md). Sí decide qué pantalla
  muestra cada final (BR-SHF-027).
- Esta capacidad NO cobra tiempo por ninguna acción: ni por cumplir ni por investigar. Todo
  cuesta porque el reloj no se detiene, no porque alguien descuente. La pausa y la preparación
  previa al juego excluyen sus intervalos.

## Contratos

- **Entrada:** los segundos reales que pasaron, la lista de obligatorias de la noche, y qué
  jornada es; el pedido de anunciarla y el avance real de su entrada; la solicitud de salir.
- **Salida:** cuánto queda, si el turno cerró, cuántas obligatorias van cumplidas, y la lectura
  del reloj de pared: la hora; texto, opacidad, apertura y finalización de la entrada;
  si se permite salir y cuándo se habilita o vuelve a trabarse la salida.
- **Falla:** cumplir una obligatoria ya cumplida, o con el turno cerrado, se rechaza. Descumplir
  una sin cumplir, o con el turno cerrado, también. Un tiempo negativo se ignora en silencio.

## Señales

- El turno cerrado, la tarea cumplida, la tarea descumplida y el tiempo consumido. El último se
  emite por cuadro: no se le puede enganchar nada que cueste.
- La entrada terminada, una sola vez por anuncio.

## Dependencias

- [`employment-record`](../employment-record/employment-record.md) (alimenta): recibe cuántas
  obligatorias se cumplieron al cerrar.
- [`investigation`](../investigation/investigation.md) (consume): si el cierre tiene una
  reflexión pendiente, y cuándo termina.
- Las capacidades de tarea (alimentan): cada una avisa cuándo su obligatoria quedó hecha
  y cuándo deja de estarlo; ese cumplimiento actual decide el permiso de salida de la prueba.
- [`notifications`](../notifications/notifications.md) (alimenta): la primera habilitación
  y cada nueva traba de la salida durante la noche.
- [`anomalies`](../anomalies/anomalies.md) (consume): desde qué hora de ficción la sexta
  noche tiene el reloj detenido.

## Preguntas abiertas

Ninguna.
