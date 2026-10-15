---
schema_version: 1
capability_id: CAP-CTR
status: draft
owner: por definir
provenance: GDD «Atención por ventanilla»; fichas «Formas de interacción», «Atención al cliente» y «Diálogos de compradores», decisiones de #429 y #433; migración de los specs 013, 035
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

En las jornadas 3 a 5 se aplica el recorrido anterior:

El sistema DEBE hacer pasar **2 compradores por jornada**, tomados en orden de un padrón fijo. El
padrón no se sortea: un sorteo daría noches distintas con el mismo balance.

### BR-CTR-002 — La caja no vuelve a sumar

En las jornadas 3 a 5 se aplica el recorrido anterior:

El sistema DEBE tomar el total de la caja del pedido y no recalcularlo. Una segunda suma daría el
mismo número hasta el día que cambie el catálogo, y ahí las dos ventanas dirían distinto.

### BR-CTR-003 — La diferencia lleva signo

En las jornadas 3 a 5 se aplica el recorrido anterior:

El sistema DEBE calcular la diferencia como **lo que paga menos el total**. Positiva es que pagó
de más y negativa que pagó de menos: el valor absoluto haría indistinguibles los dos casos.

### BR-CTR-004 — Alguien paga distinto

En las jornadas 3 a 5 se aplica el recorrido anterior:

El padrón DEBE incluir al menos un comprador que paga de más y uno que paga de menos. Un padrón
donde todos pagan justo deja la ventanilla sin nada que mirar.

### BR-CTR-006 — El cobro es todo o nada

En las jornadas 3 a 5 se aplica el recorrido anterior:

SI alguna línea del pedido supera los vendibles de su producto, ENTONCES el sistema DEBE
rechazar el cobro entero y **no mover una sola unidad**. Descontar lo que se pueda deja un
estado que el jugador no distingue de una venta completa.

### BR-CTR-007 — Se puede despachar sin vender

En las jornadas 3 a 5 se aplica el recorrido anterior:

El sistema DEBE permitir despachar a un comprador sin cobrarle nada. Un pedido puede superar los
vendibles de la noche, y exigir la venta dejaría a ese comprador sin forma de irse.

### BR-CTR-008 — Un comprador se despacha una vez

SI la atención ya está despachada, ENTONCES el sistema DEBE rechazar cobrarla o despacharla otra
vez, y no cambiar nada.

### BR-CTR-009 — La obligatoria es atender, no vender

En las jornadas 3 a 5 se aplica el recorrido anterior:

CUANDO todos los compradores de la noche quedaron despachados, el sistema DEBE dar la obligatoria
por cumplida, **contando igual las dos formas**: vender y despachar sin vender.

### BR-CTR-010 — El desvío suma sólo lo cobrado

CUANDO se suma cuánto se desvió la caja en la noche, el sistema DEBE contar **sólo las atenciones
cobradas** y conservar los signos. Al que se despachó sin vender no se le cobró nada, así que su
diferencia no es plata que falte.

### BR-CTR-011 — La ventanilla dice qué falta

En las jornadas 3 a 5 se aplica el recorrido anterior:

SI el pedido tiene productos que superan sus vendibles, ENTONCES el sistema DEBE nombrarlos, en
el orden del pedido. Es la explicación de por qué el cobro va a fallar.

### BR-CTR-012 — El pedido no da la cuenta hecha

En las jornadas 3 a 5 se aplica el recorrido anterior:

El sistema DEBE mostrar las líneas del pedido **sin el precio de cada una**, y mostrar aparte el
total, lo que paga y la diferencia. Repartir el precio por renglón le daría al jugador la cuenta
hecha justo donde el juego puede mentir.

### BR-CTR-013 — El comprador habla de a una entrada

MIENTRAS el comprador habla, el sistema DEBE avanzar **una entrada por clic izquierdo** y DEBE
impedir abandonar la ventanilla. Una conversación sin líneas no encierra a nadie: se puede
abandonar desde el principio.

### BR-CTR-014 — La venta sale del depósito, y deja el estante como está

En las jornadas 3 a 5 se aplica el recorrido anterior:

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
La segunda jornada DEBE usar el padrón definido en BR-CTR-037, sin copiar estos personajes.
Las jornadas 3 a 5 DEBEN conservar su recorrido anterior.

### BR-CTR-027 — Llegada y vencimiento independientes de la interfaz

EN la primera jornada, CUANDO se cruza una llegada, el sistema DEBE publicar una sola llegada aunque la ventanilla esté
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
DEBE conservar el resultado aunque la despedida continúe. Al terminarla, la atención DEBE
quedar despachada; la imagen del comprador DEBE retirarse según BR-CTR-033.

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
MIENTRAS espera, DEBE verse detrás de la ventanilla dentro del mundo aunque la interfaz esté
cerrada. Su dibujo DEBE mantener posición y orientación fijas hacia el interior del local,
sin seguir al jugador ni girar con su cámara. DEBE cambiar de tamaño aparente con la distancia
y quedar oculto por la geometría del local. El antepecho DEBE ocultar
siempre el corte inferior del dibujo desde las posiciones accesibles del local.
Abrir o cerrar la interfaz NO DEBE
reiniciar ni detener su animación. El diálogo conserva el diseño de Figma en pantalla.

La llegada de la primera noche usa la entrada de BR-CTR-034; la posición fija corresponde
a la espera posterior a esa entrada.

### BR-CTR-033 — Salida visible de los compradores

EN la primera noche, CUANDO termina una despedida después de vender o una compra incompleta
vence, el comprador DEBE deslizarse hacia la derecha, vista desde el interior frente a la
ventanilla, hasta quedar detrás de la pared. DEBE permanecer animado mientras sale del hueco
y retirarse definitivamente después de quedar oculto; volver a mirar NO DEBE hacerlo reaparecer.
Ya despachado NO DEBE recibir objetos ni reiniciar conversaciones, y su presencia NO DEBE
retrasar la venta, el registro ni las tareas. NO DEBE girar, inclinarse ni cambiar de altura
o profundidad. La pausa DEBE detener el movimiento y la animación.
Cerrar o reiniciar la jornada DEBE retirar también las imágenes pendientes de salida.

### BR-CTR-034 — Entrada desde la izquierda

EN la primera noche, CUANDO llega cada comprador, su imagen DEBE deslizarse desde detrás de
la pared izquierda, vista desde el interior frente a la ventanilla, hasta su sitio de espera.
DEBE conservar el idle, altura, profundidad y orientación durante la entrada y detenerse
en ese sitio. Abrir, cerrar o repintar la interfaz NO DEBE repetir la entrada.
La pausa DEBE detener desplazamiento y animación. Reiniciar o cerrar el turno DEBE retirar
la imagen en movimiento. La entrada NO DEBE adelantar ni retrasar horarios o avisos.

### BR-CTR-035 — La persona inicia la atención directamente

CUANDO se pulsa izquierdo sobre el comprador vigente desde el mundo, el sistema DEBE iniciar
su conversación inicial en esa pulsación, incluso con un objeto sostenido, sin recibirlo ni
rechazarlo. Después de terminar la inicial, con mano vacía DEBE iniciar un recordatorio y con
objeto DEBE intentar recibirlo directamente según BR-CTR-029. Cada pulsación DEBE producir una
sola interacción. Reabrir NO DEBE reiniciar pedido, inicial ni entregas. El comprador ausente,
vencido o despachado NO DEBE recibir ni iniciar otra conversación.

### BR-CTR-036 — Cada diálogo devuelve al mundo al terminar

CUANDO termina la inicial, un recordatorio, un rechazo o una despedida, el sistema DEBE avisar
su fin y devolver automáticamente la vista y movimiento normales, sin otro clic derecho.
El clic final NO DEBE activar otra interacción. MIENTRAS habla, el izquierdo DEBE avanzar una
entrada, el derecho NO DEBE abandonar, ningún clic DEBE entregar ni soltar y el reloj DEBE
seguir corriendo salvo pausa. Vencimiento y cierre DEBEN terminar conversación y encuadre.

### BR-CTR-037 — La segunda jornada tiene dos compras físicas por horario

El sistema DEBE declarar para la segunda jornada exactamente Fede y Mía, con identidad propia:

| Comprador | Llega, incluido | Vence, excluido | Desde apertura hasta llegada | Desde apertura hasta vencimiento |
|---|---|---|---|---|
| Fede | 20:30 | 23:30 | 30 minutos | 210 minutos |
| Mía | 05:00 | 08:00 | 540 minutos | 720 minutos |

Los horarios proceden de «Atención al cliente» y se miden en el reloj ficticio desde la apertura
de turno declarada por el dominio. La agenda DEBE publicar una sola llegada y un solo vencimiento
por compra incompleta, conservar la identidad original y procesar todos los cruces en orden.
La pausa DEBE detenerlos. Al llegar el cierre, DEBE procesar el límite de Mía antes de evaluar
las tareas. Una compra completada antes de su límite NO DEBE vencer.
Cada compra DEBE recibir unidades físicas y ticket exacto según BR-CTR-029 y vender una vez
según BR-CTR-030, sin descuento automático adicional. Atención DEBE cumplirse sólo con ambas
compras completas. Al vencer, los productos recibidos DEBEN quedar recogibles en el piso del
local frente a la ventanilla, del lado de adentro, sin venta; el ticket aceptado DEBE descartarse.
Una apertura nueva DEBE crear estados nuevos sin heredar entregas, conversaciones ni ventas.

### BR-CTR-038 — Un pedido al azar por comprador y apertura

CUANDO se construye el padrón definido de la segunda jornada, el sistema DEBE generar para cada
comprador un pedido de tres unidades válidas del catálogo, admitiendo repeticiones y agrupándolas
por producto. El azar DEBE recibirse como entrada controlable. El pedido DEBE permanecer idéntico
al consultar, recordar, rechazar, entregar y abrir o cerrar interfaces. Reposición y atención
DEBEN recibir los mismos pedidos ya construidos de la apertura; ninguna consulta DEBE sortear
otra vez. Otra apertura DEBE construir sus propios pedidos y estados. Un catálogo vacío o una
selección inválida DEBEN fallar explícitamente, sin publicar un pedido parcial o inválido.

### BR-CTR-039 — Los textos comunes usan el pedido real

CUANDO se pide recordatorio, el sistema DEBE usar «Quiero [producto1].», «Quiero [producto1] y
[producto2].» o «Quiero [producto1], [producto2] y [producto3].», según los tipos distintos del
pedido. Un rechazo DEBE anteponer «Yo no pedí esto. ». Con todos los productos recibidos y sólo
el ticket pendiente DEBE decir «Gracias. Me das el recibo, ¿por favor?».
Para una unidad, cada marcador DEBE usar el subtítulo del producto con primera letra minúscula
y sin punto final. Para más de una DEBE usar «dos» o «tres» seguido del nombre del producto.
Los productos DEBEN llevar el resaltado amarillo común. En jornada 2 NO DEBE inventarse una
pista dentro de esos textos.

### BR-CTR-040 — La ausencia de contenido específico es explícita

MIENTRAS Fede o Mía carezcan de conversación inicial, despedida o arte propios aprobados, el
sistema DEBE declarar esa ausencia y mantener el padrón definido disponible por solicitud
explícita, sin activarlo automáticamente en el mundo. NO DEBE sustituirlos por otro personaje
ni considerar una conversación vacía contenido aprobado. Los textos comunes y los pedidos
DEBEN poder consultarse y ejercerse independientemente de esa integración.

## Criterios de aceptación

### AC-CTR-001 — Dos por noche *(verifica BR-CTR-001)*

DADO una jornada entre la 3 y la 5 CUANDO se piden sus compradores del padrón ENTONCES son 2, son los dos primeros
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
al tercer avance se vuelve automáticamente a la vista normal. Con cero entradas no hay
bloqueo; la ausencia de contenido propio se distingue según BR-CTR-040.

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
límite conserva la venta durante la despedida; al terminarla la atención queda despachada
y su imagen conserva la salida de BR-CTR-033.

### AC-CTR-040 — Perder una compra parcial *(verifica BR-CTR-027, BR-CTR-030, BR-CTR-031)*

DADO una compra parcial, incluso hablando, CUANDO llega el límite ENTONCES sale una vez,
se cierra el diálogo y sus productos y ticket dejan el mundo con él.
Las ventas de esa compra siguen en cero. Completar la otra no cumple atención.

### AC-CTR-041 — Ambas compras y reinicio *(verifica BR-CTR-026, BR-CTR-031)*

DADO la primera noche CUANDO se completa sólo Martín ENTONCES atención sigue sin cumplir.
Al completar Tiago, cuenta una vez; lo vendido es un Marolini, una Coracola, un Malbardo,
dos Zucarachas y un Pepito. Reabrir conserva ese resultado. Reiniciar crea estados nuevos
sin entregas ni ventas. Las jornadas 3–5 conservan el recorrido anterior; la segunda usa BR-CTR-037.

### AC-CTR-042 — Dos animaciones y pausa *(verifica BR-CTR-032)*

DADO cada comprador presente CUANDO se abre la ventanilla ENTONCES su animación tiene ocho
dibujos en orden y bucle, cada uno durante 0,5 segundos. Al transcurrir cuadros cambia la pose.
La pausa conserva pose y progreso; al reanudar continúa. Al irse deja de verse.
DADO la interfaz cerrada y el jugador recorriendo el local ENTONCES el comprador sigue animado
detrás del hueco, con posición y orientación fijas hacia el interior del local; la pared lo
oculta y no hay una copia en la interfaz. Al desplazarse el jugador o girar su cámara, el
comprador no gira ni se inclina; el corte inferior queda detrás del antepecho.

### AC-CTR-043 — La venta también sale por la derecha *(verifica BR-CTR-030, BR-CTR-033)*

DADO una compra completa CUANDO todavía habla ENTONCES el comprador permanece en su sitio.
CUANDO termina la despedida ENTONCES se desliza hacia la derecha, conservando animación,
altura, profundidad y orientación hasta quedar detrás de la pared; después no reaparece.
No recibe más objetos. Cerrar la interfaz no interrumpe su salida y las ventas y tareas
conservan su resultado.

### AC-CTR-044 — El cansancio sale por la derecha *(verifica BR-CTR-027, BR-CTR-032, BR-CTR-033)*

DADO un comprador que espera, incluso con entregas parciales, CUANDO vence ENTONCES empieza
a deslizarse hacia la derecha de la ventanilla y sigue visible mientras sale del hueco.
Conserva altura, profundidad y orientación; la pared oculta su dibujo antes de retirarlo.
Pausar detiene pose y desplazamiento; reanudar los continúa. Las ventas siguen en cero.
Cerrar o reiniciar la jornada retira cualquier imagen pendiente, también la de una venta completa.

### AC-CTR-045 — Ambos entran desde la izquierda *(verifica BR-CTR-034, BR-CTR-032)*

DADO cada comprador de la primera noche CUANDO llega con la interfaz cerrada ENTONCES aparece
deslizándose desde la izquierda hasta el sitio de espera, conservando altura, profundidad,
orientación y animación. Después permanece quieto. Abrir, cerrar y repintar no reinician el
movimiento. Pausar lo congela y reanudar lo continúa; reiniciar o cerrar el turno lo retira.

### AC-CTR-046 — Una entrada por pulsación desde el mundo *(verifica BR-CTR-035, BR-CTR-028)*

DADO un comprador sin atender y un ticket en mano CUANDO se pulsa izquierdo una vez sobre la
persona ENTONCES aparece la primera entrada inicial, sin entrega ni rechazo. El siguiente
izquierdo avanza exactamente una entrada. Repetir con mano vacía conserva la misma secuencia.

### AC-CTR-047 — Terminar devuelve automáticamente *(verifica BR-CTR-036, BR-CTR-013)*

DADO, por turno, inicial, recordatorio, rechazo y despedida de una entrada CUANDO se avanza
ENTONCES el diálogo queda terminado y se devuelve la vista normal una vez, sin clic derecho y
sin otra interacción. Derecho durante la entrada no la cierra; Esc pausa y al reanudar queda
la misma entrada. Hablar sin pausa no detiene el reloj.

### AC-CTR-048 — Recordar y entregar conservan el pedido *(verifica BR-CTR-035, BR-CTR-029, BR-CTR-030)*

DADO inicial terminada CUANDO se pulsa con mano vacía ENTONCES empieza recordatorio. Al terminarlo,
una pulsación con unidad pendiente recibe sólo ese cuerpo; una con objeto ajeno conserva mano y
entregas y muestra rechazo. Repetir apertura no repite inicial ni vacía entregas. Recibir el
último elemento vende una vez y abre despedida; terminarla no repite venta ni entrega.

### AC-CTR-049 — Ausencia y vencimiento no dejan atención activa *(verifica BR-CTR-035, BR-CTR-036)*

DADO ningún comprador llegado, un comprador vencido y uno despachado, por turno, CUANDO se pulsa
sobre el hueco o la imagen en retirada ENTONCES no hay diálogo ni recepción. DADO conversación
activa CUANDO vence o cierra la jornada ENTONCES termina el encuadre y desaparece el foco sin
otro derecho; conserva el resultado y destino de cada objeto que fija la compra.

### AC-CTR-050 — Las fronteras de Fede y Mía *(verifica BR-CTR-037)*

DADO el padrón definido de jornada 2 CUANDO se recorren 20:29:59, 20:30:00, 23:29:59 y 23:30:00
ENTONCES Fede está ausente, llega, espera y vence si no completó. En 04:59:59, 05:00:00,
07:59:59 y 08:00:00 ocurre lo mismo con Mía. Repetir cada instante no repite eventos.
Saltar desde apertura a cierre entrega llegada Fede, vencimiento Fede, llegada Mía y vencimiento
Mía, en ese orden, cada uno con su comprador original; en pausa no cruza ninguno.

### AC-CTR-051 — Tres unidades admiten uno, dos o tres tipos *(verifica BR-CTR-038)*

DADO azar controlado que entrega, por turno, A/A/A, A/A/B y A/B/C de un catálogo válido CUANDO se
construye cada pedido ENTONCES contiene tres unidades agrupadas en uno, dos y tres tipos,
respectivamente. Catálogo vacío o selección inexistente falla explícitamente sin pedido válido.
Una apertura crea dos compradores nuevos con identidad Fede/Mía; otra no hereda su estado.

### AC-CTR-052 — Consultar nunca vuelve a sortear *(verifica BR-CTR-038)*

DADO una apertura con los dos pedidos construidos CUANDO se consultan faltantes y atención en
ambos órdenes, se recuerda, rechaza, entrega y reabre ENTONCES ambos consumidores conservan los
mismos pedidos y la fuente de azar no recibe nuevas solicitudes. Otra apertura sí construye
sus propios pedidos, aunque el azar pueda volver a seleccionar los mismos productos.

### AC-CTR-053 — Marcadores, cantidades y rechazo *(verifica BR-CTR-039)*

DADO pedidos A/A/A, A/A/B y A/B/C CUANDO se consulta recordatorio ENTONCES se usa respectivamente
la forma de uno, dos y tres marcadores, sin marcadores sin reemplazar. A/A/A usa «tres» y el
nombre A; A/A/B usa «dos» y el nombre A, y para B el subtítulo con inicial minúscula y sin punto
final. Un rechazo antepone exactamente «Yo no pedí esto. ». Los productos llevan amarillo y
ningún fragmento se ofrece como pista. Con los tres productos y sin ticket el texto es
exactamente «Gracias. Me das el recibo, ¿por favor?».

### AC-CTR-054 — El cierre procesa primero la compra de Mía *(verifica BR-CTR-037)*

DADO Fede vendido y Mía con tres productos entregados sin ticket CUANDO llega 08:00 ENTONCES
Mía vence antes de evaluar: atención queda pendiente, sus tres cuerpos vuelven al piso interior
recogibles y no cuentan como venta. DADO Mía completa a 07:59:59 ENTONCES ambas compras cuentan
una vez y atención queda cumplida, aunque la despedida siga. Repetir el cierre no duplica salidas.

### AC-CTR-055 — Recepción física y destinos de jornada 2 *(verifica BR-CTR-037, BR-CTR-029, BR-CTR-030)*

DADO un pedido A/A/B en el modelo de jornada 2 y una conversación de prueba explícita CUANDO se
entrega ticket exacto antes de los productos ENTONCES se acepta y aún no vende. Dos cuerpos A
distintos y uno B completan una venta; repetir un cuerpo, una tercera A o un ticket inexacto se
rechaza sin cambiar mano ni cantidades. DADO una compra incompleta con ticket y dos productos
CUANDO vence ENTONCES el ticket desaparece y ambos productos quedan dentro del local, sin venta.
Una apertura posterior no hereda esos cuerpos ni entregas.

### AC-CTR-056 — Contenido incompleto no suplanta personajes *(verifica BR-CTR-040)*

DADO Fede/Mía con pedidos y textos comunes, sin guion específico ni arte propios CUANDO se
solicita ese contenido ENTONCES se informa su ausencia, sin frases ni imágenes de otro
comprador. Abrir el juego no activa automáticamente ese padrón ni inicia una conversación
vacía. Solicitar explícitamente los datos sí entrega agenda, pedidos y textos comunes válidos.

## No objetivos

- Esta capacidad NO decide cuántas unidades hay ni dónde están: se lo pregunta a
  [`store-stock`](../store-stock/store-stock.md).
- Esta capacidad NO escribe el contenido de lo que dicen los compradores.
- Esta capacidad NO descuenta tiempo del turno. Atender cuesta porque el reloj corre.

## Contratos

- **Entrada:** el padrón de la noche, los vendibles de cada producto, el objeto leído y los
  pedidos de borrar o imprimir, el número de jornada, las elecciones por renglón y el objeto
  sostenido con su destino de uso; catálogo, fuente de azar y solicitud explícita del padrón
  definido de jornada 2, compartido por atención y reposición.
- **Salida:** quién está en la ventanilla, el pedido, el total, la diferencia, el aviso de
  faltantes, cuántos van despachados, el desvío de la noche, lo vendido de cada producto y el
  papel impreso o desechado; agenda y pedidos estables de jornada 2, textos comunes y ausencia
  explícita de contenido propio sin aprobar.
- **Falla:** un pedido que supera sus vendibles se rechaza entero; una atención despachada
  rechaza todo lo demás. Fuera de la entrega al comprador, usar un objeto que no sea ticket,
  o un destino distinto del inodoro, no produce descarte. Un catálogo vacío o selección
  inválida no produce un pedido válido; contenido específico ausente no activa al personaje.

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
  - Por qué sigue abierta: para las jornadas 3–5 game design dio un margen de 1 a 3 compradores, con 1 a 3 productos
    cada uno, y no eligió un valor. Con pocos vendibles por producto, un padrón que pide de más
    deja ventas que se rechazan.
  - Decide: game design.
  - Bloquea: nada. Cambiaría `BR-CTR-001` y el padrón. La jornada 2 está decidida en BR-CTR-037.

- **OQ-CTR-006 — ¿Cuáles son la inicial, despedida y originales visuales de Fede y Mía?**
  - Por qué sigue abierta: las fichas de jornada 2 fijan agenda y textos comunes, pero los
    guiones específicos siguen sin escribir y la ficha de sprites no enlaza los originales.
  - Decide: game design y arte.
  - Bloquea: activación automática de Fede/Mía en el mundo; no bloquea sus datos ni agenda.
