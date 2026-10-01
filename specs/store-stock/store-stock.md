---
schema_version: 1
capability_id: CAP-STK
status: ratified
owner: por definir
provenance: GDD «Reponer» y «Registrar»; fichas «6) Tarea: Registro de productos vendidos» y «8. Tarea: Reposición»; base «Productos y cajas contenedoras»; migración de los specs 005, 008, 033, 042, 047
---

# Capacidad: la mercadería del almacén

## Propósito

Saber cuántas unidades hay de cada producto y **dónde**, para que reponer sea una tarea con algo
que decidir. Lo único que tiene que hacer bien es no perder ni fabricar unidades: la góndola y el
depósito son dos lugares distintos, y mover mercadería del fondo al estante cuesta caminar.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Producto** | qué se vende: identidad, nombre y precio | ítem, SKU |
| **Unidad** | una pieza de un producto, la que se agarra con la mano | stock, cantidad |
| **Depósito** | el fondo, con la caja de cada producto: de ahí sale lo que se repone y lo que se vende | almacén, bodega |
| **Caja del depósito** | la caja de un solo producto de la que se saca de a una unidad | cajón, contenedor |
| **Góndola** | el estante del local, el que el jugador repone | vitrina, exhibidor |
| **Tanda** | las unidades de un mismo producto puestas juntas sobre un estante del local, en dos filas | bloque, exhibición |
| **Fila de adelante** | la fila de una tanda del lado del pasillo: la única que el jugador repone | frente, cara |
| **Fila de atrás** | la fila de una tanda contra el fondo del estante: fija, entera toda la noche | guía, fondo |
| **Casillero** | cada lugar de la fila de adelante, que el jugador llena colocando una unidad | hueco, slot |
| **Cupo** | cuántos casilleros tiene la fila de adelante de un producto: cuántas unidades pide su góndola. Es distinto para cada producto | umbral, mínimo, tope |
| **Faltante** | un producto con algún casillero vacío en su fila de adelante | agotado, sin stock |
| **Faltantes de la jornada** | cuántas unidades de cada producto faltan en la góndola cuando abre una jornada | pedido, reposición |
| **Vendibles** | el depósito menos los casilleros vacíos de la fila de adelante del producto | stock, disponible |
| **Planilla** | la lista donde el jugador anota cuántas unidades se vendieron de cada producto | registro de caja, ticket |
| **Lo vendido** | las unidades de un producto que salieron en ventas cobradas esa noche | stock, ventas del día |

## Comportamiento normativo

### BR-STK-001 — Un producto es su identidad, no su instancia

El sistema DEBE indexar las unidades por la identidad del producto y nunca por el objeto. Dos
consultas al catálogo dan objetos distintos del mismo producto.

### BR-STK-002 — Cada producto tiene su fila

El catálogo DEBE tener una fila por producto declarado, con nombre y precio entero. Un producto
sin fila DEBE contestar «no existe» en vez de romper la corrida. Cuántas unidades pide su góndola
no es de la fila: es su cupo, y lo dice el local armado (BR-STK-008).

### BR-STK-003 — Dos ubicaciones

El sistema DEBE llevar las unidades en **depósito** y **góndola** por separado. Sin esa
distinción, mover mercadería del fondo al estante no cambia ningún número y reponer deja de ser
una tarea.

### BR-STK-004 — La noche arranca con cada caja llena y la góndola completa salvo lo que falta

CUANDO se abre una jornada, el sistema DEBE poner **8 unidades de cada producto en el depósito**,
una caja llena, y DEBE dejar **completa la fila de adelante de cada producto, salvo los faltantes
de esa jornada**. La mercadería expuesta se cuenta: son las unidades en la góndola. Ningún
faltante DEBE pasar de las unidades de una caja ni de los casilleros de su fila de adelante: con
más que una caja, reponerlo no se puede terminar, y con más que su fila, faltaría menos de lo que
la jornada dice.

### BR-STK-005 — Ingresar no resta

SI la cantidad que se ingresa no es positiva, ENTONCES el sistema DEBE ignorarla. Sin ese corte,
un ingreso negativo deja la góndola por debajo de cero: un estado imposible que ningún número
delata.

### BR-STK-006 — Mover devuelve cuántas movió

CUANDO se piden más unidades de las que hay, el sistema DEBE mover las que hay y contestar
cuántas fueron. Quien repone unidad por unidad necesita saber si el gesto tuvo efecto.

### BR-STK-007 — Faltante es tener un casillero vacío

El sistema DEBE listar como faltantes los productos con algún casillero vacío en su **fila de
adelante**, en el orden en que entraron al inventario. La cuenta es contra la fila y no contra
lo que pidió la jornada: un casillero que se vacía durante la noche vuelve a faltar. El depósito
lleno no cuenta: ésa es justamente la razón para ir al estante.

### BR-STK-008 — El cupo es la fila de adelante

El sistema DEBE llenar la góndola de cada producto hasta los casilleros de su fila de adelante,
que son distintos para cada producto, y rechazar la unidad que sobra. Cuántos casilleros tiene
cada fila lo dice el local armado: un número aparte sería el mismo valor en dos lugares.

### BR-STK-009 — Los tres rechazos de colocar, en orden

CUANDO se coloca una unidad, el sistema DEBE rechazar por **producto no aceptado** primero, por
**estante lleno** después, y por **sin unidades en depósito** al final. El primero es una
propiedad del producto y vale siempre; el segundo es el estado del estante; el tercero depende
de cuánta mercadería trajo la noche.

### BR-STK-013 — Reponer está cumplido cuando no falta nada

CUANDO ningún producto aceptado por el estante es faltante, el sistema DEBE dar la obligatoria de
reponer por cumplida. La pregunta se la hace al inventario y no la recalcula.

### BR-STK-016 — A la caja apoyada se le saca una unidad

CUANDO el jugador le pide una unidad a una caja del depósito que **no lleva en la mano**, el
sistema DEBE darle una unidad del producto de la caja, sin importar dónde esté apoyada: el piso,
un estante, un mostrador u otra caja. SI el jugador lleva esa caja, ENTONCES el sistema NO DEBE
darle nada.

### BR-STK-017 — La caja no entrega lo que la góndola no puede recibir

SI la góndola de ese producto ya no tiene lugar, contando las unidades que ya salieron de la caja
y todavía no se colocaron, ENTONCES el sistema DEBE negar la unidad aunque la caja tenga. Una
unidad que sale de la caja no vuelve a ella: sin este corte, queda en la mano sin lugar.

### BR-STK-018 — Se vende lo que el estante no necesita

El sistema DEBE contestar los vendibles de un producto como su depósito menos los casilleros
vacíos de su fila de adelante, y nunca menos de cero. Una unidad en la mano sigue contada en el
depósito, y también en lo que a la góndola le falta. Un producto que el inventario no conoce
tiene cero vendibles.

### BR-STK-019 — La planilla tiene una fila por producto, y arranca en cero

El sistema DEBE dar a la planilla una fila por producto del catálogo, en el orden del catálogo.
CUANDO se abre una jornada, cada fila DEBE arrancar en 0 unidades: lo anotado en una noche no
pasa a la siguiente.

### BR-STK-020 — «+» y «−» mueven una unidad de una fila

CUANDO el jugador aprieta «+» o «−» en una fila, el sistema DEBE sumar o restar una unidad a
esa fila y a ninguna otra. Una fila DEBE quedar entre 0 y 99: SI el gesto la saca de ese rango,
ENTONCES el sistema NO DEBE cambiar nada.

### BR-STK-021 — El total informa, no decide

El sistema DEBE mostrar el total de la planilla como la suma de las unidades anotadas por el
precio de cada producto en el catálogo. El total NO DEBE entrar en la condición de registrar
cumplida: dos planillas distintas pueden sumar lo mismo.

### BR-STK-022 — Registrar se cumple cuando lo anotado coincide con lo vendido

CUANDO un «+» o un «−» del jugador deja, para cada producto, lo anotado igual a lo vendido esa
noche, el sistema DEBE dar la obligatoria de registrar por cumplida. CUANDO otro «+» u otro
«−» deja la planilla distinta de lo vendido, el sistema DEBE descumplirla. La obligatoria NO
DEBE arrancar cumplida, aunque la planilla en 0 coincida con una noche sin ventas. Una venta
NO DEBE cumplirla ni descumplirla: sólo el gesto del jugador la cambia.

### BR-STK-023 — Cada producto declara su sonoridad

El sistema DEBE declarar una sonoridad (ver [`ambience`](../ambience/ambience.md)) para cada
producto del catálogo. La sonoridad sale de la
ficha del producto: lata, cajita, caja, envoltorio plástico o botella plástica. Un producto sin
sonoridad no suena al agarrarlo ni al dejarlo, y nada lo avisa.

### BR-STK-024 — Un producto, un lugar

El sistema DEBE exhibir cada producto del catálogo en una sola tanda del local, al alcance de un
jugador parado en el pasillo, y DEBE ubicar todos los casilleros de ese producto en esa tanda.
SI un estante no se puede completar sin repetir un producto, ENTONCES lo que se repite DEBE ser
fijo: no tiene casilleros y nunca se vacía. Con los casilleros de un producto repartidos en dos
lugares, el jugador no sabe adónde va lo que lleva en la mano.

### BR-STK-025 — La tanda tiene dos filas

La tanda de cada producto DEBE tener dos filas, una detrás de la otra. Cada lugar de la fila de
adelante DEBE ser un casillero del producto, y ninguno de la fila de atrás. La fila de atrás DEBE
verse entera desde que abre la jornada y NO DEBE poder agarrarse ni vaciarse: es la que dice qué
va ahí.

### BR-STK-026 — Lo que falta al abrir cada jornada

CUANDO se abre una jornada, el sistema DEBE dejar faltando lo que dice su fila, y ningún otro
producto:

| Jornada | Faltan en la góndola |
|---|---|
| 1 | 5 Actroncito y 6 Coracola |
| 2 a 5 | los de la jornada 1, mientras la ficha no decida los suyos (OQ-STK-005) |

### BR-STK-027 — Lo que se vende no le quita a lo que se repone

Lo que los compradores de una jornada piden de un producto, sumado a lo que le falta a su fila
de adelante al abrir, NO DEBE pasar de las unidades de una caja. La venta y la reposición salen
de la misma caja: con más, vender y reponer no se pueden cumplir en la misma noche.

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

DADO un producto de 8 casilleros CUANDO se abre una jornada que le hace faltar 0, 5 u 8 ENTONCES
el depósito arranca con 8 y la góndola con 8, 3 o 0; con 0 faltantes no es faltante. DADO una
jornada que se abre ENTONCES cada producto del catálogo tiene 8 en el depósito.

### AC-STK-005 — Ingresar negativo no hace nada *(verifica BR-STK-005)*

DADO una góndola en 0 CUANDO se ingresan `-5` unidades ENTONCES sigue en 0.

### AC-STK-006 — Mover de más mueve lo que hay *(verifica BR-STK-006)*

DADO 2 unidades en depósito CUANDO se piden 5 al mover ENTONCES mueve 2, contesta 2, y el
depósito queda en 0.

### AC-STK-007 — El borde de la fila *(verifica BR-STK-007)*

DADO un producto de 3 casilleros CUANDO la góndola tiene 2 ENTONCES es faltante; con 3 no lo es.
DADO un producto con su fila de adelante completa, que la jornada no hizo faltar, CUANDO una de
sus unidades sale de la góndola ENTONCES vuelve a ser faltante.

### AC-STK-008 — El estante se llena hasta la fila *(verifica BR-STK-008)*

DADO un producto de 3 casilleros con la góndola en 3 CUANDO se coloca otra unidad ENTONCES se
rechaza por estante lleno y el depósito no bajó. DADO dos productos, de 4 y de 2 casilleros,
ENTONCES el cupo del primero es 4 y el del segundo 2.

### AC-STK-009 — El orden de los rechazos *(verifica BR-STK-009)*

DADO un estante que no acepta el producto, lleno y sin depósito a la vez CUANDO se coloca
ENTONCES el motivo es producto no aceptado; aceptado y lleno, estante lleno; aceptado, con lugar
y sin depósito, sin unidades en depósito.

### AC-STK-013 — Reponer cumplido *(verifica BR-STK-013)*

DADO un estante con la fila de adelante de todos sus productos completa ENTONCES la obligatoria
está cumplida; con un solo casillero vacío, no.

### AC-STK-016 — Se saca de la caja apoyada, nunca de la llevada *(verifica BR-STK-016)*

DADO una caja del depósito apoyada, en cualquier lado, CUANDO se le pide una unidad ENTONCES se
puede sacar; DADO la misma caja en la mano del jugador, ENTONCES no.

### AC-STK-017 — Lo que ya salió cuenta contra el lugar de la góndola *(verifica BR-STK-017)*

DADO un producto de 2 casilleros, con la góndola vacía y más de 2 en su caja CUANDO se sacan 2
unidades sin colocarlas ENTONCES la tercera se niega; y colocar esas 2 no habilita una tercera.

### AC-STK-018 — Los vendibles *(verifica BR-STK-018)*

DADO un producto de 8 casilleros CUANDO se piden sus vendibles ENTONCES:

| Góndola | Depósito | Vendibles |
|---|---|---|
| 8 | 2 | 2 |
| 0 | 10 | 2 |
| 7 | 3 | 2 |
| 8 | 0 | 0 |
| 0 | 5 | 0 |

Y un producto que el inventario no conoce contesta 0.

### AC-STK-020 — Una fila por producto, en cero *(verifica BR-STK-019)*

DADO una jornada que se abre CUANDO se mira la planilla ENTONCES tiene una fila por producto del
catálogo, en su orden, y cada una en 0.

### AC-STK-021 — Un gesto, una fila *(verifica BR-STK-020)*

DADO una planilla en 0 CUANDO se aprieta «+» dos veces en un producto y «−» una vez ENTONCES esa
fila queda en 1 y todas las demás en 0.

### AC-STK-022 — Los bordes de una fila *(verifica BR-STK-020)*

DADO una fila en 0 CUANDO se aprieta «−» ENTONCES sigue en 0 y el gesto se rechaza. DADO una
fila en 99 CUANDO se aprieta «+» ENTONCES sigue en 99 y el gesto se rechaza. Un producto que no
está en la planilla también se rechaza, y ninguna fila cambia.

### AC-STK-023 — El total sigue a cada gesto, y no cumple *(verifica BR-STK-021)*

DADO un producto de precio 2500 con 2 anotadas y otro de precio 1200 con 1 CUANDO se mira el
total ENTONCES es 6200; con un «−» en el primero, 3700. DADO una noche que vendió 1 unidad de un
producto de precio 1200 CUANDO se anota 1 unidad de otro producto del mismo precio ENTONCES el
total es igual al de lo vendido y registrar no se cumple.

### AC-STK-024 — Registrar se cumple con el gesto que iguala *(verifica BR-STK-022)*

DADO una jornada que se abre sin ventas ENTONCES registrar arranca sin cumplir. DADO una noche
que vendió 2 unidades de un producto y 1 de otro CUANDO se anotan esas 3 unidades ENTONCES
registrar se cumple con el último gesto, y no antes.

### AC-STK-025 — Sólo el jugador la deshace *(verifica BR-STK-022)*

DADO registrar cumplida CUANDO se aprieta «+» en cualquier fila ENTONCES se descumple, y un «−»
en esa fila la vuelve a cumplir. DADO registrar cumplida CUANDO se cobra una venta nueva
ENTONCES sigue cumplida.

### AC-STK-026 — Lo anotado no pasa a la noche siguiente *(verifica BR-STK-019)*

DADO una jornada con 3 unidades anotadas CUANDO se abre la jornada siguiente ENTONCES todas las
filas están en 0 y registrar, sin cumplir.

### AC-STK-027 — Ningún producto queda sin sonoridad *(verifica BR-STK-023)*

DADO cada producto del catálogo ENTONCES tiene una sonoridad. Las arvejas, la Coracola y las
Prongles suenan a lata.

### AC-STK-028 — Cada producto se repone en un solo lugar *(verifica BR-STK-024)*

DADO el local armado ENTONCES cada producto del catálogo tiene una sola tanda con casilleros,
sobre un solo estante y con sus unidades juntas, y cualquier otra unidad de ese producto que se
vea en el local es fija.

### AC-STK-029 — El casillero está al alcance *(verifica BR-STK-024)*

DADO cualquier producto del catálogo en la mano CUANDO el jugador se para en el pasillo frente a
su tanda ENTONCES la mira alcanza su casillero y el producto se coloca.

### AC-STK-030 — Dos filas, y el cupo adelante *(verifica BR-STK-025)*

DADO la tanda de cualquier producto ENTONCES tiene dos filas, una detrás de la otra; la de
adelante es la más cercana al pasillo, y cada uno de sus lugares es un casillero: tiene tantos
como el cupo del producto.

### AC-STK-031 — La fila de atrás, entera toda la noche *(verifica BR-STK-025)*

DADO una jornada que se abre ENTONCES de cada producto se ve entera la fila de atrás, y la de
adelante completa salvo sus faltantes. CUANDO se repone lo que falta ENTONCES la fila de adelante
queda completa y la de atrás no cambió.

### AC-STK-032 — Una caja entera alcanza para el faltante más grande *(verifica BR-STK-004)*

DADO un producto de 12 casilleros al que la jornada le hace faltar 8 CUANDO se colocan las 8
unidades de su caja ENTONCES su fila de adelante queda completa, el depósito en 0 y no es
faltante.

### AC-STK-033 — Ningún faltante pasa de una caja ni de su fila *(verifica BR-STK-004)*

DADO los faltantes de cada jornada, de la 1 a la 5, ENTONCES ninguno pasa de 8 ni de los
casilleros de la fila de adelante de su producto.

### AC-STK-034 — Lo que falta en cada jornada *(verifica BR-STK-026)*

DADO la jornada 1 que se abre ENTONCES faltan 5 Actroncito y 6 Coracola, y todos los demás
productos tienen su fila de adelante completa. DADO las jornadas 2, 3, 4 y 5 ENTONCES faltan
los mismos.

### AC-STK-035 — Se vende sin quitarle a la reposición *(verifica BR-STK-027)*

DADO cada jornada, de la 1 a la 5, CUANDO se les cobra a todos sus compradores apenas abre
ENTONCES ningún cobro se rechaza, y después se puede reponer todo lo que falta y dar reponer por
cumplida.

## No objetivos

- Esta capacidad NO cobra ni atiende: eso es de
  [`counter-service`](../counter-service/counter-service.md), que le pide el descuento.
- Esta capacidad NO mueve la unidad con la mano ni dibuja el hueco que se llenó.
- Esta capacidad NO decide el precio final de nada: el catálogo es un primer valor de balance.

## Contratos

- **Entrada:** los productos que existen, los casilleros de la fila de adelante de cada uno, la
  jornada que se abre, lo vendido de cada producto, y los pedidos de ingresar, mover, cobrar,
  sumar y restar en la planilla.
- **Salida:** cuántas unidades hay por ubicación, qué falta, lo anotado y el total de la
  planilla, si cada obligatoria está cumplida, y el motivo de cada rechazo.
- **Falla:** las cantidades no positivas se ignoran; el cobro que supera los vendibles no mueve
  nada; el producto inexistente contesta «no existe» en vez de romper. Un faltante de más de una
  caja o de más que su fila es un error de los datos, que un test detecta: el juego no lo
  acomoda.

## Señales

- El producto colocado en la góndola y la unidad retirada del depósito.

## Dependencias

- [`counter-service`](../counter-service/counter-service.md) (alimenta y consume): el cobro
  descuenta del depósito, hasta los vendibles; lo vendido de cada producto es contra qué se
  compara la planilla; y lo que piden los compradores de cada jornada entra en lo que la
  reposición deja (BR-STK-027).
- [`player-actions`](../player-actions/player-actions.md) (consume): la unidad viaja en la mano.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (alimenta y consume): avisa cuándo reponer y
  registrar quedaron cumplidas, y cuándo registrar dejó de estarlo; y la jornada que abre decide
  lo que falta.

## Preguntas abiertas

- **OQ-STK-004 — ¿Cómo suenan la botella de vidrio y la caja de cereal?**
  - Por qué sigue abierta: la ficha nombra dos familias sonoras que el juego no tiene
    —botella de vidrio y caja de cereal— y no hay audio para ellas. Mientras tanto suenan como
    la botella plástica y la cajita, que son las más parecidas.
  - Decide: el equipo de sonido.
  - Bloquea: nada.
- **OQ-STK-005 — ¿Qué falta en las jornadas 2 a 5?**
  - Por qué sigue abierta: la ficha «8. Tarea: Reposición» fija los faltantes de la jornada 1 y
    dice «A definir» en las otras cuatro. Mientras tanto arrancan con los de la jornada 1
    (BR-STK-026).
  - Decide: el diseño, en la ficha.
  - Bloquea: nada.
