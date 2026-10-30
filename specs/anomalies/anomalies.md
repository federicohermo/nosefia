---
schema_version: 1
capability_id: CAP-ANO
status: ratified
owner: game design
provenance: ficha «11. Anomalías», «9. Tarea Limpieza», fichas Poético y bidón azul; decisiones de #432, 15 de octubre de 2026; ocho jornadas de #526; siete jornadas de #693; corte de luz de #454; decisiones de #455
---

# Capacidad: las anomalías de la jornada

## Propósito

Alterar las condiciones de una tarea rutinaria según la jornada. La cuarta noche exige buscar
un sustituto vendible del jabón que falta, conservando las reglas de preparación y limpieza. La
sexta noche corta la luz a las 20:58 y deja el reloj de mesa detenido hasta el cierre. La
última noche cambia qué trae cada caja del depósito, sin cambiar qué productos existen.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Anomalía** | condición excepcional de una jornada que cambia disponibilidad o permisos de una tarea | avería aleatoria |
| **Ausente** | objeto que no está disponible en ningún lugar del mundo ni participa de su cierre físico | escondido, tirado |
| **Sustituto** | producto que recibe un permiso excepcional de uso durante esa jornada | bidón nuevo |
| **Poético** | producto vendible de limpieza, distinto del bidón azul marca «2» | jabón azul |
| **Etiqueta** | el producto que anuncia una caja del depósito | nombre de la caja |
| **Contenido real** | el producto cuyas unidades entrega, recibe y cuenta esa caja | contenido declarado |
| **Permutación** | la correspondencia fija entre etiquetas y contenidos reales de la última noche | sorteo |
| **Corte** | estado de la sexta noche: sin corte, cortado o restaurado | apagón aleatorio |
| **Panel eléctrico** | el tablero de electricidad del depósito, que se acciona con un clic | fusible, llave |
| **Luz de emergencia** | la única luz que queda encendida sobre el panel durante el corte | linterna |

## Comportamiento normativo

### BR-ANO-001 — Falta el azul sólo durante la cuarta noche

CUANDO se abre jornada 4, el sistema DEBE dejar disponibles sólo los bidones rosa y amarillo.
El azul DEBE quedar oculto, sin colisión, foco, agarre ni examen y excluido de la evaluación
física del cierre. En las demás jornadas los tres bidones DEBEN estar disponibles normalmente.
La ausencia de la jornada 4 NO DEBE producir por sí misma desorden ni objeto afuera.

### BR-ANO-002 — La disponibilidad se aplica sobre cualquier apertura

CUANDO se abre jornada 4 directamente o tras jornada 3, el sistema DEBE terminar examen y vaciar
mano antes de aplicar la ausencia, cualquiera fuera el destino previo del azul. Repetir esa
apertura NO DEBE volver a habilitarlo. CUANDO abre jornada 5, el sistema DEBE restaurar el mismo
bidón a padre, pose, visibilidad y colisiones originales, incluso si había sido tirado.

### BR-ANO-003 — El permiso del sustituto pertenece a una sola jornada

MIENTRAS la jornada es 5, el sistema DEBE habilitar exclusivamente una unidad real de Poético
como sustituto del azul al preparar agua del balde. En las demás jornadas NO DEBE habilitarlo.
El permiso DEBE recibirse por jornada e identidad y NO DEBE convertir al producto en un bidón
permanente ni cambiar el inventario. La preparación, sus rechazos y sus efectos DEBEN seguir
BR-CLN-033 y BR-CLN-034 de [`store-cleanup`](../store-cleanup/store-cleanup.md).

### BR-ANO-004 — En la última noche ninguna caja trae lo que anuncia

MIENTRAS la jornada es la última de la partida, el sistema DEBE asignar a cada caja del depósito
un contenido real distinto de su etiqueta. Cada producto que tiene caja DEBE ser contenido real de
exactamente una caja: sigue habiendo una caja por producto, y el conjunto de productos no cambia.
La permutación DEBE ser un dato fijo del juego: NO DEBE sortearse ni guardarse, y DEBE ser la
misma en cada apertura de esa jornada, directa, tras la anterior o desde un guardado. En las
demás jornadas el contenido real de cada caja DEBE ser su etiqueta. Abrir la primera jornada de
una partida nueva NO DEBE heredar la permutación.

### BR-ANO-005 — Sacar y meter siguen el contenido real

MIENTRAS rige la permutación, CUANDO el jugador saca una unidad de una caja, el sistema DEBE darle
una unidad de su contenido real, nunca del producto de su etiqueta. CUANDO el jugador devuelve una
unidad a una caja, el sistema DEBE aceptar sólo una unidad de su contenido real. Una unidad del
producto de la etiqueta DEBE rechazarse sin cambiar la mano ni las cantidades. El gesto que
la referencia de controles ofrece sobre una caja DEBE seguir el mismo criterio. Las reglas de
BR-STK-016, BR-STK-017 y BR-STK-030 de [`store-stock`](../store-stock/store-stock.md) DEBEN
valer sobre ese contenido real.

### BR-ANO-006 — Examinar, vender y reponer cuentan el contenido real

MIENTRAS rige la permutación, el sistema DEBE contar de cada caja las unidades de su contenido
real, y el examen DEBE presentar ese producto y esa cantidad, con los lugares libres que
BR-STK-031 define sobre ellas. La reposición y la venta DEBEN operar sobre las identidades reales
de producto: la anomalía NO DEBE crear identidades nuevas ni cambiar el depósito, las unidades
de una caja ni la titularidad del inventario de cada producto. Los faltantes de reposición DEBEN
seguir limitados por el contenido real disponible de su producto.

### BR-ANO-011 — El corte llega una sola vez, a las 20:58 de la sexta noche

CUANDO la hora de ficción de la jornada 6 alcanza las 20:58, el sistema DEBE pasar el corte de
sin corte a cortado, una sola vez. La hora de ficción es la que define BR-SHF-014, medida desde
la apertura del turno, y no depende de lo que lea el reloj de mesa. Antes de las 20:58 la
jornada 6 DEBE comportarse como una noche con luz y reloj normales. Las demás jornadas NO DEBEN
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

CUANDO se abre la jornada 6, por cualquier camino, el sistema DEBE dejar el corte sin corte y el
reloj normal desde las 20:00. Pausar y reanudar DEBE conservar el estado y NO DEBE consumir turno.
El corte NO DEBE escribir ni cargar guardado alguno: abandonar la jornada 6 al menú y continuar
la abre desde su apertura, según BR-SAV-015 y BR-SAV-018 de
[`save-and-resume`](../save-and-resume/save-and-resume.md).

## Criterios de aceptación

### AC-ANO-001 — Matriz de disponibilidad *(verifica BR-ANO-001)*

DADO aperturas de jornadas 1 a 7 CUANDO se consultan los bidones presentes ENTONCES la 4 tiene
rosa/amarillo y cada una de las otras seis, azul/rosa/amarillo. En la 2 están los tres aunque
pida limpiar. En la 4 ningún recorrido de mira, agarre o examen alcanza el azul ni su cuerpo obstruye el paso.
Con los demás cuerpos ordenados, la ausencia no produce motivos de desorden ni afuera al cerrar.

### AC-ANO-002 — Apertura directa y transición equivalen *(verifica BR-ANO-002, BR-ANO-001)*

DADO el azul antes, por turno, en mano, examen, piso y contenedor CUANDO se abre jornada 4
ENTONCES mano y examen quedan vacíos, el azul queda ausente y no participa de la foto física
del cierre. Abrir directamente desde checkpoint en 4 produce la misma disponibilidad. Repetir
la apertura conserva la ausencia, sin emitir un descarte de objeto importante.

### AC-ANO-003 — El quinto día recupera el objeto original *(verifica BR-ANO-002)*

DADO el azul tirado en jornada 3 y ausente durante la 4 CUANDO se abre la 5 ENTONCES el mismo
bidón vuelve a su padre y pose originales, visible, físico, enfocable, levantable y examinable;
no queda una segunda copia ni una marca de tirado heredada.

### AC-ANO-004 — Matriz de sustitución *(verifica BR-ANO-003)*

DADO el producto Poético real CUANDO se consulta su permiso de teñir agua limpia del balde en
jornadas 1 a 7 ENTONCES contesta sí sólo en la 4 y no en las otras seis. Otro producto
renombrado Poético contesta no en las siete. Consultar no tiñe ni cambia mano o mercadería; ejecutar el permiso
válido usa el recorrido de limpieza sin consumo adicional.

### AC-ANO-005 — La permutación es completa, fija y propia de la última noche *(verifica BR-ANO-004)*

DADO los productos que tienen caja en la última jornada CUANDO se consulta el contenido real de la
caja de cada etiqueta ENTONCES ninguna contesta su propia etiqueta, cada producto aparece como
contenido de exactamente una caja y el conjunto de contenidos es el de etiquetas. Abrir esa
jornada directamente, tras la anterior y desde un guardado, o dos veces, contesta el mismo
contenido para cada etiqueta. En cada jornada anterior cada etiqueta contesta su propio producto.
DADO una partida que llegó a la última jornada CUANDO se abre la primera de una partida nueva
ENTONCES cada etiqueta contesta su propio producto.

### AC-ANO-006 — Sacar entrega el contenido real *(verifica BR-ANO-005)*

DADO la última jornada y una caja con etiqueta X, cuyo contenido real es P y que tiene unidades
CUANDO se saca con la mano vacía ENTONCES la mano lleva una unidad de P y no de X, y el contenido
de la caja baja en uno. El depósito de X y su caja no cambian. DADO esa caja con 0 unidades
CUANDO se saca ENTONCES no sale nada, aunque la caja de etiqueta P tenga unidades. En jornadas
anteriores, sacar de la caja de etiqueta X entrega X.

### AC-ANO-007 — Meter sólo acepta el contenido real *(verifica BR-ANO-005)*

DADO la última jornada, la caja con etiqueta X y contenido real P con lugar, y una unidad de X en
la mano CUANDO se intenta meter ENTONCES la caja y la mano no cambian y la referencia de controles
no ofrece meter. DADO una unidad de P en la mano CUANDO se intenta meter ENTONCES la caja suma una,
la mano queda vacía y la referencia de controles ofrece meter. DADO esa caja llena y una unidad de
P CUANDO se intenta meter ENTONCES la caja y la mano no cambian.

### AC-ANO-008 — Examinar dice el contenido real *(verifica BR-ANO-006)*

DADO la última jornada y la caja con etiqueta X y contenido real P CUANDO se la examina con 8,
con 5 y con 0 unidades de P ENTONCES presenta P, esa cantidad y 0, 3 y 8 lugares libres, y no
la cantidad ni el nombre de X. Examinar no cambia el contenido. En jornadas anteriores presenta
el producto de la etiqueta.

### AC-ANO-009 — Venta y reposición usan las identidades reales *(verifica BR-ANO-006, BR-ANO-004)*

DADO la última jornada CUANDO se vende o se repone un producto P ENTONCES la venta resta de la caja
cuyo contenido real es P, no de la caja con etiqueta P, y la unidad sacada de esa caja sólo se
coloca en la góndola de P. El conjunto de identidades de producto es el del catálogo, y las
unidades de cada caja al abrir son las de una caja (BR-STK-004). Un faltante de reposición
sorteado de P no pasa del contenido real de la caja que lo tiene.

### AC-ANO-015 — Matriz del corte *(verifica BR-ANO-011)*

DADO la jornada 6 CUANDO han transcurrido 58 minutos de ficción menos un segundo ENTONCES el
corte es sin corte; con 58 minutos exactos (las 20:58), cortado; con 2 horas y con la noche
entera, también cortado. En cada jornada de 1 a 5 y en la 7, con 58 minutos, con 2 horas y con
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

DADO la jornada 6 CUANDO transcurren los segundos reales con el corte sin corte, cortado y
restaurado ENTONCES cada segundo descuenta lo mismo y el turno cierra al agotarse su presupuesto.
Cortar, restablecer y hacer clic de más sobre el panel no suman ni restan turno.

### AC-ANO-020 — Los estados no se guardan *(verifica BR-ANO-014)*

DADO el corte cortado o restaurado CUANDO se pausa y se reanuda ENTONCES conserva el estado y el
turno no descuenta durante la pausa. CUANDO se abandona al menú y se continúa ENTONCES la jornada
7 abre desde las 20:00 con el corte sin corte, y no se escribió ni se cargó un guardado
intermedio. Abrir la jornada 6 desde el guardado del cierre de la jornada 5 deja el corte sin
corte.

## No objetivos

- Esta capacidad NO decide mezclas, carga de la mopa, manchas, ventas ni consecuencias laborales.
- Esta capacidad NO define las anomalías de la jornada 5. Sus contenidos pertenecen a sus
  contratos respectivos; aquí sólo se fijan la vigencia de la excepción del jabón azul, el corte
  de luz de la sexta noche y la permutación de cajas de la última noche.
- Esta capacidad NO decide qué lee el reloj de mesa: eso es de
  [`shift-cycle`](../shift-cycle/shift-cycle.md). Tampoco decide cómo se ve la luz de
  emergencia: eso es de [`ambience`](../ambience/ambience.md).
- Esta capacidad NO decide el aspecto de las etiquetas ni de las cajas, ni qué dice una pista
  sobre ellas.

## Contratos

- **Entrada:** jornada que abre, identidad del útil o producto y estado físico previo; para las
  cajas, la etiqueta de la caja; para el corte, además, la hora de ficción y el estado vigente.
- **Salida:** útiles disponibles y permiso de sustituir azul con Poético durante esa jornada; el
  contenido real de la caja de cada etiqueta; y, para el corte, su estado —sin corte, cortado o
  restaurado— y si las interfaces están accesibles.
- **Falla:** una identidad distinta de Poético no recibe permiso; una apertura repetida
  conserva la disponibilidad y no duplica cuerpos ni descartes; una unidad que no es el
  contenido real de una caja no entra en ella. Un corte repetido o un clic de más sobre el panel
  conservan el estado.

## Señales

- La disponibilidad preparada al abrir la jornada. Consultar permisos o contenidos no publica uso
  ni hallazgo.
- El estado del corte de la sexta noche, que el local aplica a su luz y a sus interfaces.

## Dependencias

- [`shift-cycle`](../shift-cycle/shift-cycle.md) (consume): jornada que abre y hora de ficción.
  Su reloj de mesa consume la sexta noche detenida desde las 20:58.
- [`ambience`](../ambience/ambience.md) (alimenta): el estado del corte, que decide qué luces
  quedan encendidas.
- [`save-and-resume`](../save-and-resume/save-and-resume.md) (consume): la apertura de la jornada
  7 siempre parte de las 20:00; el corte no se guarda.
- [`store-cleanup`](../store-cleanup/store-cleanup.md) (alimenta): útiles disponibles y permiso
  de sustitución; limpieza resuelve y publica el teñido aceptado con identidad.
- [`store-stock`](../store-stock/store-stock.md) (consume): identidad de la unidad vendible,
  que conserva su propiedad y sus recorridos normales. (alimenta): qué producto trae cada caja
  en la última noche.

## Preguntas abiertas

Ninguna para las anomalías de las jornadas 4, 6 y 7.
