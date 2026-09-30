---
schema_version: 1
capability_id: CAP-STK
status: ratified
owner: por definir
provenance: GDD «Reponer» y «Registrar»; fichas «6) Tarea: Registro de productos vendidos», «8. Tarea: Reposición» y «5. Formas de interacción con objetos»; base «Productos y cajas contenedoras»; migración de los specs 005, 008, 033, 042, 047
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
| **Caja del depósito** | la caja de un solo producto, donde está su depósito: se le saca de a una unidad y recibe de vuelta las de su producto, hasta llenarse | cajón, contenedor |
| **Contenido de la caja** | cuántas unidades tiene la caja: su depósito menos las que salieron de ella y todavía no se colocaron | stock, carga |
| **Góndola** | el estante del local, el que el jugador repone | vitrina, exhibidor |
| **Tanda** | las unidades de un mismo producto puestas juntas sobre un estante del local, en dos filas | bloque, exhibición |
| **Fila de adelante** | la fila de una tanda del lado del pasillo: la única que el jugador repone | frente, cara |
| **Fila de atrás** | la fila de una tanda contra el fondo del estante: fija, entera toda la noche | guía, fondo |
| **Casillero** | cada lugar de la fila de adelante, que el jugador llena colocando una unidad y vacía agarrándola. Cada uno está vacío u ocupado por separado | hueco, slot |
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

### BR-STK-009 — Los rechazos de colocar, en orden

CUANDO se coloca una unidad en un casillero, el sistema DEBE rechazar por **producto no
aceptado** primero —también cuando el casillero es de otro producto—, por **estante lleno**
después, por **casillero ocupado** en tercer lugar, y por **sin unidades en depósito** al final.
El primero es una propiedad del producto y vale siempre; el segundo y el tercero son el estado
del estante, y la fila llena va antes porque es la respuesta para cualquier casillero; el último
depende de cuánta mercadería trajo la noche. Ningún rechazo mueve nada.

### BR-STK-013 — Reponer está cumplido cuando no falta nada

CUANDO ningún producto aceptado por el estante es faltante, el sistema DEBE dar la obligatoria de
reponer por cumplida. La pregunta se la hace al inventario y no la recalcula.

### BR-STK-016 — A la caja apoyada y con contenido se le saca una unidad

CUANDO el jugador le pide una unidad a una caja del depósito que **no lleva en la mano** y que
**tiene contenido**, el sistema DEBE darle una unidad del producto de la caja, sin importar dónde
esté apoyada: el piso, un estante, un mostrador u otra caja. SI el jugador lleva esa caja, o la
caja está vacía, ENTONCES el sistema NO DEBE darle nada, aunque la góndola tenga lugar.

### BR-STK-017 — La caja no entrega lo que la góndola no puede recibir

SI la góndola de ese producto ya no tiene lugar, contando las unidades que ya salieron de la caja
y todavía no se colocaron, ENTONCES el sistema DEBE negar la unidad aunque la caja tenga. Una
unidad que sale de la caja vuelve a ella sólo si el jugador la devuelve (BR-STK-030): sin este
corte, sale una unidad que ningún casillero espera.

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

### BR-STK-028 — La caja cuenta desde su depósito

El sistema DEBE contar el contenido de la caja de cada producto como su depósito menos las
unidades que salieron de ella y todavía no se colocaron. La caja y el depósito NO DEBEN contar
distinto: una venta le resta una unidad a la caja, y colocar una unidad no le cambia nada, porque
ya había salido. CUANDO se abre una jornada, cada caja DEBE arrancar llena, con las unidades de
una caja (BR-STK-004), sin importar cómo terminó la anterior.

### BR-STK-029 — El clic sobre la caja: sacar, devolver o nada

CUANDO el jugador usa una caja del depósito apoyada, el sistema DEBE elegir el gesto por lo que
lleva en la mano. Con las manos vacías, DEBE sacarle una unidad (BR-STK-016). Con una unidad del
producto de la caja, DEBE devolvérsela (BR-STK-030). Con cualquier otra cosa en la mano NO DEBE
pasar nada: la ficha no le da un efecto, y el sistema no le inventa uno.

### BR-STK-030 — Devolver a la caja

CUANDO el jugador devuelve a la caja una unidad de su producto que salió de ella y no se colocó,
el sistema DEBE sacarla de la mano y sumarla al contenido de la caja. La caja la puede volver a
dar, y el depósito y la góndola no cambian. SI la caja está llena —tiene las unidades de una
caja—, o la unidad es de otro producto, o ya volvió a la caja, ENTONCES el sistema NO DEBE cambiar
nada: la unidad sigue en la mano. Una caja no pasa nunca de las unidades de una caja.

### BR-STK-031 — La caja examinada dice cuántas tiene

CUANDO el jugador examina una caja del depósito, apoyada o en la mano, el sistema DEBE mostrar
un texto con su contenido y el nombre de su producto en el catálogo. SI la caja no está llena,
ENTONCES el texto DEBE decir además cuántas le entran: las unidades de una caja menos su
contenido. El texto NO DEBE decir nada más: la pista de la caja no se muestra. CUANDO termina el
examen, el texto DEBE desaparecer. Examinar NO DEBE cambiar el contenido.

La unidad DEBE nombrarse por la familia sonora de su producto (BR-STK-023), y no por lo que el
producto es: Actroncito es una caja de medicamentos y Malbardo un paquete de cigarrillos, y los
dos se cuentan en cajitas. Con una sola unidad va el singular:

| Familia sonora | Singular | Plural |
|---|---|---|
| cajita | cajita | cajitas |
| envoltorio plástico | paquete | paquetes |
| lata | lata | latas |
| caja | cartón | cartones |
| botella plástica | botella | botellas |

Una caja se cuenta en cartones y no en cajas: el texto diría «una caja con 8 cajas». Cada familia
que usa un producto del catálogo DEBE tener su palabra.

### BR-STK-032 — Cada casillero se ocupa y se vacía por separado

El sistema DEBE saber qué casilleros de la fila de adelante de cada producto están ocupados, y no
sólo cuántos. CUANDO se coloca una unidad, el sistema DEBE ocupar el casillero elegido y ningún
otro. CUANDO una unidad sale de la góndola, DEBE vaciar el casillero de esa unidad y ningún otro.
Las unidades de al lado NO DEBEN correrse: el jugador ve un hueco donde sacó la unidad, y ahí la
vuelve a poner.

### BR-STK-033 — Se agarra una unidad colocada de la fila de adelante

CUANDO el jugador agarra una unidad colocada en un casillero de la fila de adelante, el sistema
DEBE dársela y dejar ese casillero vacío: el producto vuelve a faltar (BR-STK-007). Da lo mismo
que la haya colocado él o que estuviera desde que abrió la jornada. SI el casillero está vacío,
ENTONCES el sistema NO DEBE darle nada. La fila de atrás no se agarra (BR-STK-025).

Con esa unidad en la mano vale todo lo que vale para una que salió de su caja: se coloca en
cualquier casillero vacío de su producto, se suelta, o se devuelve a su caja (BR-STK-030). SI
reponer estaba cumplida, ENTONCES el sistema DEBE descumplirla al agarrar la unidad, porque
vuelve a faltar algo (BR-STK-013).

### BR-STK-034 — La unidad agarrada de la góndola se cuenta una sola vez

CUANDO se agarra una unidad de la góndola, el sistema DEBE contarla como una que salió de su caja
y todavía no se colocó (BR-STK-028): la góndola tiene una menos, la caja no cambia, y los
vendibles tampoco, porque su casillero vacío la espera (BR-STK-018). MIENTRAS está en la mano o
soltada en el piso, el sistema NO DEBE contarla en la góndola ni venderla. CUANDO se la devuelve a
su caja, la caja DEBE sumarla y la góndola seguir con ese casillero vacío; SI la caja está llena,
ENTONCES la unidad no entra y sigue en la mano (BR-STK-030). CUANDO se la coloca, la góndola, la
caja y los vendibles DEBEN quedar como antes de agarrarla.

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

### AC-STK-016 — Se saca de la caja apoyada y con contenido, nunca de la llevada *(verifica BR-STK-016)*

DADO una caja del depósito apoyada, en cualquier lado y con contenido, CUANDO se le pide una
unidad ENTONCES se puede sacar; DADO la misma caja en la mano del jugador, ENTONCES no. DADO una
caja en 0 y la góndola de su producto con lugar para 6 CUANDO se le pide una unidad ENTONCES no se
saca nada.

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

### AC-STK-036 — La caja arranca en 8 y cuenta lo que sale *(verifica BR-STK-028)*

DADO una jornada que se abre ENTONCES la caja de cada producto del catálogo tiene 8. DADO una
caja en 8 CUANDO se saca una unidad ENTONCES tiene 7; CUANDO esa unidad se coloca ENTONCES sigue
en 7; CUANDO se cobra una unidad de su producto ENTONCES tiene 6, igual que su depósito.

### AC-STK-037 — Cada noche las cajas vuelven a 8 *(verifica BR-STK-028)*

DADO una jornada que termina con una caja en 0, otra con una unidad suya en la mano y otra con
una unidad devuelta CUANDO se abre la jornada siguiente ENTONCES todas las cajas tienen 8, y
ninguna unidad quedó afuera de su caja.

### AC-STK-038 — El clic sobre la caja: sacar, devolver o nada *(verifica BR-STK-029)*

DADO una caja de Actroncito apoyada CUANDO el jugador la usa ENTONCES: con las manos vacías saca
una unidad; con una unidad de Actroncito, la devuelve; con una unidad de Malbardo, con otra caja o
con cualquier otro objeto en la mano no pasa nada: lo que lleva sigue en la mano y la caja no
cambia.

### AC-STK-039 — Devolver anula la salida *(verifica BR-STK-030)*

DADO una caja en 8 CUANDO se saca una unidad, se la devuelve y se saca otra ENTONCES la caja pasa
por 7, 8 y 7, lo que se puede sacar de ella baja, sube y baja con la caja, y el depósito y la
góndola no cambian. DADO una unidad devuelta CUANDO se la devuelve otra vez ENTONCES no cambia
nada. DADO una unidad que salió de la caja, se soltó en el piso y se volvió a levantar CUANDO se
la devuelve ENTONCES la caja suma 1.

### AC-STK-040 — La caja llena no recibe *(verifica BR-STK-030)*

DADO una caja en 8 y una unidad de su producto en la mano CUANDO se la devuelve ENTONCES la caja
sigue en 8 y la unidad sigue en la mano. DADO una caja en 0 CUANDO se le devuelve una unidad de su
producto ENTONCES tiene 1.

### AC-STK-041 — El texto de la caja examinada *(verifica BR-STK-031)*

DADO una caja con tope de 8 CUANDO se la examina ENTONCES el texto es:

| En la caja | Texto |
|---|---|
| 8 de Actroncito | Una caja con 8 cajitas de Actroncito. |
| 5 de Malbardo | Una caja con 5 cajitas de Malbardo. Entran 3 más. |
| 7 de Actroncito | Una caja con 7 cajitas de Actroncito. Entra 1 más. |
| 1 de Actroncito | Una caja con 1 cajita de Actroncito. Entran 7 más. |
| 0 de Actroncito | Una caja con 0 cajitas de Actroncito. Entran 8 más. |
| 8 de Laysntt | Una caja con 8 paquetes de Laysntt. |
| 1 de Coracola | Una caja con 1 lata de Coracola. Entran 7 más. |
| 6 de Terminator | Una caja con 6 cartones de Terminator. Entran 2 más. |
| 1 de Fernet God | Una caja con 1 botella de Fernet God. Entran 7 más. |

DADO cada producto del catálogo ENTONCES su familia sonora tiene su palabra, en singular y en
plural.

### AC-STK-042 — El texto dura lo que dura el examen *(verifica BR-STK-031)*

DADO una caja apoyada CUANDO se la examina ENTONCES se lee su texto y no su pista; CUANDO se la
examina en la mano ENTONCES se lee el mismo texto. CUANDO termina el examen ENTONCES el texto
desaparece, y la caja tiene lo mismo que antes de examinarla.

### AC-STK-043 — El casillero ocupado se rechaza *(verifica BR-STK-009, BR-STK-032)*

DADO un producto de 3 casilleros con sólo el segundo ocupado y unidades en el depósito CUANDO se
coloca en el segundo ENTONCES se rechaza por casillero ocupado y ni la góndola ni el depósito
cambian; CUANDO se coloca en el primero ENTONCES queda ocupado el primero, el segundo sigue
ocupado y el tercero vacío. DADO el mismo casillero ocupado y el depósito en 0 ENTONCES el motivo
es casillero ocupado. DADO la fila llena ENTONCES el motivo es estante lleno en cualquier
casillero. DADO una unidad de otro producto ENTONCES el motivo es producto no aceptado.

### AC-STK-044 — Las de al lado no se corren *(verifica BR-STK-032, BR-STK-033)*

DADO un producto de 5 casilleros con la fila completa CUANDO se agarra la unidad del tercero
ENTONCES el único casillero vacío es el tercero, los otros cuatro siguen ocupados y el producto
es faltante. CUANDO se coloca una unidad en el tercero ENTONCES la fila vuelve a estar completa
y no es faltante.

### AC-STK-045 — Sólo se agarra lo colocado *(verifica BR-STK-033)*

DADO un casillero vacío CUANDO se lo agarra ENTONCES no se da nada y la góndola no cambia. DADO
una unidad agarrada de la góndola ENTONCES se coloca en cualquier casillero vacío de su producto,
y en uno de otro producto se rechaza por producto no aceptado.

### AC-STK-046 — La unidad agarrada se cuenta una sola vez *(verifica BR-STK-034, BR-STK-018)*

DADO un producto de 8 casilleros con la fila completa y su caja en 5 CUANDO se agarra una unidad
de la góndola ENTONCES la góndola tiene 7, la caja sigue en 5, los vendibles siguen en 5 y el
producto es faltante; CUANDO se la suelta en el piso ENTONCES nada de eso cambia. CUANDO se la
devuelve a su caja ENTONCES la caja tiene 6, la góndola sigue en 7 y los vendibles en 5. CUANDO
se la vuelve a sacar y se la coloca ENTONCES la góndola tiene 8, la caja 5 y los vendibles 5.

### AC-STK-047 — La caja llena no recibe la unidad de la góndola *(verifica BR-STK-034)*

DADO la fila completa y la caja en 8 CUANDO se agarra una unidad de la góndola y se la devuelve a
su caja ENTONCES la caja sigue en 8, la unidad sigue en la mano y la góndola tiene un casillero
vacío.

### AC-STK-048 — Agarrar de la góndola descumple reponer *(verifica BR-STK-033)*

DADO reponer cumplida CUANDO se agarra una unidad de la góndola ENTONCES reponer deja de estar
cumplida y las cumplidas bajan en 1. CUANDO se la vuelve a colocar ENTONCES reponer se cumple
otra vez.

## No objetivos

- Esta capacidad NO cobra ni atiende: eso es de
  [`counter-service`](../counter-service/counter-service.md), que le pide el descuento.
- Esta capacidad NO mueve la unidad con la mano ni dibuja el hueco que se llenó.
- Esta capacidad NO decide el precio final de nada: el catálogo es un primer valor de balance.

## Contratos

- **Entrada:** los productos que existen, los casilleros de la fila de adelante de cada uno, la
  jornada que se abre, lo vendido de cada producto, lo que el jugador lleva en la mano, la caja
  que examina, el casillero que elige, y los pedidos de ingresar, mover, cobrar, sacar y devolver
  a la caja, colocar y agarrar de la góndola, sumar y restar en la planilla.
- **Salida:** cuántas unidades hay por ubicación y en cada caja, qué casilleros de cada producto
  están vacíos y cuáles ocupados, qué falta, qué hace el clic sobre cada caja y sobre cada
  casillero, el texto de la caja examinada, lo anotado y el total de la planilla, si cada
  obligatoria está cumplida, y el motivo de cada rechazo.
- **Falla:** las cantidades no positivas se ignoran; el cobro que supera los vendibles no mueve
  nada; el producto inexistente contesta «no existe» en vez de romper; devolver a una caja llena,
  de otro producto o una unidad que ya volvió no cambia nada; colocar en un casillero ocupado no
  mueve nada, y agarrar de un casillero vacío no da nada. Un faltante de más de una caja o de más
  que su fila es un error de los datos, que un test detecta: el juego no lo acomoda.

## Señales

- El producto colocado en la góndola y la unidad retirada del depósito.

## Dependencias

- [`counter-service`](../counter-service/counter-service.md) (alimenta y consume): el cobro
  descuenta del depósito, hasta los vendibles; lo vendido de cada producto es contra qué se
  compara la planilla; y lo que piden los compradores de cada jornada entra en lo que la
  reposición deja (BR-STK-027).
- [`player-actions`](../player-actions/player-actions.md) (consume y alimenta): la unidad viaja
  en la mano, y lo que la mano lleva decide qué hace el clic sobre la caja y sobre cada casillero;
  qué casilleros están vacíos y cuáles ocupados decide cuáles se muestran y cuáles se agarran.
- [`investigation`](../investigation/investigation.md) (consume): el examen de una caja, que es
  el de cualquier levantable. Mientras dura se muestra el texto de la caja.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (alimenta y consume): avisa cuándo reponer y
  registrar quedaron cumplidas, y cuándo dejaron de estarlo; y la jornada que abre decide lo que
  falta.

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
