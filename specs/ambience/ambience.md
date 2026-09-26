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
| **Sonoridad** | cómo suena una cosa al agarrarla o al dejarla | familia, material, envase |
| **Evento de objeto** | agarrar un objeto, que un objeto soltado toque algo, o colocar un producto | — |
| **Golpe** | un contacto de un objeto soltado, lo bastante rápido para sonar | choque, impacto |

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

### BR-AMB-008 — Cada bucle tiene su voz

MIENTRAS un sonido va en bucle, el sistema DEBE dejarlo fuera de la ronda y darle una voz propia.
Dos bucles distintos, como la música y el ambiente, DEBEN sonar a la vez sin cortarse. Una ronda
con un bucle adentro se queda sin voces.

### BR-AMB-009 — Una ronda sin voces no divide por cero

SI no hay ninguna voz, ENTONCES el sistema DEBE contestar que no hay y no ocupar ninguna.

### BR-AMB-010 — Un evento de objeto suena según la sonoridad del objeto

CUANDO pasa un evento de objeto, el sistema DEBE usar la fila de ese evento para la sonoridad
del objeto. Agarrar suena el alzar de esa sonoridad; tocar algo y colocar suenan el dejar. SI no
hay fila para ese par, ENTONCES el sistema DEBE contestar que no hay.

### BR-AMB-011 — La tabla cubre cada sonoridad de cada evento de objeto

El sistema DEBE tener una fila por cada par de evento de objeto y sonoridad, y DEBE poder decir
**qué pares faltan**. Los demás eventos siguen con una sola fila.

### BR-AMB-012 — Una sonoridad sin audio no suena

SI la fila de una sonoridad no tiene audio, ENTONCES el sistema NO DEBE sonar, DEBE declarar el
rechazo y NO DEBE usar el audio de otra sonoridad.

### BR-AMB-013 — Lo soltado suena al tocar algo, y cada golpe más bajo

CUANDO un objeto soltado deja de caer contra cualquier cosa, el sistema DEBE contar un golpe. Un
contacto más lento que el umbral de golpe NO DEBE contar ni gastar un golpe. Soltar no suena.
El sistema DEBE sonar sólo los tres primeros golpes, desde que se suelta hasta que se agarra
otra vez:

| Golpe | Volumen | Filtro pasa-altos |
|---|---|---|
| 1.º | 0 dB | ninguno |
| 2.º | −6 dB | un corte |
| 3.º | −12 dB | un corte más alto que el del 2.º |
| 4.º en adelante | no suena | — |

CUANDO el objeto se agarra otra vez, el sistema DEBE volver a contar desde el 1.º.

### BR-AMB-014 — Colocar suena una vez

CUANDO un producto se coloca en la góndola, el sistema DEBE sonar el dejar de su sonoridad una
vez, a 0 dB y sin filtro. Colocar NO DEBE contar golpes.

### BR-AMB-015 — La música suena toda la noche

CUANDO se abre una jornada, el sistema DEBE sonar la música en bucle por el bus de música. SI la
música ya suena, ENTONCES NO DEBE empezarla de nuevo. CUANDO se cierra la jornada, el sistema
DEBE cortarla, aunque la computadora esté abierta.

### BR-AMB-016 — Lo que pasa en un lugar suena desde ese lugar

Que un sonido salga del espacio o salga plano DEBE ser un dato de su fila. CUANDO suena una fila
del espacio, el sistema DEBE sonarla desde el objeto que la produjo o, si no hay objeto, desde el
emisor fijo que la fila nombra. El sonido DEBE quedar donde empezó aunque el objeto se mueva o se
borre. SI una fila del espacio no tiene de dónde sonar, ENTONCES el sistema DEBE rechazarla con
un motivo propio, en vez de sonarla plana. La interfaz, el fin del turno, la música y los pasos
suenan planos.

### BR-AMB-017 — El ambiente suena desde sus emisores, con un tope

El ambiente del local DEBE sonar en bucle desde la heladera y desde los tubos del salón, por el
bus de ambiente. MIENTRAS suena, el sistema DEBE sonar sólo los emisores más cercanos al jugador,
hasta el tope de emisores; los demás esperan. Dos emisores a la misma distancia DEBEN quedar en el
mismo orden entre cuadros. Con cero emisores, NO DEBE sonar nada ni fallar.

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

### AC-AMB-008 — La fila sale del par *(verifica BR-AMB-010)*

DADO la tabla del juego CUANDO se pide agarrar para la lata ENTONCES contesta el alzar de lata,
y colocar para la cajita contesta el dejar de cajita. DADO una tabla sin la fila de agarrar para
el papel CUANDO se la pide ENTONCES contesta que no hay.

### AC-AMB-009 — Falta un par y la tabla lo nombra *(verifica BR-AMB-011)*

DADO la tabla del juego ENTONCES no falta ningún par. DADO una tabla con todas las filas menos
la de tocar algo para la bolsa ENTONCES no cubre todo, y el par que falta es ése.

### AC-AMB-010 — La caja no suena y no cae a otro audio *(verifica BR-AMB-012)*

DADO la fila de agarrar para la caja, sin audio, CUANDO se agarra una caja ENTONCES no ocupa
ninguna voz y el rechazo es «sin sonido».

### AC-AMB-011 — Tres golpes que se apagan *(verifica BR-AMB-013)*

DADO un objeto soltado CUANDO toca algo cinco veces, más rápido que el umbral ENTONCES el 1.º
suena a 0 dB sin filtro, el 2.º a −6 dB con un corte, el 3.º a −12 dB con un corte más alto que
el del 2.º, y el 4.º y el 5.º no suenan.

### AC-AMB-012 — Lo lento no gasta, y agarrar reinicia *(verifica BR-AMB-013)*

DADO un objeto soltado CUANDO toca algo justo por debajo del umbral ENTONCES no suena, y el
contacto siguiente, por encima, es el 1.º. DADO un objeto con dos golpes CUANDO se lo agarra y
se lo suelta ENTONCES el golpe siguiente es otra vez el 1.º.

### AC-AMB-013 — Agarrar y colocar suenan por su sonoridad *(verifica BR-AMB-010, BR-AMB-014)*

DADO una lata CUANDO se la agarra ENTONCES suena el alzar de lata. CUANDO se la suelta y todavía
no toca nada ENTONCES no suena. DADO un producto de cajita CUANDO se lo coloca ENTONCES suena el
dejar de cajita a 0 dB, sin filtro, y el contacto siguiente no cuenta como golpe.

### AC-AMB-014 — La música y el ambiente a la vez *(verifica BR-AMB-008)*

DADO la música y el ambiente, los dos en bucle CUANDO se piden los dos ENTONCES los dos quedan
pedidos, cada uno en su voz, y ninguna voz de la ronda queda ocupada.

### AC-AMB-015 — La música de jornada en jornada *(verifica BR-AMB-015)*

DADO la música sonando CUANDO se abre la jornada otra vez ENTONCES no se pide de nuevo. CUANDO se
cierra la jornada ENTONCES su voz queda sin nada pedido. CUANDO se abre la siguiente ENTONCES
suena otra vez.

### AC-AMB-016 — El lugar es un dato de la fila *(verifica BR-AMB-016)*

DADO una fila del espacio y un objeto en (1, 0, 2) CUANDO el objeto la produce ENTONCES suena en
una voz del espacio, en (1, 0, 2), y la voz se queda ahí aunque el objeto se mueva. DADO una fila
del espacio con un emisor fijo CUANDO suena sin objeto ENTONCES suena en la posición del emisor.
DADO una fila del espacio sin objeto y sin emisor ENTONCES se rechaza por no tener posición.
DADO una fila plana ENTONCES suena en una voz plana.

### AC-AMB-017 — El tope de emisores *(verifica BR-AMB-017)*

DADO distancias 5, 1 y 3 y un tope de 2 ENTONCES suenan el segundo y el tercero. DADO un tope de
3 ENTONCES suenan los tres. DADO dos emisores a la misma distancia en el borde del tope ENTONCES
suena el primero de la lista, las dos veces. DADO cero emisores ENTONCES no suena ninguno.

## No objetivos

- Esta capacidad NO elige los archivos de audio ni los mezcla. Una fila sin sonido es un estado
  normal: el sonido todavía no está elegido.
- Esta capacidad NO decide cuándo pasa cada evento: escucha la señal de quien lo produce.

## Contratos

- **Entrada:** la tabla de filas, las señales que los otros sistemas emiten, la sonoridad de
  cada objeto y la rapidez de cada contacto de un objeto soltado.
- **Salida:** la fila de cada evento, cuáles faltan, cuáles son inválidas y qué voz toca.
- **Falla:** un evento sin fila contesta «no hay» en vez de una fila muda inventada; una ronda
  vacía contesta que no hay voz.

## Señales

- Ninguna propia: esta capacidad sólo escucha.

## Dependencias

- Todas las demás capacidades (consume): sus señales son las fuentes de las filas.

## Preguntas abiertas

- **OQ-AMB-001 — ¿Qué suena en cada evento?**
  - Por qué sigue abierta: elegir y mezclar los archivos de audio es trabajo de sonido, y todavía
    no se hizo. La tabla existe para que hacerlo no toque código.
  - Decide: el dueño del repo.
  - Bloquea: nada de la máquina.
- **OQ-AMB-002 — ¿Qué tan rápido tiene que tocar algo un objeto para que cuente como golpe?**
  - Por qué sigue abierta: sale de medir en el local, con un objeto que vibra apoyado y uno que
    cae desde la mano. El juego arranca con un primer valor.
  - Decide: el dueño del repo.
  - Bloquea: nada de la máquina.
- **OQ-AMB-003 — ¿En qué frecuencias corta el filtro del 2.º y del 3.º golpe?**
  - Por qué sigue abierta: sale de escuchar los golpes en el local. El juego arranca con un
    primer valor.
  - Decide: el dueño del repo.
  - Bloquea: nada de la máquina.
- **OQ-AMB-004 — ¿Qué tan fuerte suena el ambiente de los tubos y la heladera?**
  - Por qué sigue abierta: tiene que ser sutil, y eso sale de escuchar en el local. El juego
    arranca con un primer valor.
  - Decide: el dueño del repo.
  - Bloquea: nada de la máquina.
- **OQ-AMB-005 — ¿Cuántos emisores del ambiente suenan a la vez?**
  - Por qué sigue abierta: sale de escuchar en el local. El juego arranca con un primer valor.
  - Decide: el dueño del repo.
  - Bloquea: nada de la máquina.
- **OQ-AMB-006 — ¿A qué distancia deja de oírse un emisor del ambiente?**
  - Por qué sigue abierta: sale de caminar el local escuchando. El juego arranca con un primer
    valor.
  - Decide: el dueño del repo.
  - Bloquea: nada de la máquina.
