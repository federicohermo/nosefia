---
schema_version: 1
capability_id: CAP-CTR
status: ratified
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
| **Vendibles** | las unidades de un producto que se pueden vender: lo que queda en la caja y el estante no necesita | stock, disponible |
| **Lector** | aparato fijo que anota la unidad sostenida en el programa | caja, escáner de inventario |
| **Programa de tickets** | tres renglones de productos que se borran o imprimen | pedido del comprador |
| **Renglón** | un producto anotado; puede repetirse | cantidad, precio |
| **Ticket** | papel que conserva los productos anotados al imprimir | pedido de la ventanilla |

## Comportamiento normativo

### BR-CTR-001 — Dos compradores por noche

En las jornadas posteriores a la primera se aplica el recorrido anterior:

El sistema DEBE hacer pasar **2 compradores por jornada**, tomados en orden de un padrón fijo. El
padrón no se sortea: un sorteo daría noches distintas con el mismo balance.

### BR-CTR-002 — La caja no vuelve a sumar

En las jornadas posteriores a la primera se aplica el recorrido anterior:

El sistema DEBE tomar el total de la caja del pedido y no recalcularlo. Una segunda suma daría el
mismo número hasta el día que cambie el catálogo, y ahí las dos ventanas dirían distinto.

### BR-CTR-003 — La diferencia lleva signo

En las jornadas posteriores a la primera se aplica el recorrido anterior:

El sistema DEBE calcular la diferencia como **lo que paga menos el total**. Positiva es que pagó
de más y negativa que pagó de menos: el valor absoluto haría indistinguibles los dos casos.

### BR-CTR-004 — Alguien paga distinto

En las jornadas posteriores a la primera se aplica el recorrido anterior:

El padrón DEBE incluir al menos un comprador que paga de más y uno que paga de menos. Un padrón
donde todos pagan justo deja la ventanilla sin nada que mirar.

### BR-CTR-006 — El cobro es todo o nada

En las jornadas posteriores a la primera se aplica el recorrido anterior:

SI alguna línea del pedido supera los vendibles de su producto, ENTONCES el sistema DEBE
rechazar el cobro entero y **no mover una sola unidad**. Descontar lo que se pueda deja un
estado que el jugador no distingue de una venta completa.

### BR-CTR-007 — Se puede despachar sin vender

En las jornadas posteriores a la primera se aplica el recorrido anterior:

El sistema DEBE permitir despachar a un comprador sin cobrarle nada. Un pedido puede superar los
vendibles de la noche, y exigir la venta dejaría a ese comprador sin forma de irse.

### BR-CTR-008 — Un comprador se despacha una vez

SI la atención ya está despachada, ENTONCES el sistema DEBE rechazar cobrarla o despacharla otra
vez, y no cambiar nada.

### BR-CTR-009 — La obligatoria es atender, no vender

En las jornadas posteriores a la primera se aplica el recorrido anterior:

CUANDO todos los compradores de la noche quedaron despachados, el sistema DEBE dar la obligatoria
por cumplida, **contando igual las dos formas**: vender y despachar sin vender.

### BR-CTR-010 — El desvío suma sólo lo cobrado

CUANDO se suma cuánto se desvió la caja en la noche, el sistema DEBE contar **sólo las atenciones
cobradas** y conservar los signos. Al que se despachó sin vender no se le cobró nada, así que su
diferencia no es plata que falte.

### BR-CTR-011 — La ventanilla dice qué falta

En las jornadas posteriores a la primera se aplica el recorrido anterior:

SI el pedido tiene productos que superan sus vendibles, ENTONCES el sistema DEBE nombrarlos, en
el orden del pedido. Es la explicación de por qué el cobro va a fallar.

### BR-CTR-012 — El pedido no da la cuenta hecha

En las jornadas posteriores a la primera se aplica el recorrido anterior:

El sistema DEBE mostrar las líneas del pedido **sin el precio de cada una**, y mostrar aparte el
total, lo que paga y la diferencia. Repartir el precio por renglón le daría al jugador la cuenta
hecha justo donde el juego puede mentir.

### BR-CTR-013 — El comprador habla de a una entrada

MIENTRAS el comprador habla, el sistema DEBE avanzar **una entrada por clic izquierdo** y DEBE
impedir abandonar la ventanilla. Una conversación sin líneas no encierra a nadie: se puede
abandonar desde el principio.

### BR-CTR-014 — La venta sale del depósito, y deja el estante como está

En las jornadas posteriores a la primera se aplica el recorrido anterior:

CUANDO se cobra un pedido, el sistema DEBE descontar cada línea **del depósito**, y sólo hasta
los vendibles de su producto. La góndola no se toca: una venta que vacía el estante deshace lo
repuesto, y nada se lo avisa al jugador.

### BR-CTR-015 — Lo vendido cuenta sólo lo cobrado

CUANDO se pregunta cuántas unidades de un producto se vendieron en la noche, el sistema DEBE
sumar sus unidades en los pedidos **cobrados**. Un comprador despachado sin vender y un cobro
rechazado no suman nada, y un producto que nadie compró contesta 0.

### BR-CTR-016 — Tres renglones en orden

MIENTRAS el programa es automático, CUANDO se lee una unidad de producto válida, el sistema DEBE anotar su producto en el primer
renglón vacío de los 3 disponibles, esté abierto o cerrado el programa. DEBE admitir repetir
el producto y DEBE avisar una lectura correcta sólo cuando se anotó.

### BR-CTR-017 — Los rechazos se distinguen y no escriben

MIENTRAS el programa es automático, SI lo leído no es una unidad de producto válida, ENTONCES el sistema DEBE rechazar por tipo
antes de comprobar si está lleno. SI ya están llenos los 3 renglones y la unidad es válida,
ENTONCES DEBE rechazar por lleno. Ambos rechazos DEBEN avisarse, sin cambiar los renglones.

### BR-CTR-018 — Borrar vacía los tres

CUANDO se pide borrar, el sistema DEBE dejar los 3 renglones vacíos, incluso si ya lo estaban.

### BR-CTR-019 — Imprimir no borra el programa

CUANDO se imprime con al menos un renglón lleno, el sistema DEBE crear un ticket y avisar su
impresión, conservando los renglones del programa. SI están vacíos, ENTONCES NO DEBE crear
papel ni avisar impresión.

### BR-CTR-020 — El papel conserva una copia independiente

El ticket DEBE conservar los productos de los renglones llenos, en su orden, sin cambiar al
borrar o modificar el programa. Dos impresiones DEBEN ser dos papeles independientes.
Consultar los renglones NO DEBE permitir cambiar el programa ni el ticket.

### BR-CTR-021 — Cada jornada empieza vacía

CUANDO abre una jornada, el sistema DEBE iniciar el programa vacío y DEBE retirar los tickets
de la noche anterior, estén en la mano, en la ranura o sueltos.

### BR-CTR-022 — Desde la tercera noche se escribe a mano

DESDE la jornada 3 y hasta el fin de la partida, el programa DEBE ser manual. Antes DEBE ser
automático. El modo DEBE salir del número de jornada: retomar una partida en la 4 no recupera
el lector, y una partida nueva vuelve al automático.

### BR-CTR-023 — Cada elección conserva su renglón

MIENTRAS el programa es manual, cada uno de los 3 renglones DEBE permitir elegir vacío o
cualquier producto del catálogo, incluidos productos repetidos. Elegir vacío DEBE vaciar
sólo ese renglón. La pantalla DEBE conservar cada posición al repintar, abrir o imprimir,
aunque los anteriores estén vacíos; el papel DEBE llevar sólo los llenos en su orden.
SI el programa es automático o el renglón está fuera de los 3, ENTONCES elegir NO DEBE
cambiar nada. Los menús DEBEN ofrecer primero vacío y después el catálogo en su orden.

### BR-CTR-024 — El hueco no lee ni avisa

MIENTRAS el programa es manual, el lector NO DEBE estar: su lugar DEBE quedar ocupado por
un hueco fijo, no levantable. Usarlo NO DEBE cambiar renglones ni producir avisos o sonidos,
con manos vacías o con cualquier objeto, esté vacío o lleno el programa. Este silencio
DEBE preceder a los rechazos por tipo o por lleno del modo automático.

### BR-CTR-025 — El ticket se desecha en el inodoro

CUANDO se usa el inodoro con un ticket en la mano, el sistema DEBE quitar ese ticket del mundo,
dejar la mano vacía y publicar una vez su descarte. Ningún otro levantable DEBE desaparecer por
usar el inodoro. Las herramientas DEBEN conservar los efectos de limpieza vigentes. Usar el
lavatorio con un ticket NO DEBE desecharlo.

### BR-CTR-026 — La primera jornada usa horarios propios

EN la primera jornada, el sistema DEBE recibir a Martín desde las 22:00 hasta las 00:00 y a
Tiago desde las 04:00 hasta las 06:00. La llegada se incluye y el límite se excluye.
Martín DEBE pedir un Marolini, una Coracola y un Malbardo. Tiago DEBE pedir dos Zucarachas
y un Pepito. Estos horarios DEBEN derivarse del reloj del turno, cuya apertura es a las 20:00.
Las jornadas siguientes DEBEN conservar el padrón y recorrido anteriores, sin copiar estos personajes.

### BR-CTR-027 — Llegada y vencimiento independientes de la interfaz

CUANDO se cruza una llegada, el sistema DEBE publicar una sola llegada aunque la ventanilla esté
cerrada. Repetir un instante o reabrir NO DEBE llamar ni repetir al comprador.
CUANDO se cruza el límite con una compra incompleta, el sistema DEBE publicar una sola salida,
cerrar su conversación y retirar con él los productos recibidos y el ticket aceptado.
Esos productos DEBEN salir del inventario sin contar como venta. El ticket DEBE descartarse.
Un salto DEBE procesar todos los cruces en orden. Una compra completa NO DEBE vencer.
Cerrar la ventanilla NO DEBE detener el horario; la pausa DEBE detenerlo.

### BR-CTR-028 — Primero hablar, después recibir

CUANDO se hace clic izquierdo sobre el comprador por primera vez, el sistema DEBE iniciar su
conversación inicial. Cada clic siguiente DEBE avanzar una entrada. MIENTRAS habla, los objetos
NO DEBEN recibirse ni rechazarse. Terminada esa conversación, un clic con manos vacías DEBE
mostrar un recordatorio de una entrada. Mientras una entrada esté activa, el clic DEBE avanzar
el diálogo, también con un objeto rechazado en la mano. Terminada la entrada, con objeto sostenido
DEBE intentar recibirlo sin avanzar diálogo en el mismo clic. Reabrir DEBE conservar el estado.
Los textos DEBEN corresponder al diseño de Figma, con las cantidades del pedido de la ficha:
una Marolini para Martín, Coracola en lugar de Pura-Cola y dos Zucarachas para Tiago.
Los productos pedidos DEBEN distinguirse con negrita y color.

### BR-CTR-029 — Productos pendientes y ticket exacto

El sistema DEBE aceptar una unidad física distinta de cada producto todavía pendiente y un
ticket con las cantidades exactas del pedido. El orden del ticket NO DEBE importar.
Una unidad repetida, extra, producto ajeno, ticket incorrecto u otro objeto DEBE rechazarse
con el texto de rechazo y el recordatorio, sin alterar mano, entregas ni ventas.
Antes de terminar la conversación inicial NO DEBE haber recepción ni rechazo.

### BR-CTR-030 — La compra completa vende una vez

SÓLO al recibir todos los productos y el ticket, el sistema DEBE registrar la compra una vez
y comenzar su despedida. Los botones de cobro y despacho NO DEBEN ofrecerse en la primera jornada.
Las entregas parciales NO DEBEN contar como ventas. La recepción DEBE usar las unidades físicas,
sin ejecutar además el descuento automático del pedido. Completar la compra antes del límite
DEBE conservar el resultado aunque la despedida continúe. Al terminarla, el comprador DEBE irse.

### BR-CTR-031 — La primera jornada exige ambas compras

EN la primera jornada, atención DEBE cumplirse sólo al completar ambas compras.
Una compra perdida DEBE dejar la tarea sin cumplir aunque se complete la otra.
La finalización DEBE contarse una sola vez y conservarse al reabrir.
Una nueva jornada DEBE empezar sin agenda, conversación, entregas, cuerpos ni ventas heredados.

### BR-CTR-032 — Compradores animados

El sistema DEBE mostrar a cada comprador con sus ocho dibujos en orden numérico, en bucle,
con transparencia y proporción conservadas, con una duración uniforme de 0,5 segundos por dibujo.
Martín DEBE usar su animación nueva. La pausa DEBE detener la animación.
Al irse el comprador, su imagen DEBE dejar de mostrarse.

## Criterios de aceptación

### AC-CTR-001 — Dos por noche *(verifica BR-CTR-001)*

DADO una jornada posterior a la primera CUANDO se piden sus compradores del padrón ENTONCES son 2, son los dos primeros
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

### AC-CTR-013 — El pedido no lleva precios por línea *(verifica BR-CTR-012)*

DADO un pedido CUANDO se leen sus renglones ENTONCES cada línea lleva unidades y nombre, ningún
precio unitario, y al final están el total, lo que paga y la diferencia.

### AC-CTR-014 — El diálogo no se abandona a mitad *(verifica BR-CTR-013)*

DADO una conversación de tres entradas CUANDO se avanzó dos veces ENTONCES no se puede abandonar;
al tercer avance sí. Con cero entradas se puede desde el principio.

### AC-CTR-015 — La venta no toca el estante *(verifica BR-CTR-014)*

DADO un producto de 8 casilleros CUANDO se cobra la venta ENTONCES:

| Góndola | Depósito | Venta | Resultado | Góndola después | Depósito después |
|---|---|---|---|---|---|
| 8 | 2 | 2 | se cobra | 8 | 0 |
| 0 | 10 | 2 | se cobra | 0 | 8 |
| 0 | 10 | 3 | se rechaza | 0 | 10 |
| 8 | 0 | 1 | se rechaza | 8 | 0 |

### AC-CTR-016 — Lo repuesto sigue repuesto *(verifica BR-CTR-014)*

DADO un producto de 8 casilleros, con la góndola en 7, el depósito en 3 y 1 unidad en la mano
CUANDO se cobra una venta de 2 ENTONCES se cobra, y colocar la unidad de la mano deja la góndola
en 8 y reponer cumplido.

### AC-CTR-017 — El segundo comprador ve lo que dejó el primero *(verifica BR-CTR-014)*

DADO un producto de 8 casilleros, con la góndola en 8 y el depósito en 2 CUANDO un comprador
compra 1 y otro pide 2 ENTONCES el primero se cobra y el segundo se rechaza.

### AC-CTR-018 — Lo vendido suma los dos pedidos *(verifica BR-CTR-015)*

DADO dos compradores que piden el mismo producto, uno 2 unidades y otro 1, CUANDO se cobran los
dos ENTONCES lo vendido de ese producto es 3.

### AC-CTR-019 — Lo no cobrado no es vendido *(verifica BR-CTR-015)*

DADO un comprador que pide 2 unidades de un producto CUANDO se lo despacha sin vender ENTONCES
lo vendido de ese producto es 0. DADO un pedido que supera los vendibles CUANDO el cobro se
rechaza ENTONCES lo vendido sigue en 0.

### AC-CTR-020 — Lo que nadie compró *(verifica BR-CTR-015)*

DADO dos ventas cobradas CUANDO se pregunta por un producto que no estaba en ningún pedido
ENTONCES lo vendido es 0.

### AC-CTR-021 — Duplicados y cuarto intento *(verifica BR-CTR-016, BR-CTR-017)*

DADO el programa automático vacío, CUANDO se lee una unidad de Marolini, otra de Marolini y una de
Coracola ENTONCES los renglones son Marolini, Marolini y Coracola, en ese orden, y se avisan
3 lecturas. CUANDO se lee una cuarta unidad válida ENTONCES se rechaza por lleno y nada cambia.

### AC-CTR-022 — El tipo se comprueba primero *(verifica BR-CTR-017)*

DADO un programa automático con un renglón lleno, CUANDO se lee una caja, mopa, balde, jabón, bolsa o ticket ENTONCES se
rechaza por no ser un producto y nada cambia. DADO los 3 llenos, ENTONCES ese rechazo sigue
siendo por tipo. DADO ningún dato o una unidad sin producto ENTONCES tampoco se anota.

### AC-CTR-023 — Copia, borrado y nueva impresión *(verifica BR-CTR-018, BR-CTR-019, BR-CTR-020)*

DADO Marolini y Coracola anotados, CUANDO se imprime dos veces ENTONCES hay dos tickets
distintos con esos productos en su orden y el programa sigue igual. CUANDO se borra y se
modifica una copia consultada ENTONCES el programa queda vacío y ambos tickets conservan
Marolini y Coracola. Modificar el arreglo recibido o devuelto por un ticket no lo cambia.

### AC-CTR-024 — Vacío no imprime *(verifica BR-CTR-018, BR-CTR-019)*

DADO el programa vacío, CUANDO se imprime, se borra y se imprime de nuevo ENTONCES no hay
ticket ni aviso de impresión, y los renglones siguen vacíos.

### AC-CTR-025 — La próxima noche retira los papeles *(verifica BR-CTR-021)*

DADO un ticket en la mano, otro suelto y el programa con un producto, CUANDO abre otra jornada
ENTONCES el programa está vacío, las manos están vacías y ninguno de esos papeles existe.

### AC-CTR-026 — El corte es la jornada tres *(verifica BR-CTR-022)*

DADO jornadas 1, 2, 3, 4 y 5, CUANDO abre cada una ENTONCES las 1 y 2 son automáticas y
las 3, 4 y 5 manuales. DADO una partida retomada en la 4 ENTONCES abre manual; CUANDO
se abre una partida nueva ENTONCES vuelve al automático. Abrir la 3 tras escribir en la 2
deja los 3 renglones vacíos.

### AC-CTR-027 — Elegir y vaciar conserva los otros *(verifica BR-CTR-023)*

DADO el modo manual, CUANDO se elige cada producto del catálogo en cada renglón ENTONCES
ese renglón conserva el producto. DADO Marolini en los 3 CUANDO se vacía el segundo ENTONCES
el primero y el tercero siguen en Marolini. DADO un índice -1 o 3 ENTONCES elegir se rechaza
y consultar devuelve vacío. DADO el modo automático ENTONCES ninguna elección lo modifica.

### AC-CTR-028 — Los huecos de la pantalla no se compactan *(verifica BR-CTR-023, BR-CTR-020)*

DADO Marolini sólo en el segundo o sólo en el tercero, CUANDO se repinta, imprime, cierra
y abre el programa ENTONCES la pantalla conserva ese renglón y el papel lleva sólo Marolini.
DADO el primero vacío, Marolini en el segundo y Coracola en el tercero ENTONCES imprimir
conserva esas posiciones y el papel lleva Marolini y Coracola, en ese orden. Borrar vacía
los 3 sin cambiar el papel, y los 3 vacíos no imprimen.

### AC-CTR-029 — Usar el hueco no se confunde con rechazar *(verifica BR-CTR-024)*

DADO una jornada manual, con el programa vacío o lleno, CUANDO se usa el hueco con unidad,
caja o manos vacías ENTONCES no se escribe ni se publica lectura, rechazo o sonido, y la
mano se conserva. El cuerpo mantiene alcance, colisión y foco real; su malla queda visible
y representa el hueco. DADO una nueva jornada automática ENTONCES vuelve la malla del lector
y una unidad vuelve a anotarse.

### AC-CTR-030 — Los menús conservan la selección durante la pausa *(verifica BR-CTR-023)*

DADO el programa manual, CUANDO se abren sus menús ENTONCES cada uno ofrece vacío primero
y el catálogo ordenado, y muestra la selección del mismo renglón; repintar no publica otra
elección ni sonidos. DADO una lista desplegada CUANDO se pulsa derecho ENTONCES se cierra
el programa conservando la mano. CUANDO se pulsa Esc ENTONCES la lista se oculta y se abre
la pausa vigente; reanudar conserva selecciones, mano y programa abierto, con control suspendido.

### AC-CTR-031 — Dos papeles producen dos descartes *(verifica BR-CTR-025)*

DADO dos tickets impresos CUANDO se llevan uno por vez a cada uno de los dos inodoros ENTONCES
cada ticket deja de existir y la mano queda vacía, con un aviso por ticket. CUANDO se repite ya
con mano vacía ENTONCES no se publica otro descarte. En automático o manual los renglones del
programa permanecen iguales.

### AC-CTR-032 — Descartar no sustituye la limpieza *(verifica BR-CTR-025)*

DADO una unidad, caja, mopa, balde, jabón o bolsa en la mano CUANDO se usa cualquiera de los
inodoros ENTONCES el levantable permanece en la mano y no hay aviso de descarte; el balde
conserva su vaciado y la mopa su enjuague. DADO un ticket CUANDO se usa cualquiera de los dos
lavatorios ENTONCES el papel sigue en la mano y no se publica descarte. Un objeto del mismo
nombre o identificador que un ticket conserva su tipo y no se desecha.

### AC-CTR-033 — La próxima jornada no vuelve a descartar *(verifica BR-CTR-025, BR-CTR-021)*

DADO un ticket desechado y otro ticket impreso todavía en el mundo CUANDO abre la próxima
jornada ENTONCES se retira el restante, los dos dejan de existir, la mano y el programa quedan
vacíos y no se publica un nuevo aviso de descarte ni se intenta liberar nuevamente el ya
desechado.

### AC-CTR-034 — Las dos ventanas *(verifica BR-CTR-026, BR-CTR-027)*

DADO la primera noche CUANDO pasan 21:59:59, 22:00:00, 23:59:59 y 00:00:00 ENTONCES Martín está
ausente, llega, espera y vence. DADO 03:59:59, 04:00:00, 05:59:59 y 06:00:00 ENTONCES ocurre
lo mismo con Tiago. Repetir cada instante no repite eventos. Los pedidos son los de BR-CTR-026.

### AC-CTR-035 — Cruces con la ventanilla cerrada *(verifica BR-CTR-027)*

DADO la ventanilla cerrada CUANDO el tiempo cruza toda la noche ENTONCES se publican llegada
de Martín, salida de Martín, llegada de Tiago y salida de Tiago, en ese orden, sin nadie esperando.
DADO Martín esperando CUANDO se cierra y reabre ENTONCES no hay nueva llegada; en pausa no vence.

### AC-CTR-036 — Prioridad de la conversación *(verifica BR-CTR-028, BR-CTR-029)*

DADO un objeto en la mano CUANDO se inicia y avanza la conversación inicial ENTONCES sólo
cambia una entrada por clic, sin recibir ni rechazar el objeto. Al terminar, manos vacías muestran
un recordatorio; un objeto correcto se recibe y ese clic no avanza una conversación.
Reabrir conserva el progreso y los nombres pedidos aparecen con negrita y color.

### AC-CTR-037 — Identidad y sobrantes *(verifica BR-CTR-029)*

DADO Tiago listo para recibir CUANDO recibe una Zucarachas ENTONCES falta otra.
Repetir esa identidad, ofrecer una tercera, un producto ajeno u otro objeto se rechaza sin
alterar entregas ni mano. El rechazo recuerda dos Zucarachas y un Pepito.

### AC-CTR-038 — El ticket es un multiconjunto *(verifica BR-CTR-029, BR-CTR-030)*

DADO Tiago CUANDO recibe un ticket con Pepito y dos Zucarachas en cualquier orden ENTONCES se
acepta. Una o tres Zucarachas, omitir Pepito o agregar otro producto se rechaza.
Sólo ticket o sólo productos dejan la compra incompleta y las ventas en cero.

### AC-CTR-039 — Venta y despedida *(verifica BR-CTR-030)*

DADO todos los elementos salvo uno CUANDO se recibe el último ENTONCES se registra una compra
y comienza la despedida. Repetir la recepción no registra otra compra. Completar antes del
límite conserva la venta durante la despedida; al terminarla se oculta al comprador.

### AC-CTR-040 — Perder una compra parcial *(verifica BR-CTR-027, BR-CTR-030, BR-CTR-031)*

DADO una compra parcial, incluso hablando, CUANDO llega el límite ENTONCES sale una vez,
se cierra el diálogo y sus productos y ticket dejan el mundo con él.
Las ventas de esa compra siguen en cero. Completar la otra no cumple atención.

### AC-CTR-041 — Ambas compras y reinicio *(verifica BR-CTR-026, BR-CTR-031)*

DADO la primera noche CUANDO se completa sólo Martín ENTONCES atención sigue sin cumplir.
Al completar Tiago, cuenta una vez; lo vendido es un Marolini, una Coracola, un Malbardo,
dos Zucarachas y un Pepito. Reabrir conserva ese resultado. Reiniciar crea estados nuevos
sin entregas ni ventas. Las jornadas 2–5 conservan el recorrido anterior.

### AC-CTR-042 — Dos animaciones y pausa *(verifica BR-CTR-032)*

DADO cada comprador presente CUANDO se abre la ventanilla ENTONCES su animación tiene ocho
dibujos en orden y bucle, cada uno durante 0,5 segundos. Al transcurrir cuadros cambia la pose.
La pausa conserva pose y progreso; al reanudar continúa. Al irse deja de verse.

## No objetivos

- Esta capacidad NO decide cuántas unidades hay ni dónde están: se lo pregunta a
  [`store-stock`](../store-stock/store-stock.md).
- Esta capacidad NO escribe el contenido de lo que dicen los compradores.
- Esta capacidad NO descuenta tiempo del turno. Atender cuesta porque el reloj corre.

## Contratos

- **Entrada:** el padrón de la noche, los vendibles de cada producto, el objeto leído y los
  pedidos de borrar o imprimir, el número de jornada, las elecciones por renglón y el objeto
  sostenido con su destino de uso.
- **Salida:** quién está en la ventanilla, el pedido, el total, la diferencia, el aviso de
  faltantes, cuántos van despachados, el desvío de la noche, lo vendido de cada producto y el
  papel impreso o desechado.
- **Falla:** un pedido que supera sus vendibles se rechaza entero; una atención despachada
  rechaza todo lo demás. Fuera de la entrega al comprador, usar un objeto que no sea ticket,
  o un destino distinto del inodoro, no produce descarte.

## Señales

- El modo con el que arranca el programa, la lectura correcta o rechazada con su motivo,
  los renglones cambiados, el ticket impreso y el descarte de un ticket.
- El comprador que llega, la entrada de diálogo mostrada, el diálogo cerrado y la atención
  despachada.

## Dependencias

- [`store-stock`](../store-stock/store-stock.md) (consume y alimenta): los vendibles y el cobro;
  y lo vendido de cada producto, contra lo que se compara la planilla de registrar.
- [`player-actions`](../player-actions/player-actions.md) (consume y alimenta): lo sostenido
  llega al lector; imprimir produce un papel levantable que se retira en otra jornada.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (consume y alimenta): el número de jornada
  decide el modo del programa; se avisa cuándo la obligatoria quedó cumplida.
- [`store-cleanup`](../store-cleanup/store-cleanup.md) (consume): distingue inodoro y lavatorio;
  desechar papel conserva los efectos de limpieza de las herramientas.

## Preguntas abiertas

- **OQ-CTR-001 — ¿Qué le pasa al jugador que cobra mal toda la noche?**
  - Por qué sigue abierta: el desvío acumulado se calcula y todavía no lo consume nadie. El GDD
    no dice si el jefe lo descuenta, lo comenta o lo ignora.
  - Decide: el dueño del repo.
  - Bloquea: nada de lo escrito acá. Abriría una regla en
    [`employment-record`](../employment-record/employment-record.md).
- **OQ-CTR-002 — ¿Cuántos compradores vienen por noche, y cuánto compra cada uno?**
  - Por qué sigue abierta: para las jornadas 2–5 game design dio un margen de 1 a 3 compradores, con 1 a 3 productos
    cada uno, y no eligió un valor. Con pocos vendibles por producto, un padrón que pide de más
    deja ventas que se rechazan.
  - Decide: game design.
  - Bloquea: nada. Cambiaría `BR-CTR-001` y el padrón.
