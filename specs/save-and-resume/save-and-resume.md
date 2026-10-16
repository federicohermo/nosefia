---
schema_version: 1
capability_id: CAP-SAV
status: draft
owner: por definir
provenance: GDD «checkpoint al final de cada noche»; ficha «Pantalla entre jornadas» y decisiones de #374; fichas «2. Menú de inicio» y «Pausa y menú de pausa» y decisiones de #378; decisión del 2026-09-28 de #299; decisiones de #375; migración de los specs 019, 020, 036; historial de devoluciones fechado y compatibilidad con textos legados de #430
---

# Capacidad: guardar y retomar

## Propósito

Que la partida sobreviva a cerrar el juego. Lo único que tiene que hacer bien es **no perder el
legajo**: el sistema de consecuencias sólo se ve funcionar a lo largo de varias noches, y sin
guardado hay que jugar las cinco de una sentada.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Guardado** | el único archivo de la partida. Hay uno, no ranuras | save, slot |
| **Campo** | un dato que cruza la sesión, con su tipo y su valor por defecto | clave, columna |
| **Sanear** | completar un guardado incompleto o mal tipado con sus defectos | migrar, parchear |
| **Retomar** | seguir la partida guardada desde el menú | cargar, continuar |
| **Pausa** | la jornada detenida, con su menú en pantalla. Incluye la jornada ya cerrada, con la devolución debajo | freeze, stop |

## Comportamiento normativo

### BR-SAV-001 — Se guarda al cerrar la jornada

CUANDO cierra una jornada, el sistema DEBE guardar. Es el checkpoint que pide el GDD, y es el
único momento en que se escribe.

### BR-SAV-002 — Un final resetea el progreso

SI la partida terminó —por despido o por contrato cumplido—, ENTONCES el sistema DEBE **borrar el
guardado** en vez de escribirlo.

### BR-SAV-003 — Decidir y escribir son dos cosas

El sistema DEBE decidir entre escribir y borrar **sin tocar disco**, y DEBE tener exactamente
esas dos acciones. No hay «abortar»: un disco que falla no interrumpe la partida.

### BR-SAV-004 — Un guardado que falla no interrumpe

SI la escritura falla, ENTONCES la partida DEBE seguir y el cierre siguiente DEBE volver a
intentar.

### BR-SAV-005 — Ida y vuelta sin pérdida

CUANDO se guarda y se carga, el sistema DEBE devolver los mismos valores con los mismos tipos.

### BR-SAV-006 — Un guardado viejo se completa, no rompe

SI a un guardado le falta un campo, o SI un campo tiene otro tipo, ENTONCES el sistema DEBE
devolverlo con su valor por defecto. Es lo mismo que le pasa a un archivo editado a mano.

### BR-SAV-007 — Una versión futura no se carga y no se borra

El sistema DEBE aceptar la versión actual, las anteriores y un guardado sin versión. SI la
versión es posterior a la actual, ENTONCES NO DEBE cargarlo **ni borrarlo**.

### BR-SAV-008 — Sin archivo no hay partida

SI no hay guardado, ENTONCES cargar DEBE contestar **vacío**, y quien llama tiene que poder
distinguir «no hay partida» de «hay una en la jornada 1».

### BR-SAV-009 — Un guardado ilegible se borra

SI el archivo está corrupto, ENTONCES el sistema DEBE contestar vacío **y borrarlo**, para que el
arranque siguiente no vuelva a tropezar con él.

### BR-SAV-010 — El juego arranca en el menú

El sistema DEBE abrir el juego en un menú, y no en el almacén. El menú DEBE mostrar cinco
opciones, en este orden: **continuar, nuevo juego, logros, configuraciones y salir**.

### BR-SAV-011 — Continuar está disponible sólo con guardado

SI no hay guardado, ENTONCES «continuar» NO DEBE estar disponible y NO DEBE llevar a ningún lado.

### BR-SAV-012 — Nuevo juego inicia directamente una partida nueva

CUANDO se elige «nuevo juego», con o sin guardado, el sistema DEBE iniciar directamente una
partida nueva sin mostrar una confirmación y borrar el guardado anterior,
fundir el menú a negro durante 0,3 segundos reales, cargar el juego y presentar las instrucciones
de Enrique antes de la entrada a la primera noche. SI falla la carga, ENTONCES DEBE volver al
menú sin quedar en negro.

### BR-SAV-013 — Salir pasa por un solo lugar

El sistema DEBE tener un único camino para cerrar el juego, y sólo la opción de salir lo produce.

### BR-SAV-014 — En la web, salir no se muestra

SI el juego corre en la web, ENTONCES el menú NO DEBE mostrar la opción de salir. La página no
puede cerrar su pestaña. Las otras cuatro opciones DEBEN quedar en el mismo orden.

### BR-SAV-015 — Retomar sigue desde lo guardado

CUANDO arranca la partida, SI hay guardado, ENTONCES el sistema DEBE seguir en la jornada
guardada y con los apercibimientos guardados. SI no hay guardado, ENTONCES DEBE arrancar una
partida nueva. Retomar un guardado NO DEBE mostrar las instrucciones: DEBE anunciar directamente
la jornada guardada sobre la persiana baja y comenzar a descontar cuando termine su entrada.

### BR-SAV-016 — Esc pausa la jornada

CUANDO el jugador aprieta Esc en cualquier momento del juego en el almacén, con la partida en
curso o terminada, el sistema DEBE pausarlo y mostrar el menú de pausa. Un segundo Esc DEBE
reanudarlo, igual que «reanudar». La devolución no es una excepción: con la devolución en
pantalla, Esc DEBE abrir la pausa por encima de ella, y reanudar DEBE dejar la misma devolución,
con el turno todavía detenido y sin abrir la noche siguiente. MIENTRAS la pausa está en pantalla,
la devolución NO DEBE responder a ningún gesto. SI el cursor pasa de tomado a suelto con la ventana
activa y sin que el juego lo suelte, ENTONCES el sistema DEBE pausar: en la web el navegador
consume Esc para soltar el cursor. Soltarlo el propio juego NO DEBE pausar, y con la
devolución en pantalla perder el cursor NO DEBE pausar. Cambiar de pestaña, minimizar o pasar a otra ventana NO DEBE pausar la jornada ni
mostrar el menú de pausa; volver tampoco DEBE abrirlo.

SI Configuraciones está abierta desde la pausa, ENTONCES Esc DEBE cerrarla y dejar el menú de
pausa en pantalla, **sin reanudar**; el Esc siguiente reanuda, como siempre. SI Configuraciones
está abierta desde el menú de inicio, ENTONCES Esc DEBE cerrarla y dejar el menú de inicio.

### BR-SAV-017 — El menú de pausa muestra cuatro opciones

El menú de pausa DEBE mostrar cuatro opciones, en este orden: **reanudar, configuraciones, logros
y volver al menú**. Sólo logros DEBE verse deshabilitada: configuraciones DEBE estar habilitada y
abrir Configuraciones. El menú de pausa no ofrece salir: el juego se cierra sólo desde el menú de
inicio.

### BR-SAV-018 — Volver al menú abandona la jornada

CUANDO el jugador elige «volver al menú» en la pausa, el sistema DEBE sacar el juego de la pausa,
llevarlo al menú de inicio y NO DEBE escribir ni borrar el guardado. SI la pausa está sobre la
devolución de una partida en curso, ENTONCES el guardado que dejó el cierre DEBE quedar intacto, con la
jornada siguiente y la deuda acumulada exacta, y continuar desde el menú DEBE abrir esa jornada
sin volver a jugar la noche cerrada. SI la partida terminó, ENTONCES el guardado ya borrado por el
final NO DEBE reaparecer.

### BR-SAV-019 — Las cuentas y las devoluciones cruzan la sesión

CUANDO se guarda, el sistema DEBE escribir, además de la jornada y el legajo, las fallas de cada
obligatoria fija, los llamados de cada motivo, R, los textos de las devoluciones recibidas con identidad, jornada cerrada y orden
(BR-EMP-025, BR-EMP-031, BR-SAV-020), y si la mopa ya se secó una vez (BR-SUB-014). CUANDO se retoma, DEBE restaurarlos exactos: la devolución
siguiente cuenta desde ellos, y el chat de Enrique intercala instrucciones, aperturas y
devoluciones según BR-INV-030. SI falta alguno o tiene otro tipo, ENTONCES DEBE sanearse (BR-SAV-006) con cero
fallas, cero llamados, R = 0, ninguna devolución y la mopa sin secarse. Dentro de las cuentas, una obligatoria o un
motivo desconocido, o un valor de otro tipo, DEBE ignorarse sin descartar los demás.

### BR-SAV-020 — Los mensajes nuevos conservan fecha y los antiguos no la inventan

CUANDO se guardan devoluciones nuevas, el sistema DEBE conservar por mensaje texto, identidad,
jornada cerrada y orden dentro de la devolución. CUANDO se retoma, esos datos DEBEN volver
con sus tipos y valores originales y permitir el historial cronológico de `investigation`.
Los guiones de apertura DEBEN reconstruirse por jornada; NO DEBEN serializarse como
devoluciones ni guardar marcas de lectura en sus recursos compartidos.

SI el guardado legado contiene una lista de textos de devoluciones, ENTONCES el sistema DEBE
aceptarla y conservar todos sus textos en el mismo orden, incluidos textos iguales, sin
asignarles una jornada u hora que el archivo no contiene. La falta de fecha NO DEBE vaciar
la lista válida de devoluciones ni borrar el progreso. Su posición entre aperturas
queda sujeta a OQ-INV-005; conservar orden y texto NO DEBE depender de resolver esa pregunta.
Los campos ausentes o de tipo incorrecto DEBEN conservar el saneamiento de BR-SAV-006.

## Criterios de aceptación

### AC-SAV-001 — El cierre guarda una vez *(verifica BR-SAV-001)*

DADO una partida en curso CUANDO cierra la jornada 3 ENTONCES se guarda **exactamente una vez**,
con la partida sin terminar. Lo guardado devuelve la jornada que sigue, la que la partida
tiene por abrir, y esos apercibimientos.

### AC-SAV-002 — El último cierre borra *(verifica BR-SAV-002)*

DADO la última jornada CUANDO cierra ENTONCES hay **una** llamada y no dos, con la partida
terminada, y el archivo queda borrado.

### AC-SAV-003 — El despido también resetea *(verifica BR-SAV-002)*

DADO dos noches graves seguidas CUANDO cierra la segunda ENTONCES la partida está terminada y el
guardado se borra.

### AC-SAV-004 — Las dos acciones y ninguna más *(verifica BR-SAV-003)*

DADO la política de guardado ENTONCES sus acciones son exactamente escribir y borrar; con la
partida en curso decide escribir, y terminada, borrar.

### AC-SAV-005 — El disco que falla no frena *(verifica BR-SAV-004)*

DADO una escritura que falla CUANDO cierra la jornada ENTONCES la partida abre la siguiente y su
cierre vuelve a intentar.

### AC-SAV-006 — Ida y vuelta *(verifica BR-SAV-005)*

DADO una partida guardada CUANDO se la carga ENTONCES todos los campos vuelven con su valor y su
tipo.

### AC-SAV-007 — El campo que falta vuelve con su defecto *(verifica BR-SAV-006)*

DADO un guardado sin algunos campos CUANDO se lo sanea ENTONCES están **todos**, y el de la
jornada es la primera jornada citada y no un número escrito.

### AC-SAV-008 — El tipo equivocado vuelve con su defecto *(verifica BR-SAV-006)*

DADO un campo con un valor de otro tipo CUANDO se lo sanea ENTONCES vuelve con su defecto, no con
el valor crudo ni con una excepción.

### AC-SAV-009 — Las cuatro versiones *(verifica BR-SAV-007)*

DADO la versión actual, una anterior y un guardado sin versión ENTONCES los tres son legibles;
una posterior no lo es, y no se borra.

### AC-SAV-010 — Sin archivo, vacío *(verifica BR-SAV-008)*

DADO que no hay guardado CUANDO se carga ENTONCES el resultado es vacío.

### AC-SAV-011 — El corrupto se borra *(verifica BR-SAV-009)*

DADO un archivo corrupto CUANDO se carga ENTONCES el resultado es vacío y el archivo ya no está.

### AC-SAV-012 — El juego abre en el menú *(verifica BR-SAV-010)*

DADO el proyecto ENTONCES su escena principal es la del menú, y esa escena instancia en headless.

### AC-SAV-013 — Los tres candados de continuar *(verifica BR-SAV-011)*

DADO que no hay guardado ENTONCES continuar no está disponible, elegirlo no produce ningún pedido
de entrar al juego, y el botón está deshabilitado. Los tres juntos: arreglar uno solo no alcanza
para creer que está cerrado.

### AC-SAV-014 — Nuevo juego es directo con o sin guardado *(verifica BR-SAV-012)*

DADO un guardado CUANDO se elige nuevo juego ENTONCES se borra y se pide una partida nueva
directamente, sin confirmación. DADO ningún guardado ENTONCES el mismo gesto inicia una partida
nueva. CUANDO se repite el clic durante la entrada ENTONCES se emite un único pedido.

### AC-SAV-015 — Salir por un solo lugar *(verifica BR-SAV-013)*

DADO todo el código del juego ENTONCES el cierre del juego aparece **una sola vez**, y sólo la
opción de salir lo produce.

### AC-SAV-016 — La web no ofrece salir *(verifica BR-SAV-014)*

DADO el juego en la web ENTONCES el menú muestra cuatro opciones, sin salir, y en el mismo orden
que fuera de la web.

### AC-SAV-017 — Retomar arranca donde quedó *(verifica BR-SAV-015)*

DADO un guardado en la jornada 3 con apercibimientos CUANDO arranca la partida ENTONCES está en
esa jornada y con esos apercibimientos. Sin guardado, arranca en la primera jornada y sin
apercibimientos.

### AC-SAV-018 — Esc pausa y reanuda *(verifica BR-SAV-016)*

DADO la jornada en curso CUANDO llega Esc ENTONCES el juego queda en pausa; CUANDO llega otro Esc
ENTONCES se reanuda. DADO la devolución en pantalla, con la partida en curso o terminada,
CUANDO llega Esc ENTONCES el menú de pausa se abre por encima de la devolución; mientras tanto,
ni un clic ni Enter despachan la devolución. CUANDO llega otro Esc ENTONCES la pausa se cierra,
la misma devolución sigue en pantalla con los mismos mensajes y la misma opción, el reloj del
turno sigue detenido y la noche siguiente no se abre. DADO la devolución en pantalla CUANDO el cursor queda suelto ENTONCES no se
pausa. DADO el cursor tomado y la ventana activa CUANDO queda suelto sin que el juego lo suelte
ENTONCES el juego queda en pausa; CUANDO lo suelta el propio juego ENTONCES no. DADO una jornada
en curso CUANDO se cambia de pestaña o ventana y se vuelve ENTONCES sigue sin pausa; Esc sigue
abriendo y cerrando la pausa manual. DADO Configuraciones abierta desde la pausa CUANDO llega Esc
ENTONCES Configuraciones se cierra, el menú de pausa está en pantalla y el juego sigue en pausa;
CUANDO llega otro Esc ENTONCES se reanuda. DADO Configuraciones abierta desde el menú de inicio
CUANDO llega Esc ENTONCES Configuraciones se cierra y el menú de inicio está en pantalla.

### AC-SAV-019 — Los cuatro botones de la pausa *(verifica BR-SAV-017)*

DADO el menú de pausa ENTONCES muestra reanudar, configuraciones, logros y volver al menú, en ese
orden; reanudar, configuraciones y volver al menú están habilitados, y sólo logros está
deshabilitado.

### AC-SAV-020 — Volver al menú no guarda *(verifica BR-SAV-018)*

DADO el juego en pausa CUANDO se elige volver al menú ENTONCES el juego sale de la pausa, el
pedido de ir al menú se emite una sola vez y no se escribe ningún guardado. DADO la devolución de la
jornada 2 cerrada con la partida en curso y 7 medios de apercibimiento CUANDO se abre la pausa y
se elige volver al menú ENTONCES el guardado no se escribe ni se borra y sigue en la jornada 3 con
7 medios; CUANDO se elige continuar desde el menú ENTONCES se anuncia «NOCHE 3» con 7 medios.
DADO la devolución de una partida terminada CUANDO se sale al menú desde la pausa ENTONCES no hay
guardado y continuar sigue deshabilitado.

### AC-SAV-021 — Continuar evita las instrucciones *(verifica BR-SAV-015)*

DADO un guardado válido en la jornada 3 con 7 medios de apercibimiento CUANDO se elige continuar
ENTONCES se conservan jornada 3 y 7 medios, se anuncia «NOCHE 3» y las instrucciones no están
en pantalla. El turno permanece retenido hasta terminar la subida de la persiana.

### AC-SAV-022 — Nuevo juego funde directamente *(verifica BR-SAV-012)*

DADO un guardado CUANDO se elige nuevo juego ENTONCES se borra el guardado, el menú se funde
a negro en 0,3 segundos reales, se completa la carga y se muestran las instrucciones de Enrique.
DADO ningún guardado CUANDO
se elige nuevo juego ENTONCES se sigue esa misma secuencia sin confirmación. DADO una carga
fallida ENTONCES vuelve a verse el menú y no permanece una pantalla negra.

### AC-SAV-023 — Abandonar durante la preparación no guarda *(verifica BR-SAV-012, BR-SAV-018)*

DADO una partida nueva en las instrucciones, o una partida en la entrada de la noche, CUANDO
se abre la pausa y se elige volver al menú ENTONCES se sale de la pausa y no se escribe ningún
guardado. En la partida nueva, el guardado anterior ya borrado no reaparece y continuar queda
deshabilitado; al continuar una partida existente, su checkpoint previo se conserva.

### AC-SAV-024 — La noche 2 cerrada vuelve igual *(verifica BR-SAV-005, BR-SAV-019)*

DADO una partida con la noche 2 cerrada, reponer sin cumplir en las dos noches, un llamado por
papel en la noche 1 y R = 0 CUANDO se guarda, se lee el archivo y se retoma ENTONCES reponer
tiene 2 fallas, papel 1 llamado, hubo llamados en la partida, R = 0, y las dos devoluciones están en orden y
letra por letra en el chat de Enrique, intercalando foto y texto de apertura 2 entre las
dos devoluciones y conservando las 19 entradas de instrucciones al principio. CUANDO
la noche 3 cierra con reponer sin cumplir ENTONCES su devolución trae la fila n = 3 de Tarea 3,
«De nuevo quedaron algunas góndolas incompletas…».

DADO la noche 1 con reponer pendiente y un llamado por papel, y la 2 impecable sin llamados
CUANDO se guarda y retoma ENTONCES reponer conserva 1 falla, papel 1 llamado y R = 1.

### AC-SAV-025 — Un guardado sin las cuentas *(verifica BR-SAV-006, BR-SAV-019)*

DADO un guardado de la jornada 3 sin fallas, llamados, R ni devoluciones CUANDO se retoma
ENTONCES sigue en la jornada 3 con su legajo, cero fallas, cero llamados, R = 0, sin llamados en
la partida, y el chat de Enrique tiene las 19 entradas de instrucciones y los mensajes
de apertura 2 reconstruidos, sin devoluciones inventadas. DADO las
fallas con un valor que no es un diccionario, o las devoluciones con un número ENTONCES vuelven
con su defecto. DADO las fallas con una obligatoria desconocida y reponer en 1 ENTONCES reponer
conserva 1 y la desconocida se ignora.

### AC-SAV-026 — La mopa recuerda que se secó *(verifica BR-SAV-005, BR-SAV-019)*

DADO una partida marcada con la mopa ya secada CUANDO se guarda y se retoma ENTONCES sigue
marcada, como booleano. DADO un guardado sin el campo, o con un número en él, ENTONCES se retoma
sin la marca.

### AC-SAV-027 — El checkpoint de jornada 2 conserva el historial fechado *(verifica BR-SAV-020, BR-SAV-019, BR-SAV-005, BR-SAV-015)*

DADO cierre 1 con devolución fechada CUANDO se guarda, lee y retoma ENTONCES abre jornada 2,
conserva identidad, texto, jornada 1 y orden de cada mensaje de esa devolución, y el chat
ordena instrucciones, devolución 1, foto y texto de apertura 2. El guion de Yasmín vuelve con
sus quince mensajes sin leer. No se repiten las instrucciones en modo introductorio.
CUANDO cierra la 2 y se repite guardar y retomar ENTONCES la devolución 2 vuelve detrás de
la apertura 2, sin duplicar ni serializar de nuevo los mensajes del guion.

### AC-SAV-028 — El legado conserva textos iguales sin fechas inventadas *(verifica BR-SAV-020, BR-SAV-006)*

DADO un guardado legado de jornada 2 con la lista de devoluciones «Buen día!», «Buen día!»
y «Seguí así» CUANDO se retoma y vuelve a guardar ENTONCES conserva los tres textos en ese
orden, sin fusionar los dos iguales ni asignarles jornada u hora. El resto del progreso
válido se conserva. DADO lista ausente o campo de devoluciones numérico ENTONCES se sanea a
cero devoluciones, sin perder la jornada ni inventar mensajes de cierre.

## No objetivos

- Esta capacidad NO decide **qué** guarda cada sistema: define el sobre. El inventario entra
  como campo cuando su dueño lo declare.
- Esta capacidad NO reconstruye fechas ausentes del legado ni guarda los guiones o sus
  marcas de lectura; acepta las listas antiguas según BR-SAV-020.
- Esta capacidad NO ofrece ranuras, autoguardado ni nube.
- Esta capacidad NO avisa en pantalla que la escritura falló.
- Esta capacidad NO guarda las preferencias del jugador: viven aparte, en
  [`settings`](../settings/settings.md), y borrar el guardado no las toca.

## Contratos

- **Entrada:** el estado de la partida al cerrar, y si hay guardado, al arrancar.
- **Salida:** la acción a ejecutar, el diccionario saneado, si hay guardado, y qué pedido produce
  cada opción del menú.
- **Falla:** sin archivo y con archivo corrupto contestan vacío; una versión futura no se carga;
  una escritura fallida no interrumpe.

## Señales

- Nuevo juego, continuar y salir. Cada una se emite **exactamente una vez** por la opción que la
  produce.
- Pausado, reanudado y volver al menú pedido. Cada una se emite una sola vez por acción.

## Dependencias

- [`employment-record`](../employment-record/employment-record.md) (consume): la jornada, el
  legajo y el final; las cuentas de la devolución y las devoluciones recibidas con identidad, jornada y orden; las
  instrucciones previas a una partida nueva.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (alimenta): la jornada que anuncia la entrada
  al empezar o continuar, sin repetir las instrucciones al retomar.
- [`investigation`](../investigation/investigation.md) (alimenta): devoluciones restauradas
  con identidad, jornada y orden cuando existen, sin inventar metadatos del legado.
- [`settings`](../settings/settings.md) (alimenta): los dos menús abren Configuraciones, y Esc
  la cierra.

## Preguntas abiertas

- **OQ-SAV-001 — ¿Qué más cruza la jornada además del legajo?**
  - Por qué sigue abierta: el inventario y los objetos movidos no declararon si su estado cruza.
  - Decide: el dueño del repo.
  - Bloquea: nada. Agrega campos a `BR-SAV-005`.
