---
schema_version: 1
capability_id: CAP-PLY
status: ratified
owner: por definir
provenance: GDD «Controles»; fichas «8. Tarea: Reposición», «Notas», «Interfaces virtuales durante la jornada» y «Referencia de controles»; decisiones de #368, #369, #370, #373 y #382; migración de los specs 003, 004, 006, 014, 034, 043; fichas de interacción, limpieza y basura revisadas el 2026-10-15; decisiones de #425, bordes de GJ-52 (#428) e interacción directa con compradores (#429); ocho jornadas de #526; cuartito de limpieza de #541; depósito trabado en la jornada 1 y baño abierto en todas de #574; salida voluntaria de #573; ticket escrito de #580; agacharse de #177
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
| **Primario** | gesto de agarrar y acción contextual, clic izquierdo por defecto | botón fijo |
| **Secundario** | gesto de usar conservado para sacar de cajas y usos no trasladados, clic derecho por defecto | botón fijo |
| **Referencia de controles** | la columna de líneas de arriba a la izquierda que dice qué control sirve ahora para lo que se mira y lo que se lleva | ayuda, tutorial, leyenda |

## Comportamiento normativo

Las reglas de interacción directa sobre la figura, foco de silueta y retorno automático del diálogo
se aplican al recorrido de atención física con comprador representado en el mundo.
Las jornadas 6 a 8 DEBEN conservar su recorrido genérico anterior sin figura, incluido el acceso al
panel de cobro. Sólo en ese recorrido genérico se admite una consulta de acceso en el hueco:
NO DEBE bloquear al jugador ni los objetos sostenidos, ni permanecer activa al usar atención física.
La barrera de vidrio NO DEBE existir en ningún recorrido. Esta excepción NO DEBE convertir el hueco,
marco o antepecho en objetivos de atención física ni inventar figuras para jornadas 6 a 8.

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
La salida por la entrada principal usa la secuencia de BR-PLY-041.

### BR-PLY-012 — Una herramienta sirve para algo o para nada

CUANDO se acciona el primario —agarrar, clic izquierdo por defecto— con lo que se lleva
sobre un objetivo que declara una interacción para ese par, el sistema DEBE pedir ese uso
antes de considerar soltar. DEBE contestar el efecto declarado y ningún efecto de herramienta
para los demás pares o con las manos vacías. Un rechazo por estado DEBE consumir el gesto y
conservar la mano, sin caer a soltado genérico ni ejecutar además el secundario.
El ticket sobre el inodoro DEBE desecharse según `counter-service`; las herramientas DEBEN
conservar los resultados, carga, agua, animaciones y rechazos de `store-cleanup`.

SI la mira enfoca una puerta, ENTONCES el primario DEBE resolver la puerta según BR-PLY-026,
sin usar la herramienta ni pedir reposición. El secundario —usar, clic derecho por defecto—
NO DEBE ejecutar los pares anteriores. El uso de la mopa sobre piso despejado conserva su
gesto secundario y sus resultados de BR-CLN-024: no pertenece a los pares que cambian al primario.
Sin interacción contextual declarada, el primario DEBE conservar agarrar y dejar.

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

Los tres bidones de jabón se llevan como el balde: verticales, a un costado y acompañando la
mira, para no perderlos de vista al volcarlos. Se apoyan como las cajas: al soltarlos quedan
derechos donde la mira toca, o al lado del jugador si ahí no entran.

Algunas cosas se apoyan derechas: hoy, sólo el balde. CUANDO se suelta una de ellas, el sistema
DEBE dejarla con su eje vertical, mire adonde mire la vista. SI justo en el punto que la mira
toca no entra, ENTONCES el sistema DEBE probar alrededor de ese punto, sobre el mismo apoyo y
hasta un ancho de lo soltado. SI ahí tampoco entra, o la superficie no la admite, ENTONCES DEBE
dejarla derecha en el piso al lado del jugador. Soltar suelta: el sistema NO DEBE devolverla a la
mano.

### BR-PLY-019 — Cada noche arranca con las puertas cerradas

CUANDO se abre una jornada, el sistema DEBE dejar las puertas interiores cerradas, con la hoja en
su lugar y sin girar hasta él, aunque la noche anterior hayan quedado abiertas o a medio giro.

### BR-PLY-020 — Las trabadas no abren, y cada gesto sobre una puerta avisa

SI una puerta está trabada, ENTONCES el primario NO DEBE abrirla ni girar la hoja, y
DEBE contestar que está trabada, todas las veces. El secundario NO DEBE emitir ese aviso. El portón del depósito y
la oficina del jefe están trabadas en todas las jornadas. La entrada permanece trabada salvo
la salida habilitada de BR-PLY-041. La puerta que lleva del local al depósito
DEBE estar trabada en la primera jornada, y abrir desde la segunda. La puerta del cuartito de
limpieza DEBE estar trabada en las jornadas que no piden limpiar, y abrir en las que sí. La puerta
del baño y la de «Solo empleados» no están trabadas en ninguna. La traba de la jornada DEBE decidirse
al abrirla, desde el número de la jornada y las obligatorias que declara, antes de cerrar las
puertas de BR-PLY-019. La primera jornada DEBE poder cumplirse entera sin entrar al depósito.

CUANDO se acciona una puerta que abre, el sistema DEBE avisar una vez si se abrió o se cerró.
CUANDO se acciona una trabada con el primario, DEBE avisar una vez que está trabada. El aviso de trabada del portón es distinto del de las demás. Cerrar las
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

### BR-PLY-026 — El primario acciona lo fijo y conserva la mano

CUANDO se hace el primario sobre una puerta interior, de heladera o trabada, la computadora,
la caja registradora o una nota pegada, el sistema DEBE resolver esa interacción
con las manos vacías o con cualquier cosa en la mano. Las puertas habilitadas DEBEN alternar, salvo la salida de BR-PLY-041;
las trabadas DEBEN avisar una vez por pulsación sin girar; los paneles DEBEN abrirse y las notas
DEBEN mostrar su lectura. Lo que se lleva DEBE seguir en la mano sin soltarse ni usarse.
La atención DEBE iniciarse sobre la persona según BR-PLY-034, sin abrir el hueco.

CUANDO se hace el secundario sobre esos objetivos cerrados, el sistema NO DEBE abrirlos,
alternarlos ni emitir el aviso de trabada. Una puerta NO DEBE pedir uso de herramienta ni
reposición con ninguno de los dos gestos. SI el control está suspendido, ENTONCES ningún
gesto DEBE abrir ni alternar lo fijo. El clic que cierra una interfaz DEBE consumirse antes
de devolver el control: NO DEBE actuar también sobre el mundo.

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
la vista antes de mostrar la devolución y conservar el control suspendido por ese cierre.

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
suspender el control. Sólo un clic derecho DEBE cerrar y reanudar; un clic izquierdo NO DEBE
cerrarla. Lo que se lleva DEBE conservar su lugar en la mano, sin usarse ni soltarse. Una pantalla abierta o un examen NO DEBE permitir
abrir otra hoja. Leer NO DEBE detener el turno.

CUANDO termina el turno, la lectura DEBE cerrarse antes de la devolución. La pausa DEBE verse
encima de la nota; al reanudar, la nota DEBE continuar abierta y el control suspendido.

### BR-PLY-030 — Lo que dice cada hoja

El sistema DEBE permitir leer las notas de tareas a realizar, mantener el local ordenado,
jabones y manchas, instrucciones de limpieza y no tirar papel. La hoja y la lectura DEBEN
compartir su contenido: texto para las dos del corcho, imagen original completa para las dos de
limpieza y las dos de no tirar papel. Las de jabones y manchas y de instrucciones de limpieza
están pegadas en una pared del cuartito. Hay una hoja de no tirar papel arriba de cada uno de
los dos inodoros del baño, y las dos comparten la misma imagen. Las dos hojas del corcho DEBEN tener formato y tamaño equivalente a
A4, con el contenido visible en el mundo; NO DEBEN presentarse como post its ni como una hoja
por tarea.
Las hojas del cuartito y del baño DEBEN conservar sus imágenes artísticas.

La nota de tareas DEBE enumerar sólo las obligatorias que declara la jornada, en el orden
atención al cliente, registro de productos vendidos, limpieza, reposición y, al final, la
particular de esa jornada. Ordenar las cajas DEBE llamarse «Ordenar cajas en el depósito» y
la basura, «Tirar la basura». CUANDO se abre otra jornada, la nota DEBE actualizarse con la
lista nueva, sin exigir salir y volver a entrar al local.
Cada tipo declarado DEBE tener nombre. Una lista vacía DEBE conservar el título sin agregar
renglones. La nota de ordenado DEBE presentar las tres viñetas de su criterio, sin reescribirlas.

### BR-PLY-031 — El programa abre sin soltar la mano

CUANDO se hace clic izquierdo sobre la caja registradora, el sistema DEBE abrir su programa y
suspender el control, conservando lo que se lleva y su lugar en la mano. Sólo un clic derecho
DEBE cerrar y reanudar; un clic izquierdo, adentro o afuera del panel, NO DEBE cerrarlo. Una pantalla o examen
abiertos NO DEBEN permitir abrir el programa.
Leerlo NO DEBE detener el turno. La pausa DEBE dibujarse por encima y, al reanudar, DEBE
continuar abierto y suspendido. El cierre del turno DEBE cerrarlo antes de mostrar la devolución.

### BR-PLY-032 — El lector usa la unidad sostenida con el primario

CUANDO se hace el primario sobre el lector con algo en la mano, el sistema DEBE pedir su
lectura sin agarrarlo, soltarlo ni usarlo como herramienta. Un rechazo, incluido lector lleno,
DEBE conservar la mano sin soltar. Con la mano vacía NO DEBE pedir lectura ni avisar rechazo.
El secundario NO DEBE pedir lectura. Los rechazos y sus motivos los decide `counter-service`;
si el programa es manual, el lector ausente NO DEBE recibir la solicitud.

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

Cada ticket impreso DEBE mostrar escrito, sobre el papel del diseño, un número de ticket de
cuatro cifras, el número de la jornada, la hora de la noche en que se imprimió, un renglón por
producto distinto y el total. Los renglones DEBEN ir en el orden en que el programa anotó los
productos, y cada uno DEBE decir la cantidad, el nombre y el precio de lista, con el precio
sumado de todas sus unidades. El precio DEBE llevar punto de miles y estar alineado a la derecha
del renglón, y el renglón DEBE caber en el ancho del papel, también el nombre más largo del
catálogo con tres unidades. El total DEBE ser la suma de los precios de lista de todos los
productos del ticket. El número de ticket NO DEBE repetirse en la partida, y imprimir otro
papel NO DEBE cambiar lo escrito en los que ya existen. La impresión en modo manual DEBE verse
igual que la del lector.

MIENTRAS se lo lleva en la mano, el papel DEBE verse un 40 % más grande que en el mundo, con
su colisión escalada igual. Al soltarlo o apoyarlo DEBE volver a su tamaño del mundo. MIENTRAS se
lo examina, DEBE verse más grande que en la mano, de modo que los renglones y el total se lean
con claridad en 1920 × 1080. El subtítulo del examen NO cambia (BR-SUB-011).

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

### BR-PLY-035 — La referencia nombra el gesto contextual

MIENTRAS transcurre la jornada, el sistema DEBE mostrar arriba a la izquierda, una por renglón,
las líneas que corresponden a lo enfocado y a lo llevado. Cada línea DEBE leerse
«[<control>] <texto>», con la asignación vigente del gesto (BR-PLY-037). De arriba abajo:
primero el examen, después la acción primaria y por último el secundario disponible.

| Texto | Gesto | Vale cuando |
|---|---|---|
| Examinar (mano) | examinar | hay un levantable en la mano |
| Examinar | examinar | mano vacía y un interactuable enfocado |
| Agarrar | primario | mano vacía y un levantable enfocado |
| Dejar | primario | mano ocupada sin interacción primaria declarada sobre el objetivo |
| Abrir | primario | puerta cerrada o trabada salvo la entrada principal de BR-PLY-041, computadora o caja registradora |
| Cerrar | primario | puerta abierta |
| Mirar | primario | nota pegada |
| Hablar | primario | comprador con inicial pendiente, aun con objeto en mano, o inicial terminada con mano vacía, cuando atención habilita el gesto |
| Entregar | primario | comprador con inicial terminada y objeto en mano, cuando atención habilita el gesto |
| Llenar | primario | balde sobre lavatorio |
| Vaciar | primario | balde sobre inodoro |
| Vertir | primario | jabón o producto de limpieza habilitado sobre balde |
| Mojar | primario | mopa sobre balde o inodoro |
| Limpiar | primario | mopa sobre mancha |
| Meter producto | primario | caja apoyada, unidad coincidente y capacidad de recibirla |
| Sacar producto | secundario | caja apoyada, mano vacía y al menos una unidad |

«Vertir» DEBE conservar esa escritura literal. Una interacción primaria DEBE reemplazar
«Dejar», nunca coexistir con ella para el mismo clic, incluso cuando el intento se rechace.
Sacar y meter DEBEN respetar existencia y capacidad; una devolución coincidente rechazada
NO DEBE presentarse como «Dejar». Las acciones fuera de esta lista DEBEN conservar su texto
vigente, asociado al gesto que realmente ejecutan: lector, descarte de ticket, tacho y cuerpo
del contenedor conservan «Interactuar» sobre el primario; la tapa usa «Abrir» o «Cerrar».
Preparar las líneas Hablar y Entregar NO DEBE habilitar por sí mismo atención directa.

El contador de tareas DEBE conservar su lugar sobre la primera línea. CUANDO cambian foco
y mano en el mismo cuadro, la referencia DEBE usar ambos valores nuevos, sin combinación intermedia.

### BR-PLY-036 — El contexto no adelanta el resultado

El sistema DEBE decidir sin mutaciones qué interacción declara cada gesto para el par
mano/objetivo. El despacho y la referencia DEBEN usar la misma decisión. Los pares de
limpieza DEBEN conservar Llenar, Vaciar, Vertir, Mojar y Limpiar aunque el balde esté lleno
o vacío, la mopa seca o el jabón sea incorrecto: mirar una mancha NO DEBE revelar su jabón.

El lector presente con una unidad, el inodoro con un ticket y el cuerpo del contenedor con
un objeto DEBEN declarar interacción primaria, aunque el resultado pueda rechazarse.
Un tacho sólo DEBE ofrecer extracción con bolsa y mano vacía; una puerta trabada DEBE
ofrecer Abrir, salvo la entrada principal de BR-PLY-041. La tapa DEBE ofrecer sólo su
alternancia, sin tirar además lo sostenido.
El secundario sobre todos esos objetivos NO DEBE ofrecer los usos trasladados al primario;
Sacar producto conserva el secundario, y las acciones ajenas conservan su contrato.

Con la mano vacía, lector, inodoro, lavatorio y balde NO DEBEN declarar uso de herramienta.
Un tacho vacío u ocupado por la mano NO DEBE ofrecer extracción. El hueco del lector manual
NO DEBE ofrecer lectura. Consultar NO DEBE cambiar mano, herramienta, objetivo ni bolsas.

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

### BR-PLY-040 — Apoyo visible en los bordes del baño y de la góndola

CUANDO se suelta una caja sobre el borde superior gris de una división del baño, el sistema
DEBE apoyar su base sobre ese borde visible, sin hundirla hasta la pared blanca ni atravesarlo.
CUANDO se suelta una caja hacia el borde de góndola documentado en
[GJ-52](https://app.notion.com/p/3fa86efecd9d80ebbfdbc900faa03a20), el sistema DEBE acomodarla
sobre metal visible, conservando la selección del apoyo según la mira, la mano vacía y el
reposo estable de BR-PLY-013. La caja DEBE quedar recogible y fuera de sólidos.
En ambos encuadres, el soporte físico DEBE corresponder al borde visible; NO DEBE aparecer
una plataforma invisible bajo la caja. El sistema NO DEBE forzar la caída de una caja que
quedó apoyada de forma estable sobre ese metal.
Los apoyos válidos de piso, mostrador, pallet del depósito y otra caja DEBEN conservarse,
incluida la caída en cascada al retirar el apoyo inferior. La regla general para decidir
otros apoyos parciales depende de OQ-PLY-004.

### BR-PLY-041 — La entrada cierra la noche cuando se puede salir

MIENTRAS está habilitada la salida de BR-SHF-021, el primario sobre cualquiera de las dos hojas de entrada
DEBE iniciar la salida de BR-SHF-025 y terminar la jornada por el cierre habitual. El gesto
NO DEBE alternar libremente las hojas ni cerrar antes de completar esa secuencia. La referencia DEBE
ofrecer Interactuar con el control vigente del primario sólo en ese estado. Antes de habilitarse,
al volver a trabarse por una tarea pendiente, o desde la primera jornada completa, NO DEBE
ofrecer esa acción y el primario DEBE conservar el sonido de puerta trabada sin girar ninguna hoja.
La entrada NO DEBE permitir soltar o usar lo
sostenido por ninguno de estos intentos. El secundario NO DEBE cerrar la noche ni sonar trabada.
Con control suspendido, pausa o jornada cerrada, ningún gesto DEBE volver a cerrar la noche.
Las demás puertas DEBEN conservar su referencia y comportamiento.

### BR-PLY-042 — Agacharse baja la vista mientras se mantiene apretado Espacio

MIENTRAS se mantiene apretada la acción de agacharse —Espacio por defecto—, el sistema DEBE
bajar la vista a la altura agachado, aproximadamente la del segundo estante desde abajo de las
góndolas. CUANDO se la suelta, DEBE devolver la vista a la altura de pie. No es un interruptor:
apretar y soltar NO DEBE dejar al jugador agachado. Las dos alturas salen del dominio, y la
agachado es mayor que cero y menor que la de pie.

Agachado, el jugador DEBE caminar a la velocidad de BR-PLY-002: la postura no cambia la
caminata, y agacharse NO DEBE quitarle su tecla a la caminata. La mira enfoca desde la altura
vigente de la vista (BR-PLY-004), y el cuerpo conserva su forma de colisión.

MIENTRAS el control está suspendido (BR-PLY-006), la postura NO DEBE cambiar, apriete o suelte
lo que apriete el jugador. CUANDO se reanuda, la postura DEBE seguir a la acción tal como esté
en ese momento.

Espacio es una tecla del juego: NO DEBE aceptar ni activar el botón que tenga el foco. Enter y
el Enter del teclado numérico lo siguen haciendo, así que Espacio sostenido al terminar la
jornada NO DEBE saltear la placa del cierre.

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

DADO el almacén armado en cualquier jornada ENTONCES la entrada, el portón del depósito y la
oficina del jefe están trabadas y contestan al primario. DADO la jornada 1 abierta ENTONCES la
puerta que lleva al depósito está trabada, contesta al primario y la hoja no gira. DADO la
jornada 2 abierta ENTONCES esa puerta abre y alterna. DADO el cierre de la 1 CUANDO se sigue a la 2
ENTONCES se destraba; DADO una partida guardada en la 1 con la puerta abierta la noche anterior
CUANDO se retoma ENTONCES abre cerrada y trabada, sin girar ni avisar. DADO la jornada 1 o la 2
abierta ENTONCES la puerta del cuartito está trabada, contesta al primario y la hoja no gira. DADO
la jornada 3 abierta ENTONCES no está trabada y alterna. DADO el cierre de la 2 CUANDO se sigue a la
3 ENTONCES se destraba; DADO una partida guardada en la 2 con la puerta abierta la noche anterior
CUANDO se retoma ENTONCES abre cerrada y trabada, sin girar ni avisar. La puerta del baño y la de
«Solo empleados» no están trabadas en ninguna jornada: abren y alternan también en la 1 y la 2.

### AC-PLY-102 — La primera jornada se cumple sin entrar al depósito *(verifica BR-PLY-020)*

DADO la jornada 1 abierta, con la puerta del depósito trabada, CUANDO se cumplen todas sus
obligatorias sin accionar esa puerta ENTONCES todas quedan cumplidas y la puerta sigue trabada.

### AC-PLY-041 — Un aviso por gesto *(verifica BR-PLY-020)*

DADO una puerta interior cerrada CUANDO se la acciona dos veces seguidas, con la hoja todavía
girando, ENTONCES avisa una vez que se abrió y después una vez que se cerró. DADO una puerta
trabada CUANDO se acciona diez veces con el primario ENTONCES avisa diez veces que está trabada, el portón con su
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

### AC-PLY-057 — Lo fijo gana y sólo el primario avisa trabada *(verifica BR-PLY-026, BR-PLY-012, BR-PLY-020)*

DADO entrada, portón y oficina trabados, y la mopa sostenida CUANDO se pulsa diez veces el
primario sobre cada uno ENTONCES cada puerta emite diez avisos de trabada, el portón con su
aviso propio, sin giro, limpieza, reposición ni soltado. CUANDO se pulsa el secundario
ENTONCES hay cero avisos adicionales y la mano conserva la mopa. DADO una puerta interior
CUANDO se hace el secundario ENTONCES no gira ni usa la mopa.

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

### AC-PLY-063 — Cada hoja abre su lectura y cierra con el derecho *(verifica BR-PLY-029, BR-PLY-006)*

DADO cada una de las seis notas pegadas enfocadas, CUANDO se hace clic izquierdo ENTONCES
aparece su contenido propio y se suspenden caminata, mirada y foco. Un clic izquierdo no la
cierra. CUANDO se hace clic derecho ENTONCES la lectura se cierra y el control vuelve.

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
abierta y el control suspendido. CUANDO termina el turno ENTONCES la nota se cierra y el
control queda suspendido. En las jornadas 1 a 3 baja la persiana y, al terminar de bajar, siguen
las instrucciones de la jornada siguiente, sin celular ni devolución. Desde la jornada 4 queda
sólo la devolución.

### AC-PLY-068 — Ordenado comparte el texto exacto *(verifica BR-PLY-030)*

DADO la nota de ordenado, ENTONCES su hoja y su lectura comparten «MANTENER EL LOCAL ORDENADO»
y las viñetas «No dejar productos tirados.», «Dejar las cajas en el depósito.» y
«Dejar los elementos de limpieza en el cuartito.», exactamente.

### AC-PLY-069 — Las obligatorias dan los renglones de tareas *(verifica BR-PLY-030)*

DADO las obligatorias declaradas, ENTONCES «TAREAS A REALIZAR» las enumera en el orden de la
regla. DADO limpieza y tirar la basura, ENTONCES da «1. Limpieza» y «2. Tirar la basura».
DADO cero, ENTONCES conserva el título y cero renglones. Cada tipo declarado tiene nombre,
y los títulos y renglones son iguales en la hoja y su lectura.

### AC-PLY-070 — El cuartito y el baño comparten la imagen artística completa *(verifica BR-PLY-030)*

DADO cada hoja de imagen —jabones y manchas e instrucciones de limpieza, en el cuartito, y las
dos de no tirar papel, en el baño—, ENTONCES su lectura amplía la misma imagen frontal
original completa y no agrega renglones. Las dos de no tirar papel abren la misma imagen.

### AC-PLY-071 — Las notas del corcho, del cuartito y del baño se pueden leer *(verifica BR-PLY-030, BR-PLY-004)*

DADO cada una de las seis notas funcionales, ENTONCES tiene foco y contorno sobre su propia
hoja desde un lugar transitable al alcance. Las dos de limpieza están en una pared del
cuartito y se leen desde adentro. Hay una hoja de no tirar papel arriba de cada inodoro. El corcho presenta dos hojas: tareas a realizar y mantener el local ordenado. No
aparecen papeles vacíos ni una hoja por tarea. Las imágenes originales del cuartito y del baño se conservan
al agregar lectura.

### AC-PLY-072 — La caja abre con cada mano y la conserva *(verifica BR-PLY-031, BR-PLY-026, BR-PLY-006, BR-PLY-028)*

DADO la caja cerrada y, por turno, manos vacías, unidad, caja, mopa, balde, jabón, bolsa y
ticket, CUANDO se hace clic izquierdo ENTONCES abre el programa y suspende el control sin
cambiar lo sostenido ni su padre o pose. Un clic izquierdo, adentro o afuera del panel, no
cierra. CUANDO se hace clic derecho ENTONCES cierra y la mano sigue igual. El derecho y E con mano vacía no abren; abierto,
el izquierdo y E no agarran ni examinan.
DADO otra pantalla o examen abiertos ENTONCES no abre el programa encima.

### AC-PLY-073 — El lector lee sólo el primario y conserva la mano *(verifica BR-PLY-032, BR-PLY-012)*

DADO una unidad sostenida y el programa cerrado CUANDO se hace el primario sobre el lector
ENTONCES se anota su producto y sigue sostenida; abrir el programa muestra la lectura.
DADO el lector lleno CUANDO se repite ENTONCES se rechaza sin soltar ni agregar renglones.
DADO un objeto que no es unidad ENTONCES conserva el rechazo y la mano; con mano vacía,
no pide lectura ni rechazo. El secundario no lee con ninguna mano; E con mano vacía no lee
ni abre el programa. En modo manual, el hueco del lector no recibe lecturas.

### AC-PLY-074 — Reloj, pausa y cierre del programa *(verifica BR-PLY-031)*

DADO el programa abierto, CUANDO pasan cuadros ENTONCES el tiempo disminuye; al pausar,
la pausa visible tiene una capa superior al programa. Al reanudar sigue abierto y el control
suspendido. Al terminar el turno el programa se cierra y el control queda suspendido. En las
jornadas 1 a 3 baja la persiana y, al terminar de bajar, siguen las instrucciones de la jornada
siguiente, sin celular ni devolución. Desde la jornada 4 queda sólo la devolución.

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

### AC-PLY-105 — Los renglones salen de lo que se anotó *(verifica BR-PLY-033)*

DADO un ticket con un Marolini, una Pura-Cola y otro Marolini, en ese orden, CUANDO se lee lo
escrito ENTONCES hay exactamente dos renglones: el de Marolini con cantidad 2 y el precio de
lista sumado de sus dos unidades, y el de Pura-Cola con cantidad 1 y su precio de lista. El
Marolini va primero. El total es la suma de los tres precios de lista. DADO un ticket con un
solo producto ENTONCES hay un renglón y el total es su precio. DADO un ticket con tres
productos distintos ENTONCES hay tres renglones. Todos los precios llevan punto de miles y
terminan con «$».

### AC-PLY-106 — Todo renglón cabe en el papel *(verifica BR-PLY-033)*

DADO un ticket de tres Feel Ricky Fort, el nombre más largo del catálogo, CUANDO se lee lo
escrito ENTONCES su renglón dice cantidad 3 y el precio de las tres unidades, y entra en el
ancho del papel con el precio alineado a la derecha igual que el de un renglón corto.
DADO un ticket impreso con el programa en modo manual ENTONCES lo escrito se ve igual que el de
uno impreso con el lector, con los mismos productos.

### AC-PLY-107 — Número, jornada y hora de cada ticket *(verifica BR-PLY-033)*

DADO una partida en la que se imprimen varios tickets CUANDO se lee el número de cada uno
ENTONCES tiene cuatro cifras y ningún par repite número. DADO un ticket impreso en la jornada
4 con 60 segundos de la noche transcurridos ENTONCES dice la jornada 4 y la hora que el marcador
da en ese instante, y no cambia cuando la noche avanza.

### AC-PLY-108 — Dos papeles distintos se ven distintos *(verifica BR-PLY-033, BR-PLY-004)*

DADO un ticket con un Marolini y, impreso después, otro con una Pura-Cola CUANDO se ven a la
vez ENTONCES cada papel muestra sus propios productos, y el primero conserva lo suyo después de
la segunda impresión. Los dos están en el mundo, sin perder su tamaño ni su colisión.

### AC-PLY-109 — Más grande en la mano y todavía más al examinar *(verifica BR-PLY-033)*

DADO un ticket en el mundo CUANDO se agarra ENTONCES su papel y su colisión miden 1,4 veces lo
que medían, y CUANDO se lo suelta o se lo apoya ENTONCES vuelven a su tamaño del mundo. DADO el
ticket en la mano CUANDO se lo examina ENTONCES mide más que en la mano, y en 1920 × 1080 el
alto de cada renglón alcanza para leerlo. CUANDO se examina un ticket ENTONCES el subtítulo es
el mismo de antes del cambio.

### AC-PLY-078 — El primario desecha sólo el ticket propio *(verifica BR-PLY-012, BR-PLY-004, BR-PLY-006, BR-PLY-010)*

DADO un ticket propio sostenido y cada inodoro enfocable desde piso transitable al alcance
CUANDO se pulsa primario ENTONCES desaparece el ticket y la mano queda vacía, con un solo
descarte y sin soltado adicional. DADO el mismo papel CUANDO se hace secundario ENTONCES
sigue sostenido y hay cero descartes. Un ticket ajeno o ya descartado no se descarta otra
vez. Un objeto distinto de ticket no se desecha como papel; conserva su uso declarado.
DADO el control suspendido CUANDO se pulsan ambos gestos ENTONCES no hay descarte.

### AC-PLY-079 — Entrega, rechazo y bloqueo *(verifica BR-PLY-034, BR-PLY-028, BR-PLY-027)*

DADO un producto sostenido y el comprador hablando CUANDO se hace izquierdo ENTONCES avanza
una entrada y conserva cuerpo y mano; derecho no cierra y Esc abre pausa. DADO la inicial
terminada y ninguna conversación activa CUANDO se acepta el producto ENTONCES la mano queda
vacía y el puesto retiene ese cuerpo. Al rechazar, cuerpo y mano no cambian y empieza su diálogo.
DADO un diálogo activo CUANDO se pulsa fuera del comprador ENTONCES no se agarra ni suelta.
CUANDO vence ENTONCES se cierra el diálogo y se devuelve automáticamente la vista, sin derecho.

### AC-PLY-080 — La nota cambia con la particular *(verifica BR-PLY-030)*

DADO la jornada 4 CUANDO se lee su nota de tareas ENTONCES enumera, en orden, «Atención al
cliente», «Registro de productos vendidos», «Limpieza», «Reposición» y «Ordenar cajas en el
depósito». CUANDO se sigue a la jornada 5 sin recargar el local ENTONCES el quinto renglón dice
«Tirar la basura». DADO la jornada 6 ENTONCES sólo están los cuatro primeros. En los tres casos,
la hoja visible y su lectura tienen los mismos renglones.

### AC-PLY-081 — El celular conserva la mano y suspende el cuerpo *(verifica BR-PLY-006)*

DADO una unidad en la mano y un objetivo enfocado CUANDO se abre el celular ENTONCES se pierde
el foco y no se puede caminar, girar la vista, enfocar, agarrar ni soltar; el cursor queda libre.
CUANDO se lo cierra ENTONCES vuelven esos controles y la misma unidad sigue en la mano. Los clics
de lectura y de foto mientras está abierto no cambian lo sostenido.

### AC-PLY-082 — Lavatorio y caja muestran el gesto exacto *(verifica BR-PLY-035, BR-PLY-036)*

DADO los controles de fábrica, mano vacía y lavatorio enfocado CUANDO se consulta la referencia
ENTONCES muestra sólo «[E] Examinar». DADO el balde sostenido ENTONCES muestra exactamente
«[E] Examinar (mano)» y «[Click Izq] Llenar». DADO una caja apoyada con una unidad y mano vacía
ENTONCES muestra «[E] Examinar», «[Click Izq] Agarrar» y «[Click Der] Sacar producto».
El contador de tareas permanece encima de la primera línea.

### AC-PLY-083 — Sacar y meter usan gestos distintos *(verifica BR-PLY-035, BR-PLY-036)*

DADO una caja apoyada con una unidad y mano vacía CUANDO se consulta ENTONCES ofrece
Examinar, Agarrar por primario y Sacar producto por secundario; con cero, sólo las dos primeras.
DADO una unidad coincidente sostenida y capacidad para recibirla ENTONCES ofrece exactamente
«[E] Examinar (mano)» y «[Click Izq] Meter producto». Con la caja llena, no ofrece Meter producto
ni Dejar: el intento coincidente conserva la mano. Con otra caja o unidad de producto ajeno,
ofrece Examinar (mano) y Dejar. Ninguna consulta cambia unidades ni mano.

### AC-PLY-084 — El verbo no predice el éxito *(verifica BR-PLY-036, BR-PLY-035)*

DADO, por turno, mopa seca o de jabón incorrecto sobre mancha, balde lleno sobre lavatorio,
balde vacío sobre inodoro, jabón sobre balde vacío o teñido y mopa sobre balde vacío CUANDO
se consulta ENTONCES ofrece por primario Limpiar, Llenar, Vaciar, Vertir y Mojar respectivamente,
sin Dejar ni mutación. DADO mopa sobre inodoro ENTONCES ofrece Mojar. DADO lector lleno y
unidad sostenida ENTONCES conserva Interactuar por primario, no por secundario. DADO una
puerta cerrada o trabada ENTONCES ofrece Abrir, salvo la entrada principal de BR-PLY-041;
abierta, Cerrar; nota, Mirar. Mano vacía ante
lector, inodoro, lavatorio o balde no ofrece esos usos; el lector ausente tampoco.

### AC-PLY-085 — Consultar el tacho no le saca la bolsa *(verifica BR-PLY-036, BR-PLY-035)*

DADO jornada 5, mano vacía y tacho con bolsa CUANDO se consulta ENTONCES ofrece
«[E] Examinar» y «[Click Izq] Interactuar», sin línea secundaria ni cambio de bolsa o mano.
DADO tacho sin bolsa u objeto sostenido ENTONCES no ofrece extracción.

### AC-PLY-086 — Cuerpo y tapa ofrecen una sola acción primaria *(verifica BR-PLY-035, BR-PLY-036)*

DADO una bolsa sostenida y el cuerpo del contenedor enfocado CUANDO se consulta ENTONCES
ofrece Interactuar por primario, sin Dejar ni acción secundaria. DADO la tapa abierta
ENTONCES ofrece Cerrar por primario; cerrada, Abrir. Pulsar la tapa conserva la bolsa sin
desecharla; pulsar el cuerpo con tapa cerrada rechaza sin soltar.

### AC-PLY-087 — Sin nada que hacer, nada *(verifica BR-PLY-035)*

DADO la mano vacía y la mira sin foco, o sobre un casillero vacío ENTONCES la referencia no
tiene ninguna línea. DADO la mopa mojada de agua y la mira sobre el piso sin mancha ENTONCES
es «[E] Examinar (mano)» y «[Click Izq] Dejar», sin línea del derecho. DADO la mano vacía y la
mira sobre una unidad de la fila de adelante de la góndola ENTONCES sale «[Click Izq] Agarrar»
y ninguna línea del derecho.

### AC-PLY-088 — Cada verbo sigue la asignación vigente *(verifica BR-PLY-037, BR-PLY-035)*

DADO examinar reasignado a Q y un levantable en la mano CUANDO se consulta ENTONCES la primera
línea dice «[Q] Examinar (mano)». DADO primario reasignado a F y balde sobre lavatorio ENTONCES
la acción dice «[F] Llenar» y F pide llenar. Sacar producto conserva el control secundario.
DADO un gesto con teclado y joystick ENTONCES muestra el teclado; sin control con nombre,
omite su línea y conserva el orden de las demás.

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

### AC-PLY-097 — Un primario produce un solo efecto contextual *(verifica BR-PLY-012, BR-PLY-026, BR-PLY-036)*

DADO un par declarado y, por separado, su estado aceptable y rechazado CUANDO se hace un
primario ENTONCES hay una sola solicitud de ese uso y cero solicitudes de soltado o secundario.
El rechazo conserva el objeto sostenido. DADO una unidad ante un objetivo sin interacción
declarada CUANDO se hace primario ENTONCES se suelta por el recorrido vigente; con mano vacía
y levantable enfocado, se agarra una sola vez.

### AC-PLY-098 — Salir consume el clic antes del mundo *(verifica BR-PLY-026, BR-PLY-028, BR-PLY-038)*

DADO una unidad sostenida y computadora, caja o nota abiertas CUANDO se cierran con secundario,
o nota con primario, o caja con primario fuera de sus márgenes ENTONCES se cierra la interfaz,
se conserva la unidad y hay cero usos, agarres o soltados en el mundo por ese clic.
DADO examen, celular, pausa o cierre CUANDO se pulsan ambos gestos ENTONCES no hay acción del
mundo y la referencia sigue vacía.

### AC-PLY-099 — La caja descansa sobre el borde gris *(verifica BR-PLY-040, BR-PLY-015, BR-PLY-018)*

DADO una caja chica y otra grande, por separado, y la división del baño del primer encuadre de
GJ-52 CUANDO se suelta mirando su borde gris superior desde piso transitable ENTONCES la base
descansa sobre la cara superior visible, no sobre la pared blanca, y no atraviesa el borde.
La comprobación cruza la base dibujada y la superficie física del mismo contacto.

### AC-PLY-101 — Los bidones se llevan y se apoyan como las cajas *(verifica BR-PLY-018)*

DADO cada bidón de jabón en la mano ENTONCES cuelga del mismo punto que una caja. CUANDO se lo
suelta mirando al piso libre ENTONCES queda derecho donde la mira tocaba y la mano queda vacía.

### AC-PLY-100 — La cabecera acomoda la caja sobre metal visible *(verifica BR-PLY-040, BR-PLY-013, BR-PLY-015, BR-PLY-018)*

DADO una caja chica y otra grande, por separado, y el segundo encuadre de GJ-52 CUANDO se
suelta por el mismo gesto real y avanza la física ENTONCES la caja queda acomodada y estable
sobre metal visible, con el contacto físico correspondiente, recogible y sin superposición.
La mano queda vacía; ni inventario ni tareas cambian por el acomodo o por la recogida.

### AC-PLY-095 — Los apoyos válidos siguen estables *(verifica BR-PLY-040, BR-PLY-013, BR-PLY-018)*

DADO caja chica y grande, por turno, sobre piso, mostrador, pallet del depósito y otra caja
CUANDO se suelta con apoyo suficiente ENTONCES queda estable y se puede recoger. DADO dos
cajas apiladas CUANDO se retira la inferior ENTONCES la superior cae hasta el soporte real
siguiente, sin inmovilizarse en el aire ni alterar cuerpos ajenos.

### AC-PLY-096 — Hablar y Entregar nombran el contexto de atención *(verifica BR-PLY-035, BR-PLY-036)*

DADO un contexto de atención que habilita hablar, con mano vacía o comprador todavía sin
atender CUANDO se arma la referencia ENTONCES la acción primaria dice «Hablar». DADO atención
terminada y entrega habilitada con objeto sostenido ENTONCES dice «Entregar», sin «Dejar»
simultáneo. Los dos verbos usan el control vigente del primario; declararlos no inicia diálogo
ni entrega por consultar, ni habilita atención directa si el puesto no la ofrece.

### AC-PLY-103 — La entrada ofrece sólo la salida disponible *(verifica BR-PLY-041, BR-PLY-037, BR-PLY-038)*

DADO una jornada de prueba antes del aviso CUANDO se enfoca cualquiera de las dos hojas de entrada ENTONCES no ofrece
acción primaria; el primario suena trabada y no gira ninguna hoja. DADO su salida habilitada
ENTONCES ofrece Interactuar con el control primario vigente. Tras vencer el aviso conserva
esa referencia mientras todas las tareas sigan cumplidas. CUANDO una tarea se descumple
ENTONCES se retira Interactuar y el primario vuelve a sonar trabada sin cerrar la noche.
Recuperar todas las tareas vuelve a ofrecer Interactuar. DADO la primera jornada completa
con todas las tareas hechas ENTONCES no ofrece salida y sigue sonando trabada.
Las otras puertas conservan Abrir y Cerrar.

### AC-PLY-104 — Un primario cierra y conserva la mano *(verifica BR-PLY-041, BR-PLY-026)*

DADO la entrada habilitada y, por separado, mano vacía y un objeto sostenido CUANDO se hace
primario sobre cualquiera de sus dos hojas ENTONCES inicia una sola salida de BR-SHF-025,
abre ambas hojas sin soltar ni usar el objeto. Durante
el giro y la apertura no se puede caminar, controlar la mirada, examinar, agarrar, soltar ni
usar; la referencia permanece vacía y se conserva el objeto. CUANDO se
hace secundario ENTONCES no cierra ni emite traba. DADO el control suspendido o la pausa
abierta ENTONCES ambos gestos dejan la noche abierta. Después del cierre los gestos no lo repiten.

### AC-PLY-120 — Agachado, la vista baja *(verifica BR-PLY-042)*

DADO el jugador de pie CUANDO se mantiene apretada la acción de agacharse ENTONCES la altura de
la vista es la altura agachado, y no la de pie.

### AC-PLY-121 — Soltar la acción levanta la vista y no es un interruptor *(verifica BR-PLY-042)*

DADO el jugador agachado CUANDO se suelta la acción ENTONCES la altura de la vista vuelve a la de
pie. DADO el jugador de pie CUANDO se aprieta y se suelta la acción ENTONCES queda a la altura de
pie, y apretarla de nuevo lo baja otra vez.

### AC-PLY-122 — La altura agachado está entre el piso y la de pie *(verifica BR-PLY-042)*

DADO las dos alturas de la vista ENTONCES la agachado es mayor que cero y menor que la de pie.

### AC-PLY-123 — Agachado se camina igual de rápido *(verifica BR-PLY-042, BR-PLY-002)*

DADO el jugador agachado y una entrada hacia adelante CUANDO se calcula la velocidad ENTONCES su
módulo es la velocidad de caminata de BR-PLY-002, la misma que de pie. DADO una entrada en
diagonal ENTONCES la normalización de BR-PLY-001 se conserva.

### AC-PLY-124 — Suspendido, la postura no cambia *(verifica BR-PLY-042, BR-PLY-006)*

DADO el jugador agachado y el control suspendido CUANDO se suelta la acción ENTONCES la altura
sigue siendo la agachado. DADO el jugador de pie y el control suspendido CUANDO se aprieta la
acción ENTONCES la altura sigue siendo la de pie. CUANDO se reanuda con la acción apretada
ENTONCES la altura es la agachado; reanudada con la acción suelta, la de pie.

### AC-PLY-125 — La mira enfoca desde la altura agachado *(verifica BR-PLY-042, BR-PLY-004)*

DADO el jugador agachado ENTONCES la cámara de la mira está a la altura agachado sobre el piso,
y un objeto interactuable apenas debajo de la altura de pie, en línea con la mira agachado, queda
enfocado. CUANDO se suelta la acción ENTONCES la cámara vuelve a la altura de pie.

### AC-PLY-126 — Espacio es de la acción y la acción tiene su nombre *(verifica BR-PLY-042)*

DADO el mapa de entradas del juego ENTONCES la acción de agacharse existe, su tecla es Espacio y
ninguna otra acción del juego que ya existía la tiene. DADO el nombre de la acción en el dominio
ENTONCES coincide con el del mapa de entradas.

### AC-PLY-127 — Espacio no acepta el botón con foco *(verifica BR-PLY-042)*

DADO el mapa de entradas del juego ENTONCES la acción de aceptar de la interfaz no tiene Espacio y
sigue teniendo Enter y el Enter del teclado numérico.

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
  asignado a cada gesto; la acción primaria o secundaria y el contexto declarado del par
  mano/objetivo, independiente del resultado del intento; la vigencia del comprador, el
  estado de su conversación y su figura animada visible para foco, contorno e interacción directa;
  si la acción de agacharse está apretada.
- **Salida:** la velocidad, los dos ángulos de la vista, su altura, qué está enfocado y si cambió, qué se
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
  diálogo devuelve automáticamente la vista y el movimiento, salvo el control tomado por el cierre.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (consume): las obligatorias declaradas que
  enumera la nota de tareas y el permiso actual para salir por la entrada durante la prueba.

- [`store-cleanup`](../store-cleanup/store-cleanup.md) (alimenta y consume): qué se lleva en la
  mano decide si se puede limpiar; si un tacho conserva su bolsa decide si el primario ofrece
  extracción.
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

- **OQ-PLY-004 — ¿Qué condición geométrica decide la estabilidad de cualquier apoyo parcial?**
  - Por qué sigue abierta: GJ-52 decide el resultado de dos encuadres, pero no fija un umbral
    de huella ni una regla general para todos los bordes. El soporte de un punto no la decide.
  - Decide: el dueño del repo con game design, sobre la reproducción y las medidas de los apoyos.
  - Bloquea: introducir un umbral general de estabilidad no decidido; si corregir el caso de
    góndola requiere ese umbral, bloquea su implementación hasta resolverlo. No cambia los
    resultados concretos de BR-PLY-040 ni los apoyos válidos existentes.
