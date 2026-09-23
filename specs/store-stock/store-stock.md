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
| **Depósito** | el fondo, donde arranca la mercadería de la noche | almacén, bodega |
| **Caja del depósito** | la caja de un solo producto de la que se saca de a una unidad | cajón, contenedor |
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

### BR-STK-004 — La noche arranca con el depósito lleno y la góndola vacía

CUANDO se abre una jornada, el sistema DEBE poner **10 unidades de cada producto en el depósito**
y **cero en la góndola**. Ese número tiene que ser estrictamente mayor que el umbral más alto del
catálogo: con el umbral exacto, una venta dejaría reponer imposible esa noche.

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

### BR-STK-010 — *Retirada*

La caja de traslado ya no existe. No hay una caja mixta de ocho.

### BR-STK-011 — *Retirada*

La caja de traslado ya no existe. Nada se descarga por arriba.

### BR-STK-012 — *Retirada*

La caja de traslado ya no existe. No hay una caja que rechace lo que no es un producto.

### BR-STK-013 — Reponer está cumplido cuando no falta nada

CUANDO ningún producto aceptado por el estante está por debajo de su umbral, el sistema DEBE dar
la obligatoria de reponer por cumplida. La pregunta se la hace al inventario y no la recalcula.

### BR-STK-014 — Registrar son tres, no el catálogo

El sistema DEBE pedir que se pasen por la caja **3 productos del día** y no los del catálogo
entero. Con todos, registrar sería recorrer la lista y no habría nada que elegir.

### BR-STK-015 — Sólo se registra lo del día

SI el producto no está entre los del día, o SI ya se registró, ENTONCES el sistema DEBE
rechazarlo. Registrar cualquier cosa dejaría la tarea cumplible con tres latas del estante.

### BR-STK-016 — A la caja apoyada se le saca una unidad

CUANDO el jugador le pide una unidad a una caja del depósito que **no lleva en la mano**, el
sistema DEBE darle una unidad del producto de la caja, sin importar dónde esté apoyada: el piso,
un estante, un mostrador u otra caja. SI el jugador lleva esa caja, ENTONCES el sistema NO DEBE
darle nada. Lo que cobra el traslado es que la caja llevada no entrega, no la altura.

### BR-STK-017 — La caja no entrega lo que la góndola no puede recibir

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

DADO una jornada que se abre ENTONCES cada producto del catálogo tiene 10 en depósito y 0 en
góndola, y 10 es mayor al umbral más alto del catálogo.

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

### AC-STK-010 — *Retirado* *(verifica BR-STK-010)*

La caja de traslado no existe más.

### AC-STK-011 — *Retirado* *(verifica BR-STK-011)*

La caja de traslado no existe más.

### AC-STK-012 — *Retirado* *(verifica BR-STK-012)*

La caja de traslado no existe más.

### AC-STK-013 — Reponer cumplido *(verifica BR-STK-013)*

DADO un estante con todos sus productos en su umbral ENTONCES la obligatoria está cumplida; con
uno solo por debajo, no.

### AC-STK-014 — Registrar son tres *(verifica BR-STK-014)*

DADO los productos del día ENTONCES son 3, sin repetidos, y pasarlos a los tres cumple la
obligatoria.

### AC-STK-015 — Lo ajeno y lo repetido se rechazan *(verifica BR-STK-015)*

DADO los tres del día CUANDO se registra un cuarto producto ENTONCES se rechaza; y registrar dos
veces el mismo suma una sola vez.

### AC-STK-016 — Se saca de la caja apoyada, nunca de la llevada *(verifica BR-STK-016)*

DADO una caja del depósito apoyada, en cualquier lado, CUANDO se le pide una unidad ENTONCES se
puede sacar; DADO la misma caja en la mano del jugador, ENTONCES no.

### AC-STK-017 — Lo que ya salió cuenta contra el lugar de la góndola *(verifica BR-STK-017)*

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
- **Falla:** las cantidades no positivas se ignoran; el cobro sin stock no mueve nada; el producto
  inexistente contesta «no existe» en vez de romper.

## Señales

- El producto colocado en la góndola y la unidad retirada del depósito.

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
- **OQ-STK-002 — *Cerrada*: la caja de traslado sale del juego.**
  - Decisión: el dueño del repo la retiró el 2026-09-23. Ninguna ficha la pide, y reponer se
    hace con las cajas de un producto.
  - Efecto: `BR-STK-010` a `BR-STK-012` quedan retiradas.
