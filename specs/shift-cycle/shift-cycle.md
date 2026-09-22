---
schema_version: 1
capability_id: CAP-SHF
status: draft
owner: por definir
provenance: GDD «Ciclo de jornadas»; migración de los specs 001, 007, 011, 016, 027, 031
---

# Capacidad: el ciclo de la jornada

## Propósito

Repartir una noche de tiempo finito entre las cinco tareas del jefe y la investigación. Lo único
que tiene que hacer bien es que el tiempo alcance para cumplir y sobre algo: **cada minuto
investigando es un minuto que no se dedica a las tareas**, y esta capacidad es esa resta.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Turno** | el presupuesto de tiempo de una noche, en segundos de ficción | nivel, ronda |
| **Jornada** | una noche de la partida, numerada desde 1 | día, nivel |
| **Obligatoria** | una de las tareas que el jefe pide esta noche | misión, objetivo |
| **Margen** | lo que sobra del turno después de cumplir y de caminar | tiempo libre, ocio |
| **Ritmo** | cuántos segundos de turno consume un segundo real | escala, velocidad |
| **Hora** | la hora de ficción de la noche, de la apertura al cierre | tiempo restante, cuenta regresiva |
| **Reloj** | el reloj de mesa del local, el único lugar donde se lee la hora | reloj de pared, HUD |

## Comportamiento normativo

### BR-SHF-001 — La noche dura doce horas de ficción

El sistema DEBE dar a cada jornada un turno de **43 200 segundos** de ficción, de las 20:00 a las
06:00.

### BR-SHF-002 — La sesión dura doce minutos reales

El sistema DEBE convertir el tiempo real a tiempo de turno con un factor tal que **720 segundos
reales cubran el turno entero**: un minuto real por hora de ficción. El factor vale
`43 200 ÷ 720`.

### BR-SHF-003 — El tiempo entra, no se busca

CUANDO pasa tiempo real, el sistema DEBE recibir cuántos segundos pasaron y descontarlos del
turno. El turno nunca lee un reloj propio. Un valor que no es positivo no descuenta nada.

### BR-SHF-004 — El turno no baja de cero

MIENTRAS queda turno, el sistema DEBE descontar hasta cero y no más. Con cero o menos, el turno
está cerrado.

### BR-SHF-005 — Las cinco obligatorias

CUANDO se abre una jornada, el sistema DEBE pedir **una tarea de cada tipo declarado**: cobrar en
la caja, reponer, registrar, limpiar y sacar la basura. La cantidad sale de recorrer los tipos y
nunca de un número escrito.

### BR-SHF-006 — Cada obligatoria cuesta turno

CUANDO se cumple una obligatoria, el sistema DEBE descontar su costo del turno. Los costos, en
segundos de ficción: caja 1800, reponer 3600, registrar 2700, limpiar 3600, sacar la basura 1200.

### BR-SHF-007 — Una obligatoria se cumple una vez

SI la tarea ya está cumplida, o SI su costo no entra en lo que queda del turno, ENTONCES el
sistema DEBE rechazar y **no descontar nada**. Una tarea a medias deja un estado que el jugador
no distingue de haberla hecho.

### BR-SHF-008 — Sólo cuentan las declaradas

El sistema DEBE contar como cumplidas sólo las obligatorias que la jornada declaró. Una tarea
cumplida fuera de esa lista consume turno y no cuenta.

### BR-SHF-009 — El turno alcanza, con margen

El sistema DEBE dejar, después de cumplir las cinco y de caminar, un margen **mayor a 3600
segundos** de ficción — una de las doce horas. El trayecto estimado de una noche completa es de
**220 segundos reales**, y es el único término que pasa por el ritmo.

### BR-SHF-010 — Un turno consumido exacto no alcanza

SI el margen es cero, ENTONCES el sistema DEBE contestar que el turno **no** alcanza. Investigar
no es opcional: es la mitad del bucle.

### BR-SHF-011 — La hora se lee en un solo lugar, y una noche falta

El sistema DEBE mostrar la hora sólo en el reloj de mesa del local, cerca del escritorio: ni en
el HUD, ni en la computadora, ni en otro objeto del local. SI es la tercera jornada y queda la
mitad del turno o menos, ENTONCES el reloj DEBE leer vacío hasta el cierre, sin decir que está
roto. Las otras jornadas, incluida la que todavía no se declaró, el reloj DEBE leer la hora el
turno entero.

### BR-SHF-012 — La lectura trunca y no miente

CUANDO se lee la hora, el sistema DEBE truncar al minuto y nunca redondear hacia arriba. Con cero
o menos de turno, DEBE leer la hora de cierre: nunca una hora pasada del cierre.

### BR-SHF-013 — *Retirada*

La última media hora ya no avisa. El reloj no cambia de tono.

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

### AC-SHF-006 — Cumplir cuesta *(verifica BR-SHF-006)*

DADO un turno entero CUANDO se cumplen las cinco ENTONCES el turno bajó exactamente la suma de
los cinco costos.

### AC-SHF-007 — El borde del costo *(verifica BR-SHF-007)*

DADO un turno con un segundo menos que el costo de la tarea CUANDO se intenta cumplirla ENTONCES
se rechaza y el turno no bajó un solo segundo; con el costo exacto, se cumple.

### AC-SHF-008 — Cumplir dos veces *(verifica BR-SHF-007)*

DADO una obligatoria ya cumplida CUANDO se la vuelve a cumplir ENTONCES se rechaza, el turno no
baja y la cuenta de cumplidas no sube.

### AC-SHF-009 — La tarea de afuera no cuenta *(verifica BR-SHF-008)*

DADO una jornada con dos obligatorias declaradas CUANDO se cumple una tercera tarea que no
estaba declarada ENTONCES el turno bajó su costo y las cumplidas siguen siendo las de la lista.

### AC-SHF-010 — El balance cierra *(verifica BR-SHF-009, BR-SHF-002)*

DADO los cinco costos, los `220.0` segundos de trayecto y el factor del ritmo CUANDO se calcula
el margen ENTONCES da `17100.0` segundos y es mayor al margen mínimo.

### AC-SHF-011 — El cero no alcanza *(verifica BR-SHF-010)*

DADO un margen de exactamente `0.0` CUANDO se pregunta si el turno alcanza ENTONCES la respuesta
es `false`.

### AC-SHF-012 — El reloj falta la mitad de una noche *(verifica BR-SHF-011)*

DADO la jornada 3 CUANDO quedan `21601.0` segundos ENTONCES el reloj lee `"01:59"`; con `21600.0`
o menos, lee `""`. En las jornadas 0, 4 y 5 lee la hora con `43200.0`, con `21600.0` y con
`1.0`.

### AC-SHF-013 — El reloj roto no dice que está roto *(verifica BR-SHF-011)*

DADO la jornada 3 con `0.0` segundos restantes CUANDO se lee el reloj ENTONCES la lectura es la
cadena vacía, y no `"06:00"`.

### AC-SHF-014 — La lectura trunca *(verifica BR-SHF-012)*

DADO `43141.0` segundos restantes ENTONCES el reloj lee `"20:00"`; con `43140.0`, `"20:01"`; con
`-10.0`, `"06:00"`.

### AC-SHF-015 — *Retirado* *(verifica BR-SHF-013)*

El aviso de la última media hora no existe más.

### AC-SHF-016 — La hora de la noche *(verifica BR-SHF-014)*

DADO una jornada que no es la tercera CUANDO se lee el reloj ENTONCES:

| Quedan | Se lee |
|---|---|
| `43200.0` | `"20:00"` |
| `28801.0` | `"23:59"` |
| `28799.0` | `"00:00"` |
| `21600.0` | `"02:00"` |
| `14400.0` | `"04:00"` |
| `0.0` | `"06:00"` |

### AC-SHF-017 — Un solo reloj *(verifica BR-SHF-011)*

DADO el local armado CUANDO se recorren sus nodos ENTONCES hay exactamente una lectura de la
hora, cuelga del reloj de mesa y no gira hacia la cámara.

## No objetivos

- Esta capacidad NO decide **cómo** se cumple cada obligatoria: eso es de la capacidad de cada
  tarea.
- Esta capacidad NO anota la noche en el legajo ni decide el final: eso es de
  [`employment-record`](../employment-record/employment-record.md).
- Esta capacidad NO cobra tiempo por investigar. Investigar cuesta porque el reloj no se
  detiene, no porque alguien descuente.

## Contratos

- **Entrada:** los segundos reales que pasaron, la lista de obligatorias de la noche, y qué
  jornada es.
- **Salida:** cuánto queda, si el turno cerró, cuántas obligatorias van cumplidas, y la lectura
  del reloj de mesa: la hora, o vacío.
- **Falla:** cumplir una obligatoria imposible se rechaza sin consumir. Un tiempo negativo se
  ignora en silencio.

## Señales

- El turno cerrado, la tarea cumplida y el tiempo consumido. El último se emite por cuadro: no
  se le puede enganchar nada que cueste.

## Dependencias

- [`employment-record`](../employment-record/employment-record.md) (alimenta): recibe cuántas
  obligatorias se cumplieron al cerrar.
- Las cinco capacidades de tarea (alimentan): cada una avisa cuándo su obligatoria quedó hecha.

## Preguntas abiertas

- **OQ-SHF-001 — ¿Los cinco costos y el trayecto se miden o se siguen suponiendo?**
  - Por qué sigue abierta: el trayecto es una estimación con 75 % de margen, y tres de las cinco
    obligatorias todavía no tienen anclaje medido en la escena.
  - Decide: el dueño del repo, jugando.
  - Bloquea: nada del comportamiento. Mueve el margen de `AC-SHF-010`.
