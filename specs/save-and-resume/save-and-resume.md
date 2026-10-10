---
schema_version: 1
capability_id: CAP-SAV
status: draft
owner: por definir
provenance: GDD «checkpoint al final de cada noche»; ficha «Pantalla entre jornadas» y decisiones de #374; migración de los specs 019, 020, 036
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
| **Pausa** | la jornada detenida, con su menú en pantalla | freeze, stop |

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

### BR-SAV-012 — Empezar de nuevo sobre una partida pide confirmación

SI hay un guardado, ENTONCES «nuevo juego» DEBE pedir confirmación antes de borrarlo. Es la pérdida
que no se puede deshacer.

CUANDO se acepta empezar una partida nueva, el sistema DEBE borrar el guardado anterior,
fundir el menú a negro, cargar el juego y presentar las instrucciones de Enrique antes de la
entrada a la primera noche. Cancelar la confirmación NO DEBE iniciar ese fundido ni borrar el
guardado. SI falla la carga, ENTONCES DEBE volver al menú sin quedar en negro.

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

CUANDO el jugador aprieta Esc durante la jornada, el sistema DEBE pausarla y mostrar el menú de
pausa. Un segundo Esc DEBE reanudarla, igual que «reanudar». SI la placa del cierre está en
pantalla, ENTONCES Esc NO DEBE hacer nada: la placa ya ofrece volver al menú. SI el cursor pasa
de tomado a suelto con la ventana activa y sin que el juego lo suelte, ENTONCES el sistema DEBE
pausar: en la web el navegador consume Esc para soltar el cursor. Soltarlo el propio juego NO
DEBE pausar. Cambiar de pestaña, minimizar o pasar a otra ventana NO DEBE pausar la jornada ni
mostrar el menú de pausa; volver tampoco DEBE abrirlo.

### BR-SAV-017 — El menú de pausa muestra cuatro opciones

El menú de pausa DEBE mostrar cuatro opciones, en este orden: **reanudar, configuraciones, logros
y volver al menú**. Configuraciones y logros DEBEN verse deshabilitadas. El menú de pausa no
ofrece salir: el juego se cierra sólo desde el menú de inicio.

### BR-SAV-018 — Volver al menú abandona la jornada

CUANDO el jugador elige «volver al menú» en la pausa, el sistema DEBE sacar el juego de la pausa,
llevarlo al menú de inicio y NO DEBE guardar nada.

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

### AC-SAV-014 — Empezar sobre una partida confirma *(verifica BR-SAV-012)*

DADO un guardado CUANDO se elige nuevo juego ENTONCES el pedido es el de confirmar y no el
de nuevo juego; recién al confirmar llega el de nuevo juego. Sin guardado, es directo.

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
ENTONCES se reanuda. DADO la placa del cierre en pantalla CUANDO llega Esc ENTONCES no pasa nada.
DADO el cursor tomado y la ventana activa CUANDO queda suelto sin que el juego lo suelte
ENTONCES el juego queda en pausa; CUANDO lo suelta el propio juego ENTONCES no. DADO una jornada
en curso CUANDO se cambia de pestaña o ventana y se vuelve ENTONCES sigue sin pausa; Esc sigue
abriendo y cerrando la pausa manual.

### AC-SAV-019 — Los cuatro botones de la pausa *(verifica BR-SAV-017)*

DADO el menú de pausa ENTONCES muestra reanudar, configuraciones, logros y volver al menú, en ese
orden, y sólo reanudar y volver al menú están habilitados.

### AC-SAV-020 — Volver al menú no guarda *(verifica BR-SAV-018)*

DADO el juego en pausa CUANDO se elige volver al menú ENTONCES el juego sale de la pausa, el
pedido de ir al menú se emite una sola vez y no se escribe ningún guardado.

### AC-SAV-021 — Continuar evita las instrucciones *(verifica BR-SAV-015)*

DADO un guardado válido en la jornada 3 con 7 medios de apercibimiento CUANDO se elige continuar
ENTONCES se conservan jornada 3 y 7 medios, se anuncia «NOCHE 3» y las instrucciones no están
en pantalla. El turno permanece retenido hasta terminar la subida de la persiana.

### AC-SAV-022 — Nuevo juego confirma antes del fundido *(verifica BR-SAV-012)*

DADO un guardado CUANDO se elige nuevo juego y se cancela ENTONCES el guardado se conserva y el
menú no se funde a negro. CUANDO se confirma ENTONCES se borra el guardado, el menú se funde,
se completa la carga y se muestran las instrucciones de Enrique. DADO ningún guardado CUANDO
se elige nuevo juego ENTONCES se sigue esa misma secuencia sin confirmación. DADO una carga
fallida ENTONCES vuelve a verse el menú y no permanece una pantalla negra.

### AC-SAV-023 — Abandonar durante la preparación no guarda *(verifica BR-SAV-012, BR-SAV-018)*

DADO una partida nueva en las instrucciones, o una partida en la entrada de la noche, CUANDO
se abre la pausa y se elige volver al menú ENTONCES se sale de la pausa y no se escribe ningún
guardado. En la partida nueva, el guardado anterior ya borrado no reaparece y continuar queda
deshabilitado; al continuar una partida existente, su checkpoint previo se conserva.

## No objetivos

- Esta capacidad NO decide **qué** guarda cada sistema: define el sobre. El inventario entra
  como campo cuando su dueño lo declare.
- Esta capacidad NO migra guardados entre versiones: eso es del día que exista una segunda.
- Esta capacidad NO ofrece ranuras, autoguardado ni nube.
- Esta capacidad NO avisa en pantalla que la escritura falló.

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
  legajo y el final; las instrucciones previas a una partida nueva.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (alimenta): la jornada que anuncia la entrada
  al empezar o continuar, sin repetir las instrucciones al retomar.

## Preguntas abiertas

- **OQ-SAV-001 — ¿Qué más cruza la jornada además del legajo?**
  - Por qué sigue abierta: el inventario y los objetos movidos no declararon si su estado cruza.
  - Decide: el dueño del repo.
  - Bloquea: nada. Agrega campos a `BR-SAV-005`.
- **OQ-SAV-002 — ¿Cuánto dura el fundido a negro del menú al empezar de nuevo?**
  - Por qué sigue abierta: la ficha decide el fundido, pero no fija su duración.
  - Decide: game design.
  - Bloquea: el tiempo definitivo de la transición de nuevo juego, no su confirmación ni carga.
