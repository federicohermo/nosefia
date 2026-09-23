---
schema_version: 1
capability_id: CAP-STK
status: ratified
owner: por definir
provenance: GDD «Reponer» y «Registrar»; migración de los specs 005, 008, 033, 042, 047
---

# Capacidad: la mercadería del almacén

## Propósito

Saber cuántas unidades hay de cada producto y **dónde**, para que reponer sea una tarea con algo
que decidir. Lo único que tiene que hacer bien es no perder ni fabricar unidades: la góndola y el
depósito son dos lugares distintos, y mover mercadería del fondo al estante cuesta caminar.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Producto** | qué se vende: identidad, nombre, precio y umbral | ítem, SKU |
| **Unidad** | una pieza de un producto, la que se agarra con la mano | stock, cantidad |
| **Depósito** | el fondo, donde arrancan las cajas de la noche | almacén, bodega |
| **Caja del depósito** | la caja de un solo producto de la que se saca de a una unidad | cajón, contenedor |
| **Caja de traslado** | la caja mixta que se carga para llevar varias cosas a la vez | carrito |
| **Góndola** | el estante del local, y lo único desde donde se vende | vitrina, exhibidor |
| **Umbral** | cuántas unidades pide la góndola de ese producto. Es también su cupo | mínimo, tope |
| **Faltante** | un producto con la góndola por debajo de su umbral | agotado, sin stock |

## Comportamiento normativo

### BR-STK-001 — Un producto es su identidad, no su instancia

El sistema DEBE indexar las unidades por la identidad del producto y nunca por el objeto. Dos
consultas al catálogo dan objetos distintos del mismo producto.

### BR-STK-002 — Cada producto tiene su fila

El catálogo DEBE tener una fila por producto declarado, con nombre, precio entero y umbral. Un
producto sin fila DEBE contestar «no existe» en vez de romper la corrida.

### BR-STK-003 — Dos ubicaciones

El sistema DEBE llevar las unidades en **depósito** y **góndola** por separado. Sin esa
distinción, mover mercadería del fondo al estante no cambia ningún número y reponer deja de ser
una tarea.

### BR-STK-004 — La noche arranca con una caja llena por producto y la góndola vacía

CUANDO se abre una jornada, el sistema DEBE poner en el depósito **una caja llena de cada
producto** y **cero en la góndola**. Lo que el depósito tiene de un producto es lo que tiene su
caja: no hay unidades del depósito fuera de las cajas.

### BR-STK-005 — Ingresar no resta

SI la cantidad que se ingresa no es positiva, ENTONCES el sistema DEBE ignorarla. Sin ese corte,
un ingreso negativo deja la góndola por debajo de cero: un estado imposible que ningún número
delata.

### BR-STK-006 — Mover devuelve cuántas movió

CUANDO se piden más unidades de las que hay, el sistema DEBE mover las que hay y contestar
cuántas fueron. Quien repone unidad por unidad necesita saber si el gesto tuvo efecto.

### BR-STK-007 — Faltante es estar por debajo del umbral

El sistema DEBE listar como faltantes los productos cuya **góndola** está por debajo de su
umbral, en el orden en que entraron al inventario. El depósito lleno no cuenta: ésa es justamente
la razón para ir al estante.

### BR-STK-008 — El cupo del estante es el umbral

El sistema DEBE llenar la góndola hasta el umbral del producto y rechazar la unidad que sobra. El
cupo no se escribe aparte: sería el mismo valor en dos lugares.

### BR-STK-009 — Los tres rechazos de colocar, en orden

CUANDO se coloca una unidad, el sistema DEBE rechazar por **producto no aceptado** primero, por
**estante lleno** después, y por **sin unidades en depósito** al final. El primero es una
propiedad del producto y vale siempre; el segundo se resuelve vendiendo; el tercero depende de
cuánta mercadería trajo la noche.

### BR-STK-010 — La caja de traslado lleva ocho

La caja DEBE aceptar **8 productos** y rechazar el noveno. Es lo que convierte reponer en una
decisión: sin caja, reponer es un viaje por unidad.

### BR-STK-011 — La caja se descarga por arriba

CUANDO se saca algo de la caja, el sistema DEBE devolver **lo último que entró**. Vacía devuelve
«no hay nada» en vez de romperse.

### BR-STK-012 — La caja rechaza lo que no es un producto

SI lo que se ofrece a la caja no es un producto, ENTONCES el sistema DEBE rechazarlo y decir ese
motivo, **incluso si la caja está llena**: el problema más cerca de quien lo ofrece es el que se
nombra.

### BR-STK-013 — Reponer está cumplido cuando no falta nada

CUANDO ningún producto aceptado por el estante está por debajo de su umbral, el sistema DEBE dar
la obligatoria de reponer por cumplida. La pregunta se la hace al inventario y no la recalcula.

### BR-STK-014 — Registrar son tres, no el catálogo

El sistema DEBE pedir que se pasen por la caja **3 productos del día** y no los del catálogo
entero. Con todos, registrar sería recorrer la lista y no habría nada que elegir.

### BR-STK-015 — Sólo se registra lo del día

SI el producto no está entre los del día, o SI ya se registró, ENTONCES el sistema DEBE
rechazarlo. Registrar cualquier cosa dejaría la tarea cumplible con tres latas del estante.

### BR-STK-016 — Una caja del depósito trae ocho de un solo producto

Cada caja del depósito DEBE guardar **un solo producto** y arrancar la noche con **8
unidades**. SI la caja ya entregó sus 8, ENTONCES el sistema DEBE negar la unidad siguiente,
aunque la góndola tenga lugar. Es otra caja que la de traslado: ésta no se carga, se vacía.

### BR-STK-017 — A la caja apoyada se le saca una unidad

CUANDO el jugador le pide una unidad a una caja del depósito que **no lleva en la mano**, el
sistema DEBE darle una unidad del producto de la caja, sin importar dónde esté apoyada: el piso,
un estante, un mostrador u otra caja. SI el jugador lleva esa caja, ENTONCES el sistema NO DEBE
darle nada. Lo que cobra el traslado es que la caja llevada no entrega, no la altura.

### BR-STK-018 — La caja no entrega lo que la góndola no puede recibir

SI la góndola de ese producto ya no tiene lugar, contando las unidades que ya salieron de la caja
y todavía no se colocaron, ENTONCES el sistema DEBE negar la unidad aunque la caja tenga. Hoy
una unidad que sale de la caja no vuelve a ella, y sin este corte quedaría en la mano sin un
lugar donde ir.

## Criterios de aceptación

### AC-STK-001 — La identidad manda *(verifica BR-STK-001)*

DADO dos objetos distintos del mismo producto CUANDO se ingresa con uno y se consulta con el otro
ENTONCES contesta las mismas unidades.

### AC-STK-002 — El catálogo está completo *(verifica BR-STK-002)*

DADO el catálogo ENTONCES tiene una fila por producto declarado, y pedir uno sin fila contesta
«no existe» sin romper la corrida.

### AC-STK-003 — Las dos ubicaciones no se mezclan *(verifica BR-STK-003)*

DADO 5 unidades en depósito CUANDO se consulta la góndola ENTONCES hay 0.

### AC-STK-004 — El arranque de la noche *(verifica BR-STK-004)*

DADO una jornada que se abre ENTONCES cada producto del catálogo tiene en el depósito lo que trae
una caja llena, y 0 en góndola.

### AC-STK-005 — Ingresar negativo no hace nada *(verifica BR-STK-005)*

DADO una góndola en 0 CUANDO se ingresan `-5` unidades ENTONCES sigue en 0.

### AC-STK-006 — Mover de más mueve lo que hay *(verifica BR-STK-006)*

DADO 2 unidades en depósito CUANDO se piden 5 al mover ENTONCES mueve 2, contesta 2, y el
depósito queda en 0.

### AC-STK-007 — El borde del umbral *(verifica BR-STK-007)*

DADO un producto de umbral 3 CUANDO la góndola tiene 2 ENTONCES es faltante; con 3 no lo es.

### AC-STK-008 — El estante se llena hasta el umbral *(verifica BR-STK-008)*

DADO un producto de umbral 3 con góndola en 3 CUANDO se coloca otra unidad ENTONCES se rechaza
por estante lleno y el depósito no bajó.

### AC-STK-009 — El orden de los rechazos *(verifica BR-STK-009)*

DADO un estante que no acepta el producto, lleno y sin depósito a la vez CUANDO se coloca
ENTONCES el motivo es producto no aceptado; aceptado y lleno, estante lleno; aceptado, con lugar
y sin depósito, sin unidades en depósito.

### AC-STK-010 — El noveno no entra *(verifica BR-STK-010)*

DADO una caja con 8 productos CUANDO se guarda el noveno ENTONCES se rechaza por caja llena y la
caja sigue con 8.

### AC-STK-011 — Lo último que entró es lo primero que sale *(verifica BR-STK-011)*

DADO una caja con A y después B CUANDO se saca ENTONCES sale B; una caja vacía contesta «no hay
nada».

### AC-STK-012 — La caja llena igual nombra lo que no es un producto *(verifica BR-STK-012)*

DADO una caja llena CUANDO se le ofrece algo que no es un producto ENTONCES el motivo es «no es
un producto» y no «caja llena».

### AC-STK-013 — Reponer cumplido *(verifica BR-STK-013)*

DADO un estante con todos sus productos en su umbral ENTONCES la obligatoria está cumplida; con
uno solo por debajo, no.

### AC-STK-014 — Registrar son tres *(verifica BR-STK-014)*

DADO los productos del día ENTONCES son 3, sin repetidos, y pasarlos a los tres cumple la
obligatoria.

### AC-STK-015 — Lo ajeno y lo repetido se rechazan *(verifica BR-STK-015)*

DADO los tres del día CUANDO se registra un cuarto producto ENTONCES se rechaza; y registrar dos
veces el mismo suma una sola vez.

### AC-STK-016 — La caja entrega ocho y la novena no *(verifica BR-STK-016, BR-STK-004)*

DADO una jornada recién abierta CUANDO se sacan 8 unidades de la caja de un producto, se colocan
en la góndola y se venden las 8 ENTONCES la góndola tiene lugar para 8 y la caja no entrega la
novena.

### AC-STK-017 — Se saca de la caja apoyada, nunca de la llevada *(verifica BR-STK-017)*

DADO una caja del depósito apoyada, en cualquier lado, CUANDO se le pide una unidad ENTONCES se
puede sacar; DADO la misma caja en la mano del jugador, ENTONCES no.

### AC-STK-018 — Lo que ya salió cuenta contra el lugar de la góndola *(verifica BR-STK-018)*

DADO un producto de umbral 2, con la góndola vacía y más de 2 en su caja CUANDO se sacan 2
unidades sin colocarlas ENTONCES la tercera se niega; y colocar esas 2 no habilita una tercera.

## No objetivos

- Esta capacidad NO cobra ni atiende: eso es de
  [`counter-service`](../counter-service/counter-service.md), que le pide el descuento.
- Esta capacidad NO mueve la unidad con la mano ni dibuja el hueco que se llenó.
- Esta capacidad NO decide el precio final de nada: el catálogo es un primer valor de balance.

## Contratos

- **Entrada:** los productos que existen, y los pedidos de ingresar, mover, cobrar y registrar.
- **Salida:** cuántas unidades hay por ubicación, qué falta, si cada obligatoria está cumplida, y
  el motivo de cada rechazo.
- **Falla:** las cantidades no positivas se ignoran; el cobro sin stock no mueve nada; la caja
  vacía y el producto inexistente contestan «no hay» en vez de romper.

## Señales

- El producto colocado en la góndola, el producto guardado en la caja y la unidad retirada del
  depósito.

## Dependencias

- [`counter-service`](../counter-service/counter-service.md) (alimenta): el cobro descuenta de
  la góndola.
- [`player-actions`](../player-actions/player-actions.md) (consume): la unidad viaja en la mano.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (alimenta): avisa cuándo reponer y registrar
  quedaron cumplidas.

## Preguntas abiertas

- **OQ-STK-001 — ¿Cuáles son los tres productos del día, y quién los elige?**
  - Por qué sigue abierta: hoy son una lista fija. El GDD no dice si varían por noche.
  - Decide: el dueño del repo.
  - Bloquea: nada. Haría variable lo que `AC-STK-014` fija.
- **OQ-STK-002 — ¿De dónde sale el margen para reponer lo que se vende?**
  - Por qué sigue abierta: la caja trae lo mismo que pide la góndola. SI un comprador se lleva
    una unidad de un producto antes de que su góndola se llene, ENTONCES esa noche reponer ya no
    se puede cumplir. La ficha «Reposición» pone el margen en una góndola que arranca con algo,
    y hoy arranca vacía.
  - Decide: el dueño del repo.
  - Bloquea: nada. Cambiaría `BR-STK-004`.
- **OQ-STK-003 — ¿La caja de traslado sigue en el juego?**
  - Por qué sigue abierta: las fichas describen sólo las cajas de un producto. La de traslado es
    anterior y ninguna ficha la pide.
  - Decide: el dueño del repo.
  - Bloquea: nada. Retiraría `BR-STK-010` a `BR-STK-012`.
