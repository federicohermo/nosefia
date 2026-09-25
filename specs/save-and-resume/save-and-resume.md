---
schema_version: 1
capability_id: CAP-SAV
status: draft
owner: por definir
provenance: GDD «checkpoint al final de cada noche»; migración de los specs 019, 020, 036
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

El sistema DEBE abrir el juego en un menú con **empezar, continuar y salir**, y no en el almacén.

### BR-SAV-011 — Continuar está disponible sólo con guardado

SI no hay guardado, ENTONCES «continuar» NO DEBE estar disponible y NO DEBE llevar a ningún lado.

### BR-SAV-012 — Empezar de nuevo sobre una partida pide confirmación

SI hay un guardado, ENTONCES «empezar» DEBE pedir confirmación antes de borrarlo. Es la pérdida
que no se puede deshacer.

### BR-SAV-013 — Salir pasa por un solo lugar

El sistema DEBE tener un único camino para cerrar el juego, y sólo la opción de salir lo produce.

## Criterios de aceptación

### AC-SAV-001 — El cierre guarda una vez *(verifica BR-SAV-001)*

DADO una partida en curso CUANDO cierra la jornada 3 ENTONCES se guarda **exactamente una vez**,
con la partida sin terminar, y lo guardado devuelve esa jornada y esos apercibimientos.

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

DADO un guardado CUANDO se elige empezar ENTONCES el pedido es el de confirmar y no el de
empezar; recién al confirmar llega el de empezar. Sin guardado, empezar es directo.

### AC-SAV-015 — Salir por un solo lugar *(verifica BR-SAV-013)*

DADO todo el código del juego ENTONCES el cierre del juego aparece **una sola vez**, y sólo la
opción de salir lo produce.

## No objetivos

- Esta capacidad NO decide **qué** guarda cada sistema: define el sobre. El expediente de
  investigación y el inventario entran como campos cuando sus dueños los declaren.
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

- Empezar, continuar y salir. Cada una se emite **exactamente una vez** por la opción que la
  produce.

## Dependencias

- [`employment-record`](../employment-record/employment-record.md) (consume): la jornada, el
  legajo y el final.
- [`investigation`](../investigation/investigation.md) (consume): la lista de pistas
  descubiertas.

## Preguntas abiertas

- **OQ-SAV-001 — ¿Qué más cruza la jornada además del legajo y el expediente?**
  - Por qué sigue abierta: el inventario y los objetos movidos no declararon si su estado cruza.
  - Decide: el dueño del repo.
  - Bloquea: nada. Agrega campos a `BR-SAV-005`.
