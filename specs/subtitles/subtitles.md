---
schema_version: 1
capability_id: CAP-SUB
status: draft
owner: por definir
provenance: fichas «Subtítulos», «5. Formas de interacción con objetos», «Interfaces virtuales durante la jornada» y «8. Tarea: Reposición»; columnas «Subtítulo al examinar» de las bases «Productos y cajas contenedoras» y «Otros objetos interactuables»; decisiones de #376
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

El sistema DEBE mostrar un pensamiento entero durante `D(n) = máx(2; 1,5 + n / 15)` segundos
reales, con `n` la cantidad de caracteres de su texto. Los espacios y los signos cuentan, y una
letra con tilde cuenta uno. Después DEBE desvanecerlo en 0,5 segundos reales, sin subir nunca
la opacidad. Al llegar a `D(n) + 0,5` segundos, o pasarse, la línea DEBE quedar vacía.

Desde 8 caracteres, un texto más largo dura estrictamente más. Hasta 7, el piso de 2 segundos
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

Cada producto del catálogo DEBE tener su texto al examinar, letra por letra como en la tabla.
Lo dice cada unidad del producto. El nombre adentro del texto se copia de la ficha, aunque
difiera del nombre del catálogo.

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

Cada objeto de la tabla DEBE decir su texto al examinar, letra por letra. Todas las instancias
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
| Portón del depósito | Un portón que da a la calle. |
| Contenedor de basura | Un contenedor de basura. |
| Tacho del local | Un tacho de basura para los compradores diurnos. |
| Tacho del escritorio | Un tachito de basura para nosotros, los empleados. |
| Tacho del baño | El tacho de basura del baño. Mejor ni mirar lo que tiene adentro. |

Las puertas interiores, las puertas de las heladeras, la ventanilla, el comprador, la góndola y
las manchas NO DEBEN tener texto al examinar.

Un tacho DEBE decir su texto con bolsa o sin bolsa. Examinarlo NO DEBE retirar ni cambiar su
bolsa.

### BR-SUB-011 — El ticket dice qué tiene

El texto al examinar de un ticket DEBE ser «Un ticket de compra por » seguido de cada producto
del ticket con su cantidad y su nombre del catálogo. Los productos DEBEN ir en el orden en que
aparecen por primera vez en los renglones. Se separan con «, », y el último con « y ». Con un
solo producto no va « y ».

### BR-SUB-012 — La caja dice cuántas tiene, apoyada o en la mano

El texto al examinar de una caja del depósito DEBE ser el de BR-STK-031, con la caja apoyada y
con la caja en la mano. Con la caja apoyada es un pensamiento (BR-SUB-002); en la mano queda
fijo durante el examen (BR-SUB-005).

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
ENTONCES el texto sigue igual y la línea se vacía a los 10/3 segundos del primer gesto.

### AC-SUB-004 — La duración según el largo *(verifica BR-SUB-004)*

DADO un pensamiento de `n` caracteres CUANDO se calcula cuánto se ve entero ENTONCES, con una
tolerancia de 0,001 segundos:

| `n` | Ejemplo | Entero | Vacía a los |
|---|---|---|---|
| 1 | «a» | 2,000 | 2,500 |
| 7 | 7 caracteres | 2,000 | 2,500 |
| 8 | 8 caracteres | 2,033 | 2,533 |
| 15 | 15 caracteres | 2,500 | 3,000 |
| 20 | «Una bolsa de basura.» | 2,833 | 3,333 |
| 26 | «Una barra de Cosa de Maní.» | 3,233 | 3,733 |
| 117 | el texto del lector | 9,300 | 9,800 |

El texto del lector dura estrictamente más que «Una bolsa de basura.».

### AC-SUB-005 — Entero, desvanecido y vacío *(verifica BR-SUB-004)*

DADO el pensamiento «Una bolsa de basura.» CUANDO avanzan 2,82 segundos ENTONCES se ve el texto
con opacidad 1. CUANDO avanzan 3,083 segundos ENTONCES la opacidad está estrictamente entre 0 y
1, y no es mayor que a los 2,95. CUANDO avanzan exactamente 10/3 ENTONCES la línea está vacía
con opacidad 0. DADO el mismo pensamiento CUANDO avanza de una vez 10 segundos ENTONCES la línea
está vacía. Un avance de cero o negativo no cambia nada.

### AC-SUB-006 — Repetir empieza de nuevo *(verifica BR-SUB-004)*

DADO el pensamiento «Una bolsa de basura.» con 2 segundos transcurridos CUANDO se pide examinar
la misma bolsa otra vez ENTONCES la opacidad es 1, a los 2,82 segundos del segundo gesto sigue
con opacidad 1, y la línea se vacía a los 10/3 segundos del segundo gesto.

### AC-SUB-007 — El examen lo deja fijo *(verifica BR-SUB-005, BR-SUB-001)*

DADO el pensamiento «Una bolsa de basura.» visible y la mopa en la mano CUANDO se pide examinar
ENTONCES arranca el examen y la línea muestra «Una mopa para limpiar las manchas del local.» con
opacidad 1. CUANDO pasan 60 segundos de examen ENTONCES sigue igual. CUANDO termina el examen
ENTONCES la línea está vacía en ese mismo cuadro.

### AC-SUB-008 — Otra interfaz y la pausa *(verifica BR-SUB-006)*

DADO las manos vacías y la mira sobre un inodoro CUANDO se pide examinar con la computadora
abierta, y por separado con la pausa abierta, ENTONCES la línea no cambia. DADO el pensamiento
«Una bolsa de basura.» con 1 segundo transcurrido CUANDO se pausa, pasan 10 segundos reales y se
reanuda ENTONCES se ve con opacidad 1, y la línea se vacía a los 7/3 segundos sin pausa
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

DADO cada producto del catálogo CUANDO se pide su texto al examinar ENTONCES es el de la tabla
de BR-SUB-009, letra por letra. Un producto sin texto hace fallar el caso con su nombre.

### AC-SUB-012 — Cada útil y cada bolsa *(verifica BR-SUB-010)*

DADO la mopa, el balde, los tres jabones y las tres bolsas de basura CUANDO se pide su texto al
examinar ENTONCES cada uno es el de la tabla de BR-SUB-010, letra por letra.

### AC-SUB-013 — Lo fijo dice su texto, y lo demás calla *(verifica BR-SUB-010)*

DADO los dos inodoros, los dos lavatorios, las cinco notas, la computadora, la caja
registradora, el lector, la entrada principal, la puerta del jefe, el portón del depósito, los
tres tachos y el cuerpo y la tapa del contenedor CUANDO se pide su texto al examinar ENTONCES
cada uno es el de la tabla de BR-SUB-010, letra por letra. DADO una puerta interior, una puerta
de heladera, la ventanilla, el comprador, la góndola y una mancha ENTONCES no tienen texto. DADO
un tacho con bolsa y otro sin bolsa CUANDO se pide examinar con las manos vacías ENTONCES los
dos muestran su texto y el primero sigue con su bolsa.

### AC-SUB-014 — El texto del ticket *(verifica BR-SUB-011)*

DADO un ticket con estos renglones CUANDO se pide su texto al examinar ENTONCES es:

| Renglones | Texto |
|---|---|
| Marolini | Un ticket de compra por 1 Marolini |
| Marolini, Marolini, Coracola | Un ticket de compra por 2 Marolini y 1 Coracola |
| Marolini, Coracola, Malbardo | Un ticket de compra por 1 Marolini, 1 Coracola y 1 Malbardo |
| Malbardo, Malbardo, Malbardo | Un ticket de compra por 3 Malbardo |

### AC-SUB-015 — La caja apoyada y en la mano *(verifica BR-SUB-012)*

DADO una caja del depósito apoyada con 0 de Actroncito y las manos vacías CUANDO se pide
examinar ENTONCES la línea muestra «Una caja con 0 cajitas de Actroncito. Entran 8 más.» como
pensamiento, sin examen. DADO una caja con 5 de Malbardo en la mano CUANDO se pide examinar
ENTONCES la línea muestra «Una caja con 5 cajitas de Malbardo. Entran 3 más.» fijo hasta que
termina el examen.

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
