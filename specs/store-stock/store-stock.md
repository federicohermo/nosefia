---
schema_version: 1
capability_id: CAP-STK
status: ratified
owner: por definir
provenance: GDD «Reponer» y «Registrar»; fichas «7. Tarea: Registro de productos vendidos», «8. Tarea: Reposición», «5. Formas de interacción con objetos» y «Particulares de cada jornada»; decisiones de #366, #367, #369, #376 y #425; base «Productos y cajas contenedoras»; migración de los specs 005, 008, 033, 042, 047; Mapa de góndolas y comentario de Tiago del 2026-10-15 a las 18:25 UTC que conserva Duronga en exhibición provisional (#434); decisión del dueño de #434 — Actroncito y Prongles conservan dos hileras y rige la lista de cinco del arte vigente; pedidos fijos y activación J2 de #433 y #444; ocho jornadas de #526; mapas de prueba y completo del 20/10/2026 (#575); Duronga en lugar de Durextra en las jornadas de prueba y compras de Fede en la jornada 2 (#605); decisión del dueño de #645 — sólo los productos de una sola fila conservan una unidad y pasan el vacío al estante vecino; correcciones y protección del aire y de los márgenes de cabeceras y laterales pedidas por el dueño en #621; paso uniforme entre productos de un estante y aire de Terminator pedidos por el dueño tras probar #621; compras físicas, pedidos sorteados y registro de las jornadas 3 a 5 de #459; registro de las noches de prueba con sólo los productos presentes (#625); cajas que amanecen donde el jugador las dejó, de la ficha «8. Tarea: Reposición» (#555); zonas de reposición del mapa de esa ficha (#554); la unidad en la mano al cierre cuenta como puesta (#386)
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
| **Contenido de la caja** | cuántas unidades tiene la caja: su depósito menos sus unidades afuera | stock, carga |
| **Unidad afuera** | una unidad que salió de su caja, o que se agarró de la góndola, y todavía no se colocó, volvió a su caja ni se tiró: en la mano o soltada en el piso. Sigue contada en el depósito | reservada, en tránsito |
| **Góndola** | el estante del local, el que el jugador repone | vitrina, exhibidor |
| **Tanda** | las unidades de un mismo producto puestas juntas sobre un estante del local, en dos filas o en una | bloque, exhibición |
| **Tanda fija** | una tanda que repite un producto para completar un estante. Su fila de adelante tiene casilleros, como la de cualquier tanda | guía, decorado |
| **Cara de lado** | cada uno de los dos lados largos de un mueble de estantes, el que da a un pasillo | frente, lateral |
| **Cabecera** | cada uno de los dos extremos cortos de un mueble de estantes | punta, testero |
| **Zócalo** | el estante de más abajo de una cara de lado | base, piso |
| **Estante de reposición** | un estante a la altura de la mano: los niveles 1 y 2 de los cuatro existentes, tanto en laterales como en cabeceras | estante del medio, estante útil |
| **Fila de adelante** | la fila de una tanda del lado del pasillo: la única que el jugador repone. En una tanda de una sola fila, es esa fila | frente, cara |
| **Fila de atrás** | la fila de una tanda de dos filas contra el fondo del estante: fija, entera toda la noche | guía, fondo |
| **Casillero** | cada lugar de la fila de adelante, que el jugador llena colocando una unidad y vacía agarrándola. Cada uno está vacío u ocupado por separado | hueco, slot |
| **Cupo** | cuántos casilleros suman las filas de adelante de las tandas de un producto: cuántas unidades pide su góndola. Es distinto para cada producto | umbral, mínimo, tope |
| **Faltante** | un producto con algún casillero vacío en su fila de adelante | agotado, sin stock |
| **Zona de reposición** | cada una de las siete regiones del piso del local del [mapa de la ficha «8. Tarea: Reposición»](https://app.notion.com/p/3cc86efecd9d81968a25c7cffca4b0dd), numeradas de 1 a 7 | sector, pasillo |
| **Zona con faltante** | zona de reposición con algún producto faltante entre los de sus muebles | zona vacía |
| **Faltantes de la jornada** | cuántas unidades de cada producto faltan en la góndola cuando abre una jornada | pedido, reposición |
| **Máximo reponible** | el menor entre los casilleros de la tanda reponible de un producto y las unidades de una caja menos sus unidades pedidas esa noche | cupo, vendibles |
| **Producto elegible** | producto del catálogo cuyo máximo reponible es al menos una unidad | producto sorteado |
| **Vendibles** | lo que queda en la caja menos lo que a la góndola todavía le falta de ella: el depósito menos el mayor entre los casilleros vacíos de la fila de adelante y las unidades afuera | stock, disponible |
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

CUANDO se abre una jornada, el sistema DEBE poner **8 unidades de cada producto presente esa jornada en el depósito** (BR-STK-046),
una caja llena, y DEBE dejar **completa la fila de adelante de cada producto exhibido, salvo los faltantes
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

El sistema DEBE llenar la góndola de cada producto exhibido hasta los casilleros de su fila de adelante,
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

### BR-STK-017 — La caja entrega hasta vaciarse

CUANDO el jugador le pide una unidad a una caja del depósito con contenido, el sistema DEBE darla
aunque la fila de adelante de su producto esté completa. El sistema NO DEBE limitar lo que sale
de la caja por los casilleros vacíos ni por las unidades afuera: sólo por su contenido
(BR-STK-028). La unidad sin casillero se rechaza al colocarla por estante lleno (BR-STK-009) y
sigue en la mano; vuelve a la caja si el jugador se la devuelve (BR-STK-030).

### BR-STK-018 — Se vende lo que queda en la caja y la góndola no necesita

El sistema DEBE contestar los vendibles de un producto como su depósito menos el mayor entre los
casilleros vacíos de su fila de adelante y sus unidades afuera, y nunca menos de cero. Es lo que
queda en la caja menos lo que a la góndola todavía le falta de ella: un casillero vacío que ya
espera una unidad afuera no se descuenta dos veces. El cobro automático NO DEBE vender una unidad afuera:
ninguna venta deja el depósito por debajo de las unidades afuera. Un producto que el inventario
no conoce tiene cero vendibles.

### BR-STK-019 — La planilla tiene una fila por producto, y arranca en cero

El sistema DEBE dar a la planilla una fila por producto del catálogo presente esa noche
(BR-STK-046), en el orden del catálogo.
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

MIENTRAS esa noche haya al menos una venta y, para cada producto, lo anotado sea igual a lo
vendido, el sistema DEBE dar registrar por cumplida. CUANDO no coincidan, el sistema DEBE
descumplirla. La jornada DEBE abrir con registrar sin cumplir. El sistema DEBE revisarla con
cada «+» o «−» que cambia una fila, con cada venta cobrada y con cada vencimiento de compra.
El cierre DEBE contar el estado de ese instante (BR-SHF-007 de
[`shift-cycle`](../shift-cycle/shift-cycle.md)): una noche sin
ventas con la planilla en cero cuenta como cumplida recién ahí.

En las jornadas 1 a 5, registrar DEBE permanecer pendiente mientras quede alguna compra
abierta de sus compradores, porque el comprador todavía no llegó o sigue esperando completar su
compra. CUANDO ambas compras terminaron, vendidas o vencidas, el sistema DEBE evaluar registrar
por la coincidencia exacta con lo vendido en compras completas, sin exigir cumplir atención.
Una compra vendida DEBE contar como terminada aunque su despedida continúe. Registrar sólo
la primera compra o anticipar la segunda NO DEBE cumplir la tarea mientras la segunda siga
abierta. Las unidades de compras vencidas NO DEBEN contarse como vendidas. Con ambas compras
vencidas y la planilla en cero, registrar DEBE contar como cumplida al cierre; antes del cierre,
sin ventas, DEBE seguir pendiente como en las demás jornadas.

### BR-STK-023 — Cada producto declara su sonoridad

El sistema DEBE declarar una sonoridad (ver [`ambience`](../ambience/ambience.md)) para cada
producto del catálogo. La sonoridad sale de la
ficha del producto: lata, cajita, caja, envoltorio plástico o botella plástica. Un producto sin
sonoridad no suena al agarrarlo ni al dejarlo, y nada lo avisa.

### BR-STK-024 — Un producto, un lugar

El sistema DEBE exhibir cada producto con exhibición declarada (BR-STK-043, BR-STK-044)
en una sola tanda reponible, al alcance de
un jugador parado en el pasillo. La fila de adelante de cada tanda del local, reponible o fija y
en cualquier estante, DEBE ser de casilleros de su producto: se agarra y se repone igual. Los
casilleros vacíos con que abre una jornada DEBEN quedar juntos: un bloque de casilleros seguidos
en la fila de adelante de una tanda del producto, reponible o fija y en cualquier estante. La
tanda DEBE elegirse al azar entre las que reciben el faltante entero.
SI el faltante no entra entero en ninguna, ENTONCES DEBE partirse: las tandas se vacían enteras,
una junto a la otra en estantes contiguos, y la tanda parcial queda pegada a ellas, debajo del
bloque; arriba sólo si debajo no hay estante. Los vacíos de la tanda parcial DEBEN ir en las mismas
columnas que los del estante anterior, hasta donde lo permita lo que la tanda protege. En una
tanda, los vacíos NO DEBEN quedar separados por casilleros ocupados. En un producto de dos filas
(BR-STK-025), la apertura PUEDE vaciar entera la fila de adelante de cualquier tanda, la
reponible incluida: la fila de atrás dice qué va ahí.

La apertura NO DEBE vaciar entera la fila de adelante de ninguna tanda de un producto de una sola
fila: en cada estante del producto DEBE quedar al menos una unidad. El faltante que no cabe en un
estante DEBE quedar en la fila de adelante del estante de justo arriba: con cuatro casilleros por
estante y cuatro faltantes, faltan tres de un estante y uno del de arriba. SI el de los tres es el
de arriba de todo, ENTONCES el que sobra DEBE quedar en el de justo abajo. SI el estante vecino
tiene una sola unidad y no puede ceder ninguna, ENTONCES el que sobra DEBE pasar al siguiente
estante del producto con más de una unidad, en la misma dirección.
Los vacíos DEBEN seguir sumando lo que faltó. «Justo arriba» y «justo abajo» se miden por la
altura de las tandas del producto en esa cara.

En un mueble de estantes, la tanda reponible DEBE ir en un estante de reposición. Un estante
de reposición NO DEBE llevar una tanda fija: todo lo que el jugador ve a la altura de la mano se
agarra y se repone. Los demás estantes —el de arriba y el zócalo, tanto de una cara de lado
como de una cabecera— DEBEN llevar sólo tandas fijas, que repiten un producto del local.
En una heladera, cualquier bandeja puede llevar la tanda reponible o una tanda fija.
En las jornadas de prueba, BR-STK-047 permite repetir una tanda fija en el otro nivel de
reposición, conservando una sola principal por producto y todos los frontales interactuables.

### BR-STK-025 — Las filas corresponden a cada tanda aprobada

Cada tanda principal o fija de un producto exhibido DEBE tener dos filas, una detrás de la
otra, salvo las excepciones siguientes. Cada lugar de la fila de adelante DEBE ser un
casillero del producto, y ninguno de la fila de atrás. La fila de atrás DEBE verse entera
desde que abre la jornada y NO DEBE poder agarrarse ni vaciarse: es la que dice qué va ahí.

Todas las tandas de Cosa de Maní, Flin Puf, Burbaloo, Marranos y Poético DEBEN tener una sola
fila. Las demás tandas DEBEN tener dos filas, incluidas las principales y fijas de Actroncito y
Prongles, que conservan las dos hileras del arte vigente. Las dos filas de una tanda DEBEN
verse separadas, y las unidades de un estante DEBEN repartirse de punta a punta con el mismo
hueco entre todas.

Cada lugar de una tanda de una fila DEBE ser un casillero, sea principal o fija; esa tanda
NO DEBE tener fila posterior. La cantidad de filas se decide por tanda, no sólo por producto.
El estante NO DEBE ensancharse para un producto: dos muebles iguales miden lo mismo.

### BR-STK-026 — Lo que falta al abrir cada jornada

CUANDO se abre una jornada de la 2 a la 8, el sistema DEBE sortear sus faltantes. CUANDO se abre
la jornada 1, el sistema NO DEBE sortear: la góndola DEBE abrir completa y cada caja llena, sin
ningún faltante. La jornada 1 NO DEBE declarar reponer, ni siquiera por las unidades vendidas
desde la góndola. Agarrar, colocar o vender esas unidades NO DEBE modificar su cuenta de tareas.
Retomar la jornada 1 desde el menú DEBE abrirla completa otra vez, sin declarar reponer.
La jornada 2 DEBE abrir con su inventario nuevo y sus faltantes sorteados.
Los huecos dejados por ventas en la jornada 1 NO DEBEN pasar a la siguiente.
DEBE elegir entre 4 y 6 productos distintos y, de cada uno, entre 3 unidades y su máximo
reponible. Ningún otro producto DEBE faltar. Los intervalos son los de la
[ficha «8. Tarea: Reposición»](https://app.notion.com/p/3cc86efecd9d81968a25c7cffca4b0dd).

Para cada producto, el máximo reponible DEBE ser `mínimo(C − P, F)`: `C` son las unidades de una
caja (BR-STK-004), `P` la suma de sus unidades pedidas esa noche y `F` los casilleros de la fila de
adelante de todas sus tandas, reponible y fijas, menos uno por cada tanda de un producto de una
sola fila, que no puede abrir vacía entera (BR-STK-024). El inventario DEBE conservar el cupo
total de todas las tandas (BR-STK-008). Los casilleros vacíos de un producto DEBEN quedar juntos
(BR-STK-024). Sólo los productos con máximo reponible mayor o igual a 3
DEBEN entrar al sorteo. Los pedidos DEBEN ser los mismos que recibe la atención de esa apertura,
incluidas las repeticiones de producto entre compradores. Consultarlos NO DEBE volver a sortear
compradores ni pedidos.

La cantidad de productos y las unidades de cada elegido DEBEN sortearse con reparto parejo
entre los enteros de sus intervalos inclusivos. Los productos DEBEN elegirse sin repetición.
SI hay menos elegibles que la cantidad sorteada, ENTONCES DEBEN faltar todos los elegibles
y ninguno más. Con cero elegibles NO DEBE faltar nada.

El sistema DEBE recibir la fuente de azar: con la misma semilla inicial, pedidos y casilleros,
DEBE producir los mismos faltantes y dejar vacíos los mismos casilleros. En juego, la fuente DEBE inicializarse al azar.
CUANDO abre la jornada siguiente o se retoma una jornada desde el menú o en otra sesión,
el sistema DEBE sortear de nuevo, sin recuperar una semilla guardada. Dos sorteos pueden
coincidir: sortear de nuevo NO DEBE exigir un resultado distinto del anterior. La semilla de la
partida que fija los pedidos de BR-CTR-047 no es esta fuente: los faltantes no la usan.

### BR-STK-027 — Lo que se vende no le quita a lo que se repone

Lo que los compradores de una jornada piden de un producto, sumado a lo que le falta a su fila
de adelante al abrir, NO DEBE pasar de las unidades de una caja. La venta y la reposición salen
de la misma caja: con más, vender y reponer no se pueden cumplir en la misma noche.

### BR-STK-028 — La caja cuenta desde su depósito

El sistema DEBE contar el contenido de la caja de cada producto como su depósito menos las
unidades que salieron de ella y todavía no se colocaron. La caja y el depósito NO DEBEN contar
distinto: una venta le resta una unidad a la caja, y colocar una unidad no le cambia nada, porque
ya había salido. CUANDO se abre una jornada, cada caja presente DEBE arrancar llena, con las unidades de
una caja (BR-STK-004), sin importar cómo terminó la anterior.

### BR-STK-029 — Sacar es secundario y devolver es primario

CUANDO el jugador hace el secundario —clic derecho por defecto— sobre una caja del depósito
apoyada con mano vacía, el sistema DEBE pedir sacar una unidad (BR-STK-016). Con mano ocupada,
el secundario NO DEBE devolver ni soltar nada. CUANDO hace el primario —clic izquierdo por
defecto— con una unidad del producto de esa caja, el sistema DEBE pedir devolverla
(BR-STK-030), antes de soltar. Una devolución coincidente rechazada por caja llena o unidad
ya devuelta DEBE conservar la mano, sin duplicar ni soltar. Con mano vacía el primario DEBE
agarrar la caja, sin sacar además una unidad. Sin par de devolución declarado, el primario
DEBE conservar el gesto genérico de dejar; el secundario con producto ajeno no cambia nada.

### BR-STK-030 — Devolver a la caja

CUANDO el jugador devuelve a la caja una unidad de su producto que salió de ella y no se colocó,
el sistema DEBE sacarla de la mano y sumarla al contenido de la caja. La caja la puede volver a
dar, y el depósito y la góndola no cambian. SI la caja está llena —tiene las unidades de una
caja—, o la unidad es de otro producto, o ya volvió a la caja, ENTONCES el sistema NO DEBE cambiar
nada: la unidad sigue en la mano. Una caja no pasa nunca de las unidades de una caja.

### BR-STK-031 — La caja examinada dice cuántas tiene

CUANDO el jugador examina una caja del depósito en la mano, o pide examinarla apoyada con las
manos vacías, el sistema DEBE mostrar un texto con su contenido y el nombre de su producto en el
catálogo. SI la caja no está llena, ENTONCES el texto DEBE decir además cuántas le entran: las
unidades de una caja menos su contenido. El texto NO DEBE decir nada más: la pista de la caja
no se muestra. CUANDO termina el examen, el texto DEBE desaparecer. Con la caja apoyada no hay
examen: el texto es un pensamiento (BR-SUB-002), y la caja sigue apoyada. Examinar NO DEBE
cambiar el contenido.

La redacción es contenido editable de [`subtitles`](../subtitles/subtitles.md). Cambiarla NO DEBE
cambiar la identidad del producto, el contenido ni los lugares libres que presenta el examen.

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

Al cerrar la noche, una unidad de producto que el jugador lleva en la mano, la esté examinando o
no, cuenta como puesta en su casillero vacío para decidir si reponer está cumplida. Es la misma
excepción que la saca del desorden: lo que se lleva en la mano no se castiga ni como desorden ni
como faltante. Vale sólo para ese chequeo: durante la noche el casillero sigue vacío mientras la
unidad está en la mano. Decisión del usuario del 26/10/2026 (#386).

### BR-STK-034 — La unidad agarrada de la góndola se cuenta una sola vez

CUANDO se agarra una unidad de la góndola, el sistema DEBE contarla como una que salió de su caja
y todavía no se colocó (BR-STK-028): la góndola tiene una menos, la caja no cambia, y los
vendibles tampoco, porque su casillero vacío la espera (BR-STK-018). MIENTRAS está en la mano o
soltada en el piso, el sistema NO DEBE contarla en la góndola ni venderla. CUANDO se la devuelve a
su caja, la caja DEBE sumarla y la góndola seguir con ese casillero vacío; SI la caja está llena,
ENTONCES la unidad no entra y sigue en la mano (BR-STK-030). CUANDO se la coloca, la góndola, la
caja y los vendibles DEBEN quedar como antes de agarrarla.

### BR-STK-035 — El estante de reposición se reparte en mitades

Un estante de reposición de una cara de lado DEBE llevar dos productos, cada uno en una mitad del
estante, o un solo producto que lo ocupa entero. NO DEBE llevar tres productos ni dos en partes
desiguales. Dos muebles de estantes iguales DEBEN medir lo mismo: ningún estante se ensancha para
un producto (BR-STK-025). En cada cara de lado, el estante inferior NO DEBE sobresalir respecto
de los estantes superiores.

### BR-STK-036 — Tirar una unidad afuera la retira del inventario

CUANDO se tira al contenedor una unidad registrada afuera, el sistema DEBE retirarla de
afuera y descontar una del depósito. La caja y la góndola DEBEN seguir como estaban: esa
unidad ya no se devuelve ni se coloca. Una unidad no registrada afuera NO DEBE cambiar el
inventario. La jornada siguiente DEBE abrir con el inventario de esa noche (BR-STK-026).

### BR-STK-037 — La venta física retira identidades una sola vez

CUANDO se completa una compra física, el sistema DEBE retirar definitivamente sus unidades
registradas afuera, una sola vez por identidad. NO DEBE volver a descontar el pedido completo.
Una recepción parcial DEBE conservarlas hasta la salida del comprador. SI vence la atención,
ENTONCES sus unidades recibidas DEBEN seguir registradas afuera, sin contar como venta ni
modificar el depósito, la caja o la góndola por el vencimiento. DEBEN conservar su identidad
y permitir agarrar, colocar, devolver a su caja o desechar como cualquier unidad suelta.
Una unidad vendida NO DEBE poder registrarse afuera otra vez.
Vender una unidad retirada de góndola NO DEBE rellenar su casillero ni cumplir reponer.

### BR-STK-038 — Las cajas empiezan donde el jugador las dejó, salvo la particular de la noche

CUANDO se abre la primera jornada de una partida nueva, el sistema DEBE poner cada caja en su
lugar de fábrica de las tres estanterías. CUANDO se abre cualquier otra jornada, DEBE poner cada
caja presente donde el jugador la dejó al cerrar la anterior (BR-STK-051).

CUANDO se abre la primera jornada completa que declara ordenar las cajas, el sistema DEBE
apilar exclusivamente las cajas de los productos ausentes en las jornadas de prueba
(BR-STK-046), en el fondo frente al portón. Las cajas de los productos ya presentes DEBEN
empezar donde el jugador las dejó, como en cualquier otra jornada. La pila DEBE conservar
las cajas dentro del depósito, sin superposición de cuerpos y con cada caja enfocable desde un
punto libre del piso dentro del alcance vigente. Sin intervención del jugador, ninguna caja
DEBE desplazarse más de 1 cm en los primeros 120 cuadros de física.

El lugar de origen de cada caja DEBE ser el de esa apertura: rescatar una de las cajas recién llegadas en la jornada 4
DEBE devolverla a la pila, sin ordenarla automáticamente. Toda otra caja DEBE volver a la pose
con que abrió esa noche. La ubicación «frente al portón» es
territorio de juicio humano; las restantes condiciones se verifican en AC-STK-077, AC-STK-080
y AC-STK-111 a AC-STK-113.

### BR-STK-039 — Ordenar sigue el apoyo de todas las cajas

MIENTRAS queda turno y la jornada declara ordenar las cajas, el sistema DEBE contar esa
obligatoria como cumplida si cada caja está suelta y su cadena de apoyos termina en un pallet
de las tres estanterías del depósito. Una caja sostenida —también examinada desde la mano— o
apoyada sobre una caja sostenida NO DEBE contar como ordenada.
Un pallet del piso NO DEBE contar como estantería. Una cadena que termina en otra superficie,
en una caja ausente o en un ciclo NO DEBE contar como ordenada. Una lista vacía DEBE contestar
que está ordenada. CUANDO una caja deja de cumplir la condición, el sistema DEBE descumplir
ordenar; recuperar la condición DEBE volver a cumplirla. Con el turno cerrado, mover cajas NO
DEBE cambiar la cuenta que se cerró. Una jornada que no declara ordenar NO DEBE sumar esa tarea.

### BR-STK-043 — La exhibición se agrupa por sector

DESDE la primera jornada completa, el sistema DEBE organizar la exhibición según estos
sectores, conservando las identidades
del catálogo, precios y gestos. La tabla cruza el nombre del catálogo vigente con el diseño;
no implica renombrar productos.

| Sector y destino | Productos del catálogo vigente |
|---|---|
| Heladera 1 | Coracola (Pura-Cola en el diseño), Oaaaa |
| Heladera 2 | Cindolor, Mayonchis |
| Estantería de no comestibles | Actroncito, Durextra, Poético, Duronga (provisional) |
| Cabecera de no comestibles, isla de almacén | Malbardo |
| Cabecera de almacén, misma isla | Amargadito |
| Lado de almacén | Marolini, Arvejas (Arvecor), Uakas (Uakalas), Marranos |
| Lado de cereales, misma isla | Zucarachas, Frotlups (Frot Lups) |
| Cabecera de bebidas sin refrigerar, misma isla | Fernet God, Terminator |
| Mitad de snacks dulces junto a cereales, primera isla | Macumbas, Pepitos (Pepito) |
| Lado de snacks dulces, segunda isla | Oremos, Petisas, Cosa de Maní, Feel Ricky Fort |
| Lado/cabecera de snacks salados, isla de snacks | Donsaturados (Don Saturados), Prongles (Progres), Chisitos, Laysntt (Laysnnt), Saladik (Saladick) |
| Cabeceras de golosinas, isla de snacks | Burbaloo, Flinpuf (Flim Pof), Jorgillo |

La primera isla DEBE reunir almacén, cereales y la mitad de snacks dulces junto a cereales,
con bebidas sin refrigerar en una cabecera. La segunda DEBE reunir los otros snacks dulces,
snacks salados y golosinas. Los cuatro no comestibles DEBEN ocupar la estantería existente;
el reparto NO DEBE reconstruir un segundo mural ausente ni duplicar tandas principales.
Cada heladera funcional DEBE agrupar sus dos productos en mitades verticales según el
[esquema de diseño](https://app.notion.com/p/3f186efecd9d8096bb5beb6c93d5a676): Coracola
arriba de Oaaaa y Cindolor arriba de Mayonchis. La heladera fuera de servicio DEBE
permanecer vacía. Fernet God y Terminator NO DEBEN exhibirse en heladera.

Cada cara de un mueble DEBE repetir sus productos en dos estantes seguidos: el de arriba de todo
con el reponible de abajo, y el otro reponible con el zócalo. En la rampa de una cabecera la
unidad DEBE apoyarse entera sobre la chapa, sin flotar.

Cada tanda fija de referencia DEBE conservar el sector de la reponible del mismo producto.
El reparto DEBE conservar alturas —salvo la bandeja del medio de cada cabecera, que sube para que
entren dos filas en la de abajo—, tamaño de muebles, niveles reponibles a altura de la mano,
separación de filas, orientaciones de envases y alcance vigentes (BR-STK-024, BR-STK-025,
BR-STK-035). Los cupos DEBEN salir de la geometría de ese reparto, sin copiar los anteriores.
Este reparto completo DEBE conservarse al abrir otra jornada completa y en escritorio o web.
Las jornadas de prueba DEBEN usar el reparto de BR-STK-047.

La medición del modelo del 2026-10-15 confirma cuatro chapas físicas y cuatro niveles con
exhibición en cada cabecera: niveles 0 y 3 fijos, niveles 1 y 2 reponibles. El antiguo detector
por distancia confundía las chapas superiores inclinadas con laterales; corregir su
clasificación conserva ese patrón original, sin agregar niveles ni modificar alturas.

### BR-STK-044 — Duronga conserva su exhibición provisional

DESDE la primera jornada completa, el sistema DEBE exhibir la tanda principal de Duronga en la mitad inferior derecha de la
estantería de no comestibles, junto a la principal de Poético en la mitad inferior izquierda;
las principales de Actroncito y Durextra ocupan la mitad superior. Esa ubicación provisional
DEBE conservarse hasta reemplazar el producto
según una decisión posterior de diseño. El
[comentario de Tiago del 2026-10-15](https://app.notion.com/p/3f186efecd9d8096bb5beb6c93d5a676?d=3fa86efecd9d81de96d5001c64307456&pvs=42)
confirma el mapa y prevalece sobre la indicación anterior de sólo depósito de la
[ficha detallada](https://app.notion.com/p/3e586efecd9d804ea459e6283e9c9868).

Duronga DEBE tener una tanda principal, referencias fijas, casilleros y cupo reponible
positivo derivados del reparto, sin cambiar su identidad, caja ni unidad física utilizable.
DEBE poder sacarse de su caja, devolverse, examinarse, reponerse y venderse. Su caja DEBE abrir
con las unidades por caja de BR-STK-004; las vendibles y faltantes DEBEN respetar BR-STK-018
y BR-STK-027, como para los demás productos exhibidos.

Las consultas indexadas DEBEN conservar las 32 identidades vigentes. Cada una DEBE tener
una sola tanda principal y sus referencias en el sector declarado. Un producto exhibible
sin tanda o con dos principales, y una marca desconocida sin sector, NO DEBEN aceptarse.
La capacidad de representar un futuro producto declarado sólo-depósito DEBE distinguirse
de esta exhibición: en ese caso sus listas pueden estar vacías y su cupo ser cero, sin
índices negativos ni elegibilidad por tener sólo una guía. Duronga NO DEBE usar ese estado
mientras conserve su exhibición provisional.

### BR-STK-040 — La segunda apertura comparte los pedidos construidos

CUANDO se calculan faltantes de reposición para el padrón definido de jornada 2, el sistema
DEBE recibir los mismos pedidos ya construidos que recibe atención (BR-CTR-038). Consultar
faltantes, en cualquier orden con atención, NO DEBE reconstruir la lista ni crear otro pedido. El
conjunto DEBE pertenecer a esa apertura y no heredar pedidos mutables de otra jornada.

### BR-STK-041 — Las compras físicas de la segunda noche conservan identidades

CUANDO se completa una compra de jornada 2 con productos y ticket exactos, el sistema DEBE
retirar sus unidades registradas afuera una sola vez por identidad y contarlas como vendidas,
sin descontar además el pedido completo. Una recepción parcial NO DEBE sumar ventas. SI vence
sin completarse, ENTONCES las unidades recibidas DEBEN seguir registradas afuera y quedar
recogibles en el piso interior del local frente a la ventanilla; depósito, caja y góndola DEBEN
conservarse como antes del vencimiento. El ticket aceptado DEBE descartarse. Esas unidades
DEBEN poder colocarse, devolverse o recogerse como cualquier unidad suelta. Vender una unidad
retirada de góndola NO DEBE rellenar su casillero ni cumplir reposición.

### BR-STK-042 — Registrar la segunda noche espera al cierre de ambas compras

EN jornada 2 con el padrón definido, MIENTRAS quede un comprador sin llegar o una compra en
curso, el sistema DEBE mantener registrar pendiente aunque la planilla coincida con lo vendido
o anticipe todos los pedidos. CUANDO ambas compras terminan, vendidas o vencidas, el sistema
DEBE cumplir registrar si para cada producto lo anotado coincide exactamente con las ventas
completas. Una compra vencida NO DEBE impedirlo. El vencimiento DEBE revisar registrar, como
la venta y cada modificación de planilla. Al cierre, dos compras vencidas con planilla en cero
DEBEN contar registrar cumplida; una unidad de más o de menos DEBE dejarla pendiente.

### BR-STK-045 — El pedido fijo admite el depósito y distingue Poético

CUANDO se prepara la compra de Fede, el sistema DEBE permitir obtener y entregar Duronga desde
el depósito, con la exhibición y cupo positivo de la etapa (BR-STK-047 hasta la última jornada de
prueba), sin exigir colocarla antes en la góndola. Progres DEBE usar la identidad del producto existente que su subtítulo denomina así,
sin crear otra fila de catálogo. Poético DEBE ser la unidad vendible del pedido, distinta del
bidón azul de limpieza; entregar el bidón NO DEBE satisfacerla. Usar previamente esa unidad para
teñir un balde NO DEBE impedir su venta ni descontarla dos veces. Atención y
reposición DEBEN consumir los mismos pedidos fijos de la única lista construida al abrir jornada 2.

### BR-STK-046 — El catálogo presente depende de la etapa

HASTA la jornada anterior a la primera completa, el sistema DEBE tener únicamente los
dieciséis productos del mapa de prueba. Sus identidades son Actroncito, Duronga, Arvecor,
Marolini, Zucarachas, Malbardo, Progres, Jorgillo, Pepito, Pura-Cola, Don Saturados, Petisas,
Mayonchis, Poético, Terminator y Fernet God, con sus nombres de catálogo vigentes.

Los otros productos NO DEBEN tener unidades en góndola o depósito, cajas visibles, cuerpos
físicos ni objetivos de interacción. Los faltantes y pedidos de compradores DEBEN limitarse
a productos presentes. Los cupos DEBEN medirse en el reparto de esa etapa.

DESDE la primera jornada completa, el sistema DEBE recuperar los treinta y dos productos
y su reparto completo, también al retomar desde el menú. Cambiar de etapa dentro del mismo
local NO DEBE conservar cupos, dibujos, objetivos ni unidades sueltas de la etapa anterior.

### BR-STK-047 — Las jornadas de prueba ocupan los cuatro niveles

EN las jornadas de prueba, el sistema DEBE ocupar los cuatro niveles de cada cara con
los mismos productos del mapa de prueba. Cada lado largo DEBE conservar dos mitades
longitudinales, repetidas en cada nivel, sin estantes vacíos:

| Destino del mapa de prueba | Productos |
|---|---|
| Lado de almacén de la primera isla | Arvecor y Marolini |
| Lado opuesto de esa isla | Terminator y Zucarachas |
| Cabecera de bebidas de esa isla | Fernet God |
| Cabecera opuesta de esa isla | Malbardo |
| Lado de dulces de la segunda isla | Pepito y Petisas |
| Lado de salados de la segunda isla | Progres y Don Saturados |
| Cabecera que conserva Jorgillo en el mapa completo | Jorgillo |
| Cabecera opuesta de la segunda isla | Poético |
| Estantería de no comestibles | Actroncito en la mitad izquierda y Duronga en la derecha |
| Primera heladera funcional | Pura-Cola |
| Segunda heladera funcional | Mayonchis |

Cada producto DEBE conservar una sola tanda principal a altura de reposición. Las
repeticiones de los demás niveles, incluido el otro nivel central, DEBEN ser tandas fijas
con frontales que se agarran y reponen. Las filas posteriores, orientaciones, apoyos,
separación de unidades y tamaño de muebles DEBEN conservar las reglas vigentes. El cambio
a la etapa completa DEBE restituir los sectores de BR-STK-043 y BR-STK-044.

### BR-STK-048 — La prueba conserva los márgenes de la etapa completa

EN las jornadas de prueba, el sistema DEBE conservar el margen de los productos contra
el borde de cada estante de la etapa completa y la separación uniforme de referencia de
cada envase. SI las columnas calculadas inicialmente no entran con ese ritmo, los márgenes
y el aire entre caras, ENTONCES DEBE quitar columnas hasta obtener la mayor cantidad que
entre en la cara, conservando las dos regiones longitudinales cuando haya dos productos.
NO DEBE comprimir ni estirar las separaciones para conservar un cupo anterior. El sobrante
DEBE repartirse a ambos lados de cada tanda, sin pegarla a la división longitudinal.
Los cupos principales y totales DEBEN medirse del reparto resultante. Se conservan las filas,
orientaciones, apoyos, destinos y la principal a altura de reposición de BR-STK-047.

### BR-STK-049 — El aire protege las unidades, las caras y la división longitudinal

EN las jornadas de prueba, el sistema DEBE reservar el mínimo de separación de exhibición
entre unidades vecinas, el mínimo de aire entre caras contiguas y el mínimo de aire entre
las dos tandas de un lateral. En cada encuentro de cabecera y lateral, el aire DEBE ser al
menos la mayor separación de referencia de los productos contiguos y nunca menor que el
mínimo entre caras del dominio. La división longitudinal NO DEBE convertirse en un borde
contra el que se amontonen ambas tandas. Los centros de ambas tandas DEBEN permanecer en mitades
opuestas, con el ritmo de su producto en la etapa completa. Un bloque puede aprovechar la
holgura del otro, como en la etapa completa, antes de quitar otra columna.

En un estante de prueba con dos productos, cada producto DEBE conservar su separación
interna de referencia. El encuentro DEBE dejar la mayor separación de referencia de sus
dos productos, nunca menor que el mínimo de aire entre las dos tandas.
El sobrante DEBE repartirse a partes iguales entre los dos bordes del estante, sin agrandar
el encuentro entre los productos ni el encuentro entre caras. Terminator DEBE tomar la
separación de Zucarachas, el otro producto de su estante, en lugar de la suya de referencia,
y con ese paso expone una columna menos que con la propia.

Las cabeceras DEBEN conservar el margen lateral de exhibición a ambos costados de la chapa,
además del retiro frontal de referencia de BR-STK-048. Sus filas DEBEN conservar el aire de
referencia cuando quepa y nunca bajar del mínimo de aire entre filas de exhibición.
Los mínimos de exhibición son valores del dominio. Ninguna adaptación DEBE poner unidades
fuera del apoyo, superponerlas ni cambiar filas, orientaciones, destinos o la altura de
reposición. SI ni una columna satisface simultáneamente esos mínimos en su región,
ENTONCES el sistema DEBE rechazar el reparto, en vez de publicarlo comprimido.

### BR-STK-050 — Las compras de las jornadas 3 a 5 conservan recepción, venta y registro

CUANDO se abre una jornada de la 3 a la 5, el sistema DEBE calcular los faltantes de reposición
con los mismos pedidos ya construidos que recibe atención (BR-CTR-047). Consultar faltantes, en
cualquier orden con atención, NO DEBE reconstruir la lista ni sortear otro pedido, y cada pedido
sumado a lo que le falta a su fila DEBE respetar BR-STK-027, incluidas las repeticiones de un
producto entre los dos compradores.

CUANDO se completa una compra de esas jornadas con productos y ticket exactos, el sistema DEBE
retirar sus unidades registradas afuera una sola vez por identidad y contarlas como vendidas, sin
descontar además el pedido completo. Una recepción parcial NO DEBE sumar ventas. SI vence sin
completarse, ENTONCES las unidades recibidas DEBEN seguir registradas afuera y quedar recogibles en
el piso interior del local frente a la ventanilla, con depósito, caja y góndola como antes del
vencimiento, y el ticket aceptado DEBE descartarse (BR-STK-041).

MIENTRAS quede un comprador sin llegar o una compra en curso, registrar DEBE seguir pendiente
aunque la planilla coincida con lo vendido o anticipe los pedidos. CUANDO ambas compras terminan,
vendidas o vencidas, DEBE cumplirse si para cada producto lo anotado coincide exactamente con las
ventas completas. Una compra vencida NO DEBE impedirlo, y el vencimiento DEBE revisar registrar
como la venta y cada modificación de planilla (BR-STK-042).

### BR-STK-051 — Cada caja amanece donde quedó, o en un lugar libre de las estanterías

CUANDO cierra una jornada, el sistema DEBE tomar la pose de cada caja y guardarla con la
partida por identidad de caja (BR-SAV-022). Una caja cuenta como **en estantería** si cumple la
condición de apoyo de BR-STK-039: suelta, y con su cadena de apoyos terminando en un pallet de
las tres estanterías. Una caja en la mano, en el piso, en el local, sobre el pallet del piso o
sobre una caja que no está en estantería cuenta como **fuera de las estanterías**.

CUANDO abre una jornada que no apila (BR-STK-038), una caja que cerró en estantería DEBE
abrir en esa misma pose, aunque esté apoyada sobre otra caja que está en estantería. Una caja
que cerró fuera de las estanterías DEBE abrir en un hueco libre de las estanterías, donde entre
sin superponerse con otra caja. SI ningún hueco libre la admite, ENTONCES DEBE abrir apoyada
sobre otra caja que está en estantería. En los dos casos DEBE quedar sin superposición de
cuerpos, con cada caja enfocable desde un punto libre del piso dentro del alcance vigente, y
sin desplazarse más de 1 cm en los primeros 120 cuadros de física sin intervención del jugador.

SI la partida no guarda la pose de una caja, o la guardada no es una pose, ENTONCES esa caja
DEBE abrir en su lugar de fábrica. Toda caja presente DEBE abrir llena (BR-STK-004).

### BR-STK-052 — Siete zonas de reposición cubren los productos de sus muebles

El sistema DEBE dividir el piso del local en las siete zonas del mapa de la ficha. Cada zona
cubre los productos cuya tanda principal está en alguno de sus muebles:

| Zona | Muebles que cubre |
|---|---|
| 1 | las dos heladeras funcionales, la heladera fuera de servicio y la cabecera norte de la primera isla |
| 2 | la estantería de no comestibles y la cabecera norte de la segunda isla |
| 3 | el lado oeste de la primera isla |
| 4 | el lado este de la primera isla y el lado oeste de la segunda |
| 5 | el lado este de la segunda isla |
| 6 | la cabecera sur de la primera isla |
| 7 | la cabecera sur de la segunda isla |

Cada producto presente DEBE pertenecer a exactamente una zona, en la etapa de prueba y en la
completa. La heladera fuera de servicio no cubre ningún producto. Las tandas fijas NO DEBEN
asignarle a una zona un producto cuya tanda principal está en otra.

Una zona DEBE ser **zona con faltante** CUANDO algún producto que cubre es faltante según
BR-STK-007, y dejar de serlo CUANDO ya no lo es, también si un casillero se vacía durante la
noche. La zona contesta contra el estado actual del inventario, sin guardar una bandera propia.
Una jornada que no declara reponer NO DEBE tener ninguna zona con faltante (BR-STK-026).

Cada punto del piso DEBE pertenecer a una sola zona, o a ninguna. Un punto del límite entre dos
zonas DEBE pertenecer siempre a la misma de las dos, sin cambiar de una consulta a otra. Un punto
fuera de las siete zonas, como el depósito, NO DEBE pertenecer a ninguna. El reparto de las
zonas y sus muebles NO DEBE cambiar el cupo, la tanda principal ni la exhibición de ningún
producto.

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
jornada que se abre ENTONCES cada producto presente esa jornada tiene 8 en el depósito.

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

### AC-STK-017 — La caja se vacía con la fila completa *(verifica BR-STK-017)*

DADO un producto de 8 casilleros con la fila de adelante completa y su caja en 8 CUANDO se le
piden unidades a la caja, de a una, ENTONCES salen 8, la caja pasa de 8 a 0 y la novena no sale.
CUANDO se coloca una de las que salieron ENTONCES se rechaza por estante lleno y sigue afuera.
CUANDO se devuelven las 8 ENTONCES la caja vuelve a 8.

### AC-STK-018 — Los vendibles *(verifica BR-STK-018)*

DADO un producto de 8 casilleros, con esas unidades en la góndola, en el depósito y afuera,
CUANDO se piden sus vendibles ENTONCES:

| Góndola | Depósito | Afuera | Vendibles |
|---|---|---|---|
| 8 | 2 | 0 | 2 |
| 0 | 10 | 0 | 2 |
| 7 | 3 | 0 | 2 |
| 8 | 0 | 0 | 0 |
| 0 | 5 | 0 | 0 |
| 8 | 8 | 0 | 8 |
| 8 | 8 | 3 | 5 |
| 5 | 8 | 1 | 5 |
| 5 | 8 | 4 | 4 |
| 0 | 8 | 8 | 0 |
| 8 | 8 | 8 | 0 |

Y un producto que el inventario no conoce contesta 0.

### AC-STK-020 — Una fila por producto, en cero *(verifica BR-STK-019)*

DADO una jornada que se abre CUANDO se mira la planilla ENTONCES tiene una fila por producto del
catálogo presente esa noche, en su orden, y cada una en 0.

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

### AC-STK-024 — Registrar arranca sin cumplir y sigue a la planilla *(verifica BR-STK-022)*

DADO una jornada que se abre ENTONCES registrar arranca sin cumplir. DADO una noche
que cobró 2 unidades de un producto y 1 de otro CUANDO se anotan esas 3 unidades ENTONCES
registrar se cumple con el último gesto, y no antes.
En las jornadas 1 a 5 se exige además que ambas compras hayan terminado, vendidas o vencidas
(AC-STK-056).

### AC-STK-025 — Una venta o una unidad de más la deshacen *(verifica BR-STK-022)*

DADO registrar cumplida CUANDO se cobra una venta nueva ENTONCES se descumple, y anotar esa
venta la vuelve a cumplir. DADO registrar cumplida CUANDO se aprieta «+» en cualquier fila
ENTONCES se descumple, y un «−» en esa fila la vuelve a cumplir.

### AC-STK-026 — Lo anotado no pasa a la noche siguiente *(verifica BR-STK-019, BR-STK-022)*

DADO una jornada con 3 unidades anotadas CUANDO se abre la jornada siguiente ENTONCES todas las
filas están en 0 y registrar está sin cumplir.

### AC-STK-027 — Ningún producto queda sin sonoridad *(verifica BR-STK-023)*

DADO cada producto del catálogo ENTONCES tiene una sonoridad. Las arvejas, la Coracola y las
Prongles suenan a lata.

### AC-STK-028 — Cada producto se repone en un solo lugar *(verifica BR-STK-024)*

DADO el local armado ENTONCES cada producto con exhibición declarada tiene una sola tanda reponible, sobre un
solo estante y con sus unidades juntas, y la fila de adelante de cada tanda fija suya también es
de casilleros: el cupo del producto los suma a todos. DADO una cara de lado ENTONCES sus tandas con casilleros están en los
estantes que no son ni el de arriba ni el zócalo, y esos estantes no llevan ninguna tanda fija; el
de arriba y el zócalo llevan sólo tandas fijas. DADO una cabecera ENTONCES los niveles 0 y 3
llevan sólo tandas fijas y los niveles 1 y 2 sólo tandas reponibles, como en el modelo original
del reparto completo. Las jornadas de prueba conservan la excepción de BR-STK-047.

### AC-STK-029 — El casillero está al alcance *(verifica BR-STK-024)*

DADO cualquier producto exhibido en la mano CUANDO el jugador se para en el pasillo frente a
su tanda ENTONCES la mira alcanza su casillero y el producto se coloca.

### AC-STK-030 — Filas por tanda y casilleros adelante *(verifica BR-STK-025)*

DADO cada tanda principal y fija del local ENTONCES sus filas coinciden con esta tabla:

| Producto | Principal | Fijas |
|---|---|---|
| Cosa de Maní, Flin Puf, Burbaloo, Marranos y Poético | 1 | 1 |
| Actroncito, Prongles y los demás productos exhibidos | 2 | 2 |

La fila de adelante es la más cercana al pasillo y cada lugar suyo es un casillero del
producto. Los casilleros totales y los que usan la apertura y el sorteo suman los frontales de
su principal y sus fijas. Un producto sin casilleros en ninguna tanda NO DEBE volverse elegible.
Las filas delanteras fijas conservan su interacción de BR-STK-024. La fila de
atrás, cuando existe, no tiene casilleros: una copia posterior no agrega ninguno.

### AC-STK-031 — La fila de atrás de cada tanda permanece entera *(verifica BR-STK-025)*

DADO una jornada que se abre ENTONCES cada tanda de dos filas muestra entera su fila de
atrás y su fila delantera completa salvo los faltantes declarados. CUANDO se agarra o repone
una unidad de delante ENTONCES sólo cambia ese casillero y la fila de atrás no cambió ni se
puede agarrar. DADO una tanda de una fila ENTONCES no tiene unidades detrás de sus
casilleros; al vaciar todos sus casilleros no queda ninguna unidad de esa tanda.

DADO Actroncito y Prongles ENTONCES sus tandas principales y fijas conservan ambas filas.

### AC-STK-032 — Una caja entera alcanza para el faltante más grande *(verifica BR-STK-004)*

DADO un producto de 12 casilleros al que la jornada le hace faltar 8 CUANDO se colocan las 8
unidades de su caja ENTONCES su fila de adelante queda completa, el depósito en 0 y no es
faltante.

### AC-STK-033 — Ningún faltante pasa de una caja ni de sus casilleros *(verifica BR-STK-004, BR-STK-024, BR-STK-026)*

DADO las 200 semillas enteras de 0 a 199, los pedidos de cada jornada de la 2 a la 8 y los casilleros
medidos en el local CUANDO se abren las jornadas ENTONCES ningún faltante pasa de las unidades
de una caja menos lo pedido —8 menos lo pedido en el balance vigente— ni de los casilleros de la
fila de adelante de todas las tandas de su producto. El inventario conserva el cupo total de
todas las tandas. DADO productos de cuatro tandas de tres casilleros, o de dos tandas de cuatro,
CUANDO se sortean sus vacíos con las 200 semillas ENTONCES hay vacíos en cada tanda de al menos
un producto. DADO un producto de una sola fila ENTONCES ninguna de sus tandas abre con su fila de
adelante entera vacía. DADO cualquier producto CUANDO se sortean sus vacíos con las 200 semillas
ENTONCES en cada tanda los casilleros vacíos son seguidos, sin un casillero ocupado entre dos
vacíos. Si el faltante entra entero en alguna tanda, todos caen en una sola, aunque otra tanda no
lo reciba entero: con dos tandas de una fila de cinco y cuatro casilleros y un faltante de cuatro,
siempre caen en la de cinco. Sólo si no entra en ninguna se parte. DADO un producto de dos filas
con cuatro tandas de tres casilleros en estantes contiguos CUANDO su faltante se parte con las 200
semillas ENTONCES las tandas con vacíos son contiguas, todas quedan vacías enteras salvo una, y esa
tanda parcial está debajo de las vacías; está arriba sólo si las vacías llegan al estante de más
abajo. DADO un producto de tres tandas con las mismas columnas, en estantes a 0,5, 1 y 2,5 m de
altura, CUANDO su faltante se parte con las 200 semillas ENTONCES los dos bloques quedan en estantes
contiguos —nunca el de 0,5 con el de 2,5 m— y las columnas del bloque más corto están entre las del
más largo. DADO un producto de dos filas CUANDO falta toda su fila de adelante ENTONCES puede abrir
con la reponible vacía entera.

### AC-STK-034 — Lo que falta en cada jornada *(verifica BR-STK-026)*

DADO las 200 semillas enteras de 0 a 199, ocho casilleros principales por producto y los pedidos de
cada jornada de la 1 a la 5 CUANDO se sortean sus faltantes ENTONCES cada sorteo contiene entre 4 y
6 productos distintos. Cada faltante está entre 3 y `mínimo(C − P, F)`, y los productos no elegidos
están completos. Para cada jornada, las semillas producen al menos dos cantidades de productos y dos
conjuntos de productos distintos.

DADO una fuente de azar controlada CUANDO se eligen los extremos de los intervalos ENTONCES
se pueden obtener 4 y 6 productos, y 3 y el máximo reponible de cada elegido. La elección de
cantidad tiene tres alternativas equiprobables; la de unidades tiene tantas alternativas
equiprobables como enteros hay entre 3 y su máximo reponible.

DADO una caja de 8 CUANDO un producto tiene 6 casilleros principales y 3 unidades pedidas ENTONCES
su máximo es 5. Con 4 casilleros principales y 1 unidad pedida, el máximo es 4. Con 8 unidades
pedidas o con cero casilleros principales, el producto nunca falta; con un máximo de 2, tampoco,
y con un máximo de 3 es elegible y le faltan exactamente 3. DADO exactamente tres elegibles
CUANDO la cantidad sorteada es 4 o 6 ENTONCES faltan los tres; con uno, sólo ese; con cero, ninguno.
DADO dos compradores que piden 2 y 3 unidades del mismo producto, una caja de 8 y 6 casilleros
principales CUANDO se calcula su máximo reponible ENTONCES es 3, porque se suman ambos pedidos.

DADO dos fuentes con la misma semilla inicial, los mismos pedidos y casilleros CUANDO se
abre la misma jornada ENTONCES los faltantes coinciden. Consultar los pedidos conserva las
identidades y cantidades recibidas y no consume azar. CUANDO se abre otra jornada, se vuelve
al menú y se continúa, o se retoma en otra sesión ENTONCES se realiza un nuevo sorteo.

### AC-STK-035 — Se vende sin quitarle a la reposición *(verifica BR-STK-027)*

DADO las 200 semillas enteras de 0 a 199, los casilleros del local y cada jornada de la 1 a la 5 CUANDO
se completan todas las compras de los pedidos usados para acotar los faltantes, por el
recorrido de esa jornada, ENTONCES ningún cobro se rechaza. CUANDO después se repone todo lo
que falta ENTONCES la góndola queda completa y reponer queda cumplida.
En el recorrido físico, el resultado se conserva tanto tomando las unidades vendidas de sus
cajas como de casilleros ocupados: también se reponen los casilleros vaciados por esas ventas.

### AC-STK-036 — La caja arranca en 8 y cuenta lo que sale *(verifica BR-STK-028)*

DADO una jornada que se abre ENTONCES la caja de cada producto presente esa jornada tiene 8. DADO una
caja en 8 CUANDO se saca una unidad ENTONCES tiene 7; CUANDO esa unidad se coloca ENTONCES sigue
en 7; CUANDO se cobra una unidad de su producto ENTONCES tiene 6, igual que su depósito.

### AC-STK-037 — Cada noche las cajas vuelven a 8 *(verifica BR-STK-028)*

DADO una jornada que termina con una caja en 0, otra con una unidad suya en la mano y otra con
una unidad devuelta CUANDO se abre la jornada siguiente ENTONCES todas las cajas tienen 8, y
ninguna unidad quedó afuera de su caja.

### AC-STK-038 — Un gesto saca y el otro devuelve *(verifica BR-STK-029, BR-STK-030, BR-STK-016)*

DADO una caja de Actroncito apoyada con contenido CUANDO se hace secundario con mano vacía
ENTONCES sale una sola unidad. CUANDO se hace secundario con esa unidad, con Malbardo, otra
caja o cualquier objeto ENTONCES la mano y la caja no cambian. DADO la unidad de Actroncito
CUANDO se hace primario sobre su caja ENTONCES se devuelve una vez. Con caja llena o identidad
ya devuelta, el intento coincidente conserva mano y contenido, sin duplicado ni soltado.
DADO mano vacía CUANDO se hace primario ENTONCES se agarra la caja sin extraer una unidad;
con cero contenido, el secundario no extrae.

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

DADO una caja con tope de 8 CUANDO se la examina ENTONCES se conservan los datos siguientes,
independientemente de la redacción usada para presentarlos:

| Producto | En la caja | Lugares libres |
|---|---|---|
| Actroncito | 8 | 0 |
| Malbardo | 5 | 3 |
| Actroncito | 7 | 1 |
| Actroncito | 1 | 7 |
| Actroncito | 0 | 8 |
| Laysntt | 8 | 0 |
| Coracola | 1 | 7 |
| Terminator | 6 | 2 |
| Fernet God | 1 | 7 |

DADO cada producto del catálogo ENTONCES su familia sonora tiene su palabra, en singular y en
plural.

### AC-STK-042 — El texto dura lo que dura el examen en la mano *(verifica BR-STK-031)*

DADO una caja en la mano CUANDO se la examina ENTONCES se lee su texto y no su pista. CUANDO
termina el examen ENTONCES el texto desaparece y la caja tiene lo mismo que antes.
DADO la caja apoyada con 5 de Malbardo y las manos vacías CUANDO se pide examinar ENTONCES no
hay examen, la línea presenta Malbardo con 5 unidades y 3 lugares libres,
y la caja sigue apoyada con 5.

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

### AC-STK-049 — La venta no se lleva lo que está afuera *(verifica BR-STK-018, BR-STK-030)*

DADO un producto de 8 casilleros con la fila de adelante completa, su caja en 8 y 3 unidades
sacadas de ella CUANDO se cobra una venta de 6 ENTONCES se rechaza, y ni el depósito ni la caja
cambian. CUANDO se cobra una de 5 ENTONCES se cobra y la caja queda en 0. CUANDO se devuelven
las 3 ENTONCES la caja tiene 3.

### AC-STK-050 — Lo que está a la altura de la mano se agarra *(verifica BR-STK-024, BR-STK-033)*

DADO cada producto exhibido, Arvejas y Coracola incluidas, con una unidad colocada en su
fila de adelante y las manos vacías CUANDO el jugador se para en el pasillo frente a su tanda
ENTONCES la mira enfoca esa unidad y el clic se la pone en la mano. DADO cualquier unidad que se
ve en un estante de reposición del reparto completo ENTONCES es de la fila de adelante de
una tanda reponible, o de su fila de atrás: ninguna es de una tanda fija. En las jornadas
de prueba, los frontales de las repeticiones permitidas por BR-STK-047 se agarran y reponen igual.

### AC-STK-051 — Mitad y mitad, o el estante entero *(verifica BR-STK-035)*

DADO cada estante de reposición de una cara de lado ENTONCES lleva dos productos o uno. DADO uno
con dos productos ENTONCES el largo que ocupa cada uno difiere del otro en menos de lo que ocupa
la unidad más ancha de ese estante. DADO uno con un solo producto ENTONCES ese producto lo ocupa
de punta a punta. DADO los dos muebles de estantes del medio del local ENTONCES miden lo mismo de
ancho, con 1 centímetro de tolerancia. DADO cada cara de lado ENTONCES el borde del estante
inferior no está más hacia el pasillo que el frente de los estantes superiores.

### AC-STK-052 — El cierre cuenta la planilla de ese instante *(verifica BR-STK-022)*

DADO una noche posterior a la quinta sin ventas y sin gestos en la planilla CUANDO cierra
ENTONCES registrar cuenta como cumplida. Antes del cierre, una planilla en cero sin ventas NO completa la tarea ni suma
una tarea al contador. DADO una noche con la planilla igual a lo vendido CUANDO se cobra una venta más
y la noche cierra sin anotarla ENTONCES registrar no cuenta.

### AC-STK-053 — Tirar conserva caja y góndola *(verifica BR-STK-036)*

DADO una caja de Actroncito en 8 y una unidad suya agarrada de un casillero CUANDO se tira
ENTONCES la caja sigue en 8, el depósito tiene una menos, el casillero sigue vacío, reponer no
se cumple y la unidad ya no está afuera ni se puede colocar o devolver. DADO una unidad
sacada de su caja CUANDO se tira ENTONCES la caja conserva su contenido anterior al tiro.
DADO una unidad no registrada afuera CUANDO se intenta desechar ENTONCES devuelve false y
no cambia el inventario.

### AC-STK-054 — Salida definitiva sin doble descuento *(verifica BR-STK-037, BR-STK-028)*

DADO una caja con ocho unidades CUANDO se retira una y completa su compra física ENTONCES
la caja conserva siete, el depósito baja una y esa identidad ya no está afuera.
Repetir la venta o intentar registrar esa identidad afuera no cambia cantidades.

### AC-STK-055 — Salida y reposición *(verifica BR-STK-037, BR-STK-033, BR-STK-030)*

DADO una unidad retirada de góndola CUANDO se entrega en una compra parcial y ésta vence
ENTONCES sigue registrada afuera con la misma identidad, sin cambiar el depósito, la caja
ni la góndola y sin sumar una venta. CUANDO se recupera y coloca en un casillero vacío de su
producto ENTONCES ocupa ese casillero y deja de estar afuera; devolverla a su caja con espacio
suma una al contenido y también deja de estar afuera. Una caja llena la rechaza y conserva
la unidad en la mano y registrada afuera.
DADO esa unidad en una compra completa ENTONCES el casillero sigue vacío y reponer incompleta
hasta rellenarlo. La planilla cuenta sólo compras completas, nunca entregas parciales.

### AC-STK-056 — Registro espera al cierre de ambas compras *(verifica BR-STK-022)*

DADO cada jornada de la 1 a la 4 CUANDO se registra la venta completa de Tin pero Tia aún no
compró ENTONCES registrar sigue pendiente. DADO todos los pedidos anotados anticipadamente
ENTONCES registrar sigue pendiente mientras alguna compra siga abierta.
CUANDO ambas ventas se completan y sus unidades están exactamente anotadas ENTONCES registrar
se cumple. Una unidad de más o de menos la descumple.

DADO Tin vendido y anotado —un Marolini, una Coracola y un Malbardo; los demás productos en cero—
y Tia con una Zucarachas recibida, pero sin Pepito ni ticket, CUANDO vence Tia ENTONCES registrar
se cumple en ese vencimiento y cuenta al cierre, aunque atención siga pendiente. La Zucarachas
no suma una venta ni se anota. CUANDO se suma una Zucarachas en la planilla ENTONCES registrar
se descumple; restarla vuelve a cumplirla. DADO la segunda compra ya anotada anticipadamente
CUANDO vence sin venderse ENTONCES registrar sigue pendiente hasta quitar esas unidades.

DADO ambas compras vencidas y todas las filas en cero CUANDO todavía no cerró la jornada
ENTONCES registrar sigue pendiente. CUANDO cierra ENTONCES cuenta como cumplida, mientras
atención sigue pendiente. Con una unidad anotada de cualquier producto no cuenta como cumplida.

### AC-STK-077 — La pila es completa, alcanzable y estable *(verifica BR-STK-038)*

DADO la jornada 4 abierta con las cajas presentes cerradas en sus lugares de fábrica en la 3
CUANDO se recorren las cajas de los productos ausentes en J1 a J3
ENTONCES son exactamente dieciséis, están apiladas dentro del depósito y ninguna se apoya en
una estantería. Las otras dieciséis están en sus lugares de estantería. Ningún cuerpo se
superpone con otro. Para cada caja de la pila existe un punto libre del piso desde el cual la
mira la enfoca dentro del alcance vigente. CUANDO pasan 120 cuadros de física sin tocar la pila
ENTONCES ninguna caja se desplazó más de 0,01 m desde su pose inicial. DADO la jornada 5 abierta
después, con las treinta y dos cajas cerradas apoyadas en pallets de estantería ENTONCES cada
caja abre apoyada en el mismo pallet, en la pose con que cerró la 4.

### AC-STK-078 — Los apoyos deciden ordenar *(verifica BR-STK-039)*

DADO el conjunto de cajas CUANDO se evalúa su orden ENTONCES:

| Estado | Ordenar |
|---|---|
| Todas sobre pallets de estantería | cumplida |
| Todas sobre estanterías salvo una en el piso | pendiente |
| Una sobre otra apoyada en estantería; el resto, en estanterías | cumplida |
| Una sobre otra que está en el piso | pendiente |
| Todas en estanterías salvo una sostenida, incluso examinada desde la mano | pendiente |
| La misma caja soltada en el piso | pendiente |
| Una sobre el pallet del piso | pendiente |
| Dos que se declaran apoyadas una sobre otra | pendiente |
| Una cuyo apoyo es una caja que no está en el conjunto | pendiente |
| Una cuyo apoyo es una caja sostenida; el resto, en estanterías | pendiente |
| Ninguna caja | cumplida |

### AC-STK-079 — La última caja cumple y puede descumplir *(verifica BR-STK-039)*

DADO la jornada 4 y todas las cajas salvo una ordenadas CUANDO se apoya la última en una
estantería ENTONCES ordenar se cumple y el HUD sube en 1. CUANDO se baja una caja al piso y queda
en reposo ENTONCES se descumple y el HUD baja en 1. CUANDO se la sostiene o se la examina desde
la mano ENTONCES sigue pendiente. CUANDO se la suelta sobre una estantería ENTONCES vuelve a
cumplirse. CUANDO se levanta una caja de la estantería ENTONCES vuelve a quedar pendiente.
DADO el turno cerrado CUANDO se mueve esa caja ENTONCES la
cuenta permanece como al cierre. DADO una jornada que no declara ordenar CUANDO todas quedan
en estanterías ENTONCES no se suma una obligatoria ajena.

### AC-STK-080 — Rescatar vuelve al origen de esa noche *(verifica BR-STK-038, BR-STK-039)*

DADO una caja recién incorporada y rescatada en la jornada 4 CUANDO vuelve a su origen
ENTONCES queda en la pose de la pila de esa apertura, sin ordenarse automáticamente.
DADO una caja que ya estaba presente en las jornadas de prueba CUANDO se rescata en J4
ENTONCES vuelve a la pose con que abrió la jornada 4. DADO la apertura de una jornada
posterior ENTONCES el origen de cada caja es la pose con que abrió esa jornada (BR-STK-051).

### AC-STK-086 — Cada sector contiene exactamente sus productos *(verifica BR-STK-043, BR-STK-044)*

DADO el local armado desde la primera jornada completa CUANDO se recorre cada destino
de la tabla de BR-STK-043 ENTONCES sus
productos coinciden con la fila, sin ajenos, y los destinos de exhibición reúnen 32 productos
distintos. La principal de Duronga comparte la mitad inferior de la estantería con Poético,
a su derecha; las de Actroncito y Durextra están arriba. Las referencias fijas están en su mismo
sector. Abrir jornada 5 en escritorio y web conserva el mapa.

### AC-STK-087 — Dos heladeras separan los fríos de las bebidas sin refrigerar *(verifica BR-STK-043)*

DADO ambas heladeras funcionales desde la primera jornada completa CUANDO se recorren
sus mitades verticales ENTONCES la primera
exhibe Coracola arriba y Oaaaa abajo; la segunda, Cindolor arriba y Mayonchis abajo.
Fernet God y Terminator están en su cabecera de bebidas sin refrigerar, y no en ninguna heladera;
Cindolor no aparece además en un estante exterior. La heladera fuera de servicio tiene cero
unidades y referencias de productos.

### AC-STK-088 — Duronga exhibida conserva caja y unidad utilizables *(verifica BR-STK-044, BR-STK-018, BR-STK-028, BR-STK-030)*

DADO apertura con Duronga en su exhibición provisional CUANDO se consulta ENTONCES tiene
principal, referencias y casilleros con cupo reponible positivo; la caja tiene las unidades
por caja y las vendibles respetan la reserva por faltantes de BR-STK-018.
CUANDO se saca una unidad ENTONCES la caja tiene una menos, la unidad se puede examinar y
devolver una sola vez; devolverla restaura el contenido. CUANDO se saca y vende una unidad
ENTONCES se conserva su cuerpo y producto hasta la venta y se retira una sola vez, sin
fabricar otra unidad ni alterar los casilleros declarados. DADO caja vacía ENTONCES no
entrega ni vende otra unidad.

### AC-STK-089 — Reponer y cerrar incluyen Duronga exhibible *(verifica BR-STK-044, BR-STK-013, BR-STK-027)*

DADO jornada 5 con pedidos y faltantes que respetan BR-STK-027 CUANDO se consulta el cupo de
las 32 identidades ENTONCES Duronga devuelve su cupo principal positivo sin error ni índice
ajeno y puede aportar faltantes según la regla vigente. Los cupos totales suman frontales
principales y fijas; los reponibles del sorteo suman sólo frontales principales. Un producto
con principal cero no es elegible aunque tenga guía. CUANDO se completan las compras y se
llenan todos los casilleros declarados, incluidos los de Duronga, ENTONCES reponer se cumple
y el cierre conserva su cumplimiento sin rechazar una venta válida de ese producto.

### AC-STK-085 — El nuevo reparto conserva alcance y unicidad *(verifica BR-STK-043, BR-STK-044, BR-STK-024, BR-STK-025, BR-STK-035)*

DADO los 32 productos exhibidos CUANDO se enfoca cada casillero reponible desde piso libre
del pasillo ENTONCES entra en el alcance vigente y acepta su unidad. Cada producto tiene una
sola tanda principal; ninguna referencia queda en el sector anterior. Los muebles conservan
tamaño y alturas, los estantes útiles sus tandas reponibles y cada envase su orientación y
separación de filas. Una identidad exhibible sin tanda o con dos principales, y una identidad
desconocida sin sector, hacen rechazar el reparto en lugar de asignar un destino por defecto.

### AC-STK-081 — Reposición y atención comparten los pedidos fijos *(verifica BR-STK-040)*

DADO una apertura de jornada 2 con los pedidos de Fede y Mía construidos CUANDO se consultan
faltantes antes y después de construir atención, y se repiten ambas consultas ENTONCES se usan
las mismas instancias de compradores y pedidos, con los seis productos fijos de BR-CTR-038,
sin reconstrucción ni azar. Otra apertura crea estados propios sin heredar entregas.

### AC-STK-082 — Vencer devuelve productos al piso interior sin venta *(verifica BR-STK-041)*

DADO jornada 2 y una compra parcial con dos unidades recibidas, una de caja y otra de góndola,
CUANDO vence ENTONCES ambas identidades siguen afuera, los cuerpos quedan visibles y recogibles
en el piso interior frente a ventanilla, sin superponerse con sólidos ni entre sí, y no suman
venta ni descuento. El ticket aceptado desaparece. Repetir vencimiento no duplica cuerpos.
Colocar o devolver esas unidades conserva los permisos habituales; dejarlas sueltas al cierre
produce desorden, no objeto afuera; sostenerlas sin examen, colocarlas o devolverlas evita ese
desorden. Una apertura posterior las retira como unidades sueltas de la noche anterior.

### AC-STK-083 — Una sola venta, anticipación y vencimiento *(verifica BR-STK-042)*

DADO Fede vendido y correctamente anotado, Mía sin llegar o esperando, CUANDO se evalúa durante
la noche ENTONCES registrar sigue pendiente. Anotar también su pedido por adelantado no la
cumple. CUANDO Mía vence ENTONCES la planilla exacta de sólo lo vendido a Fede cumple registrar,
incluso al cierre; sumar una unidad de Mía la descumple y restarla la vuelve a cumplir. DADO
ambas compras vencidas y planilla cero CUANDO cierra ENTONCES registrar cuenta cumplida aunque
atención no. Si ambas se venden, sólo su suma exacta cumple registrar.

### AC-STK-084 — La venta de jornada 2 no descuenta dos veces *(verifica BR-STK-041)*

DADO Fede con su inicial terminada y cajas con el contenido inicial declarado CUANDO se retiran
una unidad de Poético, una de Progres y una de Duronga y se entregan con ticket exacto ENTONCES
cada caja conserva su contenido inicial menos una, cada depósito pierde sólo su identidad
entregada y lo vendido suma una por cada producto. Repetir recepción o volver a registrarlas
afuera no cambia cantidades. Una unidad vendida desde góndola deja su casillero vacío y
reposición pendiente hasta rellenarlo.

### AC-STK-090 — Duronga del depósito completa el pedido fijo *(verifica BR-STK-045, BR-STK-041, BR-STK-027, BR-STK-044)*

DADO jornada 2, Duronga con la exhibición y cupo positivo de BR-STK-047, contenido inicial en
depósito y faltantes que respetan BR-STK-027 CUANDO se saca una unidad de su caja y se entrega a
Fede junto con Poético, Progres y ticket exacto ENTONCES la compra se completa y lo vendido de
Duronga es una unidad, sin exigir colocarla antes en góndola. El cupo y la reserva de reposición
se conservan según el reparto vigente. Progres corresponde al producto ya existente de ese
subtítulo, sin una fila adicional de catálogo.

### AC-STK-091 — Poético vendible conserva su identidad después de limpiar *(verifica BR-STK-045, BR-STK-041)*

DADO una unidad vendible de Poético retirada de caja CUANDO tiñe un balde y después
se entrega a Fede con los demás productos y ticket ENTONCES se vende esa misma identidad una
sola vez; el teñido no agrega descuento de inventario y la venta no vuelve a retirar el pedido
entero. DADO un intento de recepción que identifica el bidón azul en lugar de Poético CUANDO
se valida ENTONCES se rechaza sin satisfacer Poético ni alterar las cantidades de la compra.

### AC-STK-092 — Dos estantes seguidos repiten sus productos *(verifica BR-STK-043)*

DADO cualquier cara de un mueble ENTONCES el estante de arriba de todo lleva los mismos productos
que el reponible de abajo, y el otro reponible los mismos que el zócalo, en el mismo orden.

### AC-STK-093 — Un producto de una sola fila no abre con una tanda vacía entera *(verifica BR-STK-024)*

DADO un producto de una sola fila con cuatro estantes de cuatro casilleros a distinta altura, y un
faltante de cuatro CUANDO se sortean sus vacíos con las 200 semillas ENTONCES cada estante conserva
al menos una unidad, tres vacíos caen en un estante y el otro en el de justo arriba, o en el de
justo abajo si el de los tres es el de arriba de todo. DADO Poético en la jornada 2 o 3 y Flin Puf
desde la jornada 4, con un faltante igual a los casilleros de un estante, ENTONCES se cumple lo
mismo con sus estantes reales.

DADO un producto de una sola fila con tres estantes de cuatro, uno y cuatro casilleros, y un
faltante de cuatro CUANDO se sortean sus vacíos con las 200 semillas ENTONCES el del medio conserva
su unidad y los vacíos se reparten entre los otros dos, tres en uno y uno en el otro.

### AC-STK-094 — La primera jornada abre completa *(verifica BR-STK-026, BR-STK-013, BR-STK-033)*

DADO la jornada 1 recién abierta, con cualquier semilla, CUANDO se consultan los faltantes
ENTONCES no hay ninguno, cada caja del depósito está llena y reponer no está declarada.
CUANDO se agarra una unidad de la góndola y se vuelve a colocar ENTONCES la cuenta de tareas no cambia.
DADO una venta de una o tres unidades desde góndola CUANDO se completa sin reponer
ENTONCES sus casilleros siguen vacíos, sin descontar tareas.
Con todas las declaradas cumplidas, el cierre no suma apercibimientos ni antecedentes o reproches de reposición.
DADO la jornada 1 sin ventas CUANDO Tin y Tia vencen y cierra la noche
ENTONCES registrar cuenta cumplida con la planilla en cero y atención no, sin tarea de reposición.
CUANDO se retoma la jornada 1 ENTONCES vuelve a abrir completa y sin reponer declarada.
DADO la jornada 2 CUANDO abre ENTONCES declara reponer y sortea faltantes según BR-STK-026,
sin heredar los huecos de ventas de la primera.

### AC-STK-095 — La prueba tiene exactamente su catálogo *(verifica BR-STK-046, BR-STK-004, BR-STK-026)*

DADO cada jornada 1, 2 y 3 CUANDO abre con cualquier semilla de 0 a 199 ENTONCES sólo
registra los dieciséis productos de BR-STK-046, en orden de catálogo, con Duronga presente y
Durextra ausente. Cada caja presente abre llena; cada producto ausente tiene cero unidades y
cero cupo. Los faltantes sólo
incluyen presentes. DADO jornadas 4 y 8 ENTONCES están las treinta y dos identidades.

### AC-STK-096 — Cada nivel de prueba coincide con el mapa *(verifica BR-STK-047, BR-STK-024, BR-STK-025, BR-STK-035)*

DADO una apertura de prueba CUANDO se recorren las cuatro alturas de cada destino de
BR-STK-047 ENTONCES sus productos coinciden con la tabla, sin ajenos ni niveles vacíos; en
la estantería de no comestibles, Duronga ocupa la mitad derecha de los cuatro niveles junto
a Actroncito.
Cada producto tiene una sola principal y los cupos suman todos sus frontales. Cada unidad
se apoya sobre su estante, sin intersecciones, y conserva la orientación y filas de su envase.
CUANDO se agarra y repone una unidad del frontal repetido en el otro nivel central ENTONCES
sólo cambia ese casillero y la cuenta de reponer responde a ambos gestos.

### AC-STK-097 — Las cajas ausentes tampoco se pueden tocar *(verifica BR-STK-046)*

DADO cada jornada 1, 2 y 3 CUANDO se recorren las cajas del depósito ENTONCES únicamente
las dieciséis presentes se dibujan y participan en física e interacción; la de Duronga está
en el depósito y la de Durextra no. Un rayo o volumen que antes encontraba una caja ausente
ya no la encuentra. CUANDO se abre la jornada 4 ENTONCES vuelven las treinta y dos cajas,
Durextra entre ellas, y las recién llegadas satisfacen AC-STK-077.

### AC-STK-098 — Cambiar de etapa renueva el local *(verifica BR-STK-046, BR-STK-047, BR-STK-043, BR-STK-044)*

DADO el mismo local con jornada 3 abierta CUANDO se abre la jornada 4 ENTONCES recupera
las treinta y dos identidades y el reparto completo, con sus cupos y zonas correspondientes.
Repetir la apertura NO duplica objetivos ni respuestas a un gesto. DADO una nueva partida
de prueba después de una completa ENTONCES reaparece únicamente el reparto de dieciséis.
Retomar desde el menú en cualquiera de las dos etapas conserva el reparto de esa etapa.
Una unidad sostenida al cerrar NO sobrevive al cambio de etapa.

### AC-STK-099 — Los compradores de prueba piden productos presentes *(verifica BR-STK-046, BR-STK-027)*

DADO cada jornada 1, 2 y 3 CUANDO se recorren todos los pedidos construidos para ella
ENTONCES cada identidad pedida pertenece a los dieciséis presentes. Completar esas compras
y reponer sus faltantes respeta la disponibilidad de una caja por producto.

### AC-STK-100 — La prueba quita columnas antes de comprimir la referencia *(verifica BR-STK-048, BR-STK-047)*

DADO cada tipo de cara de las islas, las heladeras funcionales y la estantería de no
comestibles CUANDO se compara su exhibición de prueba con la etapa completa ENTONCES
conserva el margen de referencia contra el borde, las filas y la separación uniforme de
referencia, sin unidades fuera de la chapa ni intersecciones. DADO un cupo inicial que
no entra con esos márgenes y ese ritmo ENTONCES quita columnas y conserva la mayor cantidad
que entra en la cara con los dos centros en mitades opuestas. Agregar una columna excedería
el espacio disponible. Una tanda que ya entra conserva sus columnas. El sobrante queda libre a ambos lados, sin estirar huecos.
Las dos mitades longitudinales y la principal a altura de reposición se conservan.

### AC-STK-101 — Los laterales conservan aire entre unidades y a ambos lados de la mitad *(verifica BR-STK-049, BR-STK-047)*

DADOS los cuatro niveles de ambos laterales de cada isla de prueba CUANDO se mide su
exhibición completa ENTONCES cada fila conserva la separación uniforme de referencia
de su producto (AC-STK-106 fija la de Terminator), no menor que el mínimo entre unidades
de exhibición, y las dos tandas conservan el mínimo de aire entre tandas. Sus centros quedan en mitades opuestas, sin acumular sus unidades contra la división,
y se aprovecha la holgura conjunta antes de quitar otra columna.

### AC-STK-102 — Las cabeceras conservan aire y margen a sus costados *(verifica BR-STK-049, BR-STK-048)*

DADOS los cuatro niveles de las cuatro cabeceras de prueba CUANDO se miden sus unidades y
sus encuentros con los laterales ENTONCES cada fila conserva la separación uniforme de
referencia y cada costado conserva el margen lateral de exhibición. Cada encuentro deja
como mínimo la mayor separación de referencia de sus productos contiguos y el mínimo de
aire entre caras. Las cabeceras con dos filas conservan el aire de referencia cuando entra
y nunca bajan del mínimo entre filas. Se quitan columnas antes de sacrificar esos márgenes.

### AC-STK-103 — El reparto con aire conserva el margen frontal y los apoyos *(verifica BR-STK-049, BR-STK-048)*

DADO el reparto de prueba completo CUANDO se compara con la etapa completa ENTONCES conserva
el retiro frontal de referencia en cada cara, todas las unidades quedan apoyadas dentro
de su chapa y ninguna unidad se superpone con otra ni con el mueble. Las filas, las
orientaciones y los destinos permanecen iguales. Los cupos principales y totales coinciden
con las columnas realmente exhibidas después de adaptar su cantidad.

### AC-STK-104 — Un reparto imposible no se publica pegado *(verifica BR-STK-049)*

DADO un tramo que alcanza exactamente para una columna por producto, sus márgenes y todos
los mínimos de aire CUANDO se distribuye ENTONCES conserva una columna y satisface cada
mínimo. DADO ese mismo tramo reducido por debajo del mínimo necesario CUANDO se distribuye
ENTONCES rechaza el reparto; no elimina un producto, su margen ni el aire entre caras o
en la mitad para hacerlo entrar.

### AC-STK-105 — Entre dos productos de un estante el paso es el de sus unidades *(verifica BR-STK-049, BR-STK-047)*

DADOS los cuatro niveles de cada estante de prueba con dos productos —los dos laterales de
cada isla y la estantería de no comestibles— CUANDO se mide la separación entre unidades
vecinas ENTONCES el encuentro de los dos productos separa lo mismo que la mayor separación
de sus dos productos, nunca menos que el mínimo de aire entre tandas ni más que esa
separación más la tolerancia de exhibición. Un hueco mayor en el cambio de producto, como el
que dejaba repartir el sobrante en la unión, hace fallar el criterio. Los centros de ambas
tandas siguen en mitades opuestas.

### AC-STK-106 — Terminator toma el paso de Zucarachas *(verifica BR-STK-049, BR-STK-048)*

DADOS los cuatro niveles del lado de Terminator y Zucarachas CUANDO se mide la separación
entre unidades vecinas ENTONCES las de Terminator miden lo mismo que las de Zucarachas, con
la tolerancia de exhibición, y el encuentro entre ambos también. Con la separación de referencia
propia de Terminator entraría una columna más, y no la hay: agregarla excedería el espacio
disponible a este paso.

### AC-STK-107 — Los faltantes de las jornadas 3 a 5 respetan los pedidos sorteados *(verifica BR-STK-050, BR-STK-026, BR-STK-027, BR-STK-046)*

DADO cada jornada de la 3 a la 5 con los pedidos de sus dos compradores ya construidos CUANDO se
calculan los faltantes de reposición, con distintas semillas de partida y de apertura, ENTONCES
cada pedido sumado a lo que le falta a su fila no pasa de las unidades de una caja, también cuando
los dos compradores piden el mismo producto. En la jornada 3, cada producto pedido está entre los
dieciséis presentes. Consultar faltantes antes o después de atención conserva las mismas
instancias de compradores y pedidos.

### AC-STK-108 — Registrar espera a las dos compras de las jornadas 3 a 5 *(verifica BR-STK-050, BR-STK-042)*

DADO la jornada 4 con la compra de Tia vendida y anotada y Fede sin llegar o esperando CUANDO se
evalúa durante la noche ENTONCES registrar sigue pendiente. CUANDO Fede vence ENTONCES la planilla
exacta de sólo lo vendido a Tia cumple registrar. DADO la jornada 5 con Cami y Mía vencidas y la
planilla en cero CUANDO cierra la noche ENTONCES registrar cuenta como cumplida; una unidad de más
o de menos la deja pendiente. La misma regla vale para Cami y Tin en la jornada 3.

### AC-STK-109 — Venta y vencimiento conservan las unidades de las jornadas 3 a 5 *(verifica BR-STK-050, BR-STK-041)*

DADO una compra de la jornada 3, 4 o 5 con sus tres productos y su ticket exactos, uno retirado de
la góndola y otro de la caja, CUANDO se completa ENTONCES las tres identidades se retiran una sola
vez y cuentan como vendidas sin descontar además el pedido; repetir la entrega no vende otra vez.
DADO una compra con dos productos recibidos CUANDO vence ENTONCES las dos unidades siguen
registradas afuera y recogibles en el piso interior, sin venta, y depósito, caja y góndola quedan
como antes del vencimiento.

### AC-STK-110 — El registro de la prueba no lista productos ausentes *(verifica BR-STK-019, BR-STK-046)*

DADO cada jornada 1, 2 y 3 CUANDO abre ENTONCES la planilla tiene exactamente las dieciséis filas
de BR-STK-046, ninguna de un producto que no está en las góndolas esa noche, y cada producto que
piden sus compradores tiene fila. DADO la jornada 4 o posterior ENTONCES tiene los treinta y dos.
CUANDO se abre otra jornada en el mismo local ENTONCES la planilla es la de la nueva etapa.

### AC-STK-111 — La caja que cerró en estantería abre igual *(verifica BR-STK-051, BR-STK-038, BR-STK-004)*

DADO la jornada 2 cerrada con la caja de Marolini apoyada en un pallet de estantería, en una
pose distinta de su lugar de fábrica, y la de Uakalas apoyada sobre otra caja que está en
estantería CUANDO abre la jornada 3 ENTONCES las dos abren en la misma pose con que cerraron, la
de Uakalas sigue sobre su caja y las dos tienen 8 unidades. DADO esas cajas movidas durante
la noche 3 y vueltas a dejar en estantería CUANDO abre la 4 ENTONCES abren donde las dejó esa
noche. DADO la jornada 1 de una partida nueva ENTONCES cada caja presente abre en su lugar de
fábrica. DADO la noche 2 cerrada con todas las cajas en sus lugares de fábrica ENTONCES la 3
abre con todas en esos lugares.

### AC-STK-112 — La caja que cerró afuera abre en un lugar libre *(verifica BR-STK-051, BR-STK-039)*

DADO la jornada 2 cerrada con una caja en la mano, otra en el piso, otra en el local, otra
sobre el pallet del piso y otra sobre una caja que está en el piso CUANDO abre la jornada 3
ENTONCES cada una de esas cinco está apoyada en una estantería, en un hueco libre o encima de
otra caja que está en estantería, y ninguna abre en la mano, en el piso ni en el local. Ningún
cuerpo se superpone con otro. Para cada una existe un punto libre del piso desde el cual la
mira la enfoca dentro del alcance vigente. CUANDO pasan 120 cuadros de física sin tocarlas
ENTONCES ninguna se desplazó más de 0,01 m. DADO exactamente una caja afuera CUANDO abre ENTONCES
abre en un hueco libre y ninguna otra caja se movió. DADO una caja de tamaño grande según el
catálogo afuera y como único hueco libre el de una caja de tamaño chico CUANDO abre ENTONCES
abre apoyada sobre otra caja que está en estantería, sin superponerse. DADO dos cajas afuera y
un solo hueco libre donde entra cualquiera de las dos CUANDO abre ENTONCES una abre en ese hueco
y la otra sobre una caja en estantería.

### AC-STK-113 — Sin pose guardada la caja abre en su lugar de fábrica *(verifica BR-STK-051, BR-STK-038)*

DADO un guardado sin la pose de la caja de Actroncito, o con un número en lugar de una pose
CUANDO se retoma y abre la jornada ENTONCES esa caja abre en su lugar de fábrica y las demás
abren donde se guardaron. DADO la jornada 4 abierta con la pila de cajas llegadas, cerrada sin
ordenarlas CUANDO abre la 5 ENTONCES esas cajas abren cada una en una estantería (BR-STK-051)
y ninguna abre apilada en el fondo del depósito.

### AC-STK-114 — Cada producto presente pertenece a una sola zona *(verifica BR-STK-052, BR-STK-043, BR-STK-046, BR-STK-047)*

DADO el local de las jornadas de prueba, y luego el de la primera jornada completa, CUANDO se
asigna cada producto presente a su zona ENTONCES cada uno cae en exactamente una de las siete,
según la tabla de BR-STK-052. Duronga cae en la zona 2 con la estantería de no comestibles.
Las heladeras funcionales cubren sus productos en la zona 1 y la fuera de servicio no cubre
ninguno. Ningún producto ausente de la etapa pertenece a una zona. Una tanda fija de un producto
en un mueble de otra zona no lo suma a esa zona.

### AC-STK-115 — Una zona tiene faltante mientras algún producto suyo lo tiene *(verifica BR-STK-052, BR-STK-007, BR-STK-026)*

DADO la jornada 2 con un solo producto faltante cuya tanda principal está en la zona 4 ENTONCES la
zona 4 tiene faltante y las otras seis no. CUANDO se coloca la última unidad que le falta ENTONCES
ninguna tiene. CUANDO la zona 4 tiene dos productos faltantes y se repone uno ENTONCES sigue con
faltante. CUANDO se agarra o se vende una unidad de un producto de la zona 6 con la góndola
completa ENTONCES la zona 6 vuelve a tener faltante. DADO la jornada 1 con unidades agarradas o
vendidas de cualquier góndola ENTONCES ninguna zona tiene faltante.

### AC-STK-116 — Un punto pertenece a una sola zona *(verifica BR-STK-052)*

DADO un punto en el interior de cada una de las siete zonas CUANDO se consulta su zona ENTONCES
contesta esa zona. DADO un punto sobre el límite entre las zonas 3 y 4, y otro entre las zonas 4 y
5, CUANDO se consulta cada uno diez veces, desde cualquiera de los dos lados, ENTONCES siempre
contesta una sola zona y es la misma. DADO un punto en el depósito, fuera de las siete, ENTONCES
no contesta ninguna.

### AC-STK-117 — Lo que se lleva en la mano al cerrar cuenta como puesto *(verifica BR-STK-033)*

DADO un producto con un solo casillero vacío y el resto de la góndola completa CUANDO el jugador
cierra la noche con una unidad de ese producto en la mano, examinándola o no, ENTONCES reponer
cuenta cumplida. DADO el mismo caso durante la noche ENTONCES reponer sigue sin cumplir y su
casillero vacío. DADO dos casilleros vacíos de ese producto, o uno vacío de otro producto
además del suyo, CUANDO se cierra con esa unidad en la mano ENTONCES reponer no cuenta cumplida. DADO la
unidad en la mano que se suelta antes del cierre ENTONCES reponer no cuenta cumplida.

## No objetivos

- Esta capacidad NO cobra ni atiende: eso es de
  [`counter-service`](../counter-service/counter-service.md), que le pide el descuento.
- Esta capacidad NO mueve la unidad con la mano ni dibuja el hueco que se llenó.
- Esta capacidad NO decide el precio final de nada: el catálogo es un primer valor de balance.

## Contratos

La apertura de escena selecciona compradores una vez mediante
`compradores_de_la_apertura: Callable`, cuyo valor productivo conserva
`Compradores.de_la_jornada`. Pasa la misma `Array[Comprador]` a
`Apertura.inventario_de_la_jornada(compradores, totales, reponibles, azar)` y a
`TareaDeAtender`; las consultas `Apertura.pedidos_de(compradores)` leen las mismas `Venta`.
La fuente inyectable no activa por sí sola el padrón de la jornada 2 ni sustituye el inventario de uno
solo de sus consumidores.

- **Entrada:** el sector y destino declarado de cada producto y si admite exhibición;
  la posición del jugador en el piso, los productos que existen, sus casilleros totales y los de la fila de adelante
  de todas sus tandas, la jornada que se abre, sus pedidos ya construidos y la fuente de azar,
  lo vendido de cada producto, qué compras terminaron y cuáles siguen abiertas, lo que el jugador
  lleva en la mano, la caja que examina, el casillero que elige, y los pedidos de ingresar,
  mover, cobrar, sacar y devolver
  a la caja, desechar una unidad afuera, colocar y agarrar de la góndola, sumar y restar en la planilla.
- **Salida:** cuántas unidades hay por ubicación, en cada caja y afuera, qué casilleros de cada
  producto están vacíos y cuáles ocupados, qué falta, qué hace el clic sobre cada caja y sobre
  cada casillero, el texto de la caja examinada, lo anotado y el total de la planilla, si cada
  obligatoria está cumplida, el motivo de cada rechazo, y la zona de reposición de un punto y si
  tiene faltante.
- **Apertura sorteada:** recibe los mismos pedidos que la atención, suma sus unidades por
  producto y devuelve faltantes dentro del máximo de sus casilleros de adelante, y cuáles quedan
  vacíos. El inventario conserva el cupo total. Con menos elegibles que la
  cantidad sorteada devuelve todos; con cero, ninguno. No modifica ni vuelve a sortear los pedidos.
- **Orden del depósito:** recibe la particular de la jornada, el conjunto de cajas, si cada
  una está sostenida y su apoyo directo; contesta disposición de apertura y si todas cumplen
  la condición de orden. Ciclos y apoyos ausentes contestan pendiente; el conjunto vacío,
  ordenado. El cierre congela la cuenta de obligatorias aunque después cambien los apoyos.
- **Falla:** las cantidades no positivas se ignoran; el cobro que supera los vendibles no mueve
  nada; el producto inexistente contesta «no existe» en vez de romper; devolver a una caja llena,
  de otro producto o una unidad que ya volvió no cambia nada; colocar en un casillero ocupado no
  mueve nada, agarrar de un casillero vacío no da nada y desechar una unidad no registrada
  afuera no cambia nada. Un faltante de más de una caja o de más
  que sus casilleros de adelante es un error de los datos, que un test detecta: el juego no lo acomoda.

## Señales

- El producto colocado en la góndola, la unidad retirada del depósito y la devuelta a su caja.
- Ordenar las cajas cumplida o descumplida, sólo cuando cambia su condición con el turno abierto.

## Dependencias

- [`store-cleanup`](../store-cleanup/store-cleanup.md) (consume): la unidad tirada al
  contenedor deja de estar afuera y se descuenta del depósito.

- [`counter-service`](../counter-service/counter-service.md) (alimenta y consume): el cobro
  descuenta del depósito, hasta los vendibles; lo vendido de cada producto es contra qué se
  compara la planilla, y cada cobro o vencimiento vuelve a compararla; en las jornadas 1 a 5,
  cerrar todas las compras habilita evaluar registrar, independientemente de atención.
  Los mismos pedidos construidos para esa apertura acotan los faltantes, sin otra selección
  de compradores o productos (BR-STK-026, BR-STK-027). En jornada 2, el padrón fijo conserva
  sus identidades, recepción y revisión de registrar por venta o vencimiento (BR-STK-040,
  BR-STK-041, BR-STK-042, BR-STK-045). En las jornadas 3 a 5, los pedidos sorteados y sus
  compras físicas siguen BR-STK-050.
- [`player-actions`](../player-actions/player-actions.md) (consume y alimenta): la unidad viaja
  en la mano, y lo que la mano lleva decide qué hace el clic sobre la caja y sobre cada casillero;
  qué casilleros están vacíos y cuáles ocupados decide cuáles se muestran y cuáles se agarran.
- [`investigation`](../investigation/investigation.md) (consume): el examen de una caja, que es
  el de cualquier levantable. Mientras dura se muestra el texto de la caja.
- [`subtitles`](../subtitles/subtitles.md) (alimenta): el texto de la caja, que la línea de
  subtítulo muestra con la caja apoyada y durante su examen.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (alimenta y consume): avisa cuándo reponer y
  registrar y ordenar las cajas quedaron cumplidas, y cuándo dejaron de estarlo; y la jornada
  que abre decide lo que falta y la disposición inicial de las cajas.
- [`notifications`](../notifications/notifications.md) (alimenta): la zona donde está el
  jugador y si tiene faltante, que decide el aviso de falta reponer (BR-NTF-016).
- [`save-and-resume`](../save-and-resume/save-and-resume.md) (alimenta y consume): guarda la
  pose de cada caja al cierre y la devuelve al retomar (BR-SAV-022).

## Preguntas abiertas

- **OQ-STK-009 — ¿Sobre qué caja y cuántas encima cuando no hay hueco libre?**
  - Por qué sigue abierta: la ficha dice «arriba de otra caja en los estantes» y no precisa si
    el tamaño de las dos importa ni si caben varias apiladas sobre una. BR-STK-051 sólo exige
    que la caja quede apoyada sobre una caja que está en estantería, sin superponerse y
    estable.
  - Decide: Tiago, con el dueño del repo.
  - Bloquea: nada.

- **OQ-STK-004 — ¿Cómo suenan la botella de vidrio y la caja de cereal?**
  - Por qué sigue abierta: la ficha nombra dos familias sonoras que el juego no tiene
    —botella de vidrio y caja de cereal— y no hay audio para ellas. Mientras tanto suenan como
    la botella plástica y la cajita, que son las más parecidas.
  - Decide: el equipo de sonido.
  - Bloquea: nada.
- **OQ-STK-007 — ¿Cómo se concilian los cuatro niveles del mapa con las alturas actuales?**
  - Por qué sigue abierta: el texto del mapa habla de cuatro estantes y del primero como
    levantable; los muebles vigentes tienen cuatro chapas laterales y cuatro en cabeceras,
    con niveles 0 y 3 fijos y 1 y 2 reponibles. El reparto aprobado fija sectores y conserva
    esas alturas; no define la interacción de levantar un estante.
  - Decide: el dueño del repo con game design y arte.
  - Bloquea: cambiar niveles, alturas o qué estante es reponible a partir de esa frase;
    no bloquea los sectores ni la exhibición provisional de Duronga de BR-STK-043 y BR-STK-044.
