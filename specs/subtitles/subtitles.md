---
schema_version: 1
capability_id: CAP-SUB
status: ratified
owner: por definir
provenance: fichas «Subtítulos», «5. Formas de interacción con objetos», «Interfaces virtuales durante la jornada» y «8. Tarea: Reposición»; columnas «Subtítulo al examinar» de las bases «Productos y cajas contenedoras» y «Otros objetos interactuables»; decisiones de #376; exención de bolsa, producto vencido, ticket y pista de #516; cuartito de limpieza de #541; texto provisorio del depósito trabado de #574; útiles fuera del contenedor de #552, ficha «Subtítulos» revisada el 2026-10-21; subtítulos de las manchas de #457, ficha «Limpieza» revisada el 2026-10-20
---

# Capacidad: los subtítulos

## Propósito

Decir con una línea de texto qué piensa el protagonista de lo que mira o de lo que lleva. Lo
único que tiene que hacer bien es **no costar ni revelar**: el subtítulo nombra el objeto sin
detener al jugador y sin entregar lo que el objeto esconde.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Línea de subtítulo** | la única línea de texto abajo al centro de la pantalla donde se lee lo que piensa el protagonista | leyenda, caption |
| **Subtítulo** | el texto que muestra la línea de subtítulo en un instante | mensaje, aviso |
| **Pensamiento** | un subtítulo temporal: se ve entero un tiempo y después se desvanece | aviso, notificación |
| **Texto al examinar** | lo que dice un objeto cuando se pide examinarlo. Sale de la ficha, no de la revelación | descripción, revelación |
| **Examen** | el de `investigation`: lo que se lleva en la mano, delante de la cámara, hasta pulsar otra vez la tecla de examinar | observación, inspección |
| **Lo fijo** | un objeto interactuable que no se levanta: un artefacto, una puerta, una nota pegada, un mueble | decorado, estático |

## Comportamiento normativo

### BR-SUB-001 — Una sola línea, un subtítulo por vez

El sistema DEBE mostrar los subtítulos en una sola línea de subtítulo, abajo al centro de la
pantalla. CUANDO llega un subtítulo nuevo, el sistema DEBE reemplazar al que se ve. Dos
subtítulos NO DEBEN verse a la vez.

### BR-SUB-002 — Con las manos vacías, la E piensa

CUANDO el jugador pide examinar con las manos vacías y la mira sobre un objeto interactuable con
texto al examinar, el sistema DEBE mostrar ese texto como pensamiento. Vale para un levantable,
para lo fijo y para una caja del depósito apoyada. El gesto NO DEBE arrancar un examen, retener
al jugador, mover el objeto ni cambiar lo que hay en la mano.

### BR-SUB-003 — Sin texto, la línea no cambia

SI no hay nada en la mira, o lo que se mira no tiene texto al examinar, ENTONCES la E con las
manos vacías NO DEBE cambiar la línea de subtítulo. Un pensamiento que ya se ve sigue su curso.

### BR-SUB-004 — Cuánto dura un pensamiento

El sistema DEBE mostrar un pensamiento entero durante `D(n) = máx(2; 1,5 + n / 25)` segundos
reales, con `n` la cantidad de caracteres de su texto. Los espacios y los signos cuentan, y una
letra con tilde cuenta uno. Después DEBE desvanecerlo en 0,5 segundos reales, sin subir nunca
la opacidad. Al llegar a `D(n) + 0,5` segundos, o pasarse, la línea DEBE quedar vacía.

Desde 13 caracteres, un texto más largo dura estrictamente más. Hasta 12, el piso de 2 segundos
iguala a todos.

CUANDO llega otro pensamiento con uno visible, aunque sea el mismo texto, el sistema DEBE
empezarlo entero con su propia duración. Los tiempos NO DEBEN sumarse.

Los dos valores los decidió el diseño como aproximados, y se corrigen con el testing del juego.

### BR-SUB-005 — El examen deja el texto fijo

CUANDO arranca el examen de lo que se lleva, el sistema DEBE mostrar su texto al examinar y
mantenerlo entero mientras dure el examen. El texto NO DEBE desvanecerse, aunque pase más que
el pensamiento más largo. Reemplaza a un pensamiento visible (BR-SUB-001). CUANDO termina el
examen, el sistema DEBE vaciar la línea en ese mismo cuadro.

### BR-SUB-006 — Otra interfaz o la pausa no piensan

MIENTRAS otra interfaz tiene el control —una nota, la computadora, la caja registradora, la
ventanilla, el celular— o la pausa está abierta, la E NO DEBE mostrar un subtítulo. MIENTRAS la
pausa está abierta, el tiempo de un pensamiento NO DEBE correr: reanudar lo retoma donde quedó.

### BR-SUB-007 — La jornada nueva abre con la línea vacía

CUANDO se abre una jornada, el sistema DEBE vaciar la línea de subtítulo. Un pensamiento a
medio desvanecer y el texto fijo de un examen NO DEBEN pasar a la jornada nueva.

### BR-SUB-008 — El subtítulo no es la revelación

El texto al examinar DEBE salir de las tablas de esta capacidad, y NUNCA de la revelación del
objeto. Mostrarlo NO DEBE registrar un hallazgo (BR-INV-001). Lo que revela algo no levantable
sigue su regla (BR-INV-017), y el subtítulo sale igual.

### BR-SUB-009 — Lo que dice cada producto

Cada producto del catálogo DEBE tener un subtítulo asociado a su identidad. Cada unidad DEBE
elegir el subtítulo de su producto. La tabla conserva la redacción de referencia, que es contenido
editable y NO DEBE formar parte de la identidad. Los nombres de productos salen del catálogo.

| Producto del catálogo | Texto al examinar |
|---|---|
| Zucarachas | Una caja de cereal Zucarachas. |
| Frotlups | Una caja de cereal Frot Lups. |
| Coracola | Una lata de Pura-Cola. |
| Marranos | Una lata de atún Marranos. |
| Arvejas | Una lata de arvejas Arvecor. |
| Mayonchis | Un paquete de Mayonchis. |
| Jorgillo | Un alfajor Jorgillo. |
| Marolini | Una caja de fideos Marolini. |
| Uakas | Una caja de fideos Uakalas. |
| Saladik | Una caja de Saladick. |
| Pepitos | Una caja de galletitas Pepito. |
| Oremos | Una caja de galletitas Oremos. |
| Donsaturados | Un paquete de Don Saturados. |
| Petisas | Un paquete de galletitas Petisas. |
| Macumbas | Un paquete de galletitas Macumbas. |
| Prongles | Un tubo de papitas Progres. |
| Laysntt | Un paquete de papitas Laysnnt. |
| Chisitos | Un paquete de Chisitos. |
| Durextra | Una caja de preservativos Durextra. |
| Duronga | Una caja de preservativos Duronga. |
| Actroncito | Una caja de medicamentos Actroncito. |
| Burbaloo | Una caja de chicles Burbaloo. |
| Flinpuf | Una caja de caramelos Flim Pof. |
| Malbardo | Un paquete de cigarrillos Malbardo. |
| Amargadito | Una caja de yerba Amargadito. |
| Cindolor | Una caja de chocolatada Cindolor. |
| Cosa de Maní | Una barra de Cosa de Maní. |
| Feel Ricky Fort | Una caja de barritas Feel Ricky Fort. |
| Fernet God | Una botella de Fernet God. |
| Oaaaa | Una caja de jugo Oaaaa. |
| Terminator | Una caja de vino Terminator. |

### BR-SUB-010 — Lo que dicen los útiles, las bolsas y lo fijo

Cada objeto de la tabla DEBE elegir su subtítulo por identidad, con texto no vacío. La redacción
es contenido editable, como en BR-SUB-009. Todas las instancias
de un mismo objeto DEBEN decir el mismo texto: los dos inodoros, los dos lavatorios, cada nota
con el mismo contenido, y el cuerpo y la tapa del contenedor.

| Objeto | Texto al examinar |
|---|---|
| Mopa | Una mopa para limpiar las manchas del local. |
| Balde | Un balde para hacer las mezclas con los jabones. |
| Jabón azul | Un bidón de jabón azul, marca “2”. Sirve para manchas de humedad. |
| Jabón rosa | Un bidón de jabón rosa, marca “H”. Sirve para manchas de... para manchas marrones. |
| Jabón amarillo | Un bidón de jabón amarillo, marca “O”. Sirve para manchas de polvo. |
| Cada bolsa de basura | Una bolsa de basura. |
| Inodoro | Un inodoro. Enrique me pidió encarecidamente que no tire papel en él, porque se tapa. |
| Lavatorio | Un lavatorio. Acá puedo cargar el balde. |
| Nota de jabones y manchas | Una nota explicando qué jabón usar para cada tipo de mancha. |
| Nota de instrucciones de limpieza | Una nota que explica cómo usar los elementos de limpieza. |
| Nota de no tirar papel | “Por favor, no tirar papel en el inodoro” |
| Nota de tareas a realizar | Una lista de las tareas que me dejó Enrique. |
| Nota del local ordenado | Una nota sobre el correcto orden del local. Enrique es medio insoportable con eso… |
| Computadora | Una computadora viejita. El único programa que tiene es el registro de productos vendidos. |
| Caja registradora | La caja registradora. Acá puedo hacer los tickets para los compradores. |
| Lector | El lector de código de barras. Si le paso un producto, lo va a anotar en el programa generador de tickets de la caja. |
| Entrada principal | La entrada principal al local. Queda cerrada con llave durante el turno nocturno. |
| Puerta del jefe | Esta puerta lleva a la “oficina” de Enrique. Así le dice él. Siempre está cerrada. |
| Puerta del cuartito, trabada | Acá guardan las cosas de limpieza. Está cerrado con llave. |
| Portón del depósito | Un portón que da a la calle. |
| Contenedor de basura | Un contenedor de basura. |
| Tacho del local | Un tacho de basura para los compradores diurnos. |
| Tacho del escritorio | Un tachito de basura para nosotros, los empleados. |
| Tacho del baño | El tacho de basura del baño. Mejor ni mirar lo que tiene adentro. |

Las puertas interiores, las puertas de las heladeras, la ventanilla, el comprador, la góndola y
las manchas NO DEBEN tener texto al examinar. La excepción es la puerta del
cuartito mientras está trabada (BR-PLY-020 de
[`player-actions`](../player-actions/player-actions.md)): DEBE decir su texto en las
jornadas que la traban, y callar en las demás.

Un tacho DEBE decir su texto con bolsa o sin bolsa. Examinarlo NO DEBE retirar ni cambiar su
bolsa.

### BR-SUB-011 — El ticket dice qué tiene

El subtítulo del ticket DEBE presentar cada producto con su cantidad y su nombre del catálogo.
Los productos DEBEN ir en el orden en que aparecen por primera vez en los renglones. La redacción
actual usa «Un ticket de compra por », separa con «, » y antepone « y » al último de varios productos.

El ticket DEBE conservar su identidad y un resumen ordenado de identidades de producto y cantidades.
La redacción que presenta ese resumen es editable; cambiarla NO DEBE cambiar el resumen ni su orden.

### BR-SUB-012 — La caja dice cuántas tiene, apoyada o en la mano

El texto al examinar de una caja del depósito DEBE ser el de BR-STK-031, con la caja apoyada y
con la caja en la mano. Con la caja apoyada es un pensamiento (BR-SUB-002); en la mano queda
fijo durante el examen (BR-SUB-005).

### BR-SUB-015 — Alejarse acorta el pensamiento

Sólo un pensamiento asociado a un objeto y el texto de una entrega del comprador (BR-CTR-050)
DEBEN tener un lugar: el del objeto examinado con las manos vacías, o el de la figura del
comprador en la ventanilla en el momento de decir el texto. MIENTRAS el jugador sigue a menos de
0,75 metros más lejos de ese lugar que cuando apareció el texto, éste DEBE durar lo de
BR-SUB-004. Un aviso de una acción o del estado del jugador NO DEBE tener anclaje espacial, y
DEBE durar siempre lo de BR-SUB-004 aunque el jugador camine. Esto incluye los gestos de
BR-SUB-013 y la mopa que se seca de BR-SUB-014. CUANDO el texto tiene un lugar y el jugador
se aleja más que eso, DEBE empezar a desvanecerse en ese momento, en los mismos 0,5 segundos,
salvo que ya se estuviera desvanecido. Volver a acercarse NO DEBE devolverle la opacidad. El
texto fijo del examen NO DEBE acortarse. Un texto nuevo DEBE medir desde su propio lugar y desde
la distancia a la que el jugador estaba al decirlo, también si ya estaba lejos. El lugar de una
entrega NO DEBE moverse si el comprador se va con el texto visible, y un aviso o un pensamiento
que la reemplaza NO DEBE heredar su lugar.

### BR-SUB-013 — Los gestos que salen mal piensan

CUANDO un gesto da uno de estos resultados, el sistema DEBE mostrar su pensamiento (BR-SUB-002),
identificado por un ID estable. Ninguno cambia el resultado del gesto. La redacción de la tabla
es contenido editable: cambiarla NO DEBE cambiar la identidad ni la condición que elige el pensamiento.

| Gesto | ID | Pensamiento |
|---|---|---|
| Tirar al contenedor algo que no es una bolsa de basura, un producto vencido, un ticket ni una pista | `MALA_IDEA` | Me parece que eso fue una mala idea… |
| Tirar al contenedor una caja del depósito, que no entra | `CAJA_EN_EL_CONTENEDOR` | La caja es bastante grande para el contenedor. Rebalsaría. Además, Enrique me pidió que no tire las cajas de productos, ni siquiera las vacías. |
| Tirar al contenedor un útil de limpieza —la mopa, el balde o un jabón—, que no entra | `UTIL_EN_EL_CONTENEDOR` | Me parece que no debería tirar<br>los elementos de limpieza. |
| Soltar algo que no es un ticket y que queda quieto fuera del local, el depósito y el baño | `POR_LA_VENTANA` | Si Enrique se entera de que estoy tirando cosas por la ventana, me mata. |
| Pasar por una mancha la mopa mojada con el jabón que no es el suyo | `JABON_EQUIVOCADO` | Esto no está funcionando… Creo que no estoy usando el jabón correcto. |
| Pasar por una mancha la mopa mojada con agua sola | `MOPA_SIN_MOJAR` | Necesitaría mojar la mopa en agua con jabón. |
| Pasar por una mancha la mopa seca, sin haberla mojado en esa jornada | `MOPA_SIN_MOJAR` | Necesitaría mojar la mopa en agua con jabón. |
| Pasar por una mancha la mopa seca, después de haberla mojado en esa jornada | `MOPA_YA_SECA` | Ya se secó la mopa… |
| Borrar la caca de la pared del otro inodoro | `PARED_DEL_OTRO_INODORO` | Se ve que alguien no tuvo tiempo de apuntar bien… |
| Borrar la caca del piso frente a las estanterías del fondo del local, en la jornada 5 | `PISO_DE_LAS_ESTANTERIAS_DEL_FONDO` | Espero que sea vómito… |
| Borrar la caca del techo del baño, en la jornada 6 | `TECHO_SOBRE_UN_CUBICULO` | ¿¿Cómo llegó eso ahí?? |
| Usar la puerta de entrada del local en una jornada de prueba, con alguna obligatoria pendiente | `PUERTA_CON_TAREAS_PENDIENTES` | No debería irme. Todavía me quedan tareas por completar. |

El `<br>` de la tabla es un salto de línea del subtítulo, tal como lo marca la ficha.

`CAJA_EN_EL_CONTENEDOR` y `UTIL_EN_EL_CONTENEDOR` DEBEN decidirse por lo que se intenta tirar y no
por la tapa: con la tapa cerrada o girando piensan lo mismo que con la tapa abierta. Poético, aun en
la jornada en que sustituye al jabón azul, es un producto y piensa `MALA_IDEA`, no el del útil.
Tirar una bolsa, un producto vencido, un ticket o una pista, borrar cualquier otra mancha, o
pasar la mopa por una mancha ya limpia NO DEBE pensar nada. Pasar la mopa con el jabón equivocado por la caca de la pared piensa
el texto del jabón, no el de la caca.

`PUERTA_CON_TAREAS_PENDIENTES` DEBE decidirse por el cumplimiento de las obligatorias en el
instante de usar la puerta (BR-SHF-024), y no por si el aviso de salida ya se mostró o sigue
esperando (BR-NTF-014): SI todas están cumplidas, ENTONCES NO DEBE pensar nada, aunque el aviso
espere. Una obligatoria que se descumple después de habilitada la salida DEBE devolver el
pensamiento. Desde la primera jornada completa NO DEBE pensarlo. La puerta conserva su sonido de
trabada, y examinarla con E conserva su texto (BR-SUB-010).

Los pensamientos de la mopa de esta tabla DEBEN aparecer sólo al intentar limpiar una mancha.
Mojarla, transportarla o dejar marcas de agua NO DEBE dispararlos. SI se secó después de mojarla
sólo con agua, ENTONCES al intentar limpiar DEBE decir «Ya se secó la mopa…».

### BR-SUB-014 — La primera vez que se seca la mopa

CUANDO la carga de la mopa pasa de más de cero a cero por primera vez en la partida, el sistema
DEBE mostrar el pensamiento `MOPA_BERRETA`, cuyo texto actual es
«Dios mío, qué mopa berreta. Se seca a los tres segundos. Literal.». Las veces
siguientes, en esa jornada o en otra, NO DEBE mostrarlo. Una partida nueva lo vuelve a mostrar
una vez. SI se seca durante un examen, ENTONCES el texto fijo del examen DEBE seguir, y el
pensamiento DEBE mostrarse entero al terminar el examen. Recién al mostrarse cuenta como
mostrado: si la jornada cierra antes, la vez siguiente se muestra. Secarse otra vez con el
pensamiento pendiente NO DEBE duplicarlo.

La frase de los tres segundos expresa una queja del protagonista; NO DEBE fijar una duración
exacta ni modificar el desgaste por tiempo y recorrido de
[`store-cleanup`](../store-cleanup/store-cleanup.md) (BR-CLN-022).

## Criterios de aceptación

### AC-SUB-001 — Abajo al centro, y uno por vez *(verifica BR-SUB-001)*

DADO el HUD a 1920×1080 y a 1280×720 CUANDO se muestra un pensamiento ENTONCES el centro
horizontal de la línea coincide con el del encuadre y su centro vertical está en la mitad
inferior. DADO el pensamiento «Una bolsa de basura.» visible CUANDO llega «Un alfajor
Jorgillo.» ENTONCES la línea muestra sólo «Un alfajor Jorgillo.».

### AC-SUB-002 — La E con las manos vacías piensa *(verifica BR-SUB-002)*

DADO las manos vacías CUANDO se pide examinar con la mira, por turno, sobre la mopa, sobre un
inodoro y sobre una caja del depósito apoyada con 8 de Actroncito ENTONCES la línea muestra,
respectivamente, «Una mopa para limpiar las manchas del local.», «Un inodoro. Enrique me pidió
encarecidamente que no tire papel en él, porque se tapa.» y «Una caja con 8 cajitas de
Actroncito.». En los tres casos no hay examen, el jugador no queda retenido, el objeto sigue en
su lugar, las manos siguen vacías, y no se avisa que empezó ni que terminó un examen.

### AC-SUB-003 — Sin texto, nada *(verifica BR-SUB-003)*

DADO la línea vacía y las manos vacías CUANDO se pide examinar con la mira sobre una puerta de
heladera, y por separado sin nada en la mira, ENTONCES la línea sigue vacía. DADO el pensamiento
«Una bolsa de basura.» con 1 segundo transcurrido CUANDO se pide examinar sobre la ventanilla
ENTONCES el texto sigue igual y la línea se vacía a los 2,8 segundos del primer gesto.

### AC-SUB-004 — La duración según el largo *(verifica BR-SUB-004)*

DADO un pensamiento de `n` caracteres CUANDO se calcula cuánto se ve entero ENTONCES, con una
tolerancia de 0,001 segundos:

| `n` | Ejemplo | Entero | Vacía a los |
|---|---|---|---|
| 1 | «a» | 2,000 | 2,500 |
| 12 | 12 caracteres | 2,000 | 2,500 |
| 13 | 13 caracteres | 2,020 | 2,520 |
| 15 | 15 caracteres | 2,100 | 2,600 |
| 20 | 20 caracteres de prueba | 2,300 | 2,800 |
| 26 | 26 caracteres de prueba | 2,540 | 3,040 |
| 117 | 117 caracteres de prueba | 6,180 | 6,680 |

La muestra de 117 caracteres dura estrictamente más que la de 20. Las muestras de duración
son artificiales: editar los textos del juego NO DEBE cambiar los valores de estos casos.

### AC-SUB-005 — Entero, desvanecido y vacío *(verifica BR-SUB-004)*

DADO el pensamiento «Una bolsa de basura.» CUANDO avanzan 2,29 segundos ENTONCES se ve el texto
con opacidad 1. CUANDO avanzan 2,55 segundos ENTONCES la opacidad está estrictamente entre 0 y
1, y no es mayor que a los 2,4. CUANDO avanzan exactamente 2,8 ENTONCES la línea está vacía
con opacidad 0. DADO el mismo pensamiento CUANDO avanza de una vez 10 segundos ENTONCES la línea
está vacía. Un avance de cero o negativo no cambia nada.

### AC-SUB-006 — Repetir empieza de nuevo *(verifica BR-SUB-004)*

DADO el pensamiento «Una bolsa de basura.» con 2 segundos transcurridos CUANDO se pide examinar
la misma bolsa otra vez ENTONCES la opacidad es 1, a los 2,29 segundos del segundo gesto sigue
con opacidad 1, y la línea se vacía a los 2,8 segundos del segundo gesto.

### AC-SUB-007 — El examen lo deja fijo *(verifica BR-SUB-005, BR-SUB-001)*

DADO el pensamiento «Una bolsa de basura.» visible y la mopa en la mano CUANDO se pide examinar
ENTONCES arranca el examen y la línea muestra «Una mopa para limpiar las manchas del local.» con
opacidad 1. CUANDO pasan 60 segundos de examen ENTONCES sigue igual. CUANDO termina el examen
ENTONCES la línea está vacía en ese mismo cuadro.

DADO un objeto soltado que queda quieto afuera mientras se examina otro CUANDO corresponde su
pensamiento de la ventana ENTONCES el texto fijo del examen se conserva. CUANDO termina el
examen ENTONCES se muestra el pensamiento pendiente; si la jornada cerró antes, se descarta.

### AC-SUB-008 — Otra interfaz y la pausa *(verifica BR-SUB-006)*

DADO las manos vacías y la mira sobre un inodoro CUANDO se pide examinar con la computadora
abierta, y por separado con la pausa abierta, ENTONCES la línea no cambia. DADO el pensamiento
«Una bolsa de basura.» con 1 segundo transcurrido CUANDO se pausa, pasan 10 segundos reales y se
reanuda ENTONCES se ve con opacidad 1, y la línea se vacía a los 1,8 segundos sin pausa
después de reanudar.

### AC-SUB-009 — La jornada abre vacía *(verifica BR-SUB-007)*

DADO un pensamiento a medio desvanecer, y por separado un examen en curso con su texto fijo,
CUANDO se abre una jornada ENTONCES la línea está vacía.

### AC-SUB-010 — La revelación no sale *(verifica BR-SUB-008)*

DADO la mopa con una revelación y las manos vacías CUANDO se pide examinar ENTONCES la línea
muestra «Una mopa para limpiar las manchas del local.», ningún texto de la revelación, y la
cuenta de hallazgos sigue en 0. DADO algo no levantable con revelación y texto al examinar
CUANDO se pide examinar ENTONCES la línea muestra su texto al examinar y lo revelado se publica
como en AC-INV-019.

### AC-SUB-011 — Cada producto dice su texto *(verifica BR-SUB-009)*

DADO cada producto del catálogo CUANDO se pide su texto al examinar ENTONCES es el asociado a
su identidad. Una unidad elige el mismo subtítulo que su producto. Una identidad sin texto hace
fallar el caso; editar la redacción conservando la identidad no cambia la selección.

### AC-SUB-012 — Cada útil y cada bolsa *(verifica BR-SUB-010)*

DADO la mopa, el balde, los tres jabones y las tres bolsas de basura CUANDO se pide su texto al
examinar ENTONCES cada uno conserva su identidad y devuelve el subtítulo no vacío asociado a ella.

### AC-SUB-013 — Lo fijo dice su texto, y lo demás calla *(verifica BR-SUB-010)*

DADO los dos inodoros, los dos lavatorios, las cinco notas, la computadora, la caja
registradora, el lector, la entrada principal, la puerta del jefe, el portón del depósito, los
tres tachos y el cuerpo y la tapa del contenedor CUANDO se pide su texto al examinar ENTONCES
cada uno devuelve el subtítulo asociado a su identidad. DADO una puerta interior sin traba, una puerta
de heladera, la ventanilla, el comprador, la góndola y una mancha ENTONCES no tienen texto. DADO
un tacho con bolsa y otro sin bolsa CUANDO se pide examinar con las manos vacías ENTONCES los
dos muestran su texto y el primero sigue con su bolsa.

### AC-SUB-022 — La puerta del cuartito habla sólo trabada *(verifica BR-SUB-010)*

DADO la jornada 1 abierta CUANDO se pide examinar la puerta del cuartito con las manos
vacías ENTONCES piensa el subtítulo asociado a la puerta del cuartito trabada. DADO la jornada 2
abierta ENTONCES examinarla no muestra texto y la línea no
cambia. DADO una partida guardada en la 1 CUANDO se retoma ENTONCES vuelve a tener texto.

### AC-SUB-014 — El texto del ticket *(verifica BR-SUB-011)*

DADO un ticket con estos renglones CUANDO se consulta su resumen al examinar ENTONCES conserva
las identidades de producto, cantidades y orden siguientes. Su subtítulo presenta ese resumen.

| Renglones | Resumen ordenado |
|---|---|
| Marolini | Marolini: 1 |
| Marolini, Marolini, Coracola | Marolini: 2; Coracola: 1 |
| Marolini, Coracola, Malbardo | Marolini: 1; Coracola: 1; Malbardo: 1 |
| Malbardo, Malbardo, Malbardo | Malbardo: 3 |
| Coracola, Marolini, Coracola | Coracola: 2; Marolini: 1 |
| Sin renglones | Resumen vacío |

### AC-SUB-015 — La caja apoyada y en la mano *(verifica BR-SUB-012)*

DADO una caja del depósito apoyada con 0 de Actroncito y las manos vacías CUANDO se pide
examinar ENTONCES la línea muestra el subtítulo de esa caja, con 0 unidades y 8 lugares libres, como
pensamiento, sin examen. DADO una caja con 5 de Malbardo en la mano CUANDO se pide examinar
ENTONCES la línea muestra el subtítulo de esa caja, con 5 unidades y 3 lugares libres, fijo hasta que
termina el examen.

### AC-SUB-020 — Irse lo desvanece antes *(verifica BR-SUB-015)*

DADO el pensamiento «Una bolsa de basura.» CUANDO el jugador se aleja 0,7 metros y avanzan 2,29
segundos ENTONCES se ve con opacidad 1. CUANDO se aleja 0,8 metros ENTONCES a los 0,25 segundos
la opacidad está estrictamente entre 0 y 1, y a los 0,5 la línea está vacía. CUANDO vuelve a
acercarse durante el desvanecido ENTONCES la opacidad no sube. DADO un texto fijo CUANDO el
jugador se aleja 10 metros ENTONCES sigue entero.

DADO el pensamiento `MOPA_YA_SECA` o `MALA_IDEA` CUANDO el jugador
camina 5 metros y transcurre 1 segundo desde que apareció ENTONCES sigue con opacidad 1.

### AC-SUB-026 — Irse de la ventanilla acorta la entrega *(verifica BR-SUB-015)*

DADO el texto de una entrega del comprador y el jugador a 1 metro de su figura CUANDO el jugador se
aleja 0,7 metros y avanzan 2,29 segundos ENTONCES se ve con opacidad 1. CUANDO se aleja 0,8
metros ENTONCES a los 0,25 segundos la opacidad está estrictamente entre 0 y 1, y a los 0,5 la
línea está vacía. CUANDO vuelve a acercarse durante el desvanecido ENTONCES la opacidad no sube.
DADO el jugador a 6 metros de la figura al decir la entrega CUANDO se aleja 0,7 metros ENTONCES
sigue entero. DADO ese texto visible CUANDO el comprador se retira y el jugador se aleja 0,8
metros ENTONCES empieza a desvanecerse. DADO ese texto visible CUANDO llega un pensamiento de la
mopa ya seca y el jugador camina 5 metros ENTONCES el pensamiento sigue con opacidad 1.

### AC-SUB-016 — Lo que se tira *(verifica BR-SUB-013)*

DADO una unidad tirada al contenedor, también una de Poético en la jornada en que sustituye al
jabón azul, ENTONCES el pensamiento es `MALA_IDEA`.
DADO una bolsa, un ticket, una pista o una unidad vencida tirados ENTONCES no hay pensamiento.
DADO una caja del depósito que no entra ENTONCES el pensamiento es `CAJA_EN_EL_CONTENEDOR`; DADO la mano vacía o la tapa cerrada
con algo que entra ENTONCES no hay texto.

### AC-SUB-025 — Los útiles y las cajas que no entran *(verifica BR-SUB-013)*

DADO, por turno, el balde, la mopa y cada uno de los tres jabones sostenidos CUANDO se intenta
tirarlos con la tapa abierta y, por separado, cerrada ENTONCES el pensamiento es
`UTIL_EN_EL_CONTENEDOR`, y nunca `MALA_IDEA` ni `CAJA_EN_EL_CONTENEDOR`. DADO una caja del
depósito con la tapa abierta y con la tapa cerrada ENTONCES el pensamiento sigue siendo
`CAJA_EN_EL_CONTENEDOR`. DADO el intento rechazado ENTONCES el útil sigue en la mano y no hay
llamado. DADO la mano vacía ENTONCES no hay pensamiento.

### AC-SUB-017 — Lo que queda afuera *(verifica BR-SUB-013)*

DADO una unidad o una bolsa soltadas que quedan quietas fuera de las tres habitaciones ENTONCES
el pensamiento es `POR_LA_VENTANA`. DADO un ticket ENTONCES no hay pensamiento.

### AC-SUB-018 — La mopa sobre una mancha *(verifica BR-SUB-013)*

DADO el resultado del jabón equivocado ENTONCES el pensamiento es `JABON_EQUIVOCADO`.
DADO la mopa mojada con agua sola CUANDO se intenta limpiar una mancha ENTONCES el pensamiento
es `MOPA_SIN_MOJAR` y la mancha permanece.
DADO la mopa seca sin haberse mojado en la jornada ENTONCES el pensamiento es `MOPA_SIN_MOJAR`;
DADO la mopa seca después de mojarla, incluso sólo con agua, ENTONCES es `MOPA_YA_SECA`.
DADO una mancha ya limpia o una mancha
borrada ENTONCES no hay texto, salvo la caca de la pared del otro inodoro, la del piso frente a
las estanterías del fondo y la del techo del baño, que al borrarse piensan cada una el suyo. Las
demás manchas de las jornadas 5 a 7, aunque sean de caca, no piensan nada.

### AC-SUB-019 — La mopa berreta, una vez *(verifica BR-SUB-014)*

DADO una partida sin la marca CUANDO la mopa se seca ENTONCES se muestra `MOPA_BERRETA` y la partida
queda marcada; CUANDO se seca otra vez ENTONCES no. DADO un examen en curso CUANDO la mopa se
seca ENTONCES no se muestra; CUANDO se seca de nuevo ENTONCES sigue habiendo uno solo pendiente;
CUANDO termina el examen ENTONCES se muestra y recién ahí la partida queda marcada. DADO el
pensamiento pendiente CUANDO cierra la jornada ENTONCES se descarta y la partida sigue sin marca.

### AC-SUB-024 — La puerta de entrada con tareas pendientes *(verifica BR-SUB-013, BR-SUB-001)*

DADA cada una de las dos jornadas de prueba con alguna obligatoria pendiente CUANDO se usa la
puerta de entrada ENTONCES el pensamiento es `PUERTA_CON_TAREAS_PENDIENTES` y la puerta no se
abre. DADO ese pensamiento visible CUANDO se usa la puerta otra vez ENTONCES la línea sigue
mostrando sólo ese texto, una vez, y empieza de nuevo.
DADAS todas las obligatorias cumplidas, y el aviso de salida demorado por la computadora abierta,
CUANDO se usa la puerta ENTONCES no hay pensamiento y la noche termina. DADAS todas cumplidas y
después una descumplida CUANDO se usa la puerta ENTONCES el pensamiento vuelve. DADA la primera
jornada completa con obligatorias pendientes CUANDO se usa la puerta ENTONCES no hay pensamiento.
DADA la puerta de entrada en una jornada de prueba con una pendiente CUANDO se la examina con E
ENTONCES dice su texto fijo (BR-SUB-010).

## No objetivos

- Esta capacidad NO decide qué esconde un objeto ni registra hallazgos: eso es de
  [`investigation`](../investigation/investigation.md).
- Esta capacidad NO arranca ni termina el examen, ni decide qué se enfoca o qué se lleva: lo
  recibe.
- Esta capacidad NO cuenta lo que tiene una caja ni nombra sus unidades: el texto de la caja es
  de [`store-stock`](../store-stock/store-stock.md).
- Esta capacidad NO cambia el nombre de ningún producto del catálogo.

## Contratos

- **Entrada:** el pedido de examinar, lo que hay en la mira y lo que se lleva en la mano, si
  otra interfaz tiene el control, el comienzo y el fin de un examen, la pausa, la jornada que
  se abre y los segundos reales de cada cuadro.
- **Salida:** el texto de la línea de subtítulo y su opacidad, entre 0 y 1. Sin subtítulo, el
  texto es vacío y la opacidad 0.
- **Falla:** un texto vacío no cambia la línea; un objeto sin texto, la mira vacía, otra
  interfaz al control o la pausa no cambian la línea; un avance de tiempo de cero o negativo no
  cambia nada.

## Señales

- El pedido de un pensamiento, con su texto, cuando la E con las manos vacías encuentra un
  objeto con texto. Un gesto sin texto no emite nada.

## Dependencias

- [`investigation`](../investigation/investigation.md) (consume): cuándo arranca y termina el
  examen de lo que se lleva, y que el subtítulo no es la revelación.
- [`player-actions`](../player-actions/player-actions.md) (consume): qué hay en la mira, qué se
  lleva en la mano y si otra interfaz tiene el control.
- [`store-stock`](../store-stock/store-stock.md) (consume): el texto de la caja del depósito y
  el nombre de cada producto del catálogo.
- [`counter-service`](../counter-service/counter-service.md) (consume): los productos del
  ticket, en el orden de sus renglones.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (consume): la jornada que se abre y la pausa.

## Preguntas abiertas

- **OQ-SUB-001 — ¿Qué muestra el examen de un levantable sin texto al examinar?**
  - Por qué sigue abierta: la ficha da texto a cada levantable que el juego pone en el local
    —productos, útiles, bolsas, tickets y cajas—, pero no dice qué pasa si aparece uno sin
    texto. Mientras tanto, la regla no le inventa un texto.
  - Decide: el diseño, en la ficha «Subtítulos».
  - Bloquea: nada hoy; condiciona el primer levantable nuevo sin fila en la ficha.
