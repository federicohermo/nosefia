---
schema_version: 1
capability_id: CAP-CFG
status: ratified
owner: por definir
provenance: fichas «2. Menú de inicio» (sección «Interfaz de configuraciones») y «Pausa y menú de pausa»; rangos, pasos y defectos decididos por el dueño en #378, provisorios hasta que el testing los ajuste; «Controles» (esquema de teclado y mouse) de la ficha «2. Menú de inicio», #379; esquema de joystick de la misma ficha y decisión del dueño del 2026-11-04, #380
---

# Capacidad: configuraciones

## Propósito

Que el jugador ajuste cómo suena, cómo se ve y cómo responde el juego, qué tecla o botón del
mouse hace cada acción, y que el juego lo recuerde
al volver a abrirlo. Lo único que tiene que hacer bien es **no empeorar el juego que ya está**:
cada defecto es el juego de hoy, ningún ajuste suena más fuerte que hoy y un archivo roto no
impide jugar.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Configuraciones** | la pantalla donde se ajustan las preferencias, abierta desde el menú de inicio o desde la pausa | opciones, ajustes, settings |
| **Preferencia** | un valor que el jugador ajusta y que cruza sesiones, aparte de la partida | opción, setting, configuración |
| **Barra** | la fila que ajusta una preferencia, con un botón − a la izquierda y uno + a la derecha | slider, control |
| **Paso** | lo que mueve un + o un − | incremento, tick |
| **Tope** | el mínimo o el máximo de una preferencia | límite, borde |
| **Defecto** | el valor de una preferencia que nadie ajustó. Es el juego de hoy | por omisión, inicial |
| **Sensibilidad de fábrica** | los radianes por píxel que el dominio del jugador declara para el giro de la vista y el del examen | — |
| **Acción reasignable** | una de las siete que el jugador puede cambiar de tecla: movimiento, celular, examinar, agacharse, agarrar / soltar, interactuar y pausa | comando, bind |
| **Entrada** | una tecla o un botón del mouse. Mover el mouse y la rueda no lo son | evento, input |
| **Botón de joystick** | un botón del joystick, nombrado como en PlayStation: X, CÍRCULO, CUADRADO, L1, R1. Los ejes y los gatillos analógicos no lo son | — |
| **Esquema de joystick** | el botón que cada acción de botón tiene en el joystick, aparte de su tecla o clic | — |
| **Ranura** | el lugar fijo de una entrada dentro de una acción: Movimiento tiene ocho, dos por dirección —la de WASD y la de flechas—, y cada una de las demás tiene una | slot, alias |
| **Esquema de fábrica** | la entrada que cada ranura tiene mientras nadie la cambió. Son las teclas que nombran los demás contratos | por omisión |

## Comportamiento normativo

### BR-CFG-001 — Siete filas, en un orden fijo

Configuraciones DEBE mostrar siete filas, en este orden: **efectos, música, brillo,
sensibilidad, textos, lenguaje y controles**. Las cinco primeras DEBEN ser una barra con un botón − a la
izquierda y un botón + a la derecha. Lenguaje DEBE mostrar el idioma elegido entre un botón < a
la izquierda y un botón > a la derecha, que pasan al idioma anterior y al siguiente. Hoy hay un
solo idioma, «ESPAÑOL», y por eso los dos botones DEBEN estar deshabilitados. Controles DEBE
mostrar un botón «AJUSTAR» (`BR-CFG-015`).

### BR-CFG-002 — Rango, paso y defecto de cada preferencia

El sistema DEBE acotar cada preferencia a su rango y moverla de a un paso:

| Preferencia | Mínimo | Máximo | Paso | Defecto | Valores posibles |
|---|---|---|---|---|---|
| Efectos | 0 % | 100 % | 10 % | 100 % | 11 |
| Música | 0 % | 100 % | 10 % | 100 % | 11 |
| Brillo | 50 % | 150 % | 10 % | 100 % | 11 |
| Sensibilidad | 0,25× | 2× | 0,25× | 1× | 8 |
| Textos | 0,8× | 1,5× | 0,1× | 1× | 8 |

Los valores posibles son (máximo − mínimo) ÷ paso + 1, y los dos topes son valores posibles.

### BR-CFG-003 — Un botón mueve un paso, y el tope no se pasa

CUANDO se aprieta +, el sistema DEBE subir la preferencia un paso; CUANDO se aprieta −, bajarla
un paso. SI la preferencia está en su máximo, ENTONCES + NO DEBE cambiarla; SI está en su
mínimo, ENTONCES − tampoco. Un gesto que no cambia el valor NO DEBE escribir nada.

### BR-CFG-004 — Arrastrar cae en un paso

CUANDO se arrastra una barra, el sistema DEBE dejar la preferencia en el valor posible más
cercano al arrastrado. Arrastrar DEBE dar el mismo valor que llegar ahí con los botones.

### BR-CFG-005 — Efectos y música regulan los buses, sin pasar el volumen de hoy

Efectos DEBE regular juntos los buses de ambiente, efectos e interfaz; música DEBE regular el de
música. Son los cuatro buses de `BR-AMB-003`. En 100 % cada bus DEBE sonar al volumen de hoy,
0 dB, y ninguna barra DEBE hacer sonar un bus más fuerte que eso. En 0 % sus buses DEBEN quedar
en silencio. El volumen DEBE ser proporcional a la amplitud: en v % el bus suena a v/100 de la amplitud de
hoy, o sea 20·log10(v/100) dB. Una barra NO DEBE
cambiar el volumen de los buses de la otra.

### BR-CFG-006 — Sensibilidad multiplica la de fábrica, en la vista y en el examen

El sistema DEBE girar la vista y lo que se examina con la sensibilidad de fábrica multiplicada
por la sensibilidad elegida. Los dos giros DEBEN usar el mismo factor. En 1× DEBEN girar igual
que hoy.

### BR-CFG-007 — Brillo cambia la interfaz y el local

El sistema DEBE multiplicar por el brillo elegido el brillo de todo lo que se dibuja con el tema
de la interfaz: menús, pausa, avisos, computadora y celular. También DEBE multiplicar por él el
brillo de la vista del local en 3D. En 100 % la interfaz y el local DEBEN verse como hoy.

### BR-CFG-008 — Textos multiplica el tamaño de letra de la interfaz

El sistema DEBE multiplicar por la escala elegida el tamaño de letra de todo lo que usa el tema
de la interfaz. La escala se aplica sobre los tamaños de hoy y no sobre la escala anterior: en
1× los tamaños DEBEN ser los de hoy, sin importar por qué escalas pasó antes. Con la escala en
su máximo, ningún texto de Configuraciones DEBE recortarse.
CUANDO se cambia esta escala dentro de Configuraciones, la letra DEBE conservar su tamaño
actual hasta volver al menú anterior, tanto con «Volver» como con Esc. Al volver, la escala
elegida DEBE aplicarse a toda la interfaz.

### BR-CFG-009 — Cada cambio vale en el momento

CUANDO cambia una preferencia distinta de textos, el sistema DEBE aplicarla sin esperar a que se cierre
Configuraciones: el sonido cambia mientras la barra se mueve. La sensibilidad nueva DEBE valer
desde el primer giro después de reanudar.

### BR-CFG-010 — Se abre desde los dos menús

CUANDO se elige configuraciones en el menú de inicio o en la pausa, el sistema DEBE abrir
Configuraciones. Abierta desde la pausa, el juego DEBE seguir en pausa y el cursor suelto
mientras está en pantalla. Cómo la cierra Esc lo dice `BR-SAV-016`. Cerrarla desde la pausa
DEBE dejar el menú de pausa con el foco en reanudar.
Configuraciones DEBE reemplazar los controles y el título del menú anterior, conservando su
vista de fondo. DEBE ofrecer un botón visible «Volver», que cierre la pantalla como Esc.

### BR-CFG-011 — Las preferencias viven aparte de la partida

El sistema DEBE guardar las preferencias aparte del guardado de la partida. Borrar el guardado
—al terminar la partida (`BR-SAV-002`) o al empezar un nuevo juego (`BR-SAV-012`)— NO DEBE
tocarlas. En la web DEBEN sobrevivir a recargar la página en el mismo navegador, igual que el
guardado.

### BR-CFG-012 — Cada cambio se escribe en el momento

CUANDO cambia una preferencia, el sistema DEBE escribirla al disco, sin esperar a que se cierre
Configuraciones ni a que se cierre el juego.

### BR-CFG-013 — Se aplican al abrir el juego

CUANDO abre el juego, el sistema DEBE leer las preferencias y aplicarlas antes de que suene nada
en el menú de inicio. Cada partida que empieza o se retoma DEBE usar las preferencias guardadas,
no los defectos.

### BR-CFG-014 — Un archivo malo no impide jugar

SI a las preferencias les falta un campo, o SI un campo tiene otro tipo, o SI un valor está fuera
de su rango, ENTONCES el sistema DEBE usar el defecto de ese campo y conservar los demás. SI el
archivo es ilegible, ENTONCES DEBE usar todos los defectos y NO DEBE interrumpir el arranque. SI
no hay archivo, ENTONCES DEBE usar todos los defectos.

### BR-CFG-015 — La fila «CONTROLES» abre la pantalla de controles

CUANDO se aprieta el botón «AJUSTAR» de la fila «CONTROLES», que está debajo de lenguaje, el
sistema DEBE abrir la pantalla de controles, que DEBE ser una lista con un
renglón por acción: su nombre y la tecla o el botón de cada una de sus entradas. CUANDO llega la
tecla de Pausa, el sistema DEBE cerrar la pantalla de controles y volver a Configuraciones.
Abierta desde la pausa, el juego DEBE seguir en pausa y el cursor suelto, igual que
Configuraciones.

### BR-CFG-016 — Siete acciones reasignables

El jugador DEBE poder reasignar siete acciones, con estos nombres en pantalla: **Movimiento**,
**Abrir la interfaz del celular**, **Examinar**, **Agacharse**, **Agarrar / Soltar**,
**Interactuar** y **Pausa**. Ninguna otra acción se reasigna. Movimiento DEBE mostrar, en
su único renglón, ocho entradas, dos por cada dirección —adelante, atrás, izquierda y
derecha—, una de WASD y otra de flechas, y cada una DEBE poder reasignarse desde ese renglón. Las
demás DEBEN mostrar una en su renglón. El esquema de fábrica DEBE ser: W, A, S, D y las cuatro
flechas en Movimiento; Q en celular; E en Examinar; Espacio en Agacharse; el clic izquierdo en
Agarrar / Soltar; el clic derecho en Interactuar; Esc en Pausa.

### BR-CFG-017 — Cualquier acción acepta una tecla o un botón del mouse

CUANDO el jugador elige una entrada de la pantalla de controles y aprieta una tecla o un botón
del mouse, el sistema DEBE asignársela a esa ranura. Toda acción DEBE aceptar las dos clases:
un clic se puede pasar a una tecla, y una tecla a un clic. Mover el mouse y la rueda NO DEBEN
ser entradas aceptadas: apretarlos NO DEBE cambiar nada. CUANDO el jugador aprieta la tecla de
Pausa mientras espera una entrada, el sistema DEBE cancelar la espera sin cambiar nada. EN LA WEB, el sistema NO DEBE aceptar
Esc en ninguna acción que no sea Pausa: con el cursor tomado el navegador se come Esc y esa
acción no se podría hacer.

### BR-CFG-018 — Una entrada nunca hace dos cosas

CUANDO la entrada elegida ya la tiene otra ranura, el sistema DEBE intercambiarlas: la otra
ranura DEBE recibir la entrada que tenía la elegida. Ninguna ranura DEBE quedar sin entrada y
ninguna entrada DEBE estar en dos ranuras. El intercambio DEBE valer también entre las dos
ranuras de una misma acción y entre direcciones. CUANDO la entrada elegida es la que la ranura
ya tiene, el sistema NO DEBE cambiar nada ni escribir nada.

### BR-CFG-019 — Cada entrada tiene una ranura estable

Elegir una entrada en pantalla DEBE identificar su acción y su ranura. Cambiar la ranura de
flechas de una dirección DEBE conservar la de WASD de esa dirección, y al revés. El intercambio
DEBE identificar las dos ranuras, también si pertenecen a la misma acción.

### BR-CFG-020 — Cada asignación vale en el momento, y las acciones leen la acción

CUANDO cambia una asignación, el sistema DEBE aplicarla sin esperar a que se cierre la pantalla
de controles: la caminata, la mano, el examen, el celular, la agachada, la pausa y cada puesto
DEBEN responder a la entrada nueva y NO DEBEN responder a la que la ranura dejó. Una asignación
hecha desde la pausa DEBE valer al reanudar, sin volver al menú. Pausa DEBE ser la tecla que
pausa, reanuda y cierra Configuraciones y las listas desplegables. Pulsar al comprador en la
ventanilla DEBE seguir a Agarrar / Soltar: el comprador responde a la entrada que tenga esa acción.
Los gestos del cursor sobre una pantalla —avanzar un diálogo, arrastrar para girar lo examinado,
arrastrar la lista de la caja, y pulsar los botones y renglones de las pantallas— NO son una
acción: DEBEN seguir en el botón izquierdo del mouse, sin importar la asignación.

### BR-CFG-021 — En la web, Esc sigue pausando

SI el navegador suelta el cursor con Esc, ENTONCES el sistema DEBE pausar por `BR-SAV-016`,
aunque Pausa tenga otra entrada. Con Pausa en otra tecla, la tecla nueva y Esc DEBEN pausar.

### BR-CFG-022 — Las asignaciones se guardan con las preferencias

El sistema DEBE guardar las asignaciones en el mismo archivo de las preferencias, con su propia
clave, y cada cambio DEBE llegar al disco en el momento (`BR-CFG-012`). SI no hay asignaciones
guardadas, ENTONCES cada ranura DEBE tener su entrada del esquema de fábrica. Volver al menú y
entrar otra vez, y empezar un nuevo juego, NO DEBEN tocarlas (`BR-CFG-011`). CUANDO abre el
juego, el sistema DEBE aplicarlas antes de que el jugador pueda usar una (`BR-CFG-013`).

### BR-CFG-023 — Un esquema roto no deja a una acción sin entrada ni con una repetida

CUANDO el sistema lee las asignaciones, DEBE cargarlas sobre las ranuras de fábrica y validar el
conjunto resultante. SI una asignación es ilegible, o es de una acción o una ranura que no
existe, ENTONCES DEBE ignorarla y esa ranura DEBE volver a su entrada de fábrica. SI el conjunto
resultante deja una entrada en dos ranuras, ENTONCES el
sistema DEBE descartar el bloque de controles completo y restaurar el esquema de fábrica. NO
DEBE aplicar nunca un esquema parcial con entradas repetidas o con una acción sin entrada. Las
demás preferencias del archivo DEBEN conservarse (`BR-CFG-014`).

### BR-CFG-024 — Las teclas que nombran los demás contratos son las de fábrica

Las teclas que nombran los otros contratos —«clic derecho», «clic izquierdo», «Esc», «Espacio»,
«E», «Q»— DEBEN leerse como las del esquema de fábrica de la acción. Una asignación las
reemplaza: lo que un contrato atribuye a una tecla lo hace la entrada que la acción tiene
ahora.

### BR-CFG-025 — El joystick tiene su esquema de fábrica

Cinco de las siete acciones reasignables DEBEN tener además un botón de joystick, el de fábrica:
**X** en Agarrar / Soltar, **R1** en Interactuar, **L1** en Agacharse, **CÍRCULO** en Abrir la
interfaz del celular y **CUADRADO** en Examinar. Movimiento y Pausa NO DEBEN tener botón de
joystick reasignable: el joystick izquierdo camina y el derecho mira (`BR-PLY-055`, `BR-PLY-056`), y
Pausa en el joystick es START (`BR-SAV-024`). La cruceta, el joystick derecho y X en las interfaces
(`BR-CFG-027`) tampoco se reasignan.

### BR-CFG-026 — La pantalla de controles reasigna los botones del joystick

La pantalla de controles DEBE sumar el esquema del joystick: un renglón por cada una de las cinco
acciones de botón, con su botón, y dos renglones que sólo se muestran —joystick izquierdo,
Movimiento, y joystick derecho, Visión—, que NO DEBEN poder reasignarse. CUANDO el jugador elige el
botón de un renglón y aprieta un botón de joystick, el sistema DEBE asignárselo a esa acción, con el
intercambio de `BR-CFG-018` dentro del joystick: ninguna acción queda sin botón y ningún botón
está en dos acciones. Una ranura de teclado o mouse NO DEBE aceptar un botón de joystick, y una de
joystick NO DEBE aceptar una tecla ni un clic: apretarlos no cambia nada. START no se acepta, porque
es la pausa; un eje o un gatillo analógico tampoco. CUANDO el jugador aprieta Pausa —la tecla o
START— mientras espera un botón, el sistema DEBE cancelar la espera sin cambiar nada. Cada
asignación DEBE valer en el momento, como `BR-CFG-020`, y NO DEBE cambiar la tecla ni el clic de la
acción.

### BR-CFG-027 — En las interfaces, la cruceta y el joystick derecho eligen, y X aprieta

MIENTRAS hay una interfaz abierta, la cruceta y el joystick derecho DEBEN elegir, y X DEBE apretar
lo elegido. Arriba y abajo DEBEN pasar de renglón. Hacia los costados, sobre una fila con + y −,
DEBEN sumar o restar una unidad —la planilla de ventas de la computadora y las barras de
Configuraciones—; sobre una fila sin + ni −, NO DEBEN hacer nada. X sobre un botón deshabilitado NO
DEBE hacer nada, igual que un clic. El joystick derecho NO DEBE girar la vista mientras elige
(`BR-PLY-056`).

### BR-CFG-028 — Cada interfaz que se abre deja el foco en un control

CUANDO se abre una interfaz, el sistema DEBE dejar el foco en uno de sus controles habilitados,
para que la cruceta tenga por dónde empezar. Son interfaces: el menú de inicio, la pausa,
Configuraciones, la pantalla de controles, la computadora y sus programas, el programa de tickets y
sus listas, la ventanilla, la pantalla de devolución y el celular. La nota encuadrada no tiene
ningún control que elegir, y en la pantalla de devolución el foco llega con su opción, que aparece
cuando llega el último mensaje.

### BR-CFG-029 — Los tres gestos del botón izquierdo tienen su equivalente en el joystick

Avanzar un diálogo DEBE poder hacerse con X. Pulsar al comprador en la ventanilla DEBE seguir al
botón de Agarrar / Soltar, que de fábrica es X. Girar lo examinado DEBE poder hacerse con el
joystick derecho mientras se examina, en proporción a la inclinación y a la velocidad a fondo del
giro de la vista (`BR-PLY-056`); la sensibilidad de Configuraciones es sólo del mouse. CUANDO hay
una nota encuadrada abierta, X NO DEBE cerrarla, como el clic izquierdo (`BR-PLY-029`), y NO DEBE
apretar el control que tenga el foco; la cierra Interactuar.

### BR-CFG-030 — Los botones del joystick se guardan como números

El sistema DEBE guardar los botones del joystick en el mismo archivo y el mismo bloque de controles
que las teclas, cada uno como el número del botón (`BR-CFG-022`). CUANDO lee las asignaciones, DEBE
validarlas como `BR-CFG-023`: un botón ilegible, que no es un botón, que es START, o de una acción
sin botón de joystick, se ignora y esa acción vuelve a su botón de fábrica; dos acciones con el
mismo botón descartan el bloque de controles completo, también las teclas. SI el archivo no guarda
botones de joystick, ENTONCES cada acción DEBE tener su botón de fábrica.

## Criterios de aceptación

### AC-CFG-001 — Las siete filas *(verifica BR-CFG-001)*

DADO Configuraciones abierta ENTONCES muestra efectos, música, brillo, sensibilidad, textos,
lenguaje y controles, en ese orden; cada una de las cinco primeras tiene un − a la izquierda de su barra y un
+ a la derecha; lenguaje muestra «ESPAÑOL» entre un < y un >, y los dos están deshabilitados; controles muestra
un botón «AJUSTAR».

### AC-CFG-002 — La tabla de valores *(verifica BR-CFG-002)*

DADO ninguna preferencia ajustada ENTONCES efectos y música están en 100 %, brillo en 100 %,
sensibilidad en 1× y textos en 1×. DADO cada preferencia CUANDO se la recorre con + desde su
mínimo hasta que + deja de cambiarla ENTONCES pasa por 11 valores en efectos, música y brillo, y
por 8 en sensibilidad y textos, y termina en 100 %, 100 %, 150 %, 2× y 1,5×.

### AC-CFG-003 — Los topes *(verifica BR-CFG-003)*

DADO efectos en 100 % CUANDO se aprieta + ENTONCES sigue en 100 % y no se escribe nada. DADO
música en 0 % CUANDO se aprieta − ENTONCES sigue en 0 % y no se escribe nada. DADO textos en
1,4× CUANDO se aprieta + ENTONCES queda en 1,5×; CUANDO se aprieta + otra vez ENTONCES sigue en
1,5× y no se escribe nada. DADO sensibilidad en 0,5× CUANDO se aprieta − ENTONCES queda en
0,25×; CUANDO se aprieta − otra vez ENTONCES sigue en 0,25×.

### AC-CFG-004 — Arrastrar da lo mismo que los botones *(verifica BR-CFG-004)*

DADO brillo en 100 % CUANDO se arrastra la barra hasta 123 % ENTONCES queda en 120 %, el mismo
valor que dos + desde 100 %. DADO sensibilidad CUANDO se arrastra hasta 1,1× ENTONCES queda en
1×; hasta 1,2×, en 1,25×.

### AC-CFG-005 — Los volúmenes *(verifica BR-CFG-005)*

DADO efectos y música en 100 % ENTONCES los cuatro buses están en 0 dB. DADO efectos en 0 %
ENTONCES ambiente, efectos e interfaz están en silencio y música sigue en 0 dB. DADO música en
0 % ENTONCES música está en silencio y los otros tres siguen en 0 dB. DADO efectos en 50 %
ENTONCES los tres buses están en 20·log10(0,5) ≈ −6,02 dB, y con 10 % en −20 dB.
DADO un archivo con efectos en 150 % CUANDO se lo lee ENTONCES efectos queda en 100 % y ningún
bus pasa de 0 dB.

### AC-CFG-006 — La sensibilidad *(verifica BR-CFG-006)*

DADO un mismo movimiento del mouse ENTONCES con 1× la vista gira lo mismo que con la sensibilidad
de fábrica, con 2× gira el doble y con 0,25× la cuarta parte. DADO algo en examen y el mismo
arrastre ENTONCES con 2× gira el doble que con 1×, y con 0,25× la cuarta parte.

### AC-CFG-007 — El brillo *(verifica BR-CFG-007)*

DADO brillo en 50 % ENTONCES la interfaz se dibuja con su brillo multiplicado por 0,5; en 150 %,
por 1,5; en 100 %, sin cambio. DADO el local con el brillo de hoy CUANDO brillo pasa a 50 %
ENTONCES el brillo del local es el de hoy multiplicado por 0,5; en 150 %, por 1,5; en 100 %, el
de hoy, aunque antes haya pasado por otros valores.

### AC-CFG-008 — Los textos *(verifica BR-CFG-008)*

DADO un texto de la interfaz que hoy mide 40 CUANDO textos pasa a 1,5× ENTONCES mide 60; a 0,8×,
32; a 1×, 40. DADO textos que pasó por 1,5× y después por 0,8× CUANDO vuelve a 1× ENTONCES cada
texto mide lo mismo que antes de tocar la barra. DADO textos en 1,5× ENTONCES ningún texto de
Configuraciones se recorta, ni a 1920 × 1080 ni a 1280 × 720.
DADO Configuraciones abierta CUANDO se cambia textos ENTONCES los tamaños visibles se
conservan; CUANDO se vuelve con «Volver» o Esc ENTONCES se aplica la escala elegida.

### AC-CFG-009 — En el momento *(verifica BR-CFG-009)*

DADO Configuraciones abierta y música en 100 % CUANDO la barra pasa a 50 % ENTONCES el bus de
música ya cambió, con la pantalla todavía abierta. DADO Configuraciones abierta desde la pausa
CUANDO sensibilidad pasa a 2× y se reanuda ENTONCES el primer giro de la vista ya gira el doble
que con 1×.

### AC-CFG-010 — Los dos menús la abren *(verifica BR-CFG-010)*

DADO el menú de inicio CUANDO se elige configuraciones ENTONCES Configuraciones está en
pantalla sobre el mismo fondo, sin los controles ni el título del menú anterior. CUANDO se
elige «Volver» ENTONCES vuelve el menú de inicio. DADO el menú de pausa CUANDO se elige configuraciones ENTONCES Configuraciones está en
pantalla, el juego sigue en pausa y el cursor está suelto; CUANDO se la cierra ENTONCES el menú
de pausa está en pantalla con el foco en reanudar.

### AC-CFG-011 — Borrar la partida no borra las preferencias *(verifica BR-CFG-011)*

DADO música en 30 % y un guardado CUANDO la partida termina y se borra el guardado ENTONCES
música sigue en 30 %. DADO lo mismo CUANDO se empieza un nuevo juego ENTONCES el guardado se
borra y música sigue en 30 %. DADO el juego en la web con música en 30 % CUANDO se recarga la
página en el mismo navegador ENTONCES música sigue en 30 %.

### AC-CFG-012 — Se escribe en el momento *(verifica BR-CFG-012)*

DADO Configuraciones abierta CUANDO se aprieta + en brillo ENTONCES, antes de cerrar la pantalla,
leer las preferencias del disco devuelve el brillo nuevo. DADO preferencias escritas CUANDO se
las lee en otro arranque ENTONCES vuelven los cinco valores, cada uno con su tipo.

### AC-CFG-013 — Al abrir el juego *(verifica BR-CFG-013)*

DADO preferencias guardadas con música en 0 % CUANDO abre el juego ENTONCES el bus de música ya
está en silencio antes del primer sonido del menú de inicio. DADO sensibilidad 2× guardada
CUANDO se vuelve al menú y se empieza otra partida ENTONCES la vista gira el doble que con 1×.

### AC-CFG-014 — El archivo malo *(verifica BR-CFG-014)*

DADO preferencias sin el campo de textos y con música en 30 % ENTONCES textos queda en 1× y
música en 30 %. DADO efectos con un texto en vez de un número ENTONCES efectos queda en 100 %.
DADO sensibilidad en 0 ENTONCES queda en 1×; en 2,5×, también. DADO brillo en 40 % ENTONCES queda
en 100 %. DADO un archivo ilegible CUANDO abre el juego ENTONCES las cinco preferencias están en
su defecto y el menú de inicio aparece. DADO que no hay archivo ENTONCES las cinco están en su
defecto.

### AC-CFG-015 — La fila y la pantalla de controles *(verifica BR-CFG-015)*

DADO Configuraciones abierta ENTONCES la fila «CONTROLES», con el botón «AJUSTAR», está debajo de
lenguaje. CUANDO se aprieta «AJUSTAR» ENTONCES la pantalla de controles está en pantalla, con un
renglón por acción; CUANDO llega la tecla de Pausa ENTONCES vuelve Configuraciones y la pantalla
de controles ya no está. DADO Configuraciones abierta desde la pausa CUANDO se abre y se cierra la pantalla de
controles ENTONCES el juego sigue en pausa y el cursor sigue suelto.

### AC-CFG-016 — Las siete acciones y su esquema de fábrica *(verifica BR-CFG-016)*

DADO ninguna asignación guardada ENTONCES la pantalla muestra siete renglones, uno por acción, con
estos nombres: Movimiento, Abrir la interfaz del celular, Examinar, Agacharse, Agarrar / Soltar,
Interactuar y Pausa. El renglón de Movimiento tiene ocho entradas: adelante en W y en la flecha arriba, atrás en S y en la
flecha abajo, izquierda en A y en la flecha izquierda, derecha en D y en la flecha derecha. El
celular está en Q, Examinar en E, Agacharse en Espacio, Agarrar / Soltar en el clic izquierdo,
Interactuar en el clic derecho y Pausa en Esc. DADO la partida recién abierta ENTONCES las
entradas de cada acción en el motor son esas.

### AC-CFG-017 — Una tecla o un botón, en cualquier acción *(verifica BR-CFG-017)*

DADO Agarrar / Soltar en el clic izquierdo CUANDO se elige y se aprieta F ENTONCES queda en F;
DADO Examinar en E CUANDO se elige y se aprieta el clic central ENTONCES queda en el clic
central. DADO Examinar elegida CUANDO se mueve el mouse o se gira la rueda ENTONCES sigue en E y espera
otra entrada; CUANDO llega la tecla de Pausa ENTONCES la espera se cancela y sigue en E.
DADO la web CUANDO se elige Examinar y se aprieta Esc ENTONCES sigue en E; DADO la web CUANDO se
elige Pausa y se aprieta Esc ENTONCES sigue en Esc. DADO el juego de escritorio CUANDO se asigna
Esc a Examinar ENTONCES queda en Esc, y Pausa recibe E.

### AC-CFG-018 — El intercambio *(verifica BR-CFG-018)*

DADO Examinar en E y Agacharse en Espacio CUANDO se asigna Espacio a Examinar ENTONCES Examinar
queda en Espacio y Agacharse en E. DADO Agarrar / Soltar en el clic izquierdo e Interactuar en el
clic derecho CUANDO se asigna el clic izquierdo a Interactuar ENTONCES Interactuar queda en el clic
izquierdo y Agarrar / Soltar en el clic derecho. DADO adelante en W y en la flecha arriba CUANDO se
asigna W a la ranura de flechas de adelante ENTONCES la ranura de flechas queda en W y la de WASD
en la flecha arriba. DADO izquierda en A y derecha en D CUANDO se asigna D a la ranura de WASD de
izquierda ENTONCES queda en D y la de WASD de derecha en A. En cada caso las catorce ranuras
tienen, juntas, catorce entradas distintas. DADO Examinar en E CUANDO se asigna E a Examinar
ENTONCES nada cambia y no se escribe nada.

### AC-CFG-019 — Las ranuras *(verifica BR-CFG-019)*

DADO Movimiento de fábrica CUANDO se asigna la tecla H a la ranura de flechas de adelante
ENTONCES adelante tiene H y W, y las demás direcciones conservan sus dos entradas. DADO adelante
en W y en la flecha arriba CUANDO se asigna la flecha arriba a la ranura de WASD de adelante
ENTONCES la ranura de WASD queda en la flecha arriba y la de flechas en W, y ninguna otra acción
cambia. DADO una asignación a una acción o a una ranura que no existe ENTONCES no cambia nada.

### AC-CFG-020 — Vale en el momento *(verifica BR-CFG-020)*

DADO Agarrar / Soltar asignada a F CUANDO llega F con algo al alcance ENTONCES la mano lo agarra y
el clic izquierdo ya no lo hace. DADO Pausa asignada a P CUANDO llega P ENTONCES el juego se
pausa; CUANDO llega P otra vez ENTONCES se reanuda; CUANDO llega Esc con la partida en curso
ENTONCES no se pausa por esa tecla. DADO Pausa en P y Configuraciones abierta CUANDO llega P
ENTONCES se cierra, y Esc no la cierra. DADO una asignación hecha con la pausa abierta CUANDO se
reanuda ENTONCES vale sin volver al menú. DADO Agarrar / Soltar en F y la ventanilla abierta con un
comprador CUANDO llega F ENTONCES el comprador avanza, y el clic izquierdo no lo hace. DADO Agarrar
/ Soltar en F ENTONCES el clic izquierdo sigue avanzando un diálogo, girando lo examinado al
arrastrar y arrastrando la lista de la caja.

### AC-CFG-021 — La web sigue pausando con Esc *(verifica BR-CFG-021)*

DADO la web, Pausa en P y el cursor tomado CUANDO el navegador lo suelta con Esc ENTONCES el juego
queda en pausa; CUANDO llega P ENTONCES también. DADO la web y Pausa en Esc CUANDO el navegador
suelta el cursor ENTONCES el juego queda en pausa una sola vez.

### AC-CFG-022 — Las asignaciones se guardan *(verifica BR-CFG-022)*

DADO Examinar asignada a F CUANDO se lee el archivo del disco, antes de cerrar la pantalla,
ENTONCES Examinar está en F. DADO lo mismo CUANDO se vuelve al menú y se entra otra vez ENTONCES
sigue en F. DADO un guardado y Examinar en F CUANDO se empieza un nuevo juego ENTONCES el guardado
se borra y Examinar sigue en F. DADO preferencias guardadas sin asignaciones ENTONCES cada ranura
tiene su entrada de fábrica y las cinco preferencias conservan su valor. DADO un archivo con
música en 30 % y Examinar en F CUANDO abre el juego ENTONCES música está en 30 % y Examinar en F
desde el primer cuadro.

### AC-CFG-023 — El esquema roto *(verifica BR-CFG-023)*

DADO una asignación de una acción que no existe ENTONCES se ignora y las siete acciones tienen su
entrada de fábrica. DADO Examinar con una entrada ilegible —un tipo desconocido o un código que
no es número— y Agacharse en F ENTONCES Examinar vuelve a E y Agacharse conserva F. DADO Examinar
y Agacharse guardadas las dos en F ENTONCES se descarta el bloque completo: las siete acciones
tienen su entrada de fábrica. DADO Examinar con una entrada ilegible y Agacharse guardada en E
ENTONCES restaurar Examinar a E repite E, y se descarta el bloque completo. DADO la ranura de
WASD de adelante y la de flechas guardadas las dos en H ENTONCES se descarta el bloque completo.
DADO un archivo ilegible ENTONCES las cinco preferencias están en su defecto y las siete acciones
en su entrada de fábrica. En cada caso de descarte, una música guardada en 30 % sigue en 30 %.

### AC-CFG-024 — La tecla de fábrica es la de fábrica *(verifica BR-CFG-024)*

DADO Interactuar asignada a G ENTONCES lo que el contrato de las acciones del jugador atribuye al
clic derecho lo hace G, y el clic derecho no lo hace. DADO Pausa asignada a P ENTONCES lo que
`BR-SAV-016` atribuye a Esc lo hace P.

### AC-CFG-025 — El esquema de fábrica del joystick *(verifica BR-CFG-025)*

DADO ninguna asignación guardada ENTONCES Agarrar / Soltar está en X, Interactuar en R1, Agacharse
en L1, Abrir la interfaz del celular en CÍRCULO y Examinar en CUADRADO, y cada acción conserva su
tecla o clic de fábrica. DADO Movimiento o Pausa ENTONCES ninguna tiene botón de joystick que se
pueda reasignar.

### AC-CFG-026 — La pantalla de controles reasigna el joystick *(verifica BR-CFG-026)*

DADO la pantalla de controles ENTONCES muestra cinco renglones de botón, cada uno con el suyo, y
los dos joysticks, que no se pueden elegir para reasignar. DADO Examinar en CUADRADO CUANDO se
elige su botón y se aprieta L1 ENTONCES Examinar queda en L1, Agacharse en CUADRADO, y las teclas
de las dos no cambian. DADO Examinar eligiendo su botón CUANDO se aprieta una tecla o un clic
ENTONCES no cambia nada; DADO Examinar eligiendo su tecla CUANDO se aprieta un botón de joystick
ENTONCES no cambia nada. DADO esperando un botón CUANDO se aprieta START o Esc ENTONCES la espera
se cancela y no cambia nada; CUANDO se aprieta un gatillo analógico ENTONCES no cambia nada. DADO
Examinar en L1 CUANDO llega L1 con algo al alcance ENTONCES la mano lo examina y CUADRADO ya no.

### AC-CFG-027 — Cruceta y joystick derecho eligen, y X aprieta *(verifica BR-CFG-027)*

DADO Configuraciones abierta CUANDO se aprieta abajo en la cruceta ENTONCES el foco pasa al
renglón siguiente; CUANDO se inclina el joystick derecho hacia arriba, al anterior. DADO el foco
en la barra de efectos al 50 % CUANDO se aprieta a la derecha ENTONCES sube un paso, y a la
izquierda baja un paso. DADO el foco en el renglón de lenguaje, con los botones deshabilitados,
CUANDO se aprieta a la derecha ENTONCES no cambia nada. DADO la planilla de ventas con una fila
elegida CUANDO se aprieta a los costados ENTONCES suma o resta una unidad. DADO el foco en un botón
CUANDO se aprieta X ENTONCES se aprieta; si está deshabilitado, no pasa nada. DADO una interfaz
abierta y el joystick derecho a fondo ENTONCES la vista no gira.

### AC-CFG-028 — Cada interfaz deja el foco *(verifica BR-CFG-028)*

DADO cada interfaz de la lista, CUANDO se abre ENTONCES el foco está en un control habilitado, y
CUANDO se aprieta abajo en la cruceta ENTONCES el foco se mueve o queda en el último renglón.

### AC-CFG-029 — Los gestos del botón izquierdo con el joystick *(verifica BR-CFG-029)*

DADO un diálogo en pantalla CUANDO se aprieta X ENTONCES avanza, igual que el clic izquierdo. DADO
un comprador en la ventanilla CUANDO se aprieta X ENTONCES se lo pulsa; con Agarrar / Soltar
reasignada a L1, L1 lo pulsa y X no. DADO un objeto examinado CUANDO se inclina el joystick
derecho hacia la derecha ENTONCES el objeto gira, y a inclinación cero no gira. DADO una nota
encuadrada abierta con un botón con el foco CUANDO se aprieta X ENTONCES la nota sigue abierta y
el botón no se aprieta; CUANDO se aprieta Interactuar ENTONCES la nota se cierra.

### AC-CFG-030 — Los botones del joystick se guardan y se validan *(verifica BR-CFG-030, BR-CFG-022, BR-CFG-023)*

DADO Examinar asignada a L1 CUANDO se lee el archivo del disco ENTONCES guarda el número del botón
de L1 junto a las teclas, sin nombrar ningún evento. DADO eso CUANDO se vuelve al menú y se entra
otra vez ENTONCES sigue en L1. DADO Examinar con un botón ilegible y Agacharse en R1 ENTONCES
Examinar vuelve a CUADRADO y Agacharse conserva R1. DADO Examinar con el botón de START ENTONCES
vuelve a CUADRADO. DADO Examinar y Agacharse guardadas las dos en L1 ENTONCES se descarta el bloque
completo: el joystick y las teclas tienen su entrada de fábrica y una música guardada en 30 % sigue
en 30 %. DADO un archivo sin botones de joystick ENTONCES cada acción tiene su botón de fábrica.

## No objetivos

- Esta capacidad NO ajusta el contraste, ni ofrece otro idioma que el español.
- Esta capacidad NO ofrece una sensibilidad ni una vibración del joystick, NO muestra íconos de los
  botones, NO ofrece un botón que restablezca el esquema de fábrica y NO acepta como entrada mover
  el mouse ni la rueda.
- Esta capacidad NO guarda ni borra la partida: eso es de
  [`save-and-resume`](../save-and-resume/save-and-resume.md).
- Esta capacidad NO decide qué suena ni por qué bus: eso es de
  [`ambience`](../ambience/ambience.md). Sólo regula cuán fuerte sale cada bus.
- Esta capacidad NO ofrece perfiles, ranuras ni preferencias en la nube.

## Contratos

- **Entrada:** el + o el − de una barra, el valor arrastrado, la tecla o el botón elegido para
  una ranura, el archivo de preferencias al arrancar.
- **Salida:** el valor de cada preferencia ya acotado a su rango y a su paso; si el gesto la
  cambió; el volumen de cada bus, el brillo y la escala de la interfaz, el factor de giro y la entrada
  de cada ranura.
- **Falla:** + en el máximo y − en el mínimo contestan que no cambió; un campo faltante, de otro
  tipo o fuera de rango vuelve con su defecto; un archivo ilegible o ausente devuelve todos los
  defectos; una escritura le contesta a quien la pidió si llegó al disco; una asignación a una
  acción o ranura inexistente, o a una entrada que no acepta, contesta que no cambió; un bloque de
  controles roto vuelve entero al esquema de fábrica.

## Señales

- Preferencias cambiadas, una vez por cada gesto que cambia un valor. Un gesto en el tope no la
  emite.
- Controles cambiados, una vez por cada asignación que cambia una ranura. Una asignación igual a la
  que ya había no la emite.
- Configuraciones cerrada.
- Pantalla de controles cerrada.

## Dependencias

- [`ambience`](../ambience/ambience.md) (consume): los cuatro buses que declara.
- [`player-actions`](../player-actions/player-actions.md) (alimenta): el factor de giro de la
  vista. También (consume): sus teclas son las de fábrica, que una asignación reemplaza
  (`BR-CFG-024`).
- [`investigation`](../investigation/investigation.md) (alimenta): el factor de giro de lo que
  se examina.
- [`save-and-resume`](../save-and-resume/save-and-resume.md) (consume): los dos menús desde
  desde donde se abre, y la tecla de Pausa y START para cerrarla; en la web, Esc sigue pausando
  (`BR-CFG-021`). Borrar su guardado no toca las preferencias ni las asignaciones.

## Preguntas abiertas

- **OQ-CFG-002 — ¿Cómo se redondea un tamaño de letra que no da entero?**
  - Por qué sigue abierta: una letra de 36 en 0,8× da 28,8, y el tamaño de letra es entero.
    Ninguna ficha dice si se redondea al más cercano, hacia abajo o hacia arriba.
  - Decide: el dueño del repo.
  - Bloquea: nada de los criterios, que usan tamaños que dan entero. Decide un píxel en los
    tamaños que no.
- **OQ-CFG-004 — ¿Un valor del archivo dentro del rango pero fuera de paso vuelve al defecto o
  al paso más cercano?**
  - Por qué sigue abierta: el dueño decidió qué pasa con un valor fuera de rango —su defecto—,
    pero no con uno como 55 % de efectos, que sólo aparece en un archivo editado a mano.
  - Decide: el dueño del repo.
  - Bloquea: nada de los criterios, que no lo ejercen.
