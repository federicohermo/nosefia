---
schema_version: 1
capability_id: CAP-CLN
status: ratified
owner: por definir
provenance: GDD «Limpiar» y «Sacar la basura»; migración de los specs 010, 015, 043
---

# Capacidad: dejar el local en orden

## Propósito

Las dos obligatorias que se pagan caminando: pasar el trapeador por las cuatro esquinas y llevar
las bolsas al fondo. Lo único que tienen que hacer bien es **costar recorrido**: una tarea que se
cierra con un clic no le disputa nada a la investigación.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Mancha** | lo que hay que limpiar en una zona, con sus pasadas pendientes | suciedad |
| **Pasada** | un paso del trapeador. Baja de a uno y se puede dejar por la mitad | barra, progreso |
| **Zona** | una de las cuatro esquinas del local que llevan mancha | sector, área |
| **Bolsa** | una unidad de basura que hay que llevar al descarte | residuo |
| **Descarte** | el fondo, y el único lugar donde una bolsa cuenta | contenedor, tacho |

## Comportamiento normativo

### BR-CLN-001 — Cuatro zonas, tres pasadas

El sistema DEBE poner una mancha en **cada una de las 4 zonas** y pedir **3 pasadas por mancha**.
Con una sola pasada la mancha se limpiaría en el instante en que el jugador llega, y limpiar
volvería a ser un clic.

### BR-CLN-002 — Se limpia con el trapeador

SI lo que se lleva en la mano no es el trapeador, ENTONCES el sistema DEBE rechazar la pasada.
Limpiar con una lata en la mano sería limpiar gratis.

### BR-CLN-003 — Machacar sobre lo limpio no cierra nada

SI la mancha ya está limpia, ENTONCES el sistema DEBE rechazar la pasada y no bajar el contador
por debajo de cero.

### BR-CLN-004 — La pasada que limpia se distingue de la que no

CUANDO baja la última pasada de una mancha, el sistema DEBE decir que la mancha quedó limpia, y
no sólo que hubo una pasada: adelante del jugador son dos cosas distintas.

### BR-CLN-005 — Limpiar se puede dejar por la mitad

MIENTRAS queden pasadas, el sistema DEBE conservar cuántas faltan. Dos pasadas, irse a la
computadora, volver, y la mancha sigue esperando en una.

### BR-CLN-006 — Las manchas están repartidas

El sistema DEBE mantener las manchas a **4 metros o más** unas de otras y del trapeador, y esa
distancia DEBE ser mayor al alcance de la mira. Si no lo fuera, desde una mancha se enfocaría la
siguiente y los tramos de caminata dejarían de existir.

### BR-CLN-007 — Tres bolsas y una mano

El sistema DEBE poner **3 bolsas por jornada**, y ese número DEBE ser mayor que las manos
disponibles. Con una sola mano son tres viajes de ida y vuelta, y no hay forma de hacerlo en uno.

### BR-CLN-008 — El descarte está lejos

El descarte DEBE estar a **6 metros o más** de las tareas del local y de donde arrancan las
bolsas, y esa distancia DEBE ser mayor al alcance de la mira.

### BR-CLN-009 — La bolsa cuenta sólo adentro de la zona

SI la bolsa se suelta fuera del radio del descarte —**1,5 metros**—, ENTONCES el sistema DEBE
rechazar el depósito y **no quemar la bolsa**: la misma bolsa adentro de la zona sí deposita. El
borde entra.

### BR-CLN-010 — Los tres rechazos de depositar, en orden

CUANDO se deposita, el sistema DEBE rechazar por **no es basura** primero, por **ya depositada**
después, y por **fuera de la zona** al final. Los dos primeros son propiedades de la cosa y del
estado; el último es el único que depende de dónde está parado el jugador.

### BR-CLN-011 — Cada obligatoria cierra con lo suyo

CUANDO no queda una sola mancha, el sistema DEBE dar limpiar por cumplida. CUANDO no queda una
sola bolsa adentro, DEBE dar la basura por cumplida. Las dos se comparan contra lo que la noche
declaró y nunca contra un número escrito.

## Criterios de aceptación

### AC-CLN-001 — Cuatro manchas de tres pasadas *(verifica BR-CLN-001)*

DADO el piso de una jornada ENTONCES tiene una mancha por zona y el total de pasadas es 12.

### AC-CLN-002 — Sin trapeador no se limpia *(verifica BR-CLN-002)*

DADO una mancha entera CUANDO se pasa con la mano vacía o con otro objeto ENTONCES el resultado
es «sin trapeador» y las pasadas restantes no bajaron.

### AC-CLN-003 — Lo limpio no baja de cero *(verifica BR-CLN-003)*

DADO una mancha con 0 pasadas restantes CUANDO se pasa el trapeador ENTONCES el resultado es «ya
estaba limpia» y el contador sigue en 0.

### AC-CLN-004 — La última pasada se anuncia distinto *(verifica BR-CLN-004)*

DADO una mancha con 1 pasada restante CUANDO se pasa el trapeador ENTONCES el resultado es
«mancha limpiada»; con 2 restantes, es «pasada».

### AC-CLN-005 — La mancha espera *(verifica BR-CLN-005)*

DADO una mancha de 3 pasadas CUANDO se dan 2 y se vuelve más tarde ENTONCES le falta 1.

### AC-CLN-006 — Las manchas obligan a caminar *(verifica BR-CLN-006)*

DADO las posiciones de las cuatro manchas y del trapeador en la escena ENTONCES ningún par está a
menos de 4 metros, y 4 es mayor al alcance de la mira.

### AC-CLN-007 — Tres bolsas son más que las manos *(verifica BR-CLN-007)*

DADO las bolsas de la jornada ENTONCES son 3, con identidades distintas, y son más que las manos
disponibles.

### AC-CLN-008 — El fondo está lejos *(verifica BR-CLN-008)*

DADO las posiciones del descarte, de las tareas del local y de las bolsas en la escena ENTONCES
ninguna está a menos de 6 metros del descarte, y 6 es mayor al alcance de la mira.

### AC-CLN-009 — El borde de la zona *(verifica BR-CLN-009)*

DADO una bolsa soltada a exactamente 1,5 metros del centro ENTONCES se deposita; a 1,6 metros, el
resultado es «fuera de la zona» y la misma bolsa se puede depositar después adentro.

### AC-CLN-010 — El radio de la escena es el de la regla *(verifica BR-CLN-009)*

DADO la zona de descarte de la escena ENTONCES su radio es el mismo número que declara la regla.

### AC-CLN-011 — El orden de los rechazos *(verifica BR-CLN-010)*

DADO algo que no es una bolsa, soltado fuera de la zona ENTONCES el resultado es «no es basura»;
DADO una bolsa ya depositada, soltada fuera de la zona, es «ya depositada».

### AC-CLN-012 — Las dos obligatorias cierran *(verifica BR-CLN-011)*

DADO el piso con las cuatro manchas limpias ENTONCES limpiar está cumplida; DADO las tres bolsas
en el descarte ENTONCES la basura está cumplida; con una sola pendiente en cada caso, no.

## No objetivos

- Esta capacidad NO decide cuánto tiempo cuestan las dos tareas: los costos son de
  [`shift-cycle`](../shift-cycle/shift-cycle.md).
- Esta capacidad NO mide distancias: las recibe ya medidas. El dominio no sabe de física.
- Esta capacidad NO dibuja la mancha ni la bolsa.

## Contratos

- **Entrada:** qué se lleva en la mano, a qué zona se pasa el trapeador, y a qué distancia del
  descarte se soltó la bolsa.
- **Salida:** cómo salió la pasada, cómo salió el depósito, cuántas pasadas y bolsas faltan, y si
  cada obligatoria está cumplida.
- **Falla:** cuatro motivos de rechazo para limpiar y tres para la basura, cada uno con su
  cartel. Ninguno cambia el estado.

## Señales

- La pasada dada y la bolsa depositada.

## Dependencias

- [`player-actions`](../player-actions/player-actions.md) (consume): qué se lleva en la mano y a
  qué distancia se soltó.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (alimenta): avisa cuándo cada obligatoria quedó
  cumplida.

## Preguntas abiertas

- **OQ-CLN-001 — ¿Las manchas aparecen durante la noche o están todas desde el principio?**
  - Por qué sigue abierta: hoy están las cuatro desde la apertura, para no mover el presupuesto
    de trayecto. El GDD no lo dice.
  - Decide: el dueño del repo.
  - Bloquea: nada. Cambiaría `BR-CLN-001`.
