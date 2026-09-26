---
schema_version: 1
capability_id: CAP-SHF
status: ratified
owner: por definir
provenance: GDD «Ciclo de jornadas»; migración de los specs 001, 007, 011, 016, 027, 031
---

# Capacidad: el ciclo de la jornada

## Propósito

Repartir una noche de tiempo finito entre las cinco tareas del jefe y la investigación. Lo único
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

CUANDO pasa tiempo real, el sistema DEBE recibir cuántos segundos pasaron y descontarlos del
turno. El turno nunca lee un reloj propio. Un valor que no es positivo no descuenta nada. El
tiempo real es lo único que descuenta del turno: cumplir una obligatoria no lo mueve.

### BR-SHF-004 — El turno no baja de cero

MIENTRAS queda turno, el sistema DEBE descontar hasta cero y no más. Con cero o menos, el turno
está cerrado.

### BR-SHF-005 — Las cinco obligatorias

CUANDO se abre una jornada, el sistema DEBE pedir **una tarea de cada tipo declarado**: cobrar en
la caja, reponer, registrar, limpiar y sacar la basura. La cantidad sale de recorrer los tipos y
nunca de un número escrito.

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

### AC-SHF-005 — Una por tipo, e instancias nuevas *(verifica BR-SHF-005)*

DADO dos jornadas seguidas CUANDO cada una pide sus obligatorias ENTONCES recibe una por cada
tipo declarado, y las de la segunda están todas sin cumplir.

### AC-SHF-007 — El borde del cierre *(verifica BR-SHF-007)*

DADO un turno con `1.0` segundo restante CUANDO se cumple cualquiera de las cinco obligatorias
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

DADO un turno de `43200.0` CUANDO se cumplen las cinco obligatorias en el mismo cuadro ENTONCES
cuentan las cinco y quedan `43200.0`.

### AC-SHF-019 — Descumplir *(verifica BR-SHF-007)*

DADO una obligatoria cumplida con el turno abierto CUANDO se descumple ENTONCES las cumplidas
bajan en 1 y el turno restante no cambia; cumplirla de nuevo las deja como antes de descumplir.
DADO una obligatoria sin cumplir CUANDO se descumple ENTONCES se rechaza y las cumplidas no
cambian. DADO una obligatoria cumplida con el turno cerrado CUANDO se descumple ENTONCES se
rechaza y sigue contando.

## No objetivos

- Esta capacidad NO decide **cómo** se cumple cada obligatoria: eso es de la capacidad de cada
  tarea.
- Esta capacidad NO anota la noche en el legajo ni decide el final: eso es de
  [`employment-record`](../employment-record/employment-record.md).
- Esta capacidad NO cobra tiempo por ninguna acción: ni por cumplir ni por investigar. Todo
  cuesta porque el reloj no se detiene, no porque alguien descuente.

## Contratos

- **Entrada:** los segundos reales que pasaron, la lista de obligatorias de la noche, y qué
  jornada es.
- **Salida:** cuánto queda, si el turno cerró, cuántas obligatorias van cumplidas, y la lectura
  del reloj de mesa: la hora, o vacío.
- **Falla:** cumplir una obligatoria ya cumplida, o con el turno cerrado, se rechaza. Descumplir
  una sin cumplir, o con el turno cerrado, también. Un tiempo negativo se ignora en silencio.

## Señales

- El turno cerrado, la tarea cumplida, la tarea descumplida y el tiempo consumido. El último se emite por cuadro: no
  se le puede enganchar nada que cueste.

## Dependencias

- [`employment-record`](../employment-record/employment-record.md) (alimenta): recibe cuántas
  obligatorias se cumplieron al cerrar.
- Las cinco capacidades de tarea (alimentan): cada una avisa cuándo su obligatoria quedó hecha,
  y cuándo dejó de estarlo.

## Preguntas abiertas

Ninguna.
