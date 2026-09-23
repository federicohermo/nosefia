---
schema_version: 1
capability_id: CAP-CTR
status: draft
owner: por definir
provenance: GDD «Atención por ventanilla»; migración de los specs 013, 035
---

# Capacidad: la atención por la ventanilla

## Propósito

Atender a los compradores que tocan el timbre: qué piden, cuánto marca la caja, cuánto ponen y
cómo se despachan. Lo único que tiene que hacer bien es **poner la diferencia delante del
jugador**: es el único lugar donde el juego puede mentir en vivo.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Comprador** | quién viene a la ventanilla, con su pedido y con cuánto paga | cliente, NPC |
| **Pedido** | qué productos y cuántas unidades se lleva | carrito, orden |
| **Diferencia** | lo que paga menos lo que marca la caja, **con signo** | vuelto, error |
| **Despachar** | dar por terminada la atención, se le haya vendido o no | atender, cerrar |
| **Ventanilla** | la única ventana por la que se atiende. Nadie entra al local | mostrador, caja |
| **Vendibles** | las unidades de un producto que se pueden vender: lo que el estante no necesita | stock, disponible |

## Comportamiento normativo

### BR-CTR-001 — Dos compradores por noche

El sistema DEBE hacer pasar **2 compradores por jornada**, tomados en orden de un padrón fijo. El
padrón no se sortea: un sorteo daría noches distintas con el mismo balance.

### BR-CTR-002 — La caja no vuelve a sumar

El sistema DEBE tomar el total de la caja del pedido y no recalcularlo. Una segunda suma daría el
mismo número hasta el día que cambie el catálogo, y ahí las dos ventanas dirían distinto.

### BR-CTR-003 — La diferencia lleva signo

El sistema DEBE calcular la diferencia como **lo que paga menos el total**. Positiva es que pagó
de más y negativa que pagó de menos: el valor absoluto haría indistinguibles los dos casos.

### BR-CTR-004 — Alguien paga distinto

El padrón DEBE incluir al menos un comprador que paga de más y uno que paga de menos. Un padrón
donde todos pagan justo deja la ventanilla sin nada que mirar.

### BR-CTR-006 — El cobro es todo o nada

SI alguna línea del pedido supera los vendibles de su producto, ENTONCES el sistema DEBE
rechazar el cobro entero y **no mover una sola unidad**. Descontar lo que se pueda deja un
estado que el jugador no distingue de una venta completa.

### BR-CTR-007 — Se puede despachar sin vender

El sistema DEBE permitir despachar a un comprador sin cobrarle nada. Un pedido puede superar los
vendibles de la noche, y exigir la venta dejaría a ese comprador sin forma de irse.

### BR-CTR-008 — Un comprador se despacha una vez

SI la atención ya está despachada, ENTONCES el sistema DEBE rechazar cobrarla o despacharla otra
vez, y no cambiar nada.

### BR-CTR-009 — La obligatoria es atender, no vender

CUANDO todos los compradores de la noche quedaron despachados, el sistema DEBE dar la obligatoria
por cumplida, **contando igual las dos formas**: vender y despachar sin vender.

### BR-CTR-010 — El desvío suma sólo lo cobrado

CUANDO se suma cuánto se desvió la caja en la noche, el sistema DEBE contar **sólo las atenciones
cobradas** y conservar los signos. Al que se despachó sin vender no se le cobró nada, así que su
diferencia no es plata que falte.

### BR-CTR-011 — La ventanilla dice qué falta

SI el pedido tiene productos que superan sus vendibles, ENTONCES el sistema DEBE nombrarlos, en
el orden del ticket. Es la explicación de por qué el cobro va a fallar.

### BR-CTR-012 — El ticket no da la cuenta hecha

El sistema DEBE mostrar las líneas del pedido **sin el precio de cada una**, y mostrar aparte el
total, lo que paga y la diferencia. Repartir el precio por renglón le daría al jugador la cuenta
hecha justo donde el juego puede mentir.

### BR-CTR-013 — El comprador habla de a una entrada

MIENTRAS el comprador habla, el sistema DEBE avanzar **una entrada por clic izquierdo** y DEBE
impedir abandonar la ventanilla. Una conversación sin líneas no encierra a nadie: se puede
abandonar desde el principio.

### BR-CTR-014 — La venta sale del depósito, y deja el estante como está

CUANDO se cobra un pedido, el sistema DEBE descontar cada línea **del depósito**, y sólo hasta
los vendibles de su producto. La góndola no se toca: una venta que vacía el estante deshace lo
repuesto, y nada se lo avisa al jugador.

## Criterios de aceptación

### AC-CTR-001 — Dos por noche *(verifica BR-CTR-001)*

DADO el padrón CUANDO se piden los compradores de la jornada ENTONCES son 2, son los dos primeros
del padrón, y dos llamadas seguidas devuelven instancias distintas sin despachar.

### AC-CTR-002 — El total sale del pedido *(verifica BR-CTR-002)*

DADO un pedido de 2 unidades a 2500 y 1 a 900 CUANDO se mira la caja ENTONCES marca 5900.

### AC-CTR-003 — Los tres signos *(verifica BR-CTR-003)*

DADO un pedido de 5900 CUANDO paga 5900 la diferencia es `0`; con 6200 es `+300`; con 5400 es
`-500`.

### AC-CTR-004 — El padrón miente de los dos lados *(verifica BR-CTR-004)*

DADO el padrón entero ENTONCES hay al menos un comprador con diferencia positiva y al menos uno
con diferencia negativa.

### AC-CTR-006 — Todo o nada *(verifica BR-CTR-006)*

DADO un pedido de dos productos, uno con vendibles y otro sin CUANDO se cobra ENTONCES se
rechaza, y ni el depósito ni la góndola de ninguno de los dos cambió una unidad.

### AC-CTR-007 — Despachar sin vender *(verifica BR-CTR-007)*

DADO un pedido que supera los vendibles CUANDO se despacha sin vender ENTONCES la atención queda
despachada, no vendida, y el inventario no cambió.

### AC-CTR-008 — El segundo despacho no hace nada *(verifica BR-CTR-008)*

DADO una atención ya despachada CUANDO se la cobra ENTONCES contesta que ya estaba despachada; y
despacharla sin vender devuelve `false`.

### AC-CTR-009 — La obligatoria cuenta las dos formas *(verifica BR-CTR-009)*

DADO dos compradores CUANDO uno se cobra y el otro se despacha sin vender ENTONCES la obligatoria
está cumplida y los despachados son 2.

### AC-CTR-010 — El desvío no cuenta lo no vendido *(verifica BR-CTR-010)*

DADO uno que paga 500 de más y se cobra, y otro que paga 500 de menos y se despacha sin vender
CUANDO se suma el desvío ENTONCES da `+500`.

### AC-CTR-011 — Los signos no se cancelan por error *(verifica BR-CTR-010)*

DADO dos ventas cobradas, una con `+500` y otra con `-500` CUANDO se suma el desvío ENTONCES da
`0` y no `1000`.

### AC-CTR-012 — El aviso nombra lo que falta *(verifica BR-CTR-011)*

DADO un pedido de dos productos, uno que supera sus vendibles y otro que no, CUANDO se mira el
aviso ENTONCES nombra sólo al primero; con los dos dentro de sus vendibles, el aviso es la cadena
vacía.

### AC-CTR-013 — El ticket no lleva precios por línea *(verifica BR-CTR-012)*

DADO un pedido CUANDO se leen sus renglones ENTONCES cada línea lleva unidades y nombre, ningún
precio unitario, y al final están el total, lo que paga y la diferencia.

### AC-CTR-014 — El diálogo no se abandona a mitad *(verifica BR-CTR-013)*

DADO una conversación de tres entradas CUANDO se avanzó dos veces ENTONCES no se puede abandonar;
al tercer avance sí. Con cero entradas se puede desde el principio.

### AC-CTR-015 — La venta no toca el estante *(verifica BR-CTR-014)*

DADO un producto de umbral 8 CUANDO se cobra la venta ENTONCES:

| Góndola | Depósito | Venta | Resultado | Góndola después | Depósito después |
|---|---|---|---|---|---|
| 8 | 2 | 2 | se cobra | 8 | 0 |
| 0 | 10 | 2 | se cobra | 0 | 8 |
| 0 | 10 | 3 | se rechaza | 0 | 10 |
| 8 | 0 | 1 | se rechaza | 8 | 0 |

### AC-CTR-016 — Lo repuesto sigue repuesto *(verifica BR-CTR-014)*

DADO un producto de umbral 8, con la góndola en 7, el depósito en 3 y 1 unidad en la mano CUANDO
se cobra una venta de 2 ENTONCES se cobra, y colocar la unidad de la mano deja la góndola en 8 y
reponer cumplido.

### AC-CTR-017 — El segundo comprador ve lo que dejó el primero *(verifica BR-CTR-014)*

DADO un producto de umbral 8, con la góndola en 8 y el depósito en 2 CUANDO un comprador compra 1
y otro pide 2 ENTONCES el primero se cobra y el segundo se rechaza.

## No objetivos

- Esta capacidad NO decide cuántas unidades hay ni dónde están: se lo pregunta a
  [`store-stock`](../store-stock/store-stock.md).
- Esta capacidad NO escribe el contenido de lo que dicen los compradores.
- Esta capacidad NO descuenta tiempo del turno. Atender cuesta porque el reloj corre.

## Contratos

- **Entrada:** el padrón de la noche y los vendibles de cada producto.
- **Salida:** quién está en la ventanilla, el ticket, el total, la diferencia, el aviso de
  faltantes, cuántos van despachados y el desvío de la noche.
- **Falla:** un pedido que supera sus vendibles se rechaza entero; una atención despachada
  rechaza todo lo demás.

## Señales

- El comprador que llega, la entrada de diálogo mostrada, el diálogo cerrado y la atención
  despachada.

## Dependencias

- [`store-stock`](../store-stock/store-stock.md) (consume): los vendibles y el cobro.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (alimenta): avisa cuándo la obligatoria quedó
  cumplida.

## Preguntas abiertas

- **OQ-CTR-001 — ¿Qué le pasa al jugador que cobra mal toda la noche?**
  - Por qué sigue abierta: el desvío acumulado se calcula y todavía no lo consume nadie. El GDD
    no dice si el jefe lo descuenta, lo comenta o lo ignora.
  - Decide: el dueño del repo.
  - Bloquea: nada de lo escrito acá. Abriría una regla en
    [`employment-record`](../employment-record/employment-record.md).
- **OQ-CTR-002 — ¿Cuántos compradores vienen por noche, y cuánto compra cada uno?**
  - Por qué sigue abierta: game design dio un margen de 1 a 3 compradores, con 1 a 3 productos
    cada uno, y no eligió un valor. Con pocos vendibles por producto, un padrón que pide de más
    deja ventas que se rechazan.
  - Decide: game design.
  - Bloquea: nada. Cambiaría `BR-CTR-001` y el padrón.
