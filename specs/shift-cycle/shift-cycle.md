---
schema_version: 1
capability_id: CAP-SHF
status: ratified
owner: por definir
provenance: GDD «Ciclo de jornadas»; fichas «Pantalla entre jornadas» y «Particulares de cada jornada»; decisiones de #364 y #369; migración de los specs 001, 007, 011, 016, 027, 031
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
| **Reloj** | el reloj de mesa del local, el único lugar donde se lee la hora | reloj de pared, HUD |

## Comportamiento normativo

### BR-SHF-001 — La noche dura doce horas de ficción

El sistema DEBE dar a cada jornada un turno de **43 200 segundos** de ficción, de las 20:00 a las
08:00.

### BR-SHF-002 — La sesión dura doce minutos reales

El sistema DEBE convertir el tiempo real a tiempo de turno con un factor tal que **720 segundos
reales cubran el turno entero**: un minuto real por hora de ficción. El factor vale
`43 200 ÷ 720`.

### BR-SHF-003 — El tiempo entra, no se busca

CUANDO pasa tiempo real de juego, el sistema DEBE recibir cuántos segundos pasaron y descontarlos
del turno. El turno nunca lee un reloj propio. Un valor que no es positivo no descuenta nada. El
tiempo real es lo único que descuenta del turno: cumplir una obligatoria no lo mueve. El tiempo
en pausa no es tiempo de juego y NO DEBE descontar. Cambiar de pestaña, minimizar o pasar a otra
ventana no es una pausa: ese tiempo DEBE descontarse, también si el navegador suspendió los
cuadros y sólo permite actualizar la jornada al volver. La entrada de la noche, desde que aparece
la placa hasta que termina de subir la persiana, NO DEBE descontar turno, tampoco al cambiar de
pestaña. Soltar esa retención DEBE continuar desde el presupuesto conservado, sin cobrar el
intervalo retenido. Las instrucciones previas a la primera noche tampoco son tiempo de juego.

### BR-SHF-004 — El turno no baja de cero

MIENTRAS queda turno, el sistema DEBE descontar hasta cero y no más. Con cero o menos, el turno
está cerrado.

### BR-SHF-005 — Las obligatorias de cada jornada

CUANDO se abre una jornada, el sistema DEBE pedir las cuatro fijas —cobrar en la caja,
registrar, limpiar y reponer— más la particular que esa jornada declara. La primera DEBE declarar
ordenar las cajas del depósito y la segunda, tirar la basura. Mientras sigue abierta OQ-SHF-006,
la tercera, la cuarta y la quinta DEBEN declarar sólo las cuatro fijas. Cada apertura DEBE crear
tareas nuevas, sin cumplir. La cantidad que muestra el HUD DEBE salir de esa misma lista.

### BR-SHF-007 — Una obligatoria cuenta mientras su condición vale, y antes del cierre

MIENTRAS queda turno, el sistema DEBE contar la obligatoria que se cumple, sin importar cuánto
turno quede, y DEBE dejar de contarla si su condición deja de valer. SI la tarea ya está
cumplida, ENTONCES cumplirla otra vez NO DEBE contarla dos veces. SI la tarea no está cumplida,
ENTONCES descumplirla NO DEBE descontar nada. SI el turno está cerrado, ENTONCES el sistema DEBE
rechazar cumplir y descumplir: el cierre cuenta el estado de ese instante.

### BR-SHF-008 — Sólo cuentan las declaradas

El sistema DEBE contar como cumplidas sólo las obligatorias que la jornada declaró. Una tarea
cumplida fuera de esa lista no cuenta.

### BR-SHF-011 — La hora se lee en un solo lugar, y una noche falta

El sistema DEBE mostrar la hora sólo en el reloj de mesa del local, cerca del escritorio: ni en
el HUD, ni en la computadora, ni en otro objeto del local. SI es la tercera jornada y queda la
mitad del turno o menos, ENTONCES el reloj DEBE leer vacío hasta el cierre, sin decir que está
roto. Las otras jornadas, incluida la que todavía no se declaró, el reloj DEBE leer la hora el
turno entero.

### BR-SHF-012 — La lectura trunca y no miente

CUANDO se lee la hora, el sistema DEBE truncar al minuto y nunca redondear hacia arriba. Con cero
o menos de turno, DEBE leer la hora de cierre: nunca una hora pasada del cierre.

### BR-SHF-014 — La lectura es la hora de la noche

CUANDO se lee el reloj, el sistema DEBE contestar la hora de apertura más lo que ya pasó del
turno, en `HH:MM` de 24 horas. La hora de apertura y la duración viven una sola vez en las
reglas del juego.

### BR-SHF-019 — La persiana anuncia la noche antes de jugar

CUANDO se entra a una jornada desde el menú o al seguir desde el cierre, el sistema DEBE mostrar
la persiana baja con la placa «NOCHE N», donde N es la jornada que se abre, sin puntos suspensivos.
La placa DEBE desaparecer con un fade de opacidad 1 a 0 y la persiana DEBE subir de apertura 0 a
1, sin invertir ninguno de los avances. Hasta terminar la subida, el control del jugador DEBE
estar suspendido; al terminar, la entrada DEBE desaparecer y devolver el control una sola vez.
Un tiempo real no positivo NO DEBE avanzar la entrada. La pausa DEBE congelarla y reanudarla
desde el mismo punto. Cambiar de pestaña NO DEBE saltearla.

La entrada DEBE dibujarse encima del HUD, las interfaces diegéticas y el cierre, y debajo de
los avisos y la pausa. Un segundo pedido de seguir el mismo cierre NO DEBE anunciar otra noche.
Una partida terminada que vuelve al menú NO DEBE anunciar una noche nueva. La placa DEBE
permanecer entera 1 segundo y desaparecer durante los siguientes 0,5 segundos. Sólo después
DEBE subir la persiana durante 1 segundo, sin superponer ambos movimientos: la entrada completa
DEBE durar 2,5 segundos reales.

## Criterios de aceptación

### AC-SHF-001 — El turno de la noche *(verifica BR-SHF-001)*

DADO una jornada que se abre CUANDO se mira su turno ENTONCES el presupuesto es `43200.0`
segundos.

### AC-SHF-002 — Doce minutos reales *(verifica BR-SHF-002)*

DADO el factor del ritmo CUANDO se escalan `720.0` segundos reales ENTONCES el resultado es
exactamente la duración del turno, y un segundo real escala a `60.0`.

### AC-SHF-003 — El tiempo negativo no mueve nada *(verifica BR-SHF-003)*

DADO un turno de `100.0` CUANDO se consumen `-5.0` segundos ENTONCES quedan `100.0`.

### AC-SHF-004 — El piso es cero *(verifica BR-SHF-004)*

DADO un turno de `100.0` CUANDO se consumen `250.0` segundos ENTONCES quedan `0.0` y el turno
está cerrado.

### AC-SHF-005 — Fijas y particular, con instancias nuevas *(verifica BR-SHF-005)*

DADO las jornadas 1 a 5 CUANDO cada una pide sus obligatorias ENTONCES la 1 recibe 5, con ordenar
las cajas y sin basura; la 2 recibe 5, con basura y sin ordenar; la 3, la 4 y la 5 reciben las
4 fijas. DADO dos aperturas seguidas CUANDO se comparan sus tareas ENTONCES ninguna instancia se
comparte y todas las de la segunda están sin cumplir.

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

### AC-SHF-012 — El reloj falta la mitad de una noche *(verifica BR-SHF-011)*

DADO la jornada 3 CUANDO quedan `21601.0` segundos ENTONCES el reloj lee `"01:59"`; con `21600.0`
o menos, lee `""`. En las jornadas 0, 4 y 5 lee la hora con `43200.0`, con `21600.0` y con
`1.0`.

### AC-SHF-013 — El reloj roto no dice que está roto *(verifica BR-SHF-011)*

DADO la jornada 3 con `0.0` segundos restantes CUANDO se lee el reloj ENTONCES la lectura es la
cadena vacía, y no `"08:00"`.

### AC-SHF-014 — La lectura trunca *(verifica BR-SHF-012)*

DADO `43141.0` segundos restantes ENTONCES el reloj lee `"20:00"`; con `43140.0`, `"20:01"`; con
`-10.0`, `"08:00"`.

### AC-SHF-016 — La hora de la noche *(verifica BR-SHF-014)*

DADO una jornada que no es la tercera CUANDO se lee el reloj ENTONCES:

| Quedan | Se lee |
|---|---|
| `43200.0` | `"20:00"` |
| `28801.0` | `"23:59"` |
| `28799.0` | `"00:00"` |
| `21600.0` | `"02:00"` |
| `14400.0` | `"04:00"` |
| `0.0` | `"08:00"` |

### AC-SHF-017 — Un solo reloj *(verifica BR-SHF-011)*

DADO el local armado CUANDO se recorren sus nodos ENTONCES hay exactamente una lectura de la
hora, cuelga del reloj de mesa y no gira hacia la cámara.

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

DADO el cierre de la jornada 1 CUANDO se elige seguir dos veces ENTONCES aparece una sola entrada
«NOCHE 2», la persiana empieza baja, el control está suspendido y los cuadros no descuentan turno.
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

### AC-SHF-027 — El denominador sigue las declaradas *(verifica BR-SHF-005, BR-SHF-008)*

DADO la jornada 1 recién abierta CUANDO se consulta el HUD ENTONCES dice `0/5`. DADO la jornada 3
recién abierta ENTONCES dice `0/4`; cumplir sus cuatro declaradas lo deja en `4/4`, y cumplir una
tarea ajena a esa lista no aumenta la cuenta.

## No objetivos

- Esta capacidad NO decide **cómo** se cumple cada obligatoria: eso es de la capacidad de cada
  tarea.
- Esta capacidad NO anota la noche en el legajo ni decide el final: eso es de
  [`employment-record`](../employment-record/employment-record.md).
- Esta capacidad NO cobra tiempo por ninguna acción: ni por cumplir ni por investigar. Todo
  cuesta porque el reloj no se detiene, no porque alguien descuente. La pausa y la preparación
  previa al juego excluyen sus intervalos.

## Contratos

- **Entrada:** los segundos reales que pasaron, la lista de obligatorias de la noche, y qué
  jornada es; el pedido de anunciarla y el avance real de su entrada.
- **Salida:** cuánto queda, si el turno cerró, cuántas obligatorias van cumplidas, y la lectura
  del reloj de mesa: la hora, o vacío; texto, opacidad, apertura y finalización de la entrada.
- **Falla:** cumplir una obligatoria ya cumplida, o con el turno cerrado, se rechaza. Descumplir
  una sin cumplir, o con el turno cerrado, también. Un tiempo negativo se ignora en silencio.

## Señales

- El turno cerrado, la tarea cumplida, la tarea descumplida y el tiempo consumido. El último se
  emite por cuadro: no se le puede enganchar nada que cueste.
- La entrada terminada, una sola vez por anuncio.

## Dependencias

- [`employment-record`](../employment-record/employment-record.md) (alimenta): recibe cuántas
  obligatorias se cumplieron al cerrar.
- Las capacidades de tarea (alimentan): cada una avisa cuándo su obligatoria quedó hecha.
  Registrar y ordenar las cajas avisan también cuándo dejaron de estarlo.

## Preguntas abiertas

- **OQ-SHF-006 — ¿Qué particular declaran las jornadas 3, 4 y 5?**
  - Por qué sigue abierta: la 3 quedó fuera de esta tanda y las fichas de la 4 y la 5 no tienen
    diseño cerrado. La decisión de #369 deja las tres con sólo las cuatro fijas.
  - Decide: game design, en las fichas e issues de cada jornada.
  - Bloquea: agregar esas particulares; no bloquea abrir ni cerrar con las cuatro declaradas.
