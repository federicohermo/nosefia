---
schema_version: 1
capability_id: CAP-EMP
status: draft
owner: por definir
provenance: GDD «Consecuencias» y «Finales»; migración de los specs 002, 016, 017
---

# Capacidad: el legajo del empleado

## Propósito

Llevar la cuenta de lo que el empleado debe y decidir cuándo lo echan. Lo único que tiene que
hacer bien es que las tres bandas **pesen distinto**: dos noches graves seguidas despiden y una
noche impecable borra la deuda entera.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Banda** | cómo cerró la noche: ninguna, aviso o grave | nota, puntaje |
| **Apercibimiento** | la unidad de deuda que se arrastra entre noches | strike, falta |
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
`GRAVE`, y DEBE **reiniciar el contador a cero** con `NINGUNA`. Un día bueno borra la deuda
entera.

### BR-EMP-003 — A los cuatro lo echan

SI el legajo llega a **4 apercibimientos o más**, ENTONCES el sistema DEBE declararlo despedido.
La comparación es «o más» porque una noche grave sube de a dos: el contador salta de 3 a 5 sin
pisar el 4.

### BR-EMP-004 — El contrato dura cinco noches

El sistema DEBE numerar las jornadas **desde 1** y terminar la partida con contrato cumplido al
cerrar la **quinta**.

### BR-EMP-005 — El despido se pregunta primero

CUANDO cierra la última jornada, el sistema DEBE decidir el despido **antes** que el contrato
cumplido. La última noche puede cerrar mal justo cuando el legajo llega al tope, y felicitar a
alguien recién echado es la lectura equivocada de las dos condiciones a la vez.

### BR-EMP-006 — Una partida terminada no sigue

SI la partida terminó, ENTONCES el sistema DEBE rechazar abrir otra jornada y DEBE ignorar un
cierre nuevo. Sin eso, una noche jugada después del despido le pasa una banda al legajo, y una
noche impecable lo reinicia a cero.

### BR-EMP-007 — Cerrar dos veces no anota dos veces

SI la jornada no está abierta, ENTONCES el sistema DEBE ignorar el cierre. La puerta es pública
y una pantalla la va a tocar.

### BR-EMP-008 — El legajo se restaura entero

El sistema DEBE poder arrancar una partida con un legajo que viene de un guardado. Una historia
de noches graves repartida entre dos sesiones tiene que despedir igual.

### BR-EMP-009 — El parte del jefe

CUANDO cierra la jornada, el sistema DEBE dejar un parte con: qué jornada de cuántas fue, **una
línea por obligatoria en el orden en que se declararon**, y un comentario general elegido por
cuántos apercibimientos lleva. Ese comentario satura en el tope: con 5 apercibimientos dice lo
mismo que con 4.

### BR-EMP-010 — El aviso de riesgo aparece con deuda

SI el legajo tiene **más de cero** apercibimientos, ENTONCES el parte DEBE avisar cuántos lleva
sobre el tope. Con cero no hay nada que avisar: una placa que avisa siempre no avisa nunca.

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

### AC-EMP-005 — Una noche impecable borra la deuda *(verifica BR-EMP-002)*

DADO un legajo con 3 apercibimientos CUANDO cierra una noche con todas cumplidas ENTONCES el
legajo vuelve a cero y no está despedido.

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

### AC-EMP-015 — El aviso aparece con deuda *(verifica BR-EMP-010)*

DADO 0 apercibimientos ENTONCES el parte no avisa; con 1, avisa y nombra el tope.

## No objetivos

- Esta capacidad NO cuenta el tiempo de la noche ni cuántas obligatorias hay: las recibe.
- Esta capacidad NO escribe el guardado: entrega el legajo y la jornada a
  [`save-and-resume`](../save-and-resume/save-and-resume.md).
- Esta capacidad NO dibuja la placa del cierre. Elige el texto; pintarlo es de la pantalla.

## Contratos

- **Entrada:** cuántas obligatorias se cumplieron y cuántas se habían declarado; un legajo, que
  puede venir de un guardado.
- **Salida:** la banda, los apercibimientos, si está despedido, qué jornada va, el final, y el
  parte del jefe.
- **Falla:** cerrar dos veces o abrir sobre una partida terminada no cambian nada y no avisan.

## Señales

- La jornada abierta, la jornada cerrada y la partida terminada. El cierre y el final pueden
  llegar en el mismo instante, y quien escuche tiene que tratarlos como uno.

## Dependencias

- [`shift-cycle`](../shift-cycle/shift-cycle.md) (consume): cuántas obligatorias se cumplieron.
- [`save-and-resume`](../save-and-resume/save-and-resume.md) (alimenta): el legajo y la jornada
  que cruzan la sesión.

## Preguntas abiertas

- **OQ-EMP-001 — ¿El prototipo despide a las dos noches graves o a las tres?**
  - Por qué sigue abierta: el GDD dice «más de dos días seguidos» y el formulario de la primera
    entrega dice «tres jornadas consecutivas»; el prototipo eligió dos para que los tres caminos
    queden a la misma distancia.
  - Decide: el dueño del repo, con la cátedra.
  - Bloquea: nada. Mueve el tope de `BR-EMP-003` y los tres caminos de `AC-EMP-007`.
