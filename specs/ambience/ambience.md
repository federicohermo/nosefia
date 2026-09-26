---
schema_version: 1
capability_id: CAP-AMB
status: ratified
owner: por definir
provenance: GDD «Ambiente»; migración de los specs 021, 040
---

# Capacidad: el ambiente del local

## Propósito

Que el juego suene, sin que agregar un sonido toque código. Lo único que tiene que hacer bien es
**no sonar por el canal equivocado**: un bus que no existe no da error, cae al maestro en
silencio y el mezclador deja de servir.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Evento** | algo que pasa en el juego y puede sonar | trigger, acción |
| **Fila** | la declaración de un evento: qué señal lo dispara, por qué bus sale | entrada, regla |
| **Bus** | uno de los cuatro canales de mezcla del local | pista, canal |
| **Voz** | uno de los reproductores que se reparten los sonidos cortos | slot, player |

## Comportamiento normativo

### BR-AMB-001 — Los eventos se declaran en un solo lugar

El sistema DEBE tener **una lista cerrada de eventos que pueden sonar**, y agregar un sonido DEBE
ser sumar un evento y su fila. Ningún sistema lleva una lista propia.

### BR-AMB-002 — Lo que se emite por cuadro no suena

El sistema NO DEBE poder enganchar un sonido a una señal que se emite en cada cuadro. Sería pedir
un sonido por cuadro.

### BR-AMB-003 — Cuatro buses, declarados una vez

El sistema DEBE tener **cuatro buses** —ambiente, efectos, interfaz y música— y el mezclador de
la escena DEBE declarar los mismos nombres. Un bus renombrado deja su canal sonando por el
maestro sin que nada avise.

### BR-AMB-004 — Una fila con un bus inventado no suena

SI el bus de una fila no es uno de los cuatro, ENTONCES el sistema DEBE declararla inválida en
vez de dejarla sonar.

### BR-AMB-005 — La tabla cubre todos los eventos

El sistema DEBE tener una fila por cada evento declarado, y DEBE poder decir **cuáles faltan**.
Dos filas del mismo evento darían el número correcto con un evento mudo.

### BR-AMB-006 — El enlace es por nombre de señal

El sistema DEBE enganchar cada fila a su señal **por nombre**, como dato. Una fila cuya señal
todavía no existe queda sin fuente y se declara, en vez de romper.

### BR-AMB-007 — Las voces se reparten por turno

CUANDO suena algo corto, el sistema DEBE usar la voz siguiente y volver al principio al terminar
la vuelta. Son **8 voces**: sin repartir, dos sonidos seguidos se pisarían en la misma voz.

### BR-AMB-008 — Lo que va en bucle no gasta una voz

MIENTRAS un sonido va en bucle, el sistema DEBE dejarlo fuera de la ronda. Una ronda con un bucle
adentro se queda sin voces.

### BR-AMB-009 — Una ronda sin voces no divide por cero

SI no hay ninguna voz, ENTONCES el sistema DEBE contestar que no hay y no ocupar ninguna.

## Criterios de aceptación

### AC-AMB-001 — Un evento, una fila *(verifica BR-AMB-001, BR-AMB-005)*

DADO la tabla de sonidos ENTONCES cubre todos los eventos declarados, y la lista de los que
faltan está vacía.

### AC-AMB-002 — Lo que se emite por cuadro no está *(verifica BR-AMB-002)*

DADO la lista de eventos ENTONCES el consumo de tiempo del turno no es uno de ellos.

### AC-AMB-003 — Los cuatro buses coinciden *(verifica BR-AMB-003)*

DADO los cuatro buses declarados y el mezclador de la escena ENTONCES los nombres son los mismos,
y el maestro no es uno de los cuatro.

### AC-AMB-004 — El bus inventado se rechaza *(verifica BR-AMB-004)*

DADO una fila con un bus que no está declarado ENTONCES es inválida, y aparece en la lista de
filas inválidas.

### AC-AMB-005 — La fila sin señal se declara *(verifica BR-AMB-006)*

DADO una fila sin señal ENTONCES dice que no tiene fuente, y la tabla carga igual.

### AC-AMB-006 — La ronda vuelve al principio *(verifica BR-AMB-007)*

DADO una ronda de 8 voces CUANDO se piden 9 ENTONCES los índices van de 0 a 7 y el noveno es 0.

### AC-AMB-007 — La ronda vacía contesta que no hay *(verifica BR-AMB-009)*

DADO una ronda de 0 voces CUANDO se pide una ENTONCES contesta que no hay, sin dividir por cero.

## No objetivos

- Esta capacidad NO elige los archivos de audio ni los mezcla. Una fila sin sonido es un estado
  normal: el sonido todavía no está elegido.
- Esta capacidad NO decide cuándo pasa cada evento: escucha la señal de quien lo produce.

## Contratos

- **Entrada:** la tabla de filas y las señales que los otros sistemas emiten.
- **Salida:** la fila de cada evento, cuáles faltan, cuáles son inválidas y qué voz toca.
- **Falla:** un evento sin fila contesta «no hay» en vez de una fila muda inventada; una ronda
  vacía contesta que no hay voz.

## Señales

- Ninguna propia: esta capacidad sólo escucha.

## Dependencias

- Todas las demás capacidades (consume): sus señales son las fuentes de las filas.

## Preguntas abiertas

- **OQ-AMB-001 — ¿Qué suena en cada evento?**
  - Por qué sigue abierta: elegir y mezclar los archivos de audio es trabajo de sonido.
    La tabla existe para que hacerlo no toque código.
  - Decide: el dueño del repo.
  - Bloquea: nada de la máquina.
