---
schema_version: 1
capability_id: CAP-EMP
status: draft
owner: por definir
provenance: GDD «Consecuencias» y «Finales»; fichas «1. Ciclo de jornadas y sistema de puntos», «Pantalla entre jornadas» y «Chat con el jefe»; decisiones de #374; migración de los specs 002, 016, 017
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
| **Legajo** | el contador de apercibimientos, y lo único que cruza la noche | racha, historial |
| **Partida** | las cinco jornadas del contrato, con su final | run, sesión |
| **Final** | cómo termina la partida: en curso, contrato cumplido o despedido | game over |

## Comportamiento normativo

### BR-EMP-001 — Las tres bandas

CUANDO cierra la jornada, el sistema DEBE traducir cuántas obligatorias se cumplieron a una
banda: **todas** las declaradas es `NINGUNA`; **3 o más** y menos que todas es `AVISO`; **menos
de 3** es `GRAVE`. El corte es en tareas y no en porcentaje: no se reescala con las obligatorias.

### BR-EMP-002 — Las bandas pesan distinto

CUANDO se anota una banda, el sistema DEBE sumar **1** apercibimiento por `AVISO`, **2** por
`GRAVE`, y DEBE sumar **0** con `NINGUNA`, conservando los apercibimientos que había.

### BR-EMP-003 — A los cuatro lo echan

SI el legajo llega a **8 medios o más**, equivalentes a 4 apercibimientos, ENTONCES el sistema
DEBE declararlo despedido. Con 7 medios todavía no está despedido.

### BR-EMP-004 — El contrato dura cinco noches

El sistema DEBE numerar las jornadas **desde 1** y terminar la partida con contrato cumplido al
cerrar la **quinta**.

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

### BR-EMP-009 — El parte del jefe

CUANDO cierra la jornada, el sistema DEBE dejar un parte con: qué jornada de cuántas fue, **una
línea por obligatoria en el orden en que se declararon**, y un comentario general elegido por
cuántos apercibimientos enteros lleva, descartando sólo para el comentario el medio restante.
Con 7 medios dice lo mismo que con 6. Ese comentario satura en el tope: con 5 apercibimientos dice lo
mismo que con 4.

El parte DEBE mostrar también una línea por cada motivo de llamado de esa jornada, con su
penalización adicional, después de las obligatorias. Esas líneas no cambian el criterio del
comentario general ni agregan un contador de motivos durante la noche.

### BR-EMP-011 — Lo que ofrece el parte depende del final

CUANDO se arma el parte, el sistema DEBE decir qué puede elegir el jugador. Con la partida en
curso, ofrece seguir con la noche siguiente y volver al menú. Con la partida terminada, despedido
o contrato cumplido, ofrece sólo volver al menú: no hay noche siguiente que abrir.

### BR-EMP-012 — Los llamados suman medios por motivo

MIENTRAS la jornada está abierta, el sistema DEBE registrar cada motivo de llamado una sola vez.
CUANDO cierra, DEBE sumar un medio por motivo distinto, además del peso de la banda, incluso
con NINGUNA. Abrir otra jornada DEBE vaciar los motivos pendientes. Antes de abrir, después de
cerrar y con la partida terminada, anotar un llamado NO DEBE modificar el legajo ni una noche
futura. Los motivos pendientes no DEBEN persistirse ni mostrar un contador nuevo.

### BR-EMP-022 — Enrique introduce una partida nueva

CUANDO se inicia una partida nueva, el sistema DEBE presentar las instrucciones de Enrique
Peldaño antes del comienzo jugable de la jornada 1, sobre la persiana baja. DEBE mostrar los
catorce mensajes introductorios en el orden de la ficha «Chat con el jefe», con sus negritas.
Sólo DEBE corregir las erratas decididas: «Atendé los pedidos y» en Intro 6, el espacio final de
Intro 7, «Bastante simple.» en Intro 8 e «instrucciones» en Intro 12. NO DEBE agregar los signos
de apertura omitidos en el registro del chat ni conservar los tres mensajes de prueba previos.

Las siete fotos DEBEN mostrar el juego y acompañar Intro 4, 6, 7, 8, 9, 11 y 13: respectivamente,
la nota de tareas, la ventanilla, el lector y la caja registradora, la computadora, una estantería
con cajas, los útiles y notas del baño y el depósito con sus cajas en el piso. La foto de la
estantería NO DEBE cambiar la disposición jugable de las cajas de la primera noche. El encuadre
artístico de cada tema es territorio de juicio humano; la correspondencia se verifica en
AC-EMP-047.

### BR-EMP-023 — Las instrucciones avanzan por pasos de contenido

CUANDO se muestran las instrucciones, el sistema DEBE empezar con un paso a la vista, sin
«volver». Cada «siguiente» DEBE agregar un paso, conservando los anteriores visibles; «volver»
DEBE retirar el último, sin bajar de uno. Los botones DEBEN permanecer debajo del último paso
visible. En el paso catorce, «siguiente» DEBE decir «comenzar»; retroceder DEBE restaurar
«siguiente». Elegir «comenzar» DEBE terminar las instrucciones y pedir una sola entrada a
«NOCHE 1», aunque se repita el gesto.

Cada foto sin texto y el texto sin foto inmediatamente siguiente DEBEN formar un único paso,
con la foto arriba. Los catorce textos y siete fotos DEBEN conservarse como 21 entradas separadas
en el chat de Enrique, cada foto inmediatamente antes del texto de su Intro. Desde la primera
noche, ese chat DEBE permitir releerlos y ampliar cada foto con el texto de su propia Intro.

### BR-EMP-024 — La preparación no consume la primera noche

MIENTRAS se leen las instrucciones, el sistema DEBE conservar la persiana baja, suspender al
jugador y retener todo el presupuesto del turno, aunque la lectura dure minutos. La interfaz
DEBE emerger desde el borde inferior, encima de la persiana y debajo de avisos y pausa. Esc
DEBE pausarla y reanudarla conservando los pasos visibles. «Comenzar» DEBE retirar las
instrucciones y dar paso a la placa y subida de persiana; el control y el reloj DEBEN liberarse
sólo cuando termine esa entrada. Las duraciones del fade in de la persiana y de la subida de
instrucciones quedan en OQ-EMP-002 y OQ-EMP-003.

## Criterios de aceptación

### AC-EMP-001 — Los tres cortes *(verifica BR-EMP-001)*

DADO 5 obligatorias CUANDO se cumplieron 5 ENTONCES la banda es `NINGUNA`; con 4 y con 3 es
`AVISO`; con 2, con 1 y con 0 es `GRAVE`.

### AC-EMP-002 — El corte no se reescala *(verifica BR-EMP-001)*

DADO 6 obligatorias CUANDO se cumplieron 3 ENTONCES la banda sigue siendo `AVISO`.

### AC-EMP-003 — Los dos pesos *(verifica BR-EMP-002)*

DADO un legajo limpio CUANDO cierra una noche de `AVISO` ENTONCES lleva 1 apercibimiento; DADO
un legajo limpio CUANDO cierra una de `GRAVE` ENTONCES lleva 2.

### AC-EMP-004 — Dos noches graves despiden *(verifica BR-EMP-002, BR-EMP-003)*

DADO un legajo limpio CUANDO cierran dos noches de `GRAVE` seguidas ENTONCES está despedido.

### AC-EMP-005 — Una noche impecable conserva la deuda *(verifica BR-EMP-002, BR-EMP-003)*

DADO un legajo con 3 apercibimientos CUANDO cierra una noche con todas cumplidas ENTONCES el
legajo sigue con 3 y no está despedido. CUANDO cierra después una noche de `AVISO` ENTONCES
lleva 4 y está despedido.

### AC-EMP-006 — El umbral se pasa sin pisarlo *(verifica BR-EMP-003)*

DADO un legajo con 3 apercibimientos CUANDO cierra una noche de `GRAVE` ENTONCES lleva 5 y está
despedido.

### AC-EMP-007 — Los tres caminos al despido *(verifica BR-EMP-002, BR-EMP-003)*

DADO un legajo limpio ENTONCES despiden dos noches graves, una grave más dos avisos, y cuatro
avisos; y ninguna combinación más corta.

### AC-EMP-008 — La quinta cierra el contrato *(verifica BR-EMP-004)*

DADO una partida en la jornada 5 CUANDO cierra con todas cumplidas ENTONCES el final es contrato
cumplido, y la jornada no avanza a 6.

### AC-EMP-009 — Despedido gana sobre cumplido *(verifica BR-EMP-005)*

DADO la jornada 5 con 3 apercibimientos CUANDO cierra con menos de 3 cumplidas ENTONCES el final
es despedido y no contrato cumplido.

### AC-EMP-010 — La partida terminada no abre *(verifica BR-EMP-006)*

DADO una partida despedida CUANDO se pide abrir otra jornada ENTONCES no se abre ninguna y el
legajo no cambia.

### AC-EMP-011 — El segundo cierre no anota *(verifica BR-EMP-007)*

DADO una jornada ya cerrada CUANDO se la cierra otra vez ENTONCES los apercibimientos no se
mueven y la jornada no avanza.

### AC-EMP-012 — El legajo restaurado despide *(verifica BR-EMP-008)*

DADO una partida que arranca con un legajo de 3 apercibimientos CUANDO cierra una noche de
`AVISO` ENTONCES está despedida.

### AC-EMP-013 — El parte lleva una línea por obligatoria *(verifica BR-EMP-009)*

DADO una jornada con las cinco obligatorias, tres cumplidas CUANDO se arma el parte ENTONCES
tiene cinco líneas, en el orden en que se declararon, y cada una corresponde al estado de su
tarea.

### AC-EMP-014 — El comentario satura *(verifica BR-EMP-009)*

DADO 5 apercibimientos CUANDO se pide el comentario general ENTONCES es el mismo que con 4, y no
queda vacío.

### AC-EMP-016 — La partida terminada no ofrece seguir *(verifica BR-EMP-011)*

DADO una partida que termina al cerrar la noche, despedido o contrato cumplido, CUANDO se arma
el parte ENTONCES ofrece volver al menú y no ofrece seguir. DADO la partida en curso CUANDO se
arma el parte ENTONCES ofrece seguir y volver al menú.

### AC-EMP-017 — La banda y los motivos se suman *(verifica BR-EMP-002, BR-EMP-012)*

DADO un legajo limpio CUANDO cierra impecable con un motivo ENTONCES lleva 1 medio; con dos
motivos distintos, 2; con GRAVE y dos motivos, 6. Repetir el mismo motivo conserva una sola suma.

### AC-EMP-018 — Los motivos pertenecen sólo a la noche abierta *(verifica BR-EMP-006, BR-EMP-007, BR-EMP-012)*

DADO un motivo anotado antes de abrir, durante una jornada ya cerrada o después del final
CUANDO se consulta o abre otra noche ENTONCES no suma deuda. DADO una noche con un motivo
CUANDO se abre la siguiente y cierra sin motivos ENTONCES conserva sólo la deuda anterior.

### AC-EMP-019 — Siete y ocho medios *(verifica BR-EMP-003, BR-EMP-012)*

DADO 6 medios CUANDO cierra impecable con un motivo ENTONCES lleva 7 y no está despedido.
DADO 7 medios CUANDO cierra impecable con un motivo ENTONCES lleva 8 y está despedido.

### AC-EMP-020 — El guardado conserva el medio *(verifica BR-EMP-008)*

DADO 7 medios CUANDO se guarda, se lee el archivo y se reanuda ENTONCES conserva el entero 7;
una noche impecable sin motivos sigue con 7. DADO el dato ausente, antiguo o con valor 7,0
CUANDO se reanuda ENTONCES restaura 0 medios y conserva una jornada válida. Si también hay un
dato antiguo, el entero 7 de medios sigue prevaleciendo.

### AC-EMP-021 — El comentario usa apercibimientos enteros *(verifica BR-EMP-009)*

DADO un legajo con 7 medios CUANDO se arma el parte ENTONCES su comentario es el mismo que con
6 medios; no agrega un contador visible de medios.

### AC-EMP-022 — La quinta impecable admite siete medios *(verifica BR-EMP-004, BR-EMP-005, BR-EMP-008)*

DADO la quinta jornada con 7 medios CUANDO cierra impecable sin motivos ENTONCES conserva 7
y termina con contrato cumplido. DADO un motivo adicional ENTONCES llega a 8 y termina despedido.

### AC-EMP-023 — Los llamados se ven al cerrar *(verifica BR-EMP-009, BR-EMP-012)*

DADO un producto que quedó tirado dentro del local al terminar la jornada CUANDO aparece el
parte ENTONCES muestra el llamado por local desordenado y su penalización adicional. DADO varios
motivos distintos ENTONCES aparece una línea por cada uno, sin repetirlos ni arrastrarlos a la
noche siguiente. El comentario general conserva su criterio de apercibimientos enteros.

### AC-EMP-045 — Uno, catorce, atrás y comenzar *(verifica BR-EMP-023)*

DADO las instrucciones recién abiertas CUANDO se consulta su estado ENTONCES hay 1 paso a la
vista y «volver» está oculto; intentar volver conserva 1. CUANDO se avanza 13 veces ENTONCES hay
14 y el botón dice «comenzar». CUANDO se vuelve ENTONCES hay 13 y dice «siguiente». CUANDO se
avanza hasta 14 y se elige «comenzar» dos veces ENTONCES las instrucciones terminan y se pide una
sola entrada a la noche 1. Avanzar 3 y volver 3 desde el inicio deja 1 paso visible.

### AC-EMP-046 — Veintiuna entradas forman catorce pasos *(verifica BR-EMP-022, BR-EMP-023)*

DADO los catorce textos de la ficha, con sólo las cuatro correcciones autorizadas y sus negritas,
y las siete fotos CUANDO se agrupan las 21 entradas ENTONCES hay 14 pasos, en orden Intro 1 a 14.
Los pasos 4, 6, 7, 8, 9, 11 y 13 tienen foto arriba y su propio texto debajo; los demás sólo texto.
CUANDO se avanza y vuelve por todos ENTONCES cada botón queda debajo del último paso visible,
la cuenta coincide con los pasos mostrados y la secuencia original de 21 entradas sigue intacta.
Los tres mensajes de prueba previos no aparecen entre los textos de la conversación.

### AC-EMP-047 — Cada foto adjunta su propia Intro *(verifica BR-EMP-022, BR-EMP-023)*

DADO el chat de Enrique desde la jornada 1 CUANDO se recorren sus siete fotos ENTONCES cada una
precede inmediatamente al texto de su Intro y ampliarla muestra ese texto, nunca el siguiente
paso. CUANDO se valida cada captura ENTONCES existe una imagen de 960×540 y el rayo central de
su encuadre alcanza el tema correspondiente: nota, ventanilla, lector y caja, computadora,
estantería con cajas, útiles y notas del baño, y cajas del depósito en el piso. Preparar la foto
de Intro 9 y después la de Intro 13 deja restaurada la pila jugable de la jornada 1.

### AC-EMP-048 — Leer retiene y comenzar anuncia *(verifica BR-EMP-022, BR-EMP-024)*

DADO una partida nueva preparada CUANDO empiezan las instrucciones ENTONCES la persiana está
baja, se ve Intro 1, no se ve «volver» y el control está suspendido. CUANDO pasan 120 segundos
reales leyendo ENTONCES queda el mismo presupuesto de turno. CUANDO se llega a 14 y se elige
«comenzar» ENTONCES desaparecen las instrucciones y aparece «NOCHE 1» sobre la persiana, con
el turno y el control todavía retenidos hasta que termine de subir.

### AC-EMP-049 — Pausar conserva la lectura *(verifica BR-EMP-024)*

DADO las instrucciones con 4 pasos visibles CUANDO se pulsa Esc, pasan cuadros y se reanuda
ENTONCES siguen los mismos 4 pasos y el mismo presupuesto de turno. DADO las instrucciones
en pantalla ENTONCES su orden de dibujo está sobre la persiana y debajo de avisos y pausa;
la interfaz empieza fuera del margen inferior y termina dentro del encuadre, sin fijar duración
hasta resolver OQ-EMP-003.

### AC-EMP-050 — Todas depende de lo declarado *(verifica BR-EMP-001)*

DADO la jornada 3 con sus cuatro obligatorias declaradas CUANDO cierra con las cuatro cumplidas
ENTONCES la banda es NINGUNA; con tres es AVISO y con dos es GRAVE. El corte conserva las reglas
de las bandas y no inventa una quinta tarea para decidir el cierre.

## No objetivos

- Esta capacidad NO cuenta el tiempo de la noche ni cuántas obligatorias hay: las recibe.
- Esta capacidad NO escribe el guardado: entrega el legajo y la jornada a
  [`save-and-resume`](../save-and-resume/save-and-resume.md).
- Esta capacidad NO dibuja la placa del cierre. Elige el texto; pintarlo es de la pantalla.

## Contratos

- **Entrada:** cuántas obligatorias se cumplieron y cuántas se habían declarado; un legajo, que
  puede venir de un guardado; motivos de la jornada abierta; mensajes introductorios y pedidos
  de avanzar, volver y comenzar.
- **Salida:** la banda, los medios exactos y los apercibimientos enteros, si está despedido, qué jornada va, el final, y el
  parte del jefe con lo que el jugador puede elegir; pasos introductorios, cantidad visible,
  permiso de volver y finalización de las instrucciones.
- **Falla:** cerrar dos veces o abrir sobre una partida terminada no cambian nada y no avisan.
- **Falla de las instrucciones:** volver con un solo paso visible conserva ese paso; repetir
  comenzar después de terminarlas no pide otra entrada.

## Señales

- La jornada abierta y la jornada cerrada. El final no es una señal aparte: el parte lo lee al
  armarse.
- Comenzar pedido, una sola vez al terminar las instrucciones.

## Dependencias

- [`shift-cycle`](../shift-cycle/shift-cycle.md) (consume): cuántas obligatorias se cumplieron.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (alimenta): tras las instrucciones, anuncia la
  primera noche y conserva la retención hasta que termine de subir la persiana.
- [`investigation`](../investigation/investigation.md) (alimenta): las 21 entradas de Enrique
  y la correspondencia entre cada foto y el texto siguiente para releerlas en el celular.
- [`save-and-resume`](../save-and-resume/save-and-resume.md) (alimenta): el legajo y la jornada
  que cruzan la sesión.

## Preguntas abiertas

- **OQ-EMP-002 — ¿Cuánto dura el fade in de la persiana baja?**
  - Por qué sigue abierta: la ficha fija el fundido desde negro, pero no su duración.
  - Decide: game design.
  - Bloquea: el tiempo definitivo de la aparición del fondo de las instrucciones.
- **OQ-EMP-003 — ¿Cuánto tarda la interfaz de instrucciones en subir?**
  - Por qué sigue abierta: la ficha fija el movimiento desde abajo, pero no su duración.
  - Decide: game design.
  - Bloquea: el ritmo definitivo de la presentación, no el orden de mensajes ni la navegación.
