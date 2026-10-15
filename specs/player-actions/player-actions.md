---
schema_version: 1
capability_id: CAP-PLY
status: draft
owner: por definir
provenance: GDD «Controles»; fichas «8. Tarea: Reposición», «Notas», «Interfaces virtuales durante la jornada» y «Referencia de controles»; decisiones de #368, #369, #370, #373 y #382; migración de los specs 003, 004, 006, 014, 034, 043
---

# Capacidad: lo que el empleado puede hacer

## Propósito

Moverse por el local, enfocar lo que está a mano, levantar una cosa por vez y abrir las puertas.
Lo único que tiene que hacer bien es **costar recorrido sin pelear con el jugador**: el precio de
una tarea son los metros, no la torpeza del control.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Mira** | lo que la vista enfoca, dentro de su alcance y su desvío | cursor, puntero |
| **Foco** | qué objeto está enfocado ahora, y si cambió | selección, target |
| **Manos** | qué se lleva encima. Es una sola | inventario, mochila |
| **Suspender** | apagar juntos la caminata, la mirada y el foco | pausar, bloquear |
| **Interactuable** | lo que contesta cuando se lo usa | clickeable, activable |
| **Nota pegada** | hoja fija del local que se lee, sin levantarse ni entrar al cuaderno | nota de investigación |
| **Casillero** | cada lugar de la fila de adelante de la góndola, vacío u ocupado: lo define [`store-stock`](../store-stock/store-stock.md) | hueco, slot |
| **Referencia de controles** | la columna de líneas de arriba a la izquierda que dice qué control sirve ahora para lo que se mira y lo que se lleva | ayuda, tutorial, leyenda |

## Comportamiento normativo

### BR-PLY-001 — La diagonal no camina más rápido

CUANDO se camina en diagonal, el sistema DEBE normalizar la dirección. Es el bug clásico del
controlador de primera persona: no se nota jugando hasta que alguien lo aprovecha.

### BR-PLY-002 — El adelante gira con la mirada

El sistema DEBE rotar la dirección de la caminata con el giro horizontal de la vista. La
velocidad de caminata es de **3,5 metros por segundo**: un almacén se cruza caminando, no
corriendo.

### BR-PLY-003 — La vista no se da vuelta

El sistema DEBE dar la vuelta completa en horizontal y DEBE limitar el vertical a **±1,4
radianes**. Pasarse de ahí da vuelta la cámara, y eso no es un límite de gusto.

### BR-PLY-004 — Se enfoca lo que está a mano

El sistema DEBE enfocar lo que está a **2,5 metros o menos** y dentro de su tolerancia angular
respecto del centro de la vista: **3 grados o menos** para productos y huecos de reposición,
**15 grados o menos** para los otros objetos. El desvío se mide respecto de la superficie
visible. Entre varios candidatos gana el de menor desvío, y con el mismo desvío el más cercano.

### BR-PLY-005 — El foco avisa sólo cuando cambió

El sistema DEBE avisar del foco **sólo cuando cambia el objeto enfocado o si es interactuable**.
Que cambie la distancia mientras el jugador camina hacia lo mismo NO es un cambio: el rayo se lee
sesenta veces por segundo.

### BR-PLY-006 — Suspender es una sola llamada

CUANDO otra cosa toma el control —la ventanilla, la computadora, el celular, una nota pegada, el programa de tickets, el cierre—, el sistema DEBE
apagar **juntos** la caminata, la mirada y el foco, y DEBE soltar lo enfocado. Con interruptores
sueltos, cada pantalla tiene que acordarse de todos.

### BR-PLY-007 — Una cosa por vez

El sistema DEBE permitir llevar **1 objeto**. Es la mitad del precio de sacar la basura: tres
bolsas y una mano son tres viajes.

### BR-PLY-008 — Los dos rechazos de agarrar, en orden

CUANDO se intenta agarrar, el sistema DEBE rechazar por **no es levantable** primero y por
**manos llenas** después. Al revés, apuntarle a una puerta con algo en la mano contestaría el
motivo que el jugador puede resolver, y al vaciar las manos la puerta seguiría sin levantarse.

### BR-PLY-009 — Soltar con las manos vacías no anuncia nada

SI no se lleva nada, ENTONCES soltar NO DEBE avisar que se soltó algo. Sin eso, cada clic al aire
anuncia un objeto.

### BR-PLY-010 — Lo que se suelta se puede volver a agarrar

El sistema DEBE soltar los objetos **dentro del alcance de la mira**. Las tres distancias de
examinar, llevar y soltar van de la más cerca a la más lejos, y ninguna llega al alcance.

### BR-PLY-011 — La puerta es una intención y una hoja

CUANDO se acciona —clic izquierdo— una puerta que no está trabada, el sistema DEBE alternar
entre abierta y cerrada de inmediato, y DEBE mover la hoja hacia su tope sin pasarse y sin saltar en un cuadro.
Abierta, la hoja queda a **un cuarto de vuelta** y deja pasar.

### BR-PLY-012 — Una herramienta sirve para algo o para nada

CUANDO se usa lo que se lleva sobre algo, el sistema DEBE contestar el efecto declarado para ese
par, y **ningún efecto** para cualquier otro par o con las manos vacías. El uso de un ticket
sobre el inodoro DEBE desecharlo según [`counter-service`](../counter-service/counter-service.md);
las herramientas DEBEN conservar los efectos de [`store-cleanup`](../store-cleanup/store-cleanup.md).

SI la mira enfoca una puerta, ENTONCES usar NO DEBE usar lo que se lleva: sobre una trabada
DEBE avisar que está trabada, y sobre una puerta interior NO DEBE hacer nada. La herramienta NO DEBE
tener efecto y lo que se lleva DEBE permanecer en la mano (BR-PLY-026).

### BR-PLY-013 — Lo que se suelta queda quieto

CUANDO se suelta un objeto sobre una superficie, el sistema DEBE dejarlo llegar al reposo. Un
objeto que se agita sin decaer se ve como un parpadeo, y el jugador no tiene cómo distinguirlo de
un objeto que no se apoyó.

### BR-PLY-014 — Lo que cae no atraviesa el piso

CUANDO un objeto cae desde la altura de la mano o más, el sistema DEBE dejarlo apoyado sobre el
piso. El caso que decide es el producto más delgado.

### BR-PLY-015 — Lo que se agarra no queda adentro de un sólido fijo

CUANDO algo que se agarra se suelta, se empuja o se duerme, el sistema DEBE dejarlo sin
superponerse con el material de ningún sólido fijo: un mueble, una pared, el techo o la fachada.
Apoyado contra una cara, o encima, no es superponerse. El caso que decide es el objeto más chico
contra el sólido más delgado.

### BR-PLY-016 — Lo que igual queda adentro vuelve a un lugar alcanzable

SI algo que se agarra queda superpuesto con un sólido fijo al soltarlo, al terminar un empujón o
al dormirse, ENTONCES el sistema DEBE llevarlo al primero de estos lugares que quede libre y
alcanzable: deshacer el gesto —volver al inicio del empujón o, si se soltó, al piso al lado del
jugador—; alrededor del punto donde entró, hasta una distancia de su tamaño;
encima de lo que ocupa su lugar de origen, si admite otro encima; y su lugar de origen. Libre y
alcanzable es sin superponerse con ningún sólido fijo, apoyado y fuera de las áreas de las
tareas. SI ninguno queda libre, ENTONCES DEBE dejarlo donde está. El sistema NO DEBE devolverlo
a la mano, y NO DEBE cambiar el estado de ninguna tarea por el rescate.

### BR-PLY-017 — La hoja arrastra lo suelto que tiene adelante

MIENTRAS la hoja de una puerta gira, el sistema DEBE correr en el sentido del giro los objetos
sueltos que encuentra en su recorrido, despiertos o dormidos. CUANDO la hoja queda quieta, el
sistema NO DEBE dejar nada adentro de ella: la hoja quieta es un sólido fijo más.

### BR-PLY-018 — Lo soltado se apoya donde se mira

CUANDO se suelta algo con la mira sobre una superficie al alcance, el sistema DEBE apoyarlo sobre
el punto que la mira toca, si esa superficie lo admite. Una superficie lo admite si es
horizontal —con el mismo corte que apoyar una caja— y si lo de abajo es el mundo fijo o un objeto
que admite otro encima. Sólo las cajas contenedoras admiten otro encima.

SI la superficie no lo admite, o ahí lo soltado queda encimado con algo o adentro de un mueble,
ENTONCES el sistema DEBE soltarlo como sin mira: al frente, o a los pies si adelante no hay
lugar.

Algunas cosas se apoyan derechas: hoy, sólo el balde. CUANDO se suelta una de ellas, el sistema
DEBE dejarla con su eje vertical, mire adonde mire la vista. SI justo en el punto que la mira
toca no entra, ENTONCES el sistema DEBE probar alrededor de ese punto, sobre el mismo apoyo y
hasta un ancho de lo soltado. SI ahí tampoco entra, o la superficie no la admite, ENTONCES DEBE
dejarla derecha en el piso al lado del jugador. Soltar suelta: el sistema NO DEBE devolverla a la
mano.

### BR-PLY-019 — Cada noche arranca con las puertas cerradas

CUANDO se abre una jornada, el sistema DEBE dejar las puertas interiores cerradas, con la hoja en
su lugar y sin girar hasta él, aunque la noche anterior hayan quedado abiertas o a medio giro.

### BR-PLY-020 — Tres puertas no abren, y cada gesto sobre una puerta avisa

SI una puerta está trabada, ENTONCES usarla NO DEBE abrirla ni girar la hoja, y
DEBE contestar que está trabada, todas las veces. La entrada al local, el portón del depósito y
la oficina del jefe están trabadas; las dos puertas interiores no.

CUANDO se acciona una puerta que abre, el sistema DEBE avisar una vez si se abrió o se cerró.
CUANDO se usa una trabada, DEBE avisar una vez que está trabada. El aviso de trabada del portón es distinto del de las otras dos. Cerrar las
puertas al abrir la jornada NO DEBE avisar: no es un gesto del jugador.

### BR-PLY-021 — Cada noche arranca en la entrada

CUANDO se abre una jornada, el sistema DEBE dejar al jugador en el punto de arranque: frente a la
entrada del local, del lado de adentro y mirando hacia el local. Queda con la vista horizontal y
quieto, aunque la noche anterior haya terminado en otro lugar, mirando a otro lado y caminando.
Vale también para la primera noche.

### BR-PLY-022 — Los casilleros vacíos sólo muestran el envase al enfocarlos

El sistema NO DEBE dibujar ningún envase ni contorno en los casilleros vacíos sin foco.
Vale con las manos vacías, con una unidad en la mano y con cualquier otra cosa.
MIENTRAS el jugador lleva en la mano una unidad de un producto, la mira DEBE poder enfocar
cada casillero vacío de ese producto, y ninguno ocupado ni de otro producto. SI la mano está
vacía o lleva cualquier otra cosa, ENTONCES la mira NO DEBE enfocar ningún casillero vacío: una
caja se apoya, no se coloca.

### BR-PLY-023 — El casillero apuntado muestra una vista previa y el clic coloca ahí

CUANDO la mira enfoca un casillero vacío del producto que se lleva en la mano, el sistema DEBE
mostrar la textura correspondiente del producto en blanco y negro, con opacidad del 75%.
La vista previa DEBE ignorar las luces y sombras de la escena para conservar su claridad.
Los demás casilleros vacíos NO DEBEN dibujar envases ni contornos. Al perder el foco,
la vista previa DEBE desaparecer.
CUANDO el jugador hace clic, el sistema DEBE colocar la unidad en ese casillero y en
ningún otro (BR-STK-009). La mira elige entre casilleros como entre cualquier otro candidato
(BR-PLY-004).

### BR-PLY-024 — Con las manos vacías se agarra de la fila de adelante

MIENTRAS las manos están vacías, la mira DEBE poder enfocar cada unidad colocada en la fila de
adelante de la góndola, y CUANDO el jugador hace clic, el sistema DEBE ponérsela en la mano
(BR-STK-033). La unidad enfocada DEBE llevar el contorno del foco sobre su propio aspecto, y
dibujarse una sola vez. La mira NO DEBE enfocar la fila de atrás, ni ninguna unidad colocada
mientras la mano lleva algo: agarrar de la góndola es una cosa más por vez (BR-PLY-007).

### BR-PLY-025 — El balde se lleva vertical

MIENTRAS el jugador lleva el balde en la mano, el sistema DEBE sostenerlo en el mismo punto
de carga que las cajas, sin rotación adicional hacia la cara. Su eje DEBE permanecer vertical
respecto del piso al mirar arriba o abajo, y DEBE acompañar el giro horizontal del jugador.
CUANDO se lo suelta, queda derecho sobre el apoyo (BR-PLY-018).

### BR-PLY-026 — El clic izquierdo abre lo fijo y conserva la mano

CUANDO se hace el gesto de agarrar —clic izquierdo— sobre una puerta interior, la computadora,
la caja registradora o una nota pegada, el sistema DEBE abrirla o alternarla con las manos
vacías y con cualquier cosa en la mano. Lo que se lleva DEBE seguir en la mano: ese clic NO
DEBE soltarlo. La atención DEBE iniciarse sobre la persona según BR-PLY-034, sin abrir el hueco.

CUANDO se usa —clic derecho— la computadora, la caja registradora o una nota cerradas, el sistema
NO DEBE abrirlas. Usar una puerta interior tampoco DEBE alternarla. Usar es el único gesto que
hace avisar a una trabada (BR-PLY-020): el izquierdo sobre una trabada NO DEBE avisar ni soltar
lo que se lleva. El uso de una puerta NO DEBE pedir el uso de la herramienta ni la reposición.
SI el control está suspendido, ENTONCES ningún gesto DEBE abrir ni alternar lo fijo.

### BR-PLY-027 — Asomarse encuadra los bordes visibles y devuelve la vista

CUANDO se inicia un diálogo con el comprador, el sistema DEBE situar la vista frente a los
bordes visibles de su marco,
considerando su ancho, alto y diferencia de profundidad, el campo vertical y el aspecto de
pantalla. Los bordes DEBEN entrar completos y ocupar de borde a borde el eje que limita, sin
que la cáscara ni el antepecho oculten la abertura. El cuerpo y los ángulos efectivos de la
mirada NO DEBEN cambiar. MIENTRAS se está asomado, el encuadre DEBE permanecer estable aunque
el dibujo de la mirada termine de alcanzar su giro.

CUANDO termina el diálogo inicial, recordatorio, rechazo o despedida, o vence el comprador, el
sistema DEBE devolver automáticamente el movimiento y recuperar la posición de reposo de la
vista y su orientación efectiva anterior. Con el dibujo ya alcanzado, DEBE recuperar la pose exacta anterior; con un
giro dibujado pendiente, NO DEBE devolver la vista a los ángulos dibujados atrasados. Abrir de
nuevo sin cerrar DEBE conservar el reposo de la primera apertura. Cerrar sin abrir NO DEBE
mover la vista ni devolver el control tomado por otra cosa. El cierre del turno DEBE devolver
la vista antes de mostrar la devolución.

SI el ancho, alto o aspecto no son positivos, la profundidad es negativa o el campo vertical
no está entre 0 y 180 grados sin incluir los extremos, ENTONCES el sistema NO DEBE mover la
vista. Una profundidad nula es válida. Cambiar el aspecto mientras se está asomado NO DEBE
recalcular la vista hasta la próxima apertura.

### BR-PLY-028 — Suspendido, el izquierdo no agarra ni suelta

MIENTRAS el control está suspendido por la computadora, la ventanilla, una nota pegada o el programa de tickets, el gesto de agarrar
NO DEBE agarrar lo enfocado ni soltar lo que se lleva. Examinar DEBE conservar su propio
ruteo del gesto. Al salir, lo que se llevaba DEBE seguir en la mano, salvo una entrega aceptada al comprador (BR-PLY-034).

### BR-PLY-029 — Leer una nota pegada

CUANDO el clic izquierdo apunta a una nota pegada, el sistema DEBE mostrar su lectura y
suspender el control. Otro clic, izquierdo o derecho, DEBE cerrar y reanudar. Lo que se lleva DEBE conservar
su lugar en la mano, sin usarse ni soltarse. Una pantalla abierta o un examen NO DEBE permitir
abrir otra hoja. Leer NO DEBE detener el turno.

CUANDO termina el turno, la lectura DEBE cerrarse antes de la devolución. La pausa DEBE verse
encima de la nota; al reanudar, la nota DEBE continuar abierta y el control suspendido.

### BR-PLY-030 — Lo que dice cada hoja

El sistema DEBE permitir leer las notas de tareas a realizar, mantener el local ordenado,
jabones y manchas, instrucciones de limpieza y no tirar papel. La hoja y la lectura DEBEN
compartir su contenido: texto para las dos del corcho, imagen original completa para las cuatro
del baño. Hay una hoja de no tirar papel arriba de cada uno de los dos inodoros, y las dos
comparten la misma imagen. Las dos hojas del corcho DEBEN tener formato y tamaño equivalente a
A4, con el contenido visible en el mundo; NO DEBEN presentarse como post its ni como una hoja
por tarea.
Las hojas del baño DEBEN conservar sus imágenes artísticas.

La nota de tareas DEBE enumerar sólo las obligatorias que declara la jornada, en el orden
atención al cliente, registro de productos vendidos, limpieza, reposición y, al final, la
particular de esa jornada. Ordenar las cajas DEBE llamarse «Ordenar cajas en el depósito» y
la basura, «Tirar la basura». CUANDO se abre otra jornada, la nota DEBE actualizarse con la
lista nueva, sin exigir salir y volver a entrar al local.
Cada tipo declarado DEBE tener nombre. Una lista vacía DEBE conservar el título sin agregar
renglones. La nota de ordenado DEBE presentar las tres viñetas de su criterio, sin reescribirlas.

### BR-PLY-031 — El programa abre sin soltar la mano

CUANDO se hace clic izquierdo sobre la caja registradora, el sistema DEBE abrir su programa y
suspender el control, conservando lo que se lleva y su lugar en la mano. Un clic derecho, o un
clic izquierdo por fuera del panel del programa, DEBE cerrar y reanudar. Una pantalla o examen
abiertos NO DEBEN permitir abrir el programa.
Leerlo NO DEBE detener el turno. La pausa DEBE dibujarse por encima y, al reanudar, DEBE
continuar abierto y suspendido. El cierre del turno DEBE cerrarlo antes de mostrar la devolución.

### BR-PLY-032 — El lector usa la unidad sostenida

CUANDO se usa el lector con clic derecho y algo en la mano, el sistema DEBE pedir su lectura
sin agarrarlo, soltarlo ni usarlo como herramienta. Con la mano vacía NO DEBE pedir lectura
ni avisar rechazo. Los rechazos y sus motivos los decide
[`counter-service`](../counter-service/counter-service.md).

### BR-PLY-033 — El ticket es un papel que se lleva

CUANDO se imprime con renglones cargados, el sistema DEBE cerrar el programa y mostrar el
papel saliendo de la ranura con una animación. Al terminar DEBE quedar quieto y levantable,
sin superponerse con sólidos. Agarrarlo durante la salida DEBE detener su animación para
que permanezca en la mano. SI el anterior todavía ocupa
la ranura, ENTONCES DEBE soltarlo y dejarlo caer. Agarrarlo DEBE desocupar la ranura, de modo
que imprimir después NO DEBE soltar el papel de la mano. El ticket DEBE poder agarrarse,
soltarse y examinarse como otro levantable, llamarse «Ticket» y sonar como papel.

La caja, el lector y el papel DEBEN poder enfocarse desde un piso transitable, con el cuerpo
del jugador libre y dentro del alcance. El lector DEBE apoyar sobre el mostrador. El origen
de rescate del papel DEBE ser su pose real al imprimirse, conservando su tamaño pese a la
escala de la caja. La apertura de otra jornada DEBE retirar todos los tickets después de
terminar el examen y vaciar las manos.

### BR-PLY-034 — Clic sobre el comprador

CUANDO se hace clic izquierdo sobre el comprador físico vigente dentro del alcance, el sistema
DEBE solicitar una sola interacción según el estado de atención. El primer clic DEBE iniciar
la conversación y su encuadre sin un clic previo sobre el hueco, conservando cualquier objeto
sostenido. Antes de terminar la inicial NO DEBE intentar entregarlo. Después, la mano vacía
DEBE pedir recordatorio y la mano ocupada DEBE intentar entrega en esa misma pulsación.
Una aceptación DEBE vaciar la mano y conservar el mismo cuerpo recibido; un rechazo DEBE
mantenerlo en la mano y abrir su diálogo.
MIENTRAS habla, cada izquierdo DEBE avanzar exactamente una entrada, sin entregar ni soltar;
el que abre NO DEBE saltar la primera. Derecho NO DEBE abandonar y Esc DEBE abrir pausa.
El clic que termina un diálogo NO DEBE actuar también sobre el mundo. Vencimiento, salida y
cierre del turno DEBEN retirar el foco y liberar el encuadre; cerrar el turno conserva el control
del cierre. MIENTRAS habla, un clic fuera de la persona NO DEBE agarrar ni soltar.
La referencia DEBE decir «Hablar» antes de terminar la inicial, aun con mano ocupada; después,
«Hablar» con mano vacía y «Entregar» con producto o ticket, según el permiso de atención.

### BR-PLY-035 — La referencia lista los controles que sirven ahora

MIENTRAS transcurre la jornada, el sistema DEBE mostrar arriba a la izquierda, una por renglón,
las líneas de la referencia de controles que valen para lo que la mira enfoca y lo que se
lleva, y ninguna otra. Cada línea DEBE leerse «[<control>] <texto>», con el control de su
gesto (BR-PLY-037). De arriba abajo, en este orden:

| # | Texto | Gesto | Vale cuando |
|---|---|---|---|
| 1 | Examinar (mano) | examinar | hay un levantable en la mano |
| 2 | Examinar | examinar | la mano está vacía y la mira enfoca un interactuable |
| 3 | Agarrar | agarrar, clic izquierdo | la mano está vacía y la mira enfoca un levantable |
| 4 | Dejar | agarrar, clic izquierdo | hay un levantable en la mano |
| 5 | Interactuar | usar, clic derecho | la mira enfoca un interactuable que no es una caja del depósito, y el derecho sobre él, con lo que hay en la mano, tiene efecto (BR-PLY-036) |
| 6 | Sacar producto | usar, clic derecho | la mira enfoca una caja del depósito apoyada, la mano está vacía y la caja tiene al menos una unidad |
| 7 | Meter producto | usar, clic derecho | la mira enfoca una caja del depósito apoyada, la mano lleva una unidad de su producto y la caja tiene menos que las unidades de una caja |

Sobre una caja del depósito NO DEBE salir «Interactuar». Con algo en la mano, la línea del
izquierdo DEBE ser «Dejar» también cuando el izquierdo lo va a tirar al contenedor de basura
(BR-CLN-026): la referencia no tiene una línea para tirar. El contador de tareas DEBE conservar
su lugar, arriba de la primera línea de la referencia. CUANDO el foco y la mano cambian en el
mismo cuadro, la referencia DEBE armarse con los dos valores nuevos, sin mostrar una
combinación intermedia.

### BR-PLY-036 — El derecho no adelanta el resultado

El clic derecho DEBE contar con efecto, con cualquier cosa en la mano o con la mano vacía,
sobre una puerta trabada, que avisa (BR-PLY-020), y sobre el cuerpo
y la tapa del contenedor de basura (BR-CLN-025). Sobre una puerta interior, la computadora, la
ventanilla, la caja registradora y una nota pegada NO DEBE contar con efecto: las abre el
izquierdo. DEBE contar con efecto el par declarado de lo que se lleva y su objetivo
(BR-PLY-012); el lector con una unidad en la mano (BR-PLY-032); el inodoro con un ticket en la
mano (BR-CTR-025); y un tacho que conserva su bolsa, con la mano vacía (BR-CLN-032).

Con la mano vacía, el lector, el inodoro, el lavatorio y el balde NO DEBEN contar con efecto.
Un tacho sin bolsa, o con la mano ocupada, NO DEBE contar con efecto. MIENTRAS el programa de
la caja es manual, el hueco del lector NO DEBE contar con efecto (BR-CTR-024).

Un par declarado DEBE contar con efecto aunque el uso vaya a rechazarse por el estado de la
herramienta o del objetivo: mirar una mancha NO DEBE decir cuál es el jabón correcto sin
probarlo. Averiguar si hay efecto NO DEBE cambiar el estado de nada: ni la mano, ni la
herramienta, ni el objetivo, ni la bolsa de un tacho.

### BR-PLY-037 — El control sale de la asignación vigente

El control entre corchetes DEBE ser el que el gesto tiene asignado en el momento de mostrar la
línea, no uno escrito: si la asignación cambia, la línea la sigue. El botón izquierdo del mouse
DEBE leerse «Click Izq», el derecho «Click Der», y una tecla con su nombre de teclado. SI el
gesto tiene asignado un control de teclado o mouse y uno de joystick, ENTONCES DEBE leerse el de
teclado o mouse. SI el gesto no tiene ningún control con nombre, ENTONCES su línea NO DEBE
mostrarse.

### BR-PLY-038 — Suspendido, la referencia está vacía

MIENTRAS el control está suspendido —por el examen, una nota pegada, la computadora, la caja
registradora, la ventanilla o el celular—, la pausa está abierta o la jornada cerró, la
referencia NO DEBE mostrar ninguna línea. Al reanudar, DEBE volver a armarse con lo que la mira
enfoca y lo que se lleva.

### BR-PLY-039 — El foco pertenece a la silueta de la persona

MIENTRAS un comprador está vigente, el sistema DEBE permitir enfocar su figura visible dentro
del alcance y dibujar el contorno de su silueta animada con el color común del foco. Cada cambio
de dibujo DEBE actualizar el contorno, sin enmarcar zonas transparentes. Los sólidos que lo
ocultan DEBEN ocultar también su contorno. Perder foco DEBE restituir su apariencia original.
SI el comprador no llegó, venció o quedó despachado, ENTONCES NO DEBE ofrecer foco ni interacción,
aunque su imagen siga retirándose. El hueco, el marco y el antepecho NO DEBEN ser objetivos de
atención. El hueco NO DEBE tener una barrera de vidrio; sus sólidos reales DEBEN conservarse.

## Criterios de aceptación

### AC-PLY-001 — La diagonal no corre *(verifica BR-PLY-001)*

DADO una entrada de adelante y derecha a la vez CUANDO se calcula la velocidad ENTONCES su módulo
es la velocidad de caminata y no su raíz de dos.

### AC-PLY-002 — El adelante sigue a la vista *(verifica BR-PLY-002)*

DADO un giro de un cuarto de vuelta CUANDO se camina hacia adelante ENTONCES la dirección es la
que mira la vista, y la entrada nula da el vector cero.

### AC-PLY-003 — El vertical se clava *(verifica BR-PLY-003)*

DADO un giro hacia abajo enorme ENTONCES el ángulo vertical queda en `-1.4`; hacia arriba, en
`1.4`; y el horizontal da la vuelta sin crecer sin límite.

### AC-PLY-004 — Los dos bordes de la mira *(verifica BR-PLY-004)*

DADO un candidato a 2,5 metros ENTONCES se enfoca; a 2,6, no. DADO un objeto que no sea
un producto ni un hueco de reposición a 15 grados de desvío
ENTONCES se enfoca; a 16, no.

DADO un producto o un hueco de reposición a 3 grados de desvío ENTONCES se enfoca;
a 6 grados, no. Esta precisión NO DEBE reducir la tolerancia de los otros objetos.

### AC-PLY-005 — Gana el menor desvío *(verifica BR-PLY-004)*

DADO dos candidatos válidos, uno más cerca y otro con menos desvío ENTONCES se enfoca el de menos
desvío; con el mismo desvío, el más cercano.

### AC-PLY-006 — El foco no habla de más *(verifica BR-PLY-005)*

DADO el mismo objeto enfocado CUANDO se lo observa dos veces a distinta distancia ENTONCES la
segunda no avisa cambio; si cambia si es interactuable, sí avisa.

### AC-PLY-007 — Suspender apaga las tres cosas *(verifica BR-PLY-006)*

DADO el control suspendido CUANDO se gira, se camina y se observa ENTONCES la vista no se mueve,
la velocidad es cero, no hay objetivo enfocado y no se pide el cursor tomado.

### AC-PLY-008 — Una sola mano *(verifica BR-PLY-007)*

DADO un objeto en la mano CUANDO se intenta agarrar otro levantable ENTONCES se rechaza por manos
llenas y se sigue llevando el primero.

### AC-PLY-009 — El orden de los rechazos *(verifica BR-PLY-008)*

DADO las manos llenas CUANDO se intenta agarrar algo no levantable ENTONCES el motivo es «no es
levantable» y no «manos llenas».

### AC-PLY-010 — Soltar al aire no anuncia *(verifica BR-PLY-009)*

DADO las manos vacías CUANDO se suelta ENTONCES no se devuelve ningún objeto.

### AC-PLY-011 — Las tres distancias están ordenadas *(verifica BR-PLY-010)*

DADO las distancias de examinar, llevar y soltar ENTONCES crecen en ese orden y todas son
menores al alcance de la mira.

### AC-PLY-012 — La hoja llega al tope y no se pasa *(verifica BR-PLY-011)*

DADO una puerta recién abierta CUANDO se la hace avanzar muchos segundos ENTONCES el ángulo es
exactamente un cuarto de vuelta; y apenas alternada, ya está abierta con el ángulo en cero.

### AC-PLY-013 — La puerta cierra hasta cero *(verifica BR-PLY-011)*

DADO una puerta abierta del todo CUANDO se la cierra y avanza ENTONCES el ángulo llega a `0.0` y
no baja.

### AC-PLY-014 — El uso declarado y los demás *(verifica BR-PLY-012)*

DADO la mopa sobre una mancha ENTONCES el efecto es limpiar; el balde sobre el lavatorio, llenar;
cualquiera de los tres jabones sobre el balde, teñir; la mopa sobre el balde, mojar; el balde
sobre el inodoro, vaciar; la mopa sobre el inodoro, enjuagar; y el ticket sobre el inodoro,
desechar. Con cualquier par no declarado —uno de ésos al revés, u otro objeto— o con las
manos vacías, no hay efecto.

### AC-PLY-015 — Lo soltado se duerme *(verifica BR-PLY-013)*

DADO los productos del estante apoyados en el piso CUANDO pasan 8 segundos de física ENTONCES
todos están dormidos, y ninguno pasa de 0,02 rad/s después del segundo 2.

### AC-PLY-016 — El delgado no atraviesa *(verifica BR-PLY-014)*

DADO el producto más delgado soltado desde 1,5 metros ENTONCES su altura mínima no baja del plano
del piso menos 5 centímetros.

### AC-PLY-017 — Adentro de un mueble no hay lugar *(verifica BR-PLY-015)*

DADO una caja puesta entera adentro del mostrador, apoyada en el piso CUANDO el juego pregunta si
la caja entra ahí ENTONCES contesta que no: el mueble ocupa ese lugar.

### AC-PLY-018 — La caja soltada pegada no entra al empujarla *(verifica BR-PLY-015)*

DADO una caja soltada pegada al mostrador CUANDO el jugador camina contra ella hasta quedar
bloqueado, y sigue caminando ENTONCES la caja no se superpone con el mostrador y la mira la puede
enfocar.

### AC-PLY-019 — La unidad no entra en una pared *(verifica BR-PLY-015)*

DADO una unidad de producto en la mano CUANDO se la suelta contra una pared, en cualquiera de
tres giros y cuatro alturas de la mira ENTONCES no se superpone con la pared y la mira la puede
enfocar.

### AC-PLY-020 — La unidad no entra en el mostrador *(verifica BR-PLY-015)*

DADO una unidad de producto en la mano CUANDO se la suelta contra el mostrador, en cualquiera de
tres giros y cuatro alturas de la mira ENTONCES no se superpone con el mostrador y la mira la
puede enfocar.

### AC-PLY-021 — La caja se sigue apoyando en un estante del depósito *(verifica BR-PLY-015)*

DADO una caja en la mano CUANDO se la suelta mirando un estante del depósito ENTONCES queda
apoyada en el estante.

### AC-PLY-022 — La caja se sigue apoyando arriba del mostrador *(verifica BR-PLY-015)*

DADO una caja en la mano CUANDO se la suelta mirando la tapa del mostrador ENTONCES queda
apoyada arriba del mostrador.

### AC-PLY-023 — La caja se sigue apilando *(verifica BR-PLY-015)*

DADO una caja apoyada en el piso CUANDO se suelta otra mirando su tapa ENTONCES la segunda queda
apoyada encima de la primera.

### AC-PLY-024 — La unidad se sigue dejando adentro de la heladera *(verifica BR-PLY-015)*

DADO una unidad de producto soltada adentro de la heladera CUANDO pasa un segundo de física
ENTONCES sigue adentro de la heladera, no se superpone con sus paneles y la mira la puede
enfocar.

### AC-PLY-025 — El empujón que terminó adentro se deshace *(verifica BR-PLY-016)*

DADO una caja empujada que al terminar la racha de empujones queda superpuesta con un sólido
fijo, y con el lugar del inicio de la racha libre CUANDO pasa el primer paso de física sin
empujón ENTONCES la caja vuelve al lugar del inicio de la racha.

### AC-PLY-026 — Lo soltado adentro va al piso al lado del jugador *(verifica BR-PLY-016)*

DADO un objeto que al soltarlo queda superpuesto con un sólido fijo CUANDO pasa un paso de
física ENTONCES queda apoyado en el piso al lado del jugador, sin superponerse con nada fijo.

### AC-PLY-027 — Encima de lo que ocupa el origen *(verifica BR-PLY-016)*

DADO una caja adentro de un sólido, sin lugar libre para deshacer ni alrededor, y con otra caja
en su lugar de origen CUANDO se la rescata ENTONCES queda apoyada encima de esa caja. DADO un
objeto en el mismo caso, con otro objeto en su origen CUANDO se lo rescata ENTONCES queda
encima si ese otro admite otro encima, y no queda encima si no lo admite.

### AC-PLY-028 — El origen es el último recurso *(verifica BR-PLY-016)*

DADO un objeto adentro de un sólido, sin lugar libre para deshacer ni alrededor, y con su lugar
de origen libre CUANDO se lo rescata ENTONCES queda en su lugar de origen.

### AC-PLY-029 — El rescate nunca devuelve a la mano *(verifica BR-PLY-016)*

DADO un objeto adentro de un sólido y ningún candidato libre CUANDO se lo revisa ENTONCES queda
donde está, la mano sigue como estaba, y el rescate queda registrado sin lugar.

### AC-PLY-030 — La unidad arrastrada al abrir *(verifica BR-PLY-017)*

DADO una unidad de producto dormida en el recorrido de la hoja CUANDO se abre la puerta y la hoja
queda quieta ENTONCES la unidad no se superpone con la hoja, se movió en el sentido del giro y se
despertó en algún paso.

### AC-PLY-031 — La unidad arrastrada al cerrar *(verifica BR-PLY-017)*

DADO una unidad de producto dormida en el recorrido de la hoja abierta CUANDO se cierra la puerta
y la hoja queda quieta ENTONCES la unidad no se superpone con la hoja y se movió en el sentido
del giro.

### AC-PLY-032 — Al quedar quieta, nada adentro de la hoja *(verifica BR-PLY-017)*

DADO un objeto que quedó adentro de la hoja al terminar un giro CUANDO la hoja queda quieta
ENTONCES el objeto termina fuera de ella, sin superponerse con ningún sólido fijo.

### AC-PLY-033 — Queda donde se mira *(verifica BR-PLY-018)*

DADO algo en la mano y la mira sobre el piso libre, o sobre la tapa de una caja contenedora, a
menos del alcance CUANDO se suelta ENTONCES su base queda sobre el punto que la mira toca, sin
encimarse con nada.

### AC-PLY-034 — Qué superficie admite *(verifica BR-PLY-018)*

DADO una superficie con la inclinación justo debajo del corte de horizontal ENTONCES no admite;
con el corte exacto sobre el mundo fijo, o sobre una caja contenedora, sí; sobre la mopa, no.
Ningún objeto del almacén salvo las cajas contenedoras admite otro encima.

### AC-PLY-035 — Sin superficie que valga, se suelta como siempre *(verifica BR-PLY-018)*

DADO la mira sobre una pared, sobre nada al alcance, o sobre un punto donde lo soltado quedaría
encimado con algo o adentro de un mueble CUANDO se suelta ENTONCES lo soltado sale del mismo
punto que sin mira.

### AC-PLY-036 — La puerta abierta anoche arranca cerrada *(verifica BR-PLY-019)*

DADO una puerta abierta del todo al cerrar la noche CUANDO se abre la jornada siguiente ENTONCES
la puerta está cerrada, su ángulo es `0.0` y la hoja está en su lugar de cerrada, en el mismo
paso.

### AC-PLY-037 — La puerta a medio giro también *(verifica BR-PLY-019)*

DADO una puerta a medio giro al cerrar la noche CUANDO se abre la jornada siguiente ENTONCES la
puerta está cerrada, su ángulo es `0.0` y la hoja está en su lugar de cerrada, en el mismo paso.

### AC-PLY-038 — La trabada no se abre *(verifica BR-PLY-020)*

DADO una puerta trabada CUANDO se la alterna diez veces ENTONCES las diez contesta que está
trabada, sigue cerrada y, después de avanzar 10 segundos, su ángulo es `0.0`.

### AC-PLY-039 — La que no está trabada alterna *(verifica BR-PLY-011, BR-PLY-020)*

DADO una puerta nueva ENTONCES no está trabada. CUANDO se la alterna ENTONCES contesta que no
está trabada y queda abierta.

### AC-PLY-040 — Qué puertas están trabadas *(verifica BR-PLY-020)*

DADO el almacén armado ENTONCES la entrada, el portón del depósito y la oficina del jefe están
trabadas y contestan al uso, y las dos puertas interiores no están trabadas.

### AC-PLY-041 — Un aviso por gesto *(verifica BR-PLY-020)*

DADO una puerta interior cerrada CUANDO se la acciona dos veces seguidas, con la hoja todavía
girando, ENTONCES avisa una vez que se abrió y después una vez que se cerró. DADO una puerta
trabada CUANDO se la usa diez veces ENTONCES avisa diez veces que está trabada, el portón con su
propio aviso, y la hoja no gira. DADO la apertura de una jornada ENTONCES ninguna puerta avisa.

### AC-PLY-042 — Rescatar no mueve la mercadería *(verifica BR-PLY-016)*

DADO una caja del depósito o una unidad fuera de la góndola, superpuesta con un sólido fijo
CUANDO se la rescata ENTONCES lo repuesto en la góndola y lo que queda por sacar de cada caja
siguen iguales.

### AC-PLY-043 — Rescatar una bolsa no la cuenta ni la descuenta *(verifica BR-PLY-016)*

DADO una bolsa tirada y otra no tirada superpuesta con un sólido fijo CUANDO se rescatan
ENTONCES la tirada no se mueve ni aparece, la otra se recupera fuera del sólido y la cantidad
de bolsas depositadas no cambia.

### AC-PLY-044 — La jornada arranca en la entrada *(verifica BR-PLY-021)*

DADO un jugador en cualquier lugar, mirando a cualquier lado y en movimiento CUANDO abre una
jornada ENTONCES queda en el punto de arranque, con el yaw del arranque, la vista horizontal y la
velocidad en cero.

### AC-PLY-045 — Los huecos vacíos no muestran envases sin foco *(verifica BR-PLY-022)*

DADO una unidad de Actroncito en la mano, con dos casilleros de Actroncito vacíos y otro producto
con casilleros vacíos, todos al alcance de la mira y ninguno enfocado, ENTONCES ninguno dibuja
un envase ni un contorno. La mira puede enfocar los dos de Actroncito y ninguno del otro producto
ni ninguno ocupado. DADO las manos vacías, una caja o cualquier otro objeto en la mano ENTONCES
la mira no enfoca ningún casillero vacío.

### AC-PLY-047 — La vista previa aparece sólo en el hueco enfocado *(verifica BR-PLY-023)*

DADO una unidad en la mano y dos de sus casilleros vacíos CUANDO la mira enfoca uno ENTONCES ése
muestra la textura del producto en blanco y negro al 75% de opacidad; el otro no dibuja ningún
envase ni contorno. CUANDO la mira pasa al otro ENTONCES la vista previa aparece sólo en el otro.
CUANDO la mira deja de enfocarlos ENTONCES ninguno dibuja envases ni contornos.

### AC-PLY-048 — El clic coloca en el casillero apuntado *(verifica BR-PLY-023)*

DADO una unidad en la mano y la mira sobre uno de sus casilleros vacíos, que no es el primero
CUANDO se hace clic ENTONCES la unidad queda en ese casillero y en ningún otro, y la mano queda
vacía. CUANDO se hace clic otra vez sobre el mismo casillero ENTONCES la góndola no tiene una
unidad más: con la mano vacía, el clic agarra la que acaba de colocar.

### AC-PLY-049 — Con las manos vacías se agarra de la fila de adelante *(verifica BR-PLY-024)*

DADO las manos vacías y la mira sobre una unidad del medio de la fila de adelante CUANDO se hace
clic ENTONCES esa unidad pasa a la mano, su casillero queda vacío y las de al lado siguen donde
estaban. DADO las manos vacías CUANDO la mira enfoca una unidad colocada ENTONCES esa unidad lleva
el contorno del foco sobre su propio aspecto, se dibuja una sola vez y ninguna otra cambia. DADO
cualquier cosa en la mano ENTONCES la mira no enfoca ninguna unidad colocada, y el
clic no la agarra. DADO la fila de atrás ENTONCES ninguna de sus unidades se enfoca.

### AC-PLY-050 — El balde en la mano permanece vertical *(verifica BR-PLY-025)*

DADO el balde en la mano CUANDO el jugador mira arriba o abajo ENTONCES su eje permanece
vertical respecto del piso, con medio grado de tolerancia, y conserva el punto de carga.
CUANDO gira horizontalmente ENTONCES el balde acompaña ese giro. DADO el balde apoyado
CUANDO se lo vuelve a agarrar ENTONCES vuelve a ese mismo agarre.


### AC-PLY-051 — El balde se apoya derecho donde se mira *(verifica BR-PLY-018)*

DADO el balde en la mano, la vista 40 grados hacia abajo y la mira sobre el piso libre, la tapa
de una caja contenedora, un estante del depósito o el mostrador, a menos del alcance CUANDO se
lo suelta ENTONCES su eje queda a menos de 1 grado de la vertical, su base sobre el punto que la
mira toca, sin encimarse con nada, y la mano vacía. CUANDO pasan dos segundos de física ENTONCES
sigue derecho y a menos de 1 centímetro de donde quedó. DADO el balde con agua ENTONCES después
de apoyarlo el agua se sigue viendo, del mismo color.

### AC-PLY-052 — Si justo ahí no entra, cerca y sobre el mismo apoyo *(verifica BR-PLY-018)*

DADO la mira sobre un apoyo que admite, pegada a algo que no deja entrar el balde en ese punto, y
con lugar libre sobre el mismo apoyo a menos de un ancho de balde CUANDO se lo suelta ENTONCES
queda derecho en ese lugar, a la altura de ese apoyo. DADO además otro apoyo libre más cerca del
punto, a otra altura, ENTONCES no queda en ése.

### AC-PLY-053 — Sin superficie que valga, derecho al lado del jugador *(verifica BR-PLY-018)*

DADO el balde en la mano y la mira sobre una pared, sobre nada al alcance, sobre la mopa o sobre
una superficie con la inclinación justo debajo del corte de horizontal CUANDO se lo suelta
ENTONCES queda derecho en el piso al lado del jugador, sin encimarse con nada, y la mano vacía.
DADO la vista 40 grados hacia abajo a medio metro de una pared CUANDO se lo suelta ENTONCES queda
derecho y, al pasar dos segundos de física, a menos de 1 centímetro de donde quedó. DADO el
jugador en un hueco del tamaño de su cuerpo, sin lugar libre al lado, CUANDO se lo suelta
ENTONCES el balde no vuelve a la mano: la mano queda vacía y el balde, derecho.

### AC-PLY-054 — La puerta abre con cualquier mano y la conserva *(verifica BR-PLY-026, BR-PLY-011)*

DADO una puerta interior cerrada y, por turno, las manos vacías, una unidad, una caja, la
mopa, el balde, un jabón y una bolsa en la mano CUANDO se acciona ENTONCES queda abierta, avisa
una vez que se abrió y la mano lleva lo mismo que antes. CUANDO se acciona otra vez ENTONCES
queda cerrada y avisa una vez que se cerró, aunque la hoja todavía esté girando.

### AC-PLY-055 — Agarrar abre lo fijo sin soltar *(verifica BR-PLY-026)*

DADO una puerta interior o la computadora cerradas, con mano vacía y luego con una unidad,
CUANDO se hace el gesto de agarrar ENTONCES se abren y se conserva la mano. DADO la computadora
cerrada CUANDO se usa ENTONCES sigue cerrada. DADO el hueco vacío de atención CUANDO se hace
izquierdo ENTONCES no se abre ninguna interfaz de atención.

### AC-PLY-056 — El panel abre y cierra sin cambiar la mano *(verifica BR-PLY-026, BR-PLY-006)*

DADO la computadora cerrada y cualquier cosa en la mano CUANDO se hace el gesto de agarrar
ENTONCES se abre, el jugador queda suspendido y la mano lleva lo mismo. CUANDO se usa ENTONCES
se cierra, se reanuda y la mano sigue igual. DADO el control suspendido por otra pantalla
ENTONCES ningún gesto abre lo fijo.

### AC-PLY-057 — Lo fijo gana a la herramienta y la trabada avisa *(verifica BR-PLY-026, BR-PLY-012, BR-PLY-020)*

DADO una puerta trabada y la mopa en la mano CUANDO se usa diez veces ENTONCES avisa trabada
diez veces, la hoja no gira, la mopa sigue en la mano y no se pide limpieza ni reposición.
DADO una puerta interior con la mopa en la mano CUANDO se usa ENTONCES sigue cerrada, no avisa,
la mopa sigue en la mano y tampoco se pide el uso de la mopa.

### AC-PLY-058 — La perspectiva encuadra ambos planos *(verifica BR-PLY-027)*

DADO un marco de 1,40 × 1,36 metros, profundidad 0,18 metros y campo vertical 75 grados
CUANDO se encuadra en 16:9, 16:10 y 4:3 ENTONCES la distancia es 0,886193 metros y la elevación
respecto del centro es 0,069059 metros, con 0,00001 metros de tolerancia. DADO un marco plano
de 3 × 1 metros y campo vertical 90 grados ENTONCES la distancia es 1,125 metros en 4:3 y
2 metros en 3:4. DADO uno de 2 × 4 metros, profundidad 1 metro y campo vertical 90 grados
ENTONCES en aspecto 2 la distancia es 2 metros y la elevación 0,5 metros; en aspecto 1:4 son
4,5 metros y 2/9 metros. DADO cualquiera de los datos inválidos de BR-PLY-027 ENTONCES la
distancia es 0 y la vista conserva su pose.

DADO la ventanilla abierta en 16:9 y 4:3 CUANDO pasan varios cuadros ENTONCES sus cuatro
bordes visibles están dentro de la pantalla con medio píxel de tolerancia, y al menos un eje
ocupa sus dos bordes. DADO un cambio de aspecto mientras está abierta ENTONCES conserva esa
vista y usa el aspecto nuevo en la siguiente apertura.

### AC-PLY-059 — El marco visible tiene el recorrido libre *(verifica BR-PLY-027)*

DADO el marco visible de la ventanilla CUANDO se observan sus bordes superiores e inferiores
desde la vista asomada ENTONCES ninguna malla de la cáscara o del antepecho corta el recorrido
antes de llegar a esos puntos, con 2 milímetros de tolerancia. DADO el hueco físico CUANDO se
cruza el muro 2 centímetros por dentro de cada borde ENTONCES el recorrido está libre; 2 centímetros por fuera, está tapado.

### AC-PLY-060 — Salir recupera el reposo y la orientación efectiva *(verifica BR-PLY-027)*

DADO el dibujo de la mirada ya alcanzado CUANDO se abre y cierra ENTONCES la vista recupera
exactamente la pose global anterior, con 0,00001 metros de tolerancia, y los ángulos
efectivos no cambiaron. DADO un giro dibujado pendiente ENTONCES el encuadre permanece estable
y, al cerrar y pasar más cuadros, la vista conserva su posición de reposo y sigue la
orientación efectiva del control, sin volver a los ángulos dibujados atrasados.

DADO dos aperturas sin cerrar CUANDO se cierra ENTONCES se vuelve al reposo de la primera.
DADO el cierre del turno mientras está abierta ENTONCES se devuelve esa vista y desaparece
el panel. DADO ningún asomarse previo ENTONCES cerrar no mueve la vista.

### AC-PLY-061 — Asomado, la mano no suelta *(verifica BR-PLY-028)*

DADO una unidad en la mano y la computadora o la ventanilla abiertas CUANDO se hace el gesto
de agarrar ENTONCES se conserva la misma unidad y su padre; al cerrar se la sigue llevando.

### AC-PLY-062 — Suspendido y vacío no agarra *(verifica BR-PLY-028)*

DADO las manos vacías, un levantable enfocado y el control suspendido por la computadora o
la ventanilla CUANDO se hace el gesto de agarrar ENTONCES las manos siguen vacías y el objeto
permanece donde estaba.

### AC-PLY-063 — Cada hoja abre su lectura y cierra con cualquier clic *(verifica BR-PLY-029, BR-PLY-006)*

DADO cada una de las seis notas pegadas enfocadas, CUANDO se hace clic izquierdo ENTONCES
aparece su contenido propio y se suspenden caminata, mirada y foco. CUANDO se hace otro clic,
izquierdo o derecho, ENTONCES la lectura se cierra y el control vuelve.

### AC-PLY-064 — La lectura conserva lo llevado *(verifica BR-PLY-029, BR-PLY-026)*

DADO una unidad, caja, mopa, balde, jabón o bolsa en la mano, CUANDO se abre, lee y cierra una
nota ENTONCES se conserva el mismo objeto en su lugar en la mano. El clic NO pide usarlo.

### AC-PLY-065 — La nota no toma el derecho ni E para abrir *(verifica BR-PLY-029, BR-PLY-028)*

DADO una nota cerrada y la mano vacía, CUANDO se hace clic derecho o E ENTONCES la lectura
permanece cerrada. DADO algo en la mano ENTONCES el izquierdo abre la lectura sin soltarlo.
DADO la lectura abierta ENTONCES el izquierdo no agarra ni suelta y E no examina.

### AC-PLY-066 — Una pantalla no abre otra nota encima *(verifica BR-PLY-029)*

DADO la computadora, ventanilla o examen abiertos, CUANDO se pide leer una nota ENTONCES no
se abre. DADO una nota abierta, CUANDO se enfoca otra ENTONCES el contenido actual no cambia
hasta cerrar la primera.

### AC-PLY-067 — Reloj, pausa y cierre conservan su orden *(verifica BR-PLY-029)*

DADO una nota abierta, CUANDO pasan cuadros ENTONCES el tiempo del turno disminuye. CUANDO se
pausa ENTONCES la pausa visible se dibuja por encima de la nota; al reanudar, la nota sigue
abierta y el control suspendido. CUANDO termina el turno ENTONCES queda sólo la
devolución y el control suspendido.

### AC-PLY-068 — Ordenado comparte el texto exacto *(verifica BR-PLY-030)*

DADO la nota de ordenado, ENTONCES su hoja y su lectura comparten «MANTENER EL LOCAL ORDENADO»
y las viñetas «No dejar productos tirados.», «Dejar las cajas en el depósito.» y
«Dejar los elementos de limpieza en el baño.», exactamente.

### AC-PLY-069 — Las obligatorias dan los renglones de tareas *(verifica BR-PLY-030)*

DADO las obligatorias declaradas, ENTONCES «TAREAS A REALIZAR» las enumera en el orden de la
regla. DADO limpieza y tirar la basura, ENTONCES da «1. Limpieza» y «2. Tirar la basura».
DADO cero, ENTONCES conserva el título y cero renglones. Cada tipo declarado tiene nombre,
y los títulos y renglones son iguales en la hoja y su lectura.

### AC-PLY-070 — El baño comparte la imagen artística completa *(verifica BR-PLY-030)*

DADO cada hoja del baño —jabones y manchas, instrucciones de limpieza y las dos de no tirar
papel—, ENTONCES su lectura amplía la misma imagen frontal original completa y no agrega
renglones. Las dos de no tirar papel abren la misma imagen.

### AC-PLY-071 — Las notas del corcho y del baño se pueden leer *(verifica BR-PLY-030, BR-PLY-004)*

DADO cada una de las seis notas funcionales, ENTONCES tiene foco y contorno sobre su propia
hoja desde un lugar transitable al alcance. Hay una hoja de no tirar papel arriba de cada
inodoro. El corcho presenta dos hojas: tareas a realizar y mantener el local ordenado. No
aparecen papeles vacíos ni una hoja por tarea. Las imágenes originales del baño se conservan
al agregar lectura.

### AC-PLY-072 — La caja abre con cada mano y la conserva *(verifica BR-PLY-031, BR-PLY-026, BR-PLY-006, BR-PLY-028)*

DADO la caja cerrada y, por turno, manos vacías, unidad, caja, mopa, balde, jabón, bolsa y
ticket, CUANDO se hace clic izquierdo ENTONCES abre el programa y suspende el control sin
cambiar lo sostenido ni su padre o pose. CUANDO se hace clic derecho, o izquierdo por fuera del
panel, ENTONCES cierra y la mano sigue igual. El derecho y E con mano vacía no abren; abierto,
el izquierdo y E no agarran ni examinan.
DADO otra pantalla o examen abiertos ENTONCES no abre el programa encima.

### AC-PLY-073 — El lector lee sólo el derecho y conserva la mano *(verifica BR-PLY-032, BR-PLY-012)*

DADO una unidad sostenida y el programa cerrado, CUANDO se usa el lector ENTONCES se anota
su producto y sigue en la mano; al abrir el programa aparece. DADO cada objeto que no es
unidad ENTONCES se avisa su rechazo sin cambiar la mano. DADO manos vacías ENTONCES no se
pide lectura ni aviso. DADO clic izquierdo o E con mano vacía ENTONCES no se lee ni se abre.

### AC-PLY-074 — Reloj, pausa y cierre del programa *(verifica BR-PLY-031)*

DADO el programa abierto, CUANDO pasan cuadros ENTONCES el tiempo disminuye; al pausar,
la pausa visible tiene una capa superior al programa. Al reanudar sigue abierto y el control
suspendido. Al terminar el turno queda sólo la devolución y el control suspendido.

### AC-PLY-075 — El papel se lleva y examina *(verifica BR-PLY-033)*

DADO un ticket impreso enfocado, CUANDO se agarra ENTONCES pasa a la mano; al examinar dice
«Ticket», sin perder sus productos. CUANDO se termina el examen y se suelta ENTONCES la mano
queda vacía y el mismo papel vuelve al mundo. Su sonoridad es papel.

### AC-PLY-076 — Ranura real y segunda impresión *(verifica BR-PLY-033, BR-PLY-004)*

DADO la caja con productos cargados, CUANDO se imprime ENTONCES se cierra el programa y
el ticket sale animado de la ranura. Al terminar se puede enfocar y agarrar desde piso
transitable, sin atravesar sólidos. Caja, lector y papel tienen foco y contorno.
CUANDO se imprime otra vez ENTONCES el primero cae
y el segundo queda en la ranura. DADO el papel agarrado mientras sale CUANDO pasa el tiempo de
la salida ENTONCES sigue en el mismo lugar de la mano. DADO el primero en la mano ENTONCES otra
impresión conserva ese papel congelado en su lugar en la mano.

### AC-PLY-077 — La jornada limpia incluso el papel examinado *(verifica BR-PLY-033)*

DADO un ticket examinado en la mano y otro suelto, CUANDO abre la jornada siguiente ENTONCES
termina el examen, las manos quedan vacías y ambos papeles dejan de existir.

### AC-PLY-078 — El derecho desecha y el izquierdo suelta *(verifica BR-PLY-012, BR-PLY-004, BR-PLY-006, BR-PLY-010)*

DADO un ticket en la mano y cada inodoro dentro del alcance desde piso transitable sin
superposición de la cápsula CUANDO la mira lo enfoca y se pulsa derecho ENTONCES el ticket
desaparece y la mano queda vacía. DADO el mismo papel CUANDO se pulsa izquierdo ENTONCES se
suelta y sigue existiendo, sin aviso de descarte. Examinar conserva el ticket y, mientras el
control esté suspendido, derecho no lo desecha.

### AC-PLY-079 — Entrega, rechazo y bloqueo *(verifica BR-PLY-034, BR-PLY-028, BR-PLY-027)*

DADO un producto sostenido y el comprador hablando CUANDO se hace izquierdo ENTONCES avanza
una entrada y conserva cuerpo y mano; derecho no cierra y Esc abre pausa. DADO la inicial
terminada y ninguna conversación activa CUANDO se acepta el producto ENTONCES la mano queda
vacía y el puesto retiene ese cuerpo. Al rechazar, cuerpo y mano no cambian y empieza su diálogo.
DADO un diálogo activo CUANDO se pulsa fuera del comprador ENTONCES no se agarra ni suelta.
CUANDO vence ENTONCES se cierra el diálogo y se devuelve automáticamente la vista, sin derecho.

### AC-PLY-080 — La nota cambia con la particular *(verifica BR-PLY-030)*

DADO la jornada 1 CUANDO se lee su nota de tareas ENTONCES enumera, en orden, «Atención al
cliente», «Registro de productos vendidos», «Limpieza», «Reposición» y «Ordenar cajas en el
depósito». CUANDO se sigue a la jornada 2 sin recargar el local ENTONCES el quinto renglón dice
«Tirar la basura». DADO la jornada 3 ENTONCES sólo están los cuatro primeros. En los tres casos,
la hoja visible y su lectura tienen los mismos renglones.

### AC-PLY-081 — El celular conserva la mano y suspende el cuerpo *(verifica BR-PLY-006)*

DADO una unidad en la mano y un objetivo enfocado CUANDO se abre el celular ENTONCES se pierde
el foco y no se puede caminar, girar la vista, enfocar, agarrar ni soltar; el cursor queda libre.
CUANDO se lo cierra ENTONCES vuelven esos controles y la misma unidad sigue en la mano. Los clics
de lectura y de foto mientras está abierto no cambian lo sostenido.

### AC-PLY-082 — Los dos ejemplos de la ficha *(verifica BR-PLY-035, BR-PLY-036)*

DADO la asignación de fábrica —examinar en E, agarrar en el botón izquierdo y usar en el
derecho—, la mano vacía y la mira sobre un lavatorio ENTONCES la referencia es exactamente
«[E] Examinar». DADO el balde en la mano y la mira sobre el mismo lavatorio ENTONCES es
exactamente «[E] Examinar (mano)», «[Click Izq] Dejar» y «[Click Der] Interactuar», en ese
orden. En los dos casos, el contador de tareas está arriba de la primera línea.

### AC-PLY-083 — La caja del depósito: sacar, meter o nada *(verifica BR-PLY-035)*

DADO la mano vacía y una caja del depósito apoyada con 1 unidad ENTONCES la referencia es
«[E] Examinar», «[Click Izq] Agarrar» y «[Click Der] Sacar producto»; con 0, sólo las dos
primeras. DADO una unidad de su producto en la mano y la caja con una unidad menos que las de
una caja ENTONCES es «[E] Examinar (mano)», «[Click Izq] Dejar» y «[Click Der] Meter
producto»; con la caja llena, sólo las dos primeras. DADO una unidad de otro producto, u otra
caja, en la mano ENTONCES es «[E] Examinar (mano)» y «[Click Izq] Dejar». En ningún caso sale
«Interactuar» sobre una caja.

### AC-PLY-084 — El derecho no adelanta el resultado *(verifica BR-PLY-036, BR-PLY-035)*

DADO la mira sobre una mancha y la mopa mojada con un jabón que no es el suyo, o sobre el
lavatorio y el balde lleno, o sobre el lector y una unidad en la mano con los tres renglones del
programa llenos ENTONCES sale «[Click Der] Interactuar», y la herramienta, el objetivo y los
renglones no cambian. DADO la mano vacía y la mira sobre el lector, el inodoro, el lavatorio o
el balde ENTONCES no sale ninguna línea del derecho. DADO un ticket en la mano y la mira sobre un
inodoro ENTONCES sale. DADO la mano vacía y una puerta trabada ENTONCES la referencia es
«[E] Examinar» y «[Click Der] Interactuar»; sobre una puerta interior, no sale ninguna línea
del derecho. DADO el cuerpo o la tapa del contenedor de basura,
con la mano vacía o cargada ENTONCES sale. DADO el programa manual y la mira sobre el hueco del
lector, con una unidad en la mano ENTONCES no sale.

### AC-PLY-085 — Consultar el tacho no le saca la bolsa *(verifica BR-PLY-036)*

DADO la jornada 2, la mano vacía y la mira sobre un tacho con su bolsa ENTONCES la referencia es
«[E] Examinar» y «[Click Der] Interactuar», y el tacho sigue con su bolsa y la mano vacía.
DADO el mismo tacho sin bolsa, o una unidad en la mano ENTONCES no sale ninguna línea del
derecho.

### AC-PLY-086 — Lo que se tira al contenedor se lee «Dejar» *(verifica BR-PLY-035)*

DADO la tapa del contenedor completamente abierta, una bolsa en la mano y la mira sobre el
cuerpo o la tapa ENTONCES la línea del izquierdo es «[Click Izq] Dejar», y ninguna línea dice
tirar.

### AC-PLY-087 — Sin nada que hacer, nada *(verifica BR-PLY-035)*

DADO la mano vacía y la mira sin foco, o sobre un casillero vacío ENTONCES la referencia no
tiene ninguna línea. DADO la mopa mojada de agua y la mira sobre el piso sin mancha ENTONCES
es «[E] Examinar (mano)» y «[Click Izq] Dejar», sin línea del derecho. DADO la mano vacía y la
mira sobre una unidad de la fila de adelante de la góndola ENTONCES sale «[Click Izq] Agarrar»
y ninguna línea del derecho.

### AC-PLY-088 — El control sale de la asignación *(verifica BR-PLY-037)*

DADO examinar reasignado a la Q y un levantable en la mano ENTONCES la primera línea es
«[Q] Examinar (mano)». DADO un gesto con un control de joystick y uno de teclado ENTONCES la
línea muestra el de teclado. DADO un gesto sin ningún control con nombre ENTONCES su línea no
aparece y las demás conservan su orden.

### AC-PLY-089 — Suspendido, vacía *(verifica BR-PLY-038)*

DADO un levantable en la mano y la mira sobre un lavatorio CUANDO se abre, por turno, el examen,
una nota pegada, la computadora, la caja registradora, la ventanilla, el celular o la pausa
ENTONCES la referencia no tiene ninguna línea; CUANDO se cierra ENTONCES vuelve a tener las
líneas de esa mano y esa mira. CUANDO cierra la jornada ENTONCES queda vacía.

### AC-PLY-090 — El foco y la mano en el mismo cuadro *(verifica BR-PLY-035)*

DADO la mano vacía y la mira sobre un lavatorio CUANDO en el mismo cuadro se pone el balde en
la mano y la mira pasa a una caja del depósito ENTONCES la referencia siguiente es
«[E] Examinar (mano)» y «[Click Izq] Dejar», y no se mostró ninguna combinación de la mano
anterior con la mira nueva ni al revés.

### AC-PLY-091 — Primera pulsación y última pulsación *(verifica BR-PLY-034, BR-PLY-027)*

DADO un comprador sin atender y, por turno, mano vacía, producto, ticket, caja y mopa CUANDO se
pulsa izquierdo sobre su figura ENTONCES se ve su primera entrada y se encuadra en ese clic,
sin recepción ni cambio de mano. DADO un diálogo de una entrada, por turno inicial,
recordatorio, rechazo y despedida, CUANDO se avanza ENTONCES vuelve la vista y el movimiento
normales, conserva la mano resultante y no se ejecuta otra interacción por esa pulsación.

### AC-PLY-092 — Sólo la figura vigente responde *(verifica BR-PLY-039, BR-PLY-004)*

DADO un comprador dentro del alcance CUANDO la mira apunta a su figura visible ENTONCES el
objetivo es la persona. Sobre el hueco vacío, una zona transparente del dibujo, marco o
antepecho no hay objetivo de atención. Antes de llegar, después de vencer y durante su retirada
no hay foco, contorno ni entrega posible. Con el comprador fuera del alcance no hay foco.
El hueco no tiene vidrio que bloquee el paso y conserva los sólidos de sus bordes.

### AC-PLY-093 — Contorno animado y oculto por el mundo *(verifica BR-PLY-039)*

DADO la interfaz cerrada y un comprador enfocado CUANDO se comparan dos dibujos de su animación
ENTONCES el contorno sigue el alfa de cada figura, con el color común del foco, sin rectángulo
sobre transparencia. CUANDO pared o antepecho ocultan parte de la figura ENTONCES también
ocultan esa parte del contorno. Perder foco restaura la apariencia anterior; otro comprador
no hereda el contorno. Desde los laterales accesibles el antepecho oculta el corte inferior.

### AC-PLY-094 — El gesto sigue al estado de la atención *(verifica BR-PLY-034, BR-PLY-035)*

DADO la inicial pendiente y un ticket sostenido CUANDO se consulta la referencia ENTONCES dice
«Hablar». DADO la inicial terminada CUANDO se consulta con mano vacía ENTONCES dice «Hablar»;
con producto o ticket, «Entregar». La consulta no entrega ni inicia diálogos. DADO un diálogo
abierto CUANDO cierra el turno ENTONCES desaparecen foco y encuadre, la vista vuelve y el
control permanece suspendido por el cierre. Pausar y reanudar conserva entrada y mano.

## No objetivos

- Esta capacidad NO decide qué esconde un objeto: eso es de
  [`investigation`](../investigation/investigation.md).
- Esta capacidad NO cuenta unidades ni repone: eso es de
  [`store-stock`](../store-stock/store-stock.md).
- Esta capacidad NO lee el teclado ni el mouse. Recibe la entrada ya traducida a números, y el
  nombre del control de cada gesto ya traducido a texto.
- Esta capacidad NO asigna ni reasigna los controles: la referencia lee la asignación vigente.

## Contratos

- **Entrada:** el vector de movimiento, el delta del mouse, el yaw del arranque, los candidatos
  que el rayo encontró, el objeto que se quiere agarrar, la superficie que la mira toca, los
  casilleros vacíos y ocupados de cada producto, los segundos del cuadro y el nombre del control
  asignado a cada gesto; la vigencia del comprador, el estado de su conversación y su figura
  animada visible para foco, contorno e interacción directa.
- **Salida:** la velocidad, los dos ángulos de la vista, qué está enfocado y si cambió, qué se
  lleva en la mano, qué casillero lleva el contorno, el motivo de cada rechazo, el ángulo de
  la hoja, el aviso de cada gesto sobre una puerta, el efecto de un uso y las líneas de la
  referencia de controles.
- **Falla:** los dos rechazos de agarrar; soltar con las manos vacías no devuelve nada; un uso no
  declarado no tiene efecto; con algo que no es una unidad en la mano, ningún casillero vacío se
  enfoca; un gesto sin control con nombre no da línea en la referencia.

## Señales

- El objetivo enfocado y perdido, el objeto agarrado y soltado, el agarre rechazado, y la
  referencia de controles cuando cambia.

## Dependencias

- [`counter-service`](../counter-service/counter-service.md) (consume y alimenta): el lector
  recibe lo sostenido y contesta lectura o rechazo; imprimir entrega un papel levantable y
  usarlo sobre el inodoro publica su descarte; si el programa es manual, el lector no está.
  La vigencia de la persona y el estado de atención deciden hablar o entregar; terminar el
  diálogo devuelve automáticamente la vista y el movimiento.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (consume): las obligatorias declaradas que
  enumera la nota de tareas.

- [`store-cleanup`](../store-cleanup/store-cleanup.md) (alimenta y consume): qué se lleva en la
  mano decide si se puede limpiar; si un tacho conserva su bolsa decide si el derecho tiene
  efecto.
- [`investigation`](../investigation/investigation.md) (alimenta y consume): qué objeto se
  examina; la apertura del celular suspende el cuerpo conservando lo que se lleva en la mano.
- [`store-stock`](../store-stock/store-stock.md) (consume y alimenta): qué casilleros de cada
  producto están vacíos y cuáles ocupados; el clic sobre un casillero le pide colocar la unidad
  de la mano o agarrar la que está puesta; cuántas unidades tiene una caja del depósito decide
  si se puede sacar o meter.

## Preguntas abiertas

- **OQ-PLY-001 — ¿La segunda mano entra alguna vez?**
  - Por qué sigue abierta: subir las manos a 2 acorta los viajes de sacar la basura, y eso es
    una decisión de balance que nadie tomó.
  - Decide: el dueño del repo, jugando.
  - Bloquea: nada. Movería `BR-PLY-007` y el tercer criterio de
    [`store-cleanup`](../store-cleanup/store-cleanup.md).

- **OQ-PLY-003 — ¿Cuánto margen deja asomarse alrededor del marco?**
  - Por qué sigue abierta: la ficha dice «casi completamente» y no fija un margen.
  - Decide: game design.
  - Bloquea: nada; mientras se decide, los bordes visibles llegan a ambos límites de pantalla
    en el eje que limita (BR-PLY-027).
