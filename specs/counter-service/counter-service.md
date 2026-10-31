---
schema_version: 1
capability_id: CAP-CTR
status: ratified
owner: por definir
provenance: GDD «Atención por ventanilla»; fichas «Atención al cliente» y «Diálogos de compradores»; base «Productos y cajas contenedoras»; decisiones de #365, #366, #429, #433, #444 y #694; pedidos fijos y guiones de jornada 2 decididos el 15 de octubre de 2026; migración de los specs 013, 035; ocho jornadas de #526; horarios de Tin y Tia en la jornada 1 y de Fede y Mía en la jornada 2 de «Atención al cliente» del 21 de octubre de 2026 (#605); agenda de compradores de las jornadas 3 a 5 de «Atención al cliente» y textos predeterminados de «Diálogos de compradores» del 21 de octubre de 2026 (#459); diálogos de entrega como subtítulo de GJ-57 (#564); agendas de la noche del corte de luz y de la última noche de «Atención al cliente» del 30 de octubre de 2026, con las decisiones de Mía y de Durextra (#694)
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

Las reglas de interacción directa sobre la figura, foco de silueta y retorno automático del diálogo
se aplican al recorrido de atención física con comprador representado en el mundo.
Las jornadas sin agenda propia DEBEN conservar su recorrido genérico anterior sin figura, incluido el acceso al
panel de cobro. Sólo en ese recorrido genérico se admite una consulta de acceso en el hueco:
NO DEBE bloquear al jugador ni los objetos sostenidos, ni permanecer activa al usar atención física.
La barrera de vidrio NO DEBE existir en ningún recorrido. Esta excepción NO DEBE convertir el hueco,
marco o antepecho en objetivos de atención física ni inventar figuras para ellas.

### BR-CTR-001 — Dos compradores por noche

En las jornadas sin agenda se aplica el recorrido anterior:

El sistema DEBE hacer pasar **2 compradores por jornada**, tomados en orden de un padrón fijo. El
padrón no se sortea: un sorteo daría noches distintas con el mismo balance.

### BR-CTR-002 — La caja no vuelve a sumar

En las jornadas sin agenda se aplica el recorrido anterior:

El sistema DEBE tomar el total de la caja del pedido y no recalcularlo. Una segunda suma daría el
mismo número hasta el día que cambie el catálogo, y ahí las dos ventanas dirían distinto.

### BR-CTR-003 — La diferencia lleva signo

En las jornadas sin agenda se aplica el recorrido anterior:

El sistema DEBE calcular la diferencia como **lo que paga menos el total**. Positiva es que pagó
de más y negativa que pagó de menos: el valor absoluto haría indistinguibles los dos casos.

### BR-CTR-004 — Alguien paga distinto

En las jornadas sin agenda se aplica el recorrido anterior:

El padrón DEBE incluir al menos un comprador que paga de más y uno que paga de menos. Un padrón
donde todos pagan justo deja la ventanilla sin nada que mirar.

### BR-CTR-006 — El cobro es todo o nada

En las jornadas sin agenda se aplica el recorrido anterior:

SI alguna línea del pedido supera los vendibles de su producto, ENTONCES el sistema DEBE
rechazar el cobro entero y **no mover una sola unidad**. Descontar lo que se pueda deja un
estado que el jugador no distingue de una venta completa.

### BR-CTR-007 — Se puede despachar sin vender

En las jornadas sin agenda se aplica el recorrido anterior:

El sistema DEBE permitir despachar a un comprador sin cobrarle nada. Un pedido puede superar los
vendibles de la noche, y exigir la venta dejaría a ese comprador sin forma de irse.

### BR-CTR-008 — Un comprador se despacha una vez

SI la atención ya está despachada, ENTONCES el sistema DEBE rechazar cobrarla o despacharla otra
vez, y no cambiar nada.

### BR-CTR-009 — La obligatoria es atender, no vender

En las jornadas sin agenda se aplica el recorrido anterior:

CUANDO todos los compradores de la noche quedaron despachados, el sistema DEBE dar la obligatoria
por cumplida, **contando igual las dos formas**: vender y despachar sin vender.

### BR-CTR-010 — El desvío suma sólo lo cobrado

CUANDO se suma cuánto se desvió la caja en la noche, el sistema DEBE contar **sólo las atenciones
cobradas** y conservar los signos. Al que se despachó sin vender no se le cobró nada, así que su
diferencia no es plata que falte.

### BR-CTR-011 — La ventanilla dice qué falta

En las jornadas sin agenda se aplica el recorrido anterior:

SI el pedido tiene productos que superan sus vendibles, ENTONCES el sistema DEBE nombrarlos, en
el orden del pedido. Es la explicación de por qué el cobro va a fallar.

### BR-CTR-012 — El pedido no da la cuenta hecha

En las jornadas sin agenda se aplica el recorrido anterior:

El sistema DEBE mostrar las líneas del pedido **sin el precio de cada una**, y mostrar aparte el
total, lo que paga y la diferencia. Repartir el precio por renglón le daría al jugador la cuenta
hecha justo donde el juego puede mentir.

### BR-CTR-013 — El comprador habla de a una entrada

MIENTRAS el comprador habla, el sistema DEBE avanzar **una entrada por clic izquierdo** y DEBE
impedir abandonar la ventanilla. Una conversación sin líneas no encierra a nadie: se puede
abandonar desde el principio.

### BR-CTR-014 — La venta sale del depósito, y deja el estante como está

En las jornadas sin agenda se aplica el recorrido anterior:

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

### BR-CTR-022 — Desde la quinta noche se escribe a mano

DESDE la jornada 5 y hasta el fin de la partida, el programa DEBE ser manual. Antes DEBE ser
automático. El modo DEBE salir del número de jornada: retomar una partida en la 6 no recupera
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

### BR-CTR-026 — La primera jornada recibe a Tin y Tia por horario

EN la jornada 1, el sistema DEBE recibir a Tin a las 20:30 y despedirlo a las 23:00. La llegada
se incluye y el límite se excluye. Tia DEBE llegar 30 minutos de juego después de que Tin se
retira, ya sea porque su compra se completó o porque venció, lo que ocurra primero, y DEBE irse
150 minutos de juego después de su llegada si su compra no se completó antes. Con Tin sin atender,
Tia llega a las 23:30 y se va a las 02:00, cruzando la medianoche. La pausa DEBE detener los dos
plazos.

Tin DEBE pedir un Marolini, una Coracola y un Malbardo. Tia DEBE pedir una Zucarachas
y un Pepito, con sus diálogos y su recepción física. Estos horarios DEBEN derivarse del reloj
del turno, cuya apertura es a las 20:00. La segunda jornada DEBE usar el padrón definido en
BR-CTR-037, sin copiar estos personajes. Las jornadas 3 a 5 usan las agendas de BR-CTR-044 a
BR-CTR-046, la noche del corte de luz y la última noche las de BR-CTR-051 y BR-CTR-052, y el
padrón de BR-CTR-001 queda para las jornadas sin agenda.

### BR-CTR-027 — Llegada y vencimiento independientes de la interfaz

CUANDO se cruza una llegada, el sistema DEBE publicar una sola llegada aunque la ventanilla esté
cerrada. Repetir un instante o reabrir NO DEBE llamar ni repetir al comprador.
CUANDO se cruza el límite con una compra incompleta, el sistema DEBE publicar una sola salida,
cerrar su conversación y dejar todos los productos recibidos apoyados en el piso del local
frente a la ventanilla, del lado de adentro. DEBEN conservar su identidad y quedar visibles,
con física y recogibles, sin superponerse entre sí, con el jugador ni con los sólidos del local.
DEBEN seguir registrados afuera de su caja, sin cambiar depósito, contenido de caja ni góndola
por el vencimiento y sin contar como venta. DEBEN admitir los mismos gestos y consecuencias
de cualquier unidad suelta: agarrar, colocar en su casillero vacío, devolver a su caja o tirar
al contenedor. Dejarlos en el piso interior al cierre DEBE contar como desorden, sin producir
el motivo de objeto afuera, según [`store-cleanup`](../store-cleanup/store-cleanup.md).
El ticket aceptado DEBE descartarse y NO DEBE aparecer en el piso. Sin productos recibidos
NO DEBE aparecer ninguna unidad. Repetir el vencimiento NO DEBE duplicar ni volver a soltar
las unidades. Una compra completa DEBE retirar sus productos y ticket con el comprador.
Un salto DEBE procesar todos los cruces en orden. Una compra completa NO DEBE vencer.
Cerrar la ventanilla NO DEBE detener el horario; la pausa DEBE detenerlo.

### BR-CTR-028 — Primero hablar, después recibir

CUANDO se hace clic izquierdo sobre el comprador por primera vez, el sistema DEBE iniciar su
conversación inicial. Cada clic siguiente DEBE avanzar una entrada. MIENTRAS habla, los objetos
NO DEBEN recibirse ni rechazarse. Terminada esa conversación, un clic con manos vacías DEBE
mostrar un recordatorio de una entrada. Mientras una entrada de la inicial o de la despedida esté
activa, el clic DEBE avanzar el diálogo. Terminada la entrada, con objeto sostenido DEBE intentar
recibirlo sin avanzar diálogo en el mismo clic. Reabrir DEBE conservar el estado.
Los textos DEBEN conservar el diseño de Figma y usar las cantidades del pedido de la ficha
«Atención al cliente»: un Marolini para Tin, Coracola en lugar de Pura-Cola y una Zucarachas
para Tia. La tabla de pedidos DEBE prevalecer sobre cantidades distintas en los diálogos.
CUANDO un recordatorio o rechazo nombra una unidad, el sistema DEBE usar el subtítulo al
examinar de la base «Productos y cajas contenedoras», con primera letra en minúscula y sin
el punto final: el mismo que lee el jugador al examinar ese producto.

El recordatorio y el rechazo de Tin y Tia DEBEN seguir BR-CTR-039, como los de cualquier
comprador. Los textos de sus entradas DEBEN ser los de la ficha «Diálogos de compradores», y
los nombres de los productos pedidos DEBEN distinguirse con color, sin negrita.
La presentación de los productos de jornada 2 DEBE seguir BR-CTR-043.

### BR-CTR-029 — Productos pendientes y ticket exacto

El sistema DEBE aceptar una unidad física distinta de cada producto todavía pendiente y un
ticket con las cantidades exactas del pedido. El orden del ticket NO DEBE importar.
Una unidad repetida, extra, producto ajeno, ticket incorrecto u otro objeto DEBE rechazarse
sin alterar mano, entregas ni ventas. Una unidad ya recibida, o de un producto del pedido que
ya llegó entero, DEBE contestarse con el agradecimiento de lo ya entregado; lo demás, con el
texto de rechazo.
Antes de terminar la conversación inicial NO DEBE haber recepción ni rechazo.

### BR-CTR-030 — La compra completa vende una vez

SÓLO al recibir todos los productos y el ticket, el sistema DEBE registrar la compra una vez
y comenzar su despedida. Los botones de cobro y despacho NO DEBEN ofrecerse en las jornadas 1 a
5.
Las entregas parciales NO DEBEN contar como ventas. La recepción DEBE usar las unidades físicas,
sin ejecutar además el descuento automático del pedido. Completar la compra antes del límite
DEBE conservar el resultado aunque la despedida continúe. Al terminarla, la atención DEBE
quedar despachada; la imagen del comprador DEBE retirarse según BR-CTR-033.

### BR-CTR-031 — Atención y registro siguen a los compradores que ya llegaron

EN toda jornada con compradores por horario, MIENTRAS llegó al menos un comprador y todos los que
llegaron quedaron vendidos, atención DEBE figurar cumplida. CUANDO llega el comprador siguiente,
atención DEBE volver a pendiente. Una compra perdida DEBE dejar la tarea pendiente el resto de la
noche, aunque se complete la otra.
MIENTRAS llegó al menos un comprador y todos los que llegaron quedaron cerrados, vendidos o
vencidos, registrar DEBE evaluarse por la coincidencia con lo vendido (BR-STK-022). CUANDO llega
el comprador siguiente, registrar DEBE volver a pendiente. Una compra vendida DEBE contar como
cerrada aunque su despedida continúe.
Al cierre de la noche, atención DEBE quedar cumplida sólo si ambas compras se completaron, y
registrar DEBE evaluarse sólo si ambas compras quedaron cerradas. Un comprador que no llegó
cuenta como compra no completa y no cerrada.
Un comprador que se va antes de completar su compra DEBE contar como no atendido, tanto si
recibió una parte de su pedido como si recibió todos sus productos sin el ticket. Los productos
que deja en el piso NO DEBEN contar como vendidos.
La finalización DEBE contarse una sola vez mientras siga cumplida y conservarse al reabrir.
Una nueva jornada DEBE empezar sin agenda, conversación, entregas, cuerpos ni ventas heredados.

### BR-CTR-032 — Compradores animados

El sistema DEBE mostrar a cada comprador con sus ocho dibujos en orden numérico, en bucle,
con transparencia y proporción conservadas, con una duración uniforme de 0,5 segundos por dibujo.
Tin DEBE usar su animación nueva. La pausa DEBE detener la animación.
Al irse el comprador, su imagen DEBE dejar de mostrarse.
MIENTRAS espera, DEBE verse detrás de la ventanilla dentro del mundo aunque la interfaz esté
cerrada. Su dibujo DEBE mantener posición y orientación fijas hacia el interior del local,
sin seguir al jugador ni girar con su cámara. DEBE cambiar de tamaño aparente con la distancia
y quedar oculto por la geometría del local. El antepecho DEBE ocultar
siempre el corte inferior del dibujo desde las posiciones accesibles del local.
Abrir o cerrar la interfaz NO DEBE
reiniciar ni detener su animación. El diálogo conserva el diseño de Figma en pantalla.

La llegada de las jornadas 1 a 5 usa la entrada de BR-CTR-034; la posición fija corresponde
a la espera posterior a esa entrada.

### BR-CTR-033 — Salida visible de los compradores

EN las jornadas 1 a 5, CUANDO termina una despedida después de vender o una compra incompleta
vence, el comprador DEBE deslizarse hacia la derecha, vista desde el interior frente a la
ventanilla, hasta quedar detrás de la pared. DEBE permanecer animado mientras sale del hueco
y retirarse definitivamente después de quedar oculto; volver a mirar NO DEBE hacerlo reaparecer.
Ya despachado NO DEBE recibir objetos ni reiniciar conversaciones, y su presencia NO DEBE
retrasar la venta, el registro ni las tareas. NO DEBE girar, inclinarse ni cambiar de altura
o profundidad. La pausa DEBE detener el movimiento y la animación.
Cerrar o reiniciar la jornada DEBE retirar también las imágenes pendientes de salida.

### BR-CTR-034 — Entrada desde la izquierda

EN las jornadas 1 a 5, CUANDO llega cada comprador, su imagen DEBE deslizarse desde detrás de
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

CUANDO termina la inicial o una despedida, el sistema DEBE avisar su fin y devolver automáticamente la vista y movimiento normales, sin otro clic derecho.
El clic final NO DEBE activar otra interacción. MIENTRAS habla, el izquierdo DEBE avanzar una
entrada, el derecho NO DEBE abandonar, ningún clic DEBE entregar ni soltar y el reloj DEBE
seguir corriendo salvo pausa. Vencimiento y cierre DEBEN terminar conversación y encuadre.
SI el cierre u otra interfaz conserva el control, ENTONCES terminar el diálogo NO DEBE reanudarlo.

### BR-CTR-037 — La segunda jornada tiene dos compras físicas por horario

El sistema DEBE declarar para la segunda jornada exactamente Fede y Mía, con identidad propia:

| Comprador | Llega, incluido | Vence, excluido | Desde apertura hasta llegada | Desde apertura hasta vencimiento |
|---|---|---|---|---|
| Fede | 21:15 | 23:45 | 75 minutos | 225 minutos |
| Mía | 01:00 | 03:30 | 300 minutos | 450 minutos |

Los horarios proceden de «Atención al cliente» y se miden en el reloj ficticio desde la apertura
de turno declarada por el dominio. La agenda DEBE publicar una sola llegada y un solo vencimiento
por compra incompleta, conservar la identidad original y procesar todos los cruces en orden.
La pausa DEBE detenerlos. Una compra completada antes de su límite NO DEBE vencer.
Cada compra DEBE recibir unidades físicas y ticket exacto según BR-CTR-029 y vender una vez
según BR-CTR-030, sin descuento automático adicional. Atención sigue BR-CTR-031. Al vencer, los productos recibidos DEBEN quedar recogibles en el piso del
local frente a la ventanilla, del lado de adentro, sin venta; el ticket aceptado DEBE descartarse.
Una apertura nueva DEBE crear estados nuevos sin heredar entregas, conversaciones ni ventas.

### BR-CTR-038 — Un pedido fijo por comprador y apertura

CUANDO se construye el padrón de la segunda jornada, el sistema DEBE declarar exactamente estos
pedidos, en el orden indicado y con una unidad de cada producto, según «Atención al cliente» y
la decisión de conservar los productos nombrados por «Diálogos de compradores, Jornada 2»:

| Comprador | Primer producto | Segundo producto | Tercer producto |
|---|---|---|---|
| Fede | Poético | Progres | Duronga |
| Mía | Terminator | Fernet God | Actroncito |

El pedido DEBE permanecer idéntico al consultar, recordar, rechazar, entregar y abrir o cerrar
interfaces. El sistema NO DEBE sortear ni sustituir productos. Progres DEBE identificar el
producto existente cuyo subtítulo lo denomina así, sin crear otro producto ni renombrar el
catálogo. Reposición y atención DEBEN recibir los mismos compradores y pedidos ya construidos
de la apertura. Otra apertura DEBE crear estados propios con los mismos pedidos fijos. Si
algún producto requerido no existe en el catálogo, el sistema DEBE fallar explícitamente sin
publicar un pedido parcial ni sustituirlo.

### BR-CTR-039 — Los textos comunes usan el pedido real

CUANDO se pide recordatorio, el sistema DEBE enumerar los productos que todavía faltan, en el
orden del pedido, con los textos comunes de la ficha «Diálogos de compradores». Un rechazo DEBE
anteponer su prefijo y enumerar los productos que todavía faltan, no los ya recibidos. Con todos
los productos recibidos y sólo el ticket pendiente DEBE pedir el ticket, y un rechazo en ese
estado DEBE anteponerle el prefijo a ese pedido. CUANDO recibe un producto, el comprador DEBE agradecer
nombrando lo que todavía falta, o pedir el ticket si ya recibió todos. Ese agradecimiento NO
DEBE retener el clic siguiente con un objeto ni impedir dejar la ventanilla.
Para una unidad, cada marcador DEBE usar el subtítulo del producto con primera letra minúscula
y sin punto final. Para más de una DEBE usar «dos» o «tres» seguido del nombre del producto.
En cualquier cantidad, sólo el nombre propio del producto DEBE llevar el resaltado amarillo
común: la cantidad, el resto del subtítulo y los separadores de la enumeración NO DEBEN llevar
color. En jornada 2 NO DEBE inventarse una pista dentro de esos textos.

### BR-CTR-041 — La segunda noche activa a Fede y Mía con su contenido propio

CUANDO se abre jornada 2, por transición o desde una partida retomada, el sistema DEBE activar
exactamente Fede y Mía con horarios de BR-CTR-037, pedidos de BR-CTR-038, guiones de BR-CTR-042
y sus figuras propias. NO DEBE activar el padrón genérico ni duplicar compradores. Cada figura
DEBE conservar presencia animada en el mundo con la interfaz cerrada, orientación fija y
oclusión por los sólidos, incluido el corte inferior detrás del antepecho desde laterales
accesibles. La entrada y retirada DEBEN usar el recorrido existente desde la izquierda y
hacia la derecha, respectivamente, conservando orientación, altura y profundidad.
La apertura DEBE construir una sola lista compartida por reposición y atención. Reiniciar
DEBE limpiar conversaciones, entregas, ventas e imágenes anteriores. La jornada 1 y las
jornadas sin agenda DEBEN conservar sus recorridos propios.

### BR-CTR-042 — Nueve entradas propias de la segunda jornada

El sistema DEBE entregar los siguientes textos sólo al comprador y etapa indicados, en su
orden, conservando puntuación y límites de entrada de «Diálogos de compradores, Jornada 2».
Un espacio final de celda NO DEBE formar parte del texto. Los textos y las figuras propias
DEBEN estar disponibles también en el paquete distribuido del juego, sin depender de las fuentes.

| Comprador | Etapa | Entrada | Texto |
|---|---|---|---|
| Fede | inicial | 1 | Hola, ¿qué tal? Qué tarde se hizo… me alegra que todavía esté abierto el negocio. |
| Fede | inicial | 2 | Salí tardísimo del trabajo y no tuve un buen día. No vendimos suficiente. Por eso busco un momento de tranquilidad y placer, ¿vos entendes? |
| Fede | inicial | 3 | Quiero una botella de jabón Poético, una lata de papitas Progres y unos preservativos Duronga. |
| Fede | despedida | 1 | ¡Guau, salió la colección de los productos del Chiqui Tapia! No me había dado cuenta. Ese señor es mi ídolo. Siempre me da los mejores tips. |
| Fede | despedida | 2 | Gracias, compañero. Cuando quieras podes venir a casa y los probamos juntos. |
| Mía | inicial | 1 | Hola… ¿me darías un vino Terminator, un Fernet God y una cajita de Actroncito? |
| Mía | despedida | 1 | Zzzzzz.zzzzz.zzzzz |
| Mía | despedida | 2 | Perdon, me quedé dormida... ¿En dónde estaba? |
| Mía | despedida | 3 | Ah sí, gracias… Espero que esto me ayude a dormir mejor… |

### BR-CTR-043 — Cada atención conserva su lectura y sus destacados

CUANDO se inicia la conversación de Fede o Mía, el sistema DEBE mostrar la primera entrada
propia y avanzar sólo una por clic izquierdo, sin recepción, rechazo ni abandono mientras
habla. Terminar la inicial DEBE devolver el control según BR-CTR-036; hablar de nuevo DEBE
mostrar recordatorio sin repetir introducción. Cada atención DEBE tener un progreso de lectura
independiente, sin modificar el contenido compartido. Un cuadro largo sin nuevos clics NO DEBE
consumir entradas. Los nombres Poético, Progres y Duronga del pedido de Fede, y Terminator,
Fernet God y Actroncito del de Mía, DEBEN llevar amarillo, sin negrita añadida ni pistas lilas.
Los recordatorios y rechazos DEBEN usar los pedidos fijos según BR-CTR-039.
CUANDO se completa una compra, el sistema DEBE vender una sola vez e iniciar la despedida
propia desde su primera entrada. NO DEBE despachar ni retirar al comprador mientras quede
alguna entrada de despedida; tras terminarla DEBE retirarlo una sola vez. Una compra parcial
o vencida NO DEBE iniciar esa despedida. Vencer o cerrar DEBE conservar BR-CTR-037, incluso
con diálogo abierto; una compra completada antes del límite conserva su resultado.

### BR-CTR-044 — La tercera jornada recibe a Cami y Tin por horario

CUANDO se abre la jornada 3, por transición o desde una partida retomada, el sistema DEBE activar
exactamente Cami y Tin, con su figura propia, en estas ventanas. La llegada se incluye y el
límite se excluye. Tin cruza la medianoche.

| Comprador | Llega | Se va | Desde apertura hasta llegada | Desde apertura hasta límite |
|---|---|---|---|---|
| Cami | 20:03 | 22:33 | 3 minutos | 153 minutos |
| Tin | 01:30 | 04:00 | 330 minutos | 480 minutos |

Los horarios proceden de «Atención al cliente» y se derivan del reloj del turno, cuya apertura es
a las 20:00. Cada pedido sale de BR-CTR-047. NO DEBE activar el padrón de BR-CTR-001 ni duplicar
compradores. La agenda DEBE publicar una sola llegada y un solo vencimiento por compra incompleta,
conservar la identidad original y procesar todos los cruces en orden. La pausa DEBE detenerlos y una
compra completada antes de su límite NO DEBE vencer. Cada compra DEBE recibir unidades físicas y
ticket exacto según BR-CTR-029, vender una vez según BR-CTR-030 y, al vencer incompleta, dejar sus
productos y su ticket como BR-CTR-037. Atención sigue BR-CTR-031. Tin NO DEBE repetir la conversación ni el pedido de la jornada 1.

### BR-CTR-045 — La cuarta jornada recibe a Tia y Fede por horario

CUANDO se abre la jornada 4, por transición o desde una partida retomada, el sistema DEBE activar
exactamente Tia y Fede, con su figura propia, en estas ventanas. La llegada se incluye y el
límite se excluye. Tia cruza la medianoche.

| Comprador | Llega | Se va | Desde apertura hasta llegada | Desde apertura hasta límite |
|---|---|---|---|---|
| Tia | 22:00 | 00:30 | 120 minutos | 270 minutos |
| Fede | 04:00 | 06:30 | 480 minutos | 630 minutos |

Valen las demás condiciones de BR-CTR-044: el reloj del turno, el padrón excluido, una sola
llegada y un solo vencimiento, la pausa, la recepción física, la venta única, el destino al
vencer y el cumplimiento de atención de BR-CTR-031. Tia y Fede NO DEBEN repetir las conversaciones ni
los pedidos fijos de las jornadas 1 y 2.

### BR-CTR-046 — La quinta jornada recibe a Cami y Mía por horario

CUANDO se abre la jornada 5, por transición o desde una partida retomada, el sistema DEBE activar
exactamente Cami y Mía, con su figura propia, en estas ventanas. La llegada se incluye y el
límite se excluye.

| Comprador | Llega | Se va | Desde apertura hasta llegada | Desde apertura hasta límite |
|---|---|---|---|---|
| Cami | 20:30 | 23:00 | 30 minutos | 180 minutos |
| Mía | 05:00 | 07:30 | 540 minutos | 690 minutos |

Valen las demás condiciones de BR-CTR-044. Mía NO DEBE repetir la conversación ni el pedido fijo de la jornada 2, y Cami conserva su
identidad entre las jornadas 3 y 5 sin heredar pedido ni estado.

### BR-CTR-047 — Cada visita pide dos o tres tipos distintos de su grupo, sorteados al abrir

CUANDO se abre una jornada de la 3 a la 5, la noche del corte de luz o la última noche, el sistema
DEBE sortear el pedido de cada comprador:
dos o tres productos de tipos distintos, una unidad de cada uno, con reparto parejo entre las dos
cantidades y entre los productos candidatos. Los candidatos son los productos del grupo del
comprador que se venden esa noche (BR-STK-046). Dos compradores de la misma noche PUEDEN coincidir
en un producto, y el orden del pedido es el del sorteo. Un producto sin unidades vendibles sigue
siendo el pedido: su falta es de inventario o reposición.

Los grupos son estos:

| Comprador | Productos que puede pedir |
|---|---|
| Tin | Marolini, Coracola, Malbardo, Mayonchis, Arvecor, Uakalas, Don Saturados, Amargadito |
| Tia | Zucarachas, Pepito, Marranos, Arvecor, Mayonchis, Jorgillo, Marolini, Saladick, Don Saturados, Laysnnt, Chisitos, Malbardo |
| Fede | Poético, Progres, Duronga, Burbaloo, Malbardo, Fernet God, Terminator |
| Mía | Burbaloo, Fernet God, Terminator, Actroncito, Amargadito, Coracola, Uakalas, Marranos |
| Cami | Burbaloo, Zucarachas, Frot Lups, Jorgillo, Pepito, Oremos, Petisas, Macumbas, Flim Pof, Cindolor, Cosa de Maní, Feel Ricky Fort, Oaaaa |

Coracola es la Pura-Cola de la ficha, y Jorgillo la Jorgillata. El Durextra entra al pedido de
Fede sólo en la última noche (BR-CTR-052). Los productos de almacén que pide alguna noche siguen
sin noche ni lista (OQ-CTR-007), y no entran.

La partida DEBE llevar una semilla propia, fijada al empezar y conservada al guardar y retomar.
Con la misma partida, abrir de nuevo la misma jornada, retomarla o reintentarla DEBE construir los
mismos productos en el mismo orden, con estados nuevos; otra partida PUEDE sortear otros.

El sorteo ocurre una sola vez por apertura y produce una única lista que reciben Reposición y
Atención (BR-STK-026). Consultar, recordar, rechazar, entregar y abrir o cerrar interfaces NO
DEBE sortear de nuevo ni modificar el pedido. Reutilizar la identidad de un comprador de otra
jornada NO DEBE reutilizar su pedido ni su estado.

### BR-CTR-048 — Los compradores sin guion propio usan la apertura y la despedida predeterminadas

CUANDO un comprador de las jornadas 3 a 5 inicia su conversación, el sistema DEBE decir, en una
sola entrada, «Buenas noches. Quiero » seguido de sus productos y un punto final: uno,
«[producto1]»; dos, «[producto1] y [producto2]»; tres, «[producto1], [producto2] y [producto3]».
Los productos DEBEN presentarse como en BR-CTR-039. Terminar la entrada DEBE devolver el control
según BR-CTR-036 y hablar de nuevo DEBE mostrar el recordatorio de BR-CTR-039 sin repetir la
apertura. CUANDO se completa su compra, el sistema DEBE vender una sola vez y decir, en una sola
entrada, «Muchas gracias.»; NO DEBE retirar al comprador hasta terminarla. Los textos de las
jornadas 1 y 2 son de sus compradores y NO DEBEN decirse en estas jornadas. El sistema NO DEBE
inventar guiones propios para estos compradores.

### BR-CTR-049 — Sólo la inicial y la despedida abren la ventanilla

CUANDO el comprador dice su conversación inicial o su despedida, el sistema DEBE abrir la
ventanilla y suspender al jugador hasta que termine, según BR-CTR-036. CUANDO el comprador
agradece una entrega, recuerda lo que falta, rechaza un objeto o contesta que ya recibió lo que se
le ofrece, el sistema NO DEBE abrir la ventanilla ni suspender al jugador, ni cerrarla si estaba
abierta por otra causa. La despedida de un comprador que vence NO EXISTE: BR-CTR-043 conserva su
destino.

### BR-CTR-050 — Los textos de entrega salen como subtítulo de comprador

CUANDO el comprador agradece una entrega, recuerda lo que falta, rechaza un objeto o contesta que
ya recibió lo que se le ofrece, el sistema DEBE mostrar su texto en la línea de subtítulo, con el
diseño de los diálogos de compradores y los nombres de los productos resaltados como en
BR-CTR-039. DEBE verse como un pensamiento, con la duración y el desvanecido de
[`subtitles`](../subtitles/subtitles.md), y reemplazar al subtítulo que se vea; un pensamiento
posterior DEBE reemplazarlo a él (BR-SUB-001). Esos textos tienen lugar: la figura del comprador
en la ventanilla, y se acortan al alejarse el jugador según BR-SUB-015. La inicial y la
despedida NO DEBEN acortarse: siguen abriendo la ventanilla. Esos textos NO DEBEN retener el clic siguiente:
cada pulsación DEBE producir una sola interacción nueva, con el objeto sostenido o con la mano
vacía, incluso sobre un objeto que acaba de rechazarse.

### BR-CTR-051 — La noche del corte de luz recibe a Tin y Tia por horario

CUANDO se abre la noche del corte de luz (BR-ANO-011), por transición o desde una partida retomada,
el sistema DEBE activar exactamente Tin y Tia, con su figura propia, en estas ventanas. La llegada
se incluye y el límite se excluye.

| Comprador | Llega | Se va | Desde apertura hasta llegada | Desde apertura hasta límite |
|---|---|---|---|---|
| Tin | 00:00 | 02:30 | 240 minutos | 390 minutos |
| Tia | 02:31 | 05:01 | 391 minutos | 541 minutos |

El horario de Tia es fijo: NO DEBE depender de cuándo se retira Tin, a diferencia de la jornada 1.
Tia llega un minuto después del límite de Tin, así que con Tin sin atender vence primero Tin y
llega Tia después. Valen las demás condiciones de BR-CTR-044: el reloj del turno, el padrón
excluido, una sola llegada y un solo vencimiento, la pausa, la recepción física, la venta única, el
destino al vencer y el cumplimiento de atención de BR-CTR-031. Cada pedido sale de BR-CTR-047. Tin y
Tia NO DEBEN repetir las conversaciones ni los pedidos fijos de la jornada 1. El corte de luz no
cambia estas ventanas.

### BR-CTR-052 — La última noche recibe a Fede y Mía por horario, y Fede pide Duronga y Durextra

CUANDO se abre la última noche de la partida (BR-ANO-004), por transición o desde una partida
retomada, el sistema DEBE activar exactamente Fede y Mía, con su figura propia, en estas ventanas.
La llegada se incluye y el límite se excluye.

| Comprador | Llega | Se va | Desde apertura hasta llegada | Desde apertura hasta límite |
|---|---|---|---|---|
| Fede | 23:00 | 01:30 | 180 minutos | 330 minutos |
| Mía | 05:30 | 08:00 | 570 minutos | 720 minutos |

Fede cruza la medianoche. Mía se va al cerrar el turno, para esperar sus dos horas y media
completas dentro de él; la ficha dice 06:00 a 08:30, y manda la decisión de game design del 30 de
octubre de 2026. Valen las demás condiciones de BR-CTR-044. Fede y Mía NO DEBEN repetir las
conversaciones ni los pedidos fijos de las jornadas 1 y 2.

El pedido de Fede de esta noche DEBE incluir siempre Duronga y Durextra. Con dos tipos, pide
exactamente esos dos; con tres, suma un tipo más de su grupo (BR-CTR-047), distinto de esos dos.
Pedir dos o tres tiene la misma probabilidad. Durextra NO DEBE salir sin Duronga, ni en el pedido
de otro comprador, ni en otra noche. Un pedido que las cajas cambiadas no permiten reponer vale
igual, como un producto sin unidades vendibles en BR-CTR-047.

## Criterios de aceptación

### AC-CTR-001 — Dos por noche *(verifica BR-CTR-001)*

DADO una jornada sin agenda CUANDO se piden sus compradores del padrón ENTONCES son 2, son los dos primeros
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
bloqueo. Las conversaciones propias de jornada 2 son las de BR-CTR-042.

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

### AC-CTR-026 — El corte es la jornada cinco *(verifica BR-CTR-022)*

DADO jornadas 1 a 7, CUANDO abre cada una ENTONCES de la 1 a la 4 son automáticas y
la 5, la 6 y la 7 manuales. DADO una partida retomada en la 6 ENTONCES abre manual; CUANDO
se abre una partida nueva ENTONCES vuelve al automático. Abrir la 5 tras escribir en la 4
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

DADO la jornada 1 CUANDO pasan 20:29:59, 20:30:00, 22:59:59 y 23:00:00 ENTONCES Tin está
ausente, llega, espera y vence. DADO 23:29:59, 23:30:00, 01:59:59 y 02:00:00 ENTONCES ocurre
lo mismo con Tia, que cruza la medianoche. Repetir cada instante no repite eventos. Tin pide un Marolini, una Coracola
y un Malbardo; Tia pide una Zucarachas y un Pepito, sin una segunda Zucarachas.

### AC-CTR-035 — Cruces con la ventanilla cerrada *(verifica BR-CTR-027)*

DADO la ventanilla cerrada CUANDO el tiempo cruza toda la noche ENTONCES se publican llegada
de Tin, salida de Tin, llegada de Tia y salida de Tia, en ese orden, sin nadie esperando.
DADO Tin esperando CUANDO se cierra y reabre ENTONCES no hay nueva llegada; en pausa no vence.

### AC-CTR-036 — Prioridad de la conversación *(verifica BR-CTR-028, BR-CTR-029)*

DADO un comprador de la jornada 1 y un objeto en la mano CUANDO se inicia y avanza
la conversación inicial ENTONCES sólo
cambia una entrada por clic, sin recibir ni rechazar el objeto. Al terminar, manos vacías muestran
un recordatorio; un objeto correcto se recibe y ese clic no avanza una conversación.
Reabrir conserva el progreso y los nombres pedidos aparecen con negrita y color.
DADO Tia CUANDO se inicia su conversación ENTONCES tiene una entrada que nombra sus productos
resaltados con color y sin negrita. La conversación inicial de Tin conserva sus tres entradas, y
sus despedidas, una y cuatro.

### AC-CTR-037 — Identidad y sobrantes *(verifica BR-CTR-028, BR-CTR-029)*

DADO Tia lista para recibir CUANDO recibe una Zucarachas ENTONCES no falta otra Zucarachas
y sigue pendiente un Pepito. CUANDO se ofrece otra Zucarachas con identidad distinta, la misma
unidad ya recibida, un producto ajeno u otro objeto ENTONCES se rechaza sin alterar entregas,
mano ni ventas. DADO un pedido de prueba de dos Zucarachas CUANDO se entrega una unidad y se
repite su identidad ENTONCES se rechaza la repetición y sigue faltando una; una segunda unidad
distinta se acepta y una tercera se rechaza como sobrante.

DADO cada comprador de la jornada 1, terminada su conversación inicial, CUANDO se ofrece
un objeto incorrecto ENTONCES el rechazo antepone su prefijo y nombra todos los productos del
pedido, resaltados con color. CUANDO se le habla con manos vacías ENTONCES el recordatorio no
lleva el prefijo.

### AC-CTR-038 — El ticket es un multiconjunto *(verifica BR-CTR-029, BR-CTR-030)*

DADO Tia CUANDO recibe un ticket con una Zucarachas y un Pepito, o un Pepito y una Zucarachas,
ENTONCES se acepta. Cero o dos Zucarachas, omitir Pepito o agregar otro producto se rechaza
sin alterar mano, entregas ni ventas.
Sólo ticket o sólo productos dejan la compra incompleta y las ventas en cero.

### AC-CTR-039 — Venta y despedida *(verifica BR-CTR-030)*

DADO todos los elementos salvo uno CUANDO se recibe el último ENTONCES se registra una compra
y comienza la despedida. Repetir la recepción no registra otra compra. Completar antes del
límite conserva la venta durante la despedida; al terminarla la atención queda despachada
y su imagen conserva la salida de BR-CTR-033.

### AC-CTR-040 — Perder una compra parcial *(verifica BR-CTR-027, BR-CTR-030, BR-CTR-031)*

DADO una compra parcial, incluso hablando, CUANDO llega el límite ENTONCES sale una vez,
se cierra el diálogo, sus productos quedan en el piso interior frente a la ventanilla y el
ticket aceptado deja de existir sin aparecer en el piso.
Las ventas de esa compra siguen en cero. Completar la otra no cumple atención.
DADO por separado una compra sin elementos, sólo con ticket, con una unidad o con todos los
productos pero sin ticket CUANDO vence ENTONCES aparecen respectivamente cero, cero, una
o todas sus unidades; ningún caso suma una venta. Un salto que cruza los dos vencimientos
procesa ambas compras una sola vez, y repetir el instante no vuelve a entregar sus unidades.

### AC-CTR-041 — Ambas compras y reinicio *(verifica BR-CTR-026, BR-CTR-031)*

DADO la jornada 1 CUANDO se completa sólo Tin ENTONCES atención figura cumplida hasta que
llega Tia (BR-CTR-031); al cierre sin Tia ENTONCES atención no se cumple.
Al completar Tia, cuenta una vez al cierre; lo vendido es un Marolini, una Coracola, un Malbardo,
una Zucarachas y un Pepito. Reabrir conserva ese resultado. Reiniciar crea estados nuevos
sin entregas ni ventas. Las jornadas sin agenda conservan el recorrido anterior; la segunda usa BR-CTR-037.

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

DADO cada comprador de las jornadas 1 a 5 CUANDO llega con la interfaz cerrada ENTONCES aparece
deslizándose desde la izquierda hasta el sitio de espera, conservando altura, profundidad,
orientación y animación. Después permanece quieto. Abrir, cerrar y repintar no reinician el
movimiento. Pausar lo congela y reanudar lo continúa; reiniciar o cerrar el turno lo retira.

### AC-CTR-046 — Lo abandonado queda adentro y se puede recuperar *(verifica BR-CTR-027)*

DADO Tin con sus tres productos recibidos pero sin ticket, y el jugador asomado a la ventanilla,
CUANDO vence la compra ENTONCES las tres unidades conservan sus identidades y quedan visibles,
con física y recogibles, apoyadas en el piso del lado interior frente a la ventanilla,
sin superponerse entre sí, con el jugador ni con un sólido. La pausa detiene su caída y reanudar
la continúa. Repetir el vencimiento no crea otras unidades ni recoloca las recuperadas.

DADO esas unidades como únicos cuerpos desordenados CUANDO se cierra la noche con las tres
en el piso ENTONCES hay un único motivo de desorden y ninguno de objeto afuera. DADO el mismo
caso CUANDO se coloca cada una en un casillero vacío de su producto, se devuelven a sus cajas
con espacio, o se colocan dos y se sostiene la tercera sin examinarla, y se cierra ENTONCES
no hay ninguno de esos dos motivos. Agarrarlas conserva su producto e identidad; una unidad
devuelta a una caja llena permanece en la mano. Tirar una al contenedor conserva el descuento
y el motivo de objeto importante tirado de las unidades sueltas. Abrir la jornada siguiente
retira las unidades que hayan quedado en el piso, sin heredarlas como nuevas entregas.

### AC-CTR-047 — Terminar devuelve automáticamente *(verifica BR-CTR-036, BR-CTR-013)*

DADO, por turno, inicial y despedida de una entrada CUANDO se avanza
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

DADO el padrón definido de jornada 2 CUANDO se recorren 21:14:59, 21:15:00, 23:44:59 y 23:45:00
ENTONCES Fede está ausente, llega, espera y vence si no completó. En 00:59:59, 01:00:00,
03:29:59 y 03:30:00 ocurre lo mismo con Mía. Repetir cada instante no repite eventos.
Saltar desde apertura a cierre entrega llegada Fede, vencimiento Fede, llegada Mía y vencimiento
Mía, en ese orden, cada uno con su comprador original; en pausa no cruza ninguno.

### AC-CTR-051 — Los seis productos son fijos *(verifica BR-CTR-038)*

DADO la apertura de jornada 2 CUANDO se construyen sus compradores ENTONCES Fede pide una unidad
de Poético, Progres y Duronga, en ese orden; Mía una de Terminator, Fernet God y Actroncito,
en ese orden. Cada pedido tiene tres tipos y tres unidades. Progres corresponde al producto
existente de ese subtítulo. Un producto requerido ausente del catálogo falla explícitamente,
sin pedido parcial, sustitución ni selección al azar. Otra apertura conserva los productos
pero crea estados nuevos.

### AC-CTR-052 — Consultar conserva la lista de apertura *(verifica BR-CTR-038)*

DADO una apertura con Fede/Mía y sus pedidos fijos construidos CUANDO se consultan faltantes y
atención en ambos órdenes, se recuerda, rechaza, entrega y reabre ENTONCES ambos consumidores
conservan las mismas instancias de compradores y pedidos, sin reconstruir la lista ni sortear.
Otra apertura crea sus propios estados con los mismos seis productos, sin heredar entregas.

### AC-CTR-053 — Marcadores, cantidades y rechazo *(verifica BR-CTR-039)*

DADO pedidos A/A/A, A/A/B y A/B/C CUANDO se consulta recordatorio ENTONCES se usa respectivamente
la forma de uno, dos y tres marcadores, sin marcadores sin reemplazar. A/A/A usa «tres» y el
nombre A; A/A/B usa «dos» y el nombre A, y para B el subtítulo con inicial minúscula y sin punto
final. Un rechazo antepone exactamente «Yo no pedí esto. ». Los productos llevan amarillo y
ningún fragmento se ofrece como pista. Con los tres productos y sin ticket el texto es
exactamente «Gracias. Me das el ticket, ¿por favor?».
DADO un pedido de dos unidades de A y una de B, con una unidad de A ya entregada, CUANDO se
ofrece un objeto ajeno ENTONCES el rechazo es el prefijo seguido de «Quiero» con una unidad de A
y B, en el orden del pedido. Con dos y tres productos distintos faltantes el rechazo usa su forma de
dos y de tres. Sin entregas, el rechazo nombra el pedido completo. Con todos los productos
entregados y sin ticket, el rechazo es el prefijo seguido de «Me das el ticket, ¿por favor?».

### AC-CTR-055 — Recepción física y destinos de jornada 2 *(verifica BR-CTR-037, BR-CTR-038, BR-CTR-029, BR-CTR-030)*

DADO Fede con su inicial terminada CUANDO se entrega un ticket exacto antes de los productos
ENTONCES se acepta y aún no vende. Una unidad de Poético, una de Progres y una de Duronga
completan una venta; repetir un cuerpo, ofrecer una segunda unidad de un producto o un ticket
inexacto se rechaza sin cambiar mano ni cantidades. DADO una compra incompleta con ticket y
dos productos CUANDO vence ENTONCES el ticket desaparece y ambos productos quedan dentro del
local, sin venta. Una apertura posterior no hereda esos cuerpos ni entregas.

### AC-CTR-057 — Dos caminos de apertura activan los mismos compradores *(verifica BR-CTR-041, BR-CTR-038)*

DADO una transición de jornada 1 a 2 y, por separado, una partida retomada directamente en 2
CUANDO llega 21:15 ENTONCES hay un único Fede con su figura, pedido fijo e inicial propia.
A 01:00 hay una única Mía con los suyos. No aparecen compradores genéricos ni copias de Fede/Mía.
Reposición y atención reciben la misma lista y los mismos pedidos de cada apertura.

### AC-CTR-058 — Nueve textos en cuatro bloques *(verifica BR-CTR-042)*

DADO los diálogos propios de jornada 2 CUANDO se consultan inicial y despedida de cada comprador
ENTONCES Fede tiene tres entradas iniciales y dos finales; Mía una inicial y tres finales.
Las nueve coinciden exactamente, en texto y orden, con BR-CTR-042, sin espacios finales, sin
corregir «entendes», «podes» o «Perdon», y sin entradas de otro comprador.

### AC-CTR-059 — Seis nombres amarillos sin pista *(verifica BR-CTR-043, BR-CTR-039)*

DADO la tercera entrada inicial de Fede y la única inicial de Mía CUANDO se dibujan ENTONCES
los únicos nombres resaltados como productos son respectivamente Poético/Progres/Duronga y
Terminator/Fernet God/Actroncito, en amarillo y sin negrita añadida; ninguno es una pista lila.
Tras la inicial, recordatorio y rechazo nombran los tres productos de ese mismo pedido fijo.

### AC-CTR-060 — Tres avances para Fede y uno para Mía *(verifica BR-CTR-043, BR-CTR-035, BR-CTR-036)*

DADO cada comprador sin atender y un producto sostenido CUANDO se pulsa izquierdo una vez sobre
su figura ENTONCES se muestra su primera entrada sin recibir ni rechazar. Fede vuelve al mundo
tras tres avances; Mía tras uno. Cada pulsación avanza sólo una entrada; un cuadro largo sin
clic no avanza. Derecho durante el diálogo no abandona. La última pulsación conserva mano y no
entrega además el producto; hablar nuevamente muestra recordatorio sin repetir la introducción.

### AC-CTR-061 — Dos y tres entradas antes de retirarse *(verifica BR-CTR-043, BR-CTR-030)*

DADO cada inicial terminada CUANDO se entregan los tres productos correctos y ticket exacto,
con ticket primero o último ENTONCES vende una sola vez y muestra la primera despedida propia.
Fede sigue presente tras el primer avance y se despacha tras el segundo; Mía sigue presente
tras el primero y el segundo y se despacha tras el tercero. Repetir entrada o recepción no
vende ni retira otra vez. Al terminar, la vista vuelve y la imagen sale hacia la derecha.

### AC-CTR-062 — Vencimiento y cierre no fabrican despedida *(verifica BR-CTR-043, BR-CTR-037)*

DADO Fede con compra parcial y diálogo abierto CUANDO llega 23:45 ENTONCES vence sin despedida
de venta y sus productos vuelven al piso interior; el ticket aceptado se descarta. DADO Mía
incompleta con diálogo abierto CUANDO llega 03:30 ENTONCES vence y atención queda pendiente.
DADO ambas compras completas y Mía completada a 03:29:59 ENTONCES atención queda cumplida
aunque siga en su despedida. Pausar conserva el estado hasta reanudar.

### AC-CTR-063 — Progreso independiente y figuras propias *(verifica BR-CTR-041, BR-CTR-043)*

DADO dos atenciones independientes del mismo guion de Fede CUANDO sólo una avanza ENTONCES la
otra conserva su primera entrada y el contenido compartido no cambia. DADO la jornada 2 con
introducción o despedida en curso CUANDO se reinicia ENTONCES no quedan cursores, entregas,
ventas ni imágenes heredadas. Con la interfaz cerrada, cada figura durante su presencia conserva animación,
orientación fija y oclusión; el antepecho oculta el corte inferior desde laterales accesibles.
La jornada 1 y las jornadas sin agenda mantienen sus compradores y conversaciones anteriores.

### AC-CTR-064 — El paquete conserva conversaciones y figuras *(verifica BR-CTR-042, BR-CTR-041, BR-CTR-043)*

DADO el paquete distribuido del juego ejecutado fuera de las fuentes CUANDO se recorren las
iniciales y despedidas de Fede/Mía ENTONCES se cargan los nueve textos exactos, en los mismos
cuatro bloques, con los seis nombres destacados y la figura propia de cada identidad. No hay
recursos ausentes ni errores de ejecución al recorrerlas. Las figuras se ven con el panel
cerrado y los textos completos al hablar, conservando los gestos de entrada y retorno.

### AC-CTR-065 — Una entrada por pulsación desde el mundo *(verifica BR-CTR-035, BR-CTR-028)*

DADO un comprador sin atender y un ticket en mano CUANDO se pulsa izquierdo una vez sobre la
persona ENTONCES aparece la primera entrada inicial, sin entrega ni rechazo. El siguiente
izquierdo avanza exactamente una entrada. Repetir con mano vacía conserva la misma secuencia.

### AC-CTR-066 — El recordatorio nombra lo que falta *(verifica BR-CTR-039)*

DADO un comprador que recibió uno de sus productos CUANDO se le habla con manos vacías ENTONCES
el recordatorio y el rechazo nombran los que faltan y no el recibido. Con todos los productos
recibidos, pide el ticket.

### AC-CTR-067 — Recibir agradece sin retener *(verifica BR-CTR-029, BR-CTR-039)*

DADO un comprador listo para recibir CUANDO recibe un producto ENTONCES agradece nombrando lo que
falta y se puede dejar la ventanilla. CUANDO después se le ofrece otra unidad de ese producto ya completo, o la misma
unidad, ENTONCES la rechaza en ese mismo clic con el agradecimiento de lo ya entregado. Un
producto ajeno se rechaza con el prefijo de rechazo.

### AC-CTR-069 — Las fronteras de las agendas de las jornadas 3 a 5 *(verifica BR-CTR-044, BR-CTR-045, BR-CTR-046)*

DADO cada jornada de la 3 a la 5 CUANDO se piden sus compradores ENTONCES son exactamente dos,
en este orden: Cami y Tin; Tia y Fede; Cami y Mía. Para cada uno, un segundo antes de su llegada
está ausente, en su llegada llega, un segundo antes de su límite espera y en su límite vence si no
completó; repetir cada instante no repite eventos. Saltar desde la apertura hasta el cierre entrega
llegada y vencimiento del primero y después llegada y vencimiento del segundo, cada uno con su
comprador original; en pausa no cruza ninguno. Una compra completada antes de su límite no vence.

### AC-CTR-070 — Cada apertura activa sólo sus dos figuras *(verifica BR-CTR-044, BR-CTR-045, BR-CTR-046, BR-CTR-048)*

DADO una transición a cada jornada de la 3 a la 5 y, por separado, una partida retomada
directamente en ella CUANDO llega cada horario ENTONCES hay un único comprador con la identidad y
la figura de la tabla. No aparecen compradores del padrón ni copias. Tin de la jornada 3 no pide ni
dice lo de Tin de la jornada 1; Tia y Fede de la jornada 4 y Mía de la jornada 5 no piden ni dicen
lo de las jornadas 1 y 2. Reposición y atención reciben la misma lista de cada apertura.

### AC-CTR-071 — Dos o tres tipos distintos de su grupo y de lo que se vende *(verifica BR-CTR-047)*

DADO la apertura de cada jornada de la 3 a la 5, con distintas semillas de partida, CUANDO se
construyen sus compradores ENTONCES cada pedido tiene dos o tres productos de tipos distintos
con una unidad cada uno, y todos pertenecen al grupo de su comprador y a los que se venden esa
noche: el catálogo completo, desde la primera jornada completa. Entre las semillas
probadas hay pedidos distintos.

### AC-CTR-072 — La misma partida repite sus pedidos *(verifica BR-CTR-047)*

DADO una partida y una jornada de la 3 a la 5 CUANDO se abre dos veces, o se guarda y se retoma, o
se reintenta la noche ENTONCES los compradores traen los mismos productos en el mismo orden, con
instancias y estados nuevos, sin entregas heredadas. DADO partidas con semillas distintas ENTONCES
al menos dos producen pedidos distintos para la misma jornada.

### AC-CTR-073 — Consultar no sortea *(verifica BR-CTR-047)*

DADO una apertura de la jornada 3, 4 o 5 con sus compradores construidos CUANDO se consultan
faltantes y atención en ambos órdenes, se recuerda, rechaza, entrega y se abre y cierra la
ventanilla ENTONCES ambos consumidores conservan las mismas instancias de compradores y pedidos,
sin reconstruir la lista ni sortear. Un pedido con un producto sin unidades vendibles conserva ese
producto.

### AC-CTR-074 — Apertura y despedida predeterminadas *(verifica BR-CTR-048)*

DADO un comprador de la jornada 3, 4 o 5 con pedido de uno, dos o tres tipos CUANDO se le habla por
primera vez ENTONCES muestra una sola entrada «Buenas noches. Quiero » más sus productos con la
conjunción de BR-CTR-048 y punto final, con los nombres en amarillo y sin pistas lilas; tras
terminarla, hablar de nuevo muestra el recordatorio sin repetirla. CUANDO se le entregan sus
productos y el ticket exacto ENTONCES vende una sola vez, muestra la única entrada «Muchas
gracias.» y no se retira hasta terminarla; repetir la entrega no vende ni retira otra vez.

### AC-CTR-075 — Recepción, venta y vencimiento de las jornadas 3 a 5 *(verifica BR-CTR-044, BR-CTR-045, BR-CTR-046, BR-CTR-029, BR-CTR-030, BR-CTR-031)*

DADO un comprador de la jornada 3, 4 o 5 con su apertura terminada CUANDO se le entrega un ticket
exacto antes de los productos ENTONCES se acepta y aún no vende; sus productos completan una
venta, y ofrecer una unidad de más o un ticket inexacto se rechaza sin cambiar mano ni cantidades.
DADO una compra incompleta con ticket y dos productos CUANDO vence ENTONCES el ticket desaparece y
ambos productos quedan dentro del local, sin venta. Atención sigue BR-CTR-031: una perdida la deja pendiente aunque la otra se complete, y reiniciar no hereda entregas
ni ventas.

### AC-CTR-096 — Entregar no abre la ventanilla *(verifica BR-CTR-049, BR-CTR-050)*

DADO un comprador atendido, con su inicial terminada, y el jugador libre CUANDO se le entrega una
unidad pendiente, un producto de más, la misma unidad por segunda vez, un objeto ajeno o nada
ENTONCES el jugador no queda suspendido en ninguna de las cinco pulsaciones y el texto de cada
una —agradecimiento, rechazo, ya entregado, rechazo y recordatorio— se ve en la línea de
subtítulo con el diseño de comprador, sin abrir la ventanilla.

### AC-CTR-097 — La inicial y la despedida siguen abriendo *(verifica BR-CTR-049, BR-CTR-036)*

DADO un comprador sin atender CUANDO se le pulsa por primera vez ENTONCES la ventanilla se abre y
el jugador queda suspendido hasta terminar la inicial. DADO una compra completa CUANDO se entrega
el último elemento ENTONCES se abre con su despedida y al terminarla el jugador vuelve al mundo.
DADO un comprador que vence con la compra incompleta ENTONCES no se abre ninguna ventanilla.

### AC-CTR-098 — El subtítulo de entrega no retiene el clic *(verifica BR-CTR-050)*

DADO un comprador con la inicial terminada y un objeto ajeno en la mano CUANDO se pulsa dos veces
ENTONCES cada pulsación muestra el rechazo y ninguna avanza ni cierra un diálogo. DADO que acaba
de recibir un producto CUANDO se pulsa con la mano vacía ENTONCES esa pulsación muestra el
recordatorio, sin gastar un clic en cerrar el agradecimiento.

### AC-CTR-099 — Una sola línea *(verifica BR-CTR-050)*

DADO un pensamiento visible CUANDO el comprador agradece una entrega ENTONCES la línea muestra sólo
el texto del comprador, entero y con el tiempo de un pensamiento. DADO ese texto visible CUANDO
llega un pensamiento ENTONCES la línea muestra sólo el pensamiento.

### AC-CTR-106 — Tia llega después de que Tin se retira *(verifica BR-CTR-026, BR-CTR-027)*

DADO la jornada 1 con Tin sin atender CUANDO pasan 23:29:59 y 23:30:00 ENTONCES Tia está ausente y
llega; y 01:59:59 y 02:00:00 ENTONCES espera y vence. DADO Tin completo a las 21:00 CUANDO pasan
21:29:59 y 21:30:00 ENTONCES Tia está ausente y llega; y 23:59:59 y 00:00:00 ENTONCES espera y vence.
DADO Tin completo en el mismo instante en que vence a las 23:00 ENTONCES Tia llega a las 23:30. Repetir
cada instante no repite eventos. Tin sigue llegando a las 20:30 y pidiendo lo mismo, y Tia lo mismo que antes.

### AC-CTR-107 — Cada comprador pide de su grupo *(verifica BR-CTR-047)*

DADO la apertura de cada jornada de la 3 a la 5, con muchas semillas, CUANDO se construyen sus
compradores ENTONCES ningún pedido incluye un producto fuera del grupo de su comprador. DADO la
jornada 3 ENTONCES con las semillas probadas cada comprador pide todos los productos de su
grupo. DADO Fede en la jornada 4 ENTONCES jamás pide Durextra.

### AC-CTR-108 — Dos o tres, nunca uno ni cuatro *(verifica BR-CTR-047)*

DADO la apertura de cada jornada de la 3 a la 5, con muchas semillas, CUANDO se construyen sus
compradores ENTONCES cada pedido tiene dos o tres productos, aparecen las dos cantidades, ninguno
tiene un producto repetido ni más de una unidad por producto, y las dos cantidades salen con
frecuencias parecidas.

### AC-CTR-109 — Las ventanas de dos horas y media *(verifica BR-CTR-045, BR-CTR-046)*

DADO la jornada 4 CUANDO pasan 21:59:59, 22:00:00, 00:29:59 y 00:30:00 ENTONCES Tia está ausente,
llega, espera y vence; y 03:59:59, 04:00:00, 06:29:59 y 06:30:00 ENTONCES lo mismo con Fede. DADO la
jornada 5 CUANDO pasan 20:29:59, 20:30:00, 22:59:59 y 23:00:00 ENTONCES lo mismo con Cami; y 04:59:59,
05:00:00, 07:29:59 y 07:30:00 con Mía. Cada una de las cuatro ventanas dura 150 minutos de juego.

### AC-CTR-126 — Las fronteras de la noche del corte de luz *(verifica BR-CTR-051)*

DADO la noche del corte de luz CUANDO se piden sus compradores ENTONCES son exactamente dos, en este
orden: Tin y Tia. Para Tin, a las 23:59:59 está ausente, a las 00:00:00 llega, a las 02:29:59 espera y
a las 02:30:00 vence si no completó; para Tia, a las 02:30:59 está ausente, a las 02:31:00 llega, a las
05:00:59 espera y a las 05:01:00 vence si no completó. Repetir cada instante no repite eventos.
DADO Tin completo a las 00:10 CUANDO pasan 02:30:59 y 02:31:00 ENTONCES Tia sigue ausente y llega.
DADO Tin sin atender CUANDO el reloj salta de la apertura al cierre ENTONCES vencen en este orden Tin
y Tia. Cada ventana dura 150 minutos de juego.

### AC-CTR-127 — Las fronteras de la última noche *(verifica BR-CTR-052)*

DADO la última noche CUANDO se piden sus compradores ENTONCES son exactamente dos, en este orden:
Fede y Mía. Para Fede, a las 22:59:59 está ausente, a las 23:00:00 llega, a las 01:29:59 espera y a las
01:30:00 vence si no completó; para Mía, a las 05:29:59 está ausente, a las 05:30:00 llega, a las
07:59:59 espera y al cierre del turno, a las 08:00:00, vence si no completó. Repetir cada instante no
repite eventos. Una compra completada antes de su límite no vence.

### AC-CTR-128 — Cada apertura activa sólo sus dos figuras *(verifica BR-CTR-051, BR-CTR-052, BR-CTR-048)*

DADO una transición a la noche del corte de luz y a la última noche y, por separado, una partida
retomada directamente en cada una CUANDO llega cada horario ENTONCES hay un único comprador con la
identidad y la figura de la tabla. No aparecen compradores del padrón ni copias. Tin y Tia no piden ni
dicen lo de la jornada 1; Fede y Mía no piden ni dicen lo de la jornada 2. Reposición y atención
reciben la misma lista de cada apertura.

### AC-CTR-129 — Cada uno pide dos o tres tipos de su grupo *(verifica BR-CTR-051, BR-CTR-052, BR-CTR-047)*

DADO la apertura de la noche del corte de luz y la de la última noche, con muchas semillas, CUANDO
se construyen sus compradores ENTONCES cada pedido tiene dos o tres productos de tipos distintos con
una unidad cada uno, todos del grupo de su comprador, aparecen las dos cantidades y salen con
frecuencias parecidas. Ningún pedido incluye un producto de almacén.

### AC-CTR-130 — Fede pide siempre Duronga y Durextra en la última noche *(verifica BR-CTR-052)*

DADO la última noche, con muchas semillas, CUANDO se construye el pedido de Fede ENTONCES incluye
Duronga y Durextra. Si pide dos, son exactamente esos dos; si pide tres, el tercero es de su grupo y
distinto de ellos, y con las semillas probadas salen todos los candidatos. Las dos cantidades
aparecen con frecuencias parecidas. DADO cualquier otro comprador de esa noche, o cualquier comprador
de otra noche con agenda al azar, incluido Fede en la jornada 4, ENTONCES jamás pide Durextra.

### AC-CTR-131 — La misma partida repite estos pedidos *(verifica BR-CTR-047, BR-CTR-052)*

DADO una partida con su semilla CUANDO se abre de nuevo la noche del corte de luz o la última noche,
se retoma o se reintenta ENTONCES cada comprador, incluido Fede, pide los mismos productos en el mismo
orden y con estados nuevos. Consultar, recordar, rechazar o entregar no sortea de nuevo.

### AC-CTR-132 — Recepción, venta y vencimiento de las dos noches *(verifica BR-CTR-051, BR-CTR-052, BR-CTR-029, BR-CTR-030, BR-CTR-031)*

DADO cada una de las dos noches CUANDO se entregan a un comprador todos sus productos y su ticket
exacto ENTONCES se vende una sola vez; si vence incompleto, sus productos y su ticket quedan como en
BR-CTR-037. DADO sólo una de las dos compras completas CUANDO cierra la noche ENTONCES atención no
se cumple, y con las dos completas se cumple. Un pedido con un producto sin unidades vendibles
sigue siendo el pedido.

### AC-CTR-143 — Atención y registro figuran cumplidos hasta que llega el siguiente *(verifica BR-CTR-031)*

DADO una noche con dos compradores por horario, sin nadie llegado, CUANDO todavía no
llegó ninguno ENTONCES atención y registrar figuran pendientes. CUANDO llega el primero y se le
vende ENTONCES atención figura cumplida; registrar sigue pendiente hasta anotar exactamente lo que
se le vendió, y entonces figura cumplido. CUANDO llega el segundo ENTONCES las dos vuelven a
pendiente. CUANDO se le vende al segundo y se anotan las ventas de los dos ENTONCES las dos figuran
cumplidas, y al cierre siguen cumplidas. DADO el primero vendido y el segundo sin llegar CUANDO
cierra la noche ENTONCES atención y registrar quedan pendientes. El primero vendido que todavía se
despide ya cuenta como vendido y cerrado.

### AC-CTR-144 — Entrega incompleta: el comprador que se va no cuenta *(verifica BR-CTR-031, BR-CTR-015)*

DADO dos compradores, CUANDO al primero se le entrega una parte del pedido y se va al vencer su
horario ENTONCES lo entregado queda en el piso, el primero no cuenta como atendido y lo vendido de
cada producto sigue en 0. CUANDO el segundo compra bien y se anotan sólo los productos del
segundo ENTONCES registrar figura cumplido y atención figura pendiente, también al cierre. Anotar
una unidad de más o de menos descumple registrar.

### AC-CTR-145 — Pedido completo sin ticket: el comprador que se va no cuenta *(verifica BR-CTR-031, BR-CTR-015)*

DADO dos compradores, CUANDO al primero se le entregan todos los productos y no el ticket y se va
al vencer su horario ENTONCES los productos quedan en el piso, el primero no cuenta como atendido
y lo vendido de cada producto sigue en 0. CUANDO el segundo compra bien y se anotan sólo los
productos del segundo ENTONCES registrar figura cumplido y atención figura pendiente, también al
cierre.

### AC-CTR-146 — Una compra vendida se despide sin vencer *(verifica BR-CTR-031, BR-CTR-030)*

DADO el primer comprador con todos los productos y el ticket entregados, antes de terminar su
despedida, CUANDO llega el límite de su horario ENTONCES no vence: sigue vendido, sus productos no
vuelven al piso y atención y registrar lo cuentan como cerrado.

### AC-CTR-133 — Sólo el nombre propio va en amarillo *(verifica BR-CTR-039)*

DADO un pedido de una unidad de un producto cuyo subtítulo es «Una caja de fideos» más su nombre
CUANDO se consulta recordatorio ENTONCES el texto es «Quiero una caja de fideos » seguido del
nombre en amarillo y un punto final sin color; el resto del subtítulo no lleva color. Con dos
unidades, «dos» sin color y el nombre en amarillo; con tres, lo mismo con «tres». DADO un pedido
de tres productos distintos CUANDO se consulta recordatorio ENTONCES cada nombre queda en amarillo
y el subtítulo restante, las comas y la «y» quedan sin color. En el rechazo y en el
agradecimiento rige lo mismo.

## No objetivos

- Esta capacidad NO decide cuántas unidades hay ni dónde están: se lo pregunta a
  [`store-stock`](../store-stock/store-stock.md).
- Esta capacidad NO inventa el contenido narrativo: conserva los guiones aprobados de los compradores.
- Esta capacidad NO descuenta tiempo del turno. Atender cuesta porque el reloj corre.

## Contratos

`Compradores.segunda_jornada_definida() -> Array[Comprador]` declara el padrón fijo de la
jornada 2 sin azar.
`DialogosDeCompradores.Personaje` conserva NINGUNO/TIN/TIA y añade FEDE/MIA. Sus campos
`fede`, `mia`, `despedida_fede` y `despedida_mia` son `PackedStringArray`; cada consulta crea
un cursor propio. `inicial(personaje)` y `despedida(personaje)` conservan sus firmas.
`recordatorio(personaje: int, rechazo: bool = false, pedido: Venta = null,
productos_completos: bool = false) -> Dialogo` conserva los lectores de Tin y Tia y calcula los
comunes de Fede y Mía desde el pedido original y la recepción. Un dato requerido sin catálogo devuelve `null`
en la construcción del comprador y emite el diagnóstico, sin publicar una compra parcial.
Cada jornada de la 3 a la 5 declara la agenda de sus dos compradores y recibe la semilla de la
partida: devuelve compradores con pedidos y estados nuevos, y el mismo par de semilla y jornada
produce los mismos productos. `DialogosDeCompradores.Personaje` suma CAMI; el comprador que no
trae guion propio usa los textos de BR-CTR-048.

- **Entrada:** el padrón de la noche, los vendibles de cada producto, el objeto leído y los
  pedidos de borrar o imprimir, el número de jornada, las elecciones por renglón y el objeto
  sostenido con su destino de uso; catálogo y apertura del padrón fijo de jornada 2,
  compartido por atención y reposición, con los guiones y figuras propios de Fede/Mía; para las
  jornadas 3 a 5, la semilla de la partida y la lista de compradores de la apertura.
- **Salida:** quién está en la ventanilla, el pedido, el total, la diferencia, el aviso de
  faltantes, cuántos van despachados, el desvío de la noche, lo vendido de cada producto y el
  papel impreso o desechado; al vencer una compra incompleta, las unidades recibidas que
  vuelven al piso interior y el descarte del ticket aceptado; agenda, pedidos fijos, textos
  comunes y conversaciones propias de jornada 2 con progreso independiente por atención.
- **Falla:** un pedido que supera sus vendibles se rechaza entero; una atención despachada
  rechaza todo lo demás. Fuera de la entrega al comprador, usar un objeto que no sea ticket,
  o un destino distinto del inodoro, no produce descarte. Un producto requerido ausente
  del catálogo impide construir su pedido; no se sustituye ni se publica un pedido parcial.

## Señales

- El modo con el que arranca el programa, la lectura correcta o rechazada con su motivo,
  los renglones cambiados, el ticket impreso y el descarte de un ticket.
- El comprador que llega, la entrada de diálogo mostrada, el diálogo cerrado y la atención
  despachada.
- La compra vencida y sus unidades abandonadas, una sola vez por compra.

## Dependencias

- [`store-stock`](../store-stock/store-stock.md) (consume y alimenta): los vendibles y el cobro;
  y lo vendido de cada producto, contra lo que se compara la planilla de registrar.
  Las compras físicas cerradas, vendidas o vencidas, de los compradores que ya llegaron
  habilitan esa comparación durante la noche (BR-CTR-031); al cierre se exigen cerradas ambas.
  No se exige vender ambas para evaluar Registro. Los productos de compras parciales no suman ventas.
- [`player-actions`](../player-actions/player-actions.md) (consume y alimenta): lo sostenido
  llega al lector; imprimir produce un papel levantable que se retira en otra jornada.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (consume y alimenta): el número de jornada
  decide el modo del programa; se avisa cuándo la obligatoria quedó cumplida.
- [`store-cleanup`](../store-cleanup/store-cleanup.md) (consume): distingue inodoro y lavatorio;
  desechar papel conserva los efectos de limpieza de las herramientas; las unidades abandonadas
  adentro participan del desorden al cierre y de las consecuencias de tirar objetos importantes.

## Preguntas abiertas

- **OQ-CTR-001 — ¿Qué le pasa al jugador que cobra mal toda la noche?**
  - Por qué sigue abierta: el desvío acumulado se calcula y todavía no lo consume nadie. El GDD
    no dice si el jefe lo descuenta, lo comenta o lo ignora.
  - Decide: el dueño del repo.
  - Bloquea: nada de lo escrito acá. Abriría una regla en
    [`employment-record`](../employment-record/employment-record.md).
- **OQ-CTR-002 — ¿Cuántos compradores vienen por noche, y cuánto compra cada uno?**
  - Por qué sigue abierta: para las jornadas sin agenda game design dio un margen de 1 a 3 compradores, con 1 a 3 productos
    cada uno, y no eligió un valor. Con pocos vendibles por producto, un padrón que pide de más
    deja ventas que se rechazan.
  - Decide: game design.
  - Bloquea: nada. Cambiaría `BR-CTR-001` y el padrón. La jornada 2 está decidida en BR-CTR-037
    y las jornadas 3 a 5 en BR-CTR-044 a BR-CTR-047.
- **OQ-CTR-007 — ¿Cuándo pide Fede productos de almacén?**
  - Por qué sigue abierta: la ficha dice que alguna noche Fede pide productos de almacén, pero no da
    la noche ni la lista.
  - Decide: game design.
  - Bloquea: nada. Sumaría productos al grupo de Fede en BR-CTR-047.
