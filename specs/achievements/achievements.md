---
schema_version: 1
capability_id: CAP-ACH
status: ratified
owner: por definir
provenance: fichas «Logros», «2. Menú de inicio» (sección «Interfaz de logros») y «Pausa y menú de pausa»; decisiones de #381
---

# Capacidad: logros

## Propósito

Premiar ciertas acciones del jugador con logros que duran entre partidas, y mostrar en una pantalla
cuáles tiene, qué pistas halló y a qué finales llegó. Los logros no cambian el resultado de ninguna
noche.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Logro** | uno de los nueve premios del catálogo cerrado, con nombre fijo | medalla, trofeo |
| **Desbloquear** | ganar un logro por primera vez; ocurre una sola vez en la vida del archivo | completar, activar |
| **Catalogado** | el logro existe y se muestra, aunque nada lo desbloquee todavía | implementado |
| **Final alcanzado** | un final de la partida que el jugador vio alguna vez: despedido, contrato cumplido o jefe saboteador | final desbloqueado |
| **Pista descubierta** | una pista que la investigación aceptó alguna vez, en cualquier partida | pista vista |
| **Pantalla de logros** | la pantalla de tres columnas —pistas, finales y logros— que abren el menú de inicio y la pausa | galería |

Los nueve logros y su nombre en pantalla son: **Obelisco de cartón**, **Rebelde**, **Y se marchó…**,
**A la basura**, **Estamos al pedo, ¿no?**, **Empleado ejemplar**, **Pésima primera impresión**,
**Mi talón de Aquiles** y **Elemental, mi querida Yasmín**. Los tres finales y su nombre en pantalla
son **Despedido**, **Contrato cumplido** y **Jefe saboteador**.

## Comportamiento normativo

### BR-ACH-001 — El catálogo es cerrado

El sistema DEBE ofrecer exactamente los nueve logros del lenguaje de la capacidad, cada uno con su
nombre. Un nombre desconocido NO DEBE crear un logro.

### BR-ACH-002 — Un logro se desbloquea una sola vez

CUANDO se cumple la condición de un logro todavía bloqueado, el sistema DEBE desbloquearlo, avisar
(BR-NTF-017) y escribirlo al disco en ese momento. SI el logro ya estaba desbloqueado, ENTONCES
cumplir otra vez su condición NO DEBE avisar ni escribir. Dos logros ganados juntos se desbloquean y se avisan
por separado.

### BR-ACH-003 — Rebelde

CUANDO el jugador tira un ticket al inodoro, el sistema DEBE desbloquear Rebelde. Es el mismo suceso
que BR-CLN-030 anota como papel en el inodoro.

### BR-ACH-004 — Y se marchó…

CUANDO un cuerpo levantable que el jugador soltó adentro del local pasa a estar afuera, el sistema
DEBE desbloquear Y se marchó… en ese momento, no al cierre. «Afuera» es la definición de BR-CLN-029:
un cuerpo sostenido no cuenta, y lo que BR-CLN-038 exime tampoco. Lo que recibió un comprador y lo que
un comprador que se cansa deja en el piso NO DEBEN desbloquearlo: no los soltó el jugador.

### BR-ACH-005 — A la basura

CUANDO el jugador tira al contenedor un objeto que BR-CLN-031 cuenta como importante, el sistema DEBE
desbloquear A la basura. Una bolsa de basura, un ticket y todo lo que BR-CLN-038 exime NO DEBEN
desbloquearlo. El logro DEBE leer la misma regla que el llamado, para que no se separen.

### BR-ACH-006 — Estamos al pedo, ¿no?

CUANDO una fila de la planilla de ventas llega al tope de BR-STK-020, el sistema DEBE desbloquear
Estamos al pedo, ¿no?. Una fila en el tope menos una unidad NO DEBE desbloquearlo. Llegar al tope,
bajar y volver a llegar NO DEBE avisar otra vez (BR-ACH-002).

### BR-ACH-007 — Empleado ejemplar

CUANDO la partida termina con contrato cumplido (BR-EMP-004) y el legajo no suma ningún medio
apercibimiento, el sistema DEBE desbloquear Empleado ejemplar. Un solo medio apercibimiento en el
legajo NO DEBE desbloquearlo.

### BR-ACH-008 — Pésima primera impresión

CUANDO la partida termina despedida al cerrar una jornada de la prueba (BR-EMP-037), el sistema DEBE
desbloquear Pésima primera impresión. Un despido desde la primera jornada completa NO DEBE
desbloquearlo.

### BR-ACH-009 — Mi talón de Aquiles

CUANDO una misma obligatoria fija suma su cuarta falla en la partida (BR-EMP-025), el sistema DEBE
desbloquear Mi talón de Aquiles. Tres fallas NO DEBEN desbloquearlo. La cuenta cruza el guardado
(BR-SAV-019), y una partida nueva empieza en cero; el logro ya ganado sigue ganado. La tarea
particular de cada noche NO suma fallas.

### BR-ACH-010 — Dos logros catalogados y bloqueados

El sistema DEBE catalogar Obelisco de cartón y Elemental, mi querida Yasmín, y mostrarlos bloqueados.
NINGUNA acción del juego DEBE desbloquearlos mientras OQ-ACH-001 y OQ-ACH-002 sigan abiertas.

### BR-ACH-011 — Los logros duran entre partidas

El sistema DEBE guardar los logros desbloqueados en un archivo propio, separado del guardado de la
partida y de las preferencias. Borrar el guardado de la partida (BR-SAV-002, BR-SAV-012) NO DEBE
tocarlo. En la web sobrevive a recargar la página en el mismo navegador.
SI no hay archivo, ENTONCES ningún logro está desbloqueado. SI el archivo es ilegible, ENTONCES
ninguno lo está y el juego NO DEBE interrumpirse. SI el archivo nombra un logro que el catálogo no
conoce, ENTONCES el sistema DEBE ignorarlo y conservar los demás.

### BR-ACH-012 — Los finales y las pistas también duran

CUANDO la partida termina, el sistema DEBE anotar en el mismo archivo el final alcanzado: despedido,
contrato cumplido o jefe saboteador. CUANDO la investigación acepta una pista nueva (BR-NTF-010), el sistema DEBE
anotarla como descubierta en el mismo archivo. Las dos anotaciones DEBEN cruzar partidas como los
logros, y repetirlas no cambia nada. SI el archivo nombra una pista o un final que el juego no
conoce, ENTONCES el sistema DEBE ignorarlo.

### BR-ACH-013 — La pantalla tiene tres columnas

La pantalla de logros DEBE mostrar tres columnas, en este orden: **pistas, finales y logros**. La de
pistas DEBE listar las pistas del caso que dejan una nota, con foto y texto: una pista de acción,
sin foto ni texto, NO DEBE aparecer, porque nunca se descubre como las demás. La de finales DEBE
listar todos los finales de la partida. La de logros DEBE listar los nueve.

### BR-ACH-014 — Una entrada desbloqueada muestra, una bloqueada pregunta

Una entrada desbloqueada DEBE mostrar su imagen pequeña y su nombre. Una pista descubierta muestra
su foto y el texto de su nota. Una entrada bloqueada DEBE mostrar la imagen de signo de pregunta y el
texto «?????» en lugar de su nombre. Los nombres con «¿», «¡» y «…» DEBEN verse enteros.

### BR-ACH-015 — La pantalla se abre del menú de inicio y de la pausa

CUANDO el jugador elige «logros» en el menú de inicio o en el menú de pausa, el sistema DEBE abrir
la pantalla de logros. La pantalla DEBE correr también con la partida en pausa, y NO DEBE cambiar
nada de la partida. El cierre y el regreso a cada menú los fija BR-SAV-016.

## Criterios de aceptación

### AC-ACH-001 — El catálogo y sus nombres *(verifica BR-ACH-001, BR-ACH-010)*

DADO el catálogo ENTONCES hay exactamente nueve logros, cada uno con un nombre distinto y no vacío,
y un nombre fuera de la lista no produce ninguno. DADO un archivo sin logros ENTONCES los nueve están
bloqueados.

### AC-ACH-002 — Una sola vez *(verifica BR-ACH-002)*

DADO un logro bloqueado CUANDO se desbloquea ENTONCES contesta que lo ganó, está desbloqueado y se
escribió al disco una vez. CUANDO se desbloquea otra vez ENTONCES contesta que ya estaba, no avisa y
no vuelve a escribir. DADO dos logros distintos ganados en el mismo cuadro ENTONCES hay dos avisos.

### AC-ACH-003 — Rebelde y A la basura no se confunden *(verifica BR-ACH-003, BR-ACH-005)*

DADO un ticket CUANDO se tira al inodoro ENTONCES se desbloquea Rebelde y no A la basura. DADO el
mismo ticket CUANDO se tira al contenedor ENTONCES no se desbloquea ninguno. DADO una bolsa de basura
tirada al contenedor ENTONCES tampoco. DADO un levantable que BR-CLN-031 cuenta como importante
tirado al contenedor ENTONCES se desbloquea A la basura.

### AC-ACH-004 — Y se marchó… al instante y sólo si lo soltó el jugador *(verifica BR-ACH-004)*

DADO un levantable soltado adentro CUANDO queda afuera ENTONCES se desbloquea en ese momento, con la
jornada todavía abierta. DADO un cuerpo sostenido afuera, uno recibido por un comprador, uno que un
comprador cansado deja en el piso, o uno eximido por BR-CLN-038 ENTONCES no se desbloquea.

### AC-ACH-005 — El tope de la planilla *(verifica BR-ACH-006)*

DADO una fila en el tope de BR-STK-020 menos una unidad CUANDO se suma una ENTONCES se desbloquea
Estamos al pedo, ¿no?. DADO la fila una unidad antes del tope ENTONCES no. DADO el logro ganado
CUANDO se baja y se vuelve al tope ENTONCES no hay otro aviso.

### AC-ACH-006 — Empleado ejemplar pide cero medios *(verifica BR-ACH-007)*

DADO una partida con contrato cumplido y el legajo en cero medios ENTONCES se desbloquea Empleado
ejemplar. DADO la misma partida con un medio apercibimiento ENTONCES no. DADO una partida despedida
ENTONCES no.

### AC-ACH-007 — Pésima primera impresión sólo en la prueba *(verifica BR-ACH-008)*

DADO una partida despedida al cerrar la última jornada de la prueba ENTONCES se desbloquea Pésima
primera impresión. DADO una partida despedida al cerrar la primera jornada completa o una posterior
ENTONCES no. DADO una partida que sigue, o con contrato cumplido, ENTONCES no.

### AC-ACH-008 — Mi talón de Aquiles cuenta hasta cuatro y cruza el guardado *(verifica BR-ACH-009)*

DADO una obligatoria fija con tres fallas ENTONCES no se desbloquea; con cuatro, sí. DADO fallas
repartidas, tres en una tarea y tres en otra, ENTONCES no. DADO tres fallas guardadas y retomadas
CUANDO una cuarta falla de esa tarea cierra la noche ENTONCES se desbloquea. DADO una partida nueva
ENTONCES la cuenta empieza en cero y el logro ya ganado sigue desbloqueado.

### AC-ACH-009 — Los bloqueados de esta tanda *(verifica BR-ACH-010)*

DADO cualquier secuencia de las siete condiciones entregadas ENTONCES Obelisco de cartón y Elemental,
mi querida Yasmín siguen bloqueados, y ambos aparecen en el catálogo.

### AC-ACH-010 — El archivo sobrevive al guardado de la partida *(verifica BR-ACH-011)*

DADO un logro desbloqueado CUANDO termina la partida, o se confirma «nuevo juego», ENTONCES sigue
desbloqueado al cargar el archivo. DADO que no hay archivo ENTONCES ningún logro está desbloqueado.
DADO un archivo ilegible ENTONCES ninguno lo está y no hay error. DADO un archivo con un logro
desconocido y uno válido ENTONCES sólo el válido queda desbloqueado.

### AC-ACH-011 — Finales y pistas duran *(verifica BR-ACH-012)*

DADO una partida que termina despedida ENTONCES el final despedido queda alcanzado y el de contrato
cumplido no. DADO una pista nueva aceptada ENTONCES queda descubierta, también en la partida
siguiente. DADO el mismo final o la misma pista otra vez ENTONCES el archivo queda igual. DADO un
final o una pista desconocidos en el archivo ENTONCES se ignoran.

### AC-ACH-012 — Tres columnas en orden *(verifica BR-ACH-013, BR-ACH-014)*

DADO la pantalla de logros ENTONCES hay tres columnas, en este orden: pistas, finales y logros. La
de logros lista nueve entradas, la de finales una por cada final de la partida, y la de pistas una
por cada pista del caso que deja nota: una pista sin foto ni texto no tiene entrada.

### AC-ACH-013 — Desbloqueada nombra, bloqueada pregunta *(verifica BR-ACH-014)*

DADO un logro desbloqueado ENTONCES su entrada muestra su imagen y su nombre. DADO uno bloqueado
ENTONCES muestra el signo de pregunta y «?????». DADO una pista descubierta ENTONCES muestra su foto
y el texto de su nota; sin descubrir, el signo de pregunta. DADO un final alcanzado y uno no
ENTONCES lo mismo. Los nombres con «¿», «¡» y «…» se ven enteros con la fuente del tema.

### AC-ACH-014 — Se abre del menú de inicio y de la pausa *(verifica BR-ACH-015)*

DADO el menú de inicio CUANDO se elige «logros» ENTONCES se abre la pantalla. DADO el menú de pausa
CUANDO se elige «logros» ENTONCES se abre, con el árbol en pausa, y abrirla y cerrarla no cambia la
jornada, el reloj ni el guardado.

## No objetivos

- Esta capacidad NO desbloquea Obelisco de cartón ni Elemental, mi querida Yasmín.
- Esta capacidad NO incluye logros en Steam ni en otra plataforma.
- Esta capacidad NO decide los finales de la partida ni qué es una pista: los consume.
- Esta capacidad NO guarda la partida ni las preferencias.

## Contratos

- **Entrada:** los sucesos de la partida —ticket tirado al inodoro, cuerpo afuera, objeto al contenedor,
  fila de la planilla, final de la partida, fallas por tarea, pista aceptada— y el archivo al
  arrancar.
- **Salida:** logros, finales y pistas desbloqueados; si un desbloqueo es nuevo; la pantalla.
- **Falla:** sin archivo, o con uno ilegible, todo bloqueado y sin error. Una escritura fallida no
  interrumpe y no revierte el desbloqueo en memoria.

## Señales

- Logro desbloqueado: una vez por logro, para que `notifications` lo avise.
- Pedido de abrir la pantalla, desde el menú de inicio y desde la pausa, y cierre de la pantalla.

## Dependencias

- [`store-cleanup`](../store-cleanup/store-cleanup.md) (consume): ticket al inodoro, cuerpo afuera y
  objeto al contenedor.
- [`store-stock`](../store-stock/store-stock.md) (consume): el tope de las filas de la planilla.
- [`employment-record`](../employment-record/employment-record.md) (consume): el final, el legajo
  y las fallas por tarea.
- [`investigation`](../investigation/investigation.md) (consume): la pista aceptada y las pistas
  del caso.
- [`notifications`](../notifications/notifications.md) (alimenta): el aviso de cada logro.
- [`save-and-resume`](../save-and-resume/save-and-resume.md) (consume): el menú de inicio y el
  de pausa abren la pantalla, y Esc la cierra.

## Preguntas abiertas

- **OQ-ACH-001 — ¿Se desbloquea Elemental, mi querida Yasmín en esta tanda?**
  - Por qué sigue abierta: su condición, descubrir todas las pistas, ya es evaluable porque las pistas
    existen. El issue la deja fuera de la entrega, a la espera de una decisión.
  - Decide: el dueño del repo.
  - Bloquea: BR-ACH-010, en lo que toca a este logro.
- **OQ-ACH-002 — ¿Se puede apilar siete cajas con los gestos reales?**
  - Por qué sigue abierta: no se demostró una secuencia jugable que apile siete cajas. Armar la pila
    por código no entrega el logro al jugador.
  - Decide: el dueño del repo, con una prueba jugada.
  - Bloquea: el desbloqueo de Obelisco de cartón.
