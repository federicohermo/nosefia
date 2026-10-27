---
schema_version: 1
capability_id: CAP-ANO
status: ratified
owner: game design
provenance: ficha «11. Anomalías», «9. Tarea Limpieza», fichas Poético y bidón azul; decisiones de #432, 15 de octubre de 2026; ocho jornadas de #526; corte de luz de #454
---

# Capacidad: las anomalías de la jornada

## Propósito

Alterar las condiciones de una tarea rutinaria según la jornada. La quinta noche exige buscar
un sustituto vendible del jabón que falta, conservando las reglas de preparación y limpieza. La
séptima noche corta la luz a las 20:58 y deja el reloj de mesa detenido hasta el cierre.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Anomalía** | condición excepcional de una jornada que cambia disponibilidad o permisos de una tarea | avería aleatoria |
| **Ausente** | objeto que no está disponible en ningún lugar del mundo ni participa de su cierre físico | escondido, tirado |
| **Sustituto** | producto que recibe un permiso excepcional de uso durante esa jornada | bidón nuevo |
| **Poético** | producto vendible de limpieza, distinto del bidón azul marca «2» | jabón azul |
| **Corte** | estado de la séptima noche: sin corte, cortado o restaurado | apagón aleatorio |
| **Panel eléctrico** | el tablero de electricidad del depósito, que se acciona con un clic | fusible, llave |
| **Luz de emergencia** | la única luz que queda encendida sobre el panel durante el corte | linterna |

## Comportamiento normativo

### BR-ANO-001 — Falta el azul sólo durante la quinta noche

CUANDO se abre jornada 5, el sistema DEBE dejar disponibles sólo los bidones rosa y amarillo.
El azul DEBE quedar oculto, sin colisión, foco, agarre ni examen y excluido de la evaluación
física del cierre. En las demás jornadas los tres bidones DEBEN estar disponibles normalmente.
La ausencia de la jornada 5 NO DEBE producir por sí misma desorden ni objeto afuera.

### BR-ANO-002 — La disponibilidad se aplica sobre cualquier apertura

CUANDO se abre jornada 5 directamente o tras jornada 4, el sistema DEBE terminar examen y vaciar
mano antes de aplicar la ausencia, cualquiera fuera el destino previo del azul. Repetir esa
apertura NO DEBE volver a habilitarlo. CUANDO abre jornada 6, el sistema DEBE restaurar el mismo
bidón a padre, pose, visibilidad y colisiones originales, incluso si había sido tirado.

### BR-ANO-003 — El permiso del sustituto pertenece a una sola jornada

MIENTRAS la jornada es 5, el sistema DEBE habilitar exclusivamente una unidad real de Poético
como sustituto del azul al preparar agua del balde. En las demás jornadas NO DEBE habilitarlo.
El permiso DEBE recibirse por jornada e identidad y NO DEBE convertir al producto en un bidón
permanente ni cambiar el inventario. La preparación, sus rechazos y sus efectos DEBEN seguir
BR-CLN-033 y BR-CLN-034 de [`store-cleanup`](../store-cleanup/store-cleanup.md).

### BR-ANO-011 — El corte llega una sola vez, a las 20:58 de la séptima noche

CUANDO la hora de ficción de la jornada 7 alcanza las 20:58, el sistema DEBE pasar el corte de
sin corte a cortado, una sola vez. La hora de ficción es la que define BR-SHF-014, medida desde
la apertura del turno, y no depende de lo que lea el reloj de mesa. Antes de las 20:58 la
jornada 7 DEBE comportarse como una noche con luz y reloj normales. Las demás jornadas NO DEBEN
cortar la luz.

### BR-ANO-012 — Cortado: oscuridad e interfaces inaccesibles

MIENTRAS el corte está cortado, el sistema DEBE dejar el depósito a oscuras salvo la luz de
emergencia sobre el panel eléctrico, y el local sólo con la luz exterior tenue. La computadora y
la caja registradora DEBEN rechazar que se las abra. CUANDO se corta con una abierta, el sistema
DEBE cerrarla. El turno NO DEBE detenerse: sigue descontando con su presupuesto y su ritmo
normales (BR-SHF-001, BR-SHF-002 y BR-SHF-003).

### BR-ANO-013 — Un clic sobre el panel restablece la luz

CUANDO el jugador hace clic sobre el panel eléctrico con el corte cortado, el sistema DEBE
pasarlo a restaurado: la iluminación y las interfaces vuelven a la normalidad. Hacer clic sobre el
panel sin corte o ya restaurado NO DEBE cambiar el estado, cortar de nuevo ni alterar la lectura
del reloj de mesa. Un corte restaurado
NO DEBE volver a cortar en esa noche.

### BR-ANO-014 — Los estados del corte viven sólo en la jornada en memoria

CUANDO se abre la jornada 7, por cualquier camino, el sistema DEBE dejar el corte sin corte y el
reloj normal desde las 20:00. Pausar y reanudar DEBE conservar el estado y NO DEBE consumir turno.
El corte NO DEBE escribir ni cargar guardado alguno: abandonar la jornada 7 al menú y continuar
la abre desde su apertura, según BR-SAV-015 y BR-SAV-018 de
[`save-and-resume`](../save-and-resume/save-and-resume.md).

## Criterios de aceptación

### AC-ANO-001 — Matriz de disponibilidad *(verifica BR-ANO-001)*

DADO aperturas de jornadas 1 a 8 CUANDO se consultan los bidones presentes ENTONCES la 5 tiene
rosa/amarillo y cada una de las otras siete, azul/rosa/amarillo. En la 3 están los tres aunque
pida limpiar. En la 5 ningún recorrido de mira, agarre o examen alcanza el azul ni su cuerpo obstruye el paso.
Con los demás cuerpos ordenados, la ausencia no produce motivos de desorden ni afuera al cerrar.

### AC-ANO-002 — Apertura directa y transición equivalen *(verifica BR-ANO-002, BR-ANO-001)*

DADO el azul antes, por turno, en mano, examen, piso y contenedor CUANDO se abre jornada 5
ENTONCES mano y examen quedan vacíos, el azul queda ausente y no participa de la foto física
del cierre. Abrir directamente desde checkpoint en 5 produce la misma disponibilidad. Repetir
la apertura conserva la ausencia, sin emitir un descarte de objeto importante.

### AC-ANO-003 — El sexto día recupera el objeto original *(verifica BR-ANO-002)*

DADO el azul tirado en jornada 4 y ausente durante la 5 CUANDO se abre la 6 ENTONCES el mismo
bidón vuelve a su padre y pose originales, visible, físico, enfocable, levantable y examinable;
no queda una segunda copia ni una marca de tirado heredada.

### AC-ANO-004 — Matriz de sustitución *(verifica BR-ANO-003)*

DADO el producto Poético real CUANDO se consulta su permiso de teñir agua limpia del balde en
jornadas 1 a 8 ENTONCES contesta sí sólo en la 5 y no en las otras siete. Otro producto
renombrado Poético contesta no en las ocho. Consultar no tiñe ni cambia mano o mercadería; ejecutar el permiso
válido usa el recorrido de limpieza sin consumo adicional.

### AC-ANO-015 — Matriz del corte *(verifica BR-ANO-011)*

DADO la jornada 7 CUANDO han transcurrido 58 minutos de ficción menos un segundo ENTONCES el
corte es sin corte; con 58 minutos exactos (las 20:58), cortado; con 2 horas y con la noche
entera, también cortado. En cada jornada de 1 a 6 y en la 8, con 58 minutos, con 2 horas y con
la noche entera, el corte es sin corte.

### AC-ANO-016 — Se corta una sola vez *(verifica BR-ANO-011, BR-ANO-013)*

DADO el corte cortado CUANDO se vuelve a evaluar la hora, a las 20:58, a las 22:00 y a las 04:00,
ENTONCES sigue cortado y no emite otro corte. DADO el corte restaurado CUANDO se evalúa con la
hora pasada de las 20:58 ENTONCES sigue restaurado.

### AC-ANO-017 — Cortado rechaza las interfaces *(verifica BR-ANO-012)*

DADO el corte cortado CUANDO se intenta abrir la computadora o la caja registradora ENTONCES
ninguna abre. DADO una abierta al cortar ENTONCES queda cerrada. Con el corte sin corte o
restaurado, las dos abren normalmente.

### AC-ANO-018 — Un clic sobre el panel restablece *(verifica BR-ANO-013)*

DADO el corte cortado CUANDO se hace clic sobre el panel ENTONCES queda restaurado y las
interfaces abren. Hacer clic otra vez, o hacerlo con el corte sin corte, no cambia el estado.

### AC-ANO-019 — El turno no se entera del corte *(verifica BR-ANO-012, BR-ANO-013)*

DADO la jornada 7 CUANDO transcurren los segundos reales con el corte sin corte, cortado y
restaurado ENTONCES cada segundo descuenta lo mismo y el turno cierra al agotarse su presupuesto.
Cortar, restablecer y hacer clic de más sobre el panel no suman ni restan turno.

### AC-ANO-020 — Los estados no se guardan *(verifica BR-ANO-014)*

DADO el corte cortado o restaurado CUANDO se pausa y se reanuda ENTONCES conserva el estado y el
turno no descuenta durante la pausa. CUANDO se abandona al menú y se continúa ENTONCES la jornada
7 abre desde las 20:00 con el corte sin corte, y no se escribió ni se cargó un guardado
intermedio. Abrir la jornada 7 desde el guardado del cierre de la jornada 6 deja el corte sin
corte.

## No objetivos

- Esta capacidad NO decide mezclas, carga de la mopa, manchas, ventas ni consecuencias laborales.
- Esta capacidad NO define las anomalías de las jornadas 6 y 8. Sus contenidos pertenecen a
  sus contratos respectivos; aquí sólo se fijan la vigencia de la excepción del jabón azul y el
  corte de luz de la séptima noche.
- Esta capacidad NO decide qué lee el reloj de mesa: eso es de
  [`shift-cycle`](../shift-cycle/shift-cycle.md). Tampoco decide cómo se ve la luz de
  emergencia: eso es de [`ambience`](../ambience/ambience.md).

## Contratos

- **Entrada:** jornada que abre, identidad del útil o producto y estado físico previo; para el
  corte, además, la hora de ficción y el estado vigente.
- **Salida:** útiles disponibles y permiso de sustituir azul con Poético durante esa jornada; y,
  para el corte, su estado —sin corte, cortado o restaurado— y si las interfaces están
  accesibles.
- **Falla:** una identidad distinta de Poético no recibe permiso; una apertura repetida
  conserva la disponibilidad y no duplica cuerpos ni descartes. Un corte repetido o un clic
  de más sobre el panel conservan el estado.

## Señales

- La disponibilidad preparada al abrir la jornada. Consultar permisos no publica uso ni hallazgo.
- El estado del corte de la séptima noche, que el local aplica a su luz y a sus interfaces.

## Dependencias

- [`shift-cycle`](../shift-cycle/shift-cycle.md) (consume): jornada que abre y hora de ficción.
  Su reloj de mesa consume la séptima noche detenida desde las 20:58.
- [`ambience`](../ambience/ambience.md) (alimenta): el estado del corte, que decide qué luces
  quedan encendidas.
- [`save-and-resume`](../save-and-resume/save-and-resume.md) (consume): la apertura de la jornada
  7 siempre parte de las 20:00; el corte no se guarda.
- [`store-cleanup`](../store-cleanup/store-cleanup.md) (alimenta): útiles disponibles y permiso
  de sustitución; limpieza resuelve y publica el teñido aceptado con identidad.
- [`store-stock`](../store-stock/store-stock.md) (consume): identidad de la unidad vendible,
  que conserva su propiedad y sus recorridos normales.

## Preguntas abiertas

Ninguna para las anomalías de las jornadas 5 y 7.
