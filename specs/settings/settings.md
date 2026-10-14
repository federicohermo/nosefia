---
schema_version: 1
capability_id: CAP-CFG
status: ratified
owner: por definir
provenance: fichas «2. Menú de inicio» (sección «Interfaz de configuraciones») y «Pausa y menú de pausa»; rangos, pasos y defectos decididos por el dueño en #378, provisorios hasta que el testing los ajuste
---

# Capacidad: configuraciones

## Propósito

Que el jugador ajuste cómo suena, cómo se ve y cómo responde el juego, y que el juego lo recuerde
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

## Comportamiento normativo

### BR-CFG-001 — Seis filas, en un orden fijo

Configuraciones DEBE mostrar seis filas, en este orden: **efectos, música, brillo,
sensibilidad, textos y lenguaje**. Las cinco primeras DEBEN ser una barra con un botón − a la
izquierda y un botón + a la derecha. Lenguaje DEBE ser un desplegable con una sola opción,
«ESPAÑOL».

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

### BR-CFG-007 — Brillo cambia la interfaz y no el local

El sistema DEBE multiplicar por el brillo elegido el brillo de todo lo que se dibuja con el tema
de la interfaz: menús, pausa, avisos, computadora y celular. La vista del local en 3D NO DEBE
cambiar. En 100 % la interfaz DEBE verse como hoy.

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

## Criterios de aceptación

### AC-CFG-001 — Las seis filas *(verifica BR-CFG-001)*

DADO Configuraciones abierta ENTONCES muestra efectos, música, brillo, sensibilidad, textos y
lenguaje, en ese orden; cada una de las cinco primeras tiene un − a la izquierda de su barra y un
+ a la derecha; el desplegable de lenguaje tiene exactamente una opción, «ESPAÑOL».

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
por 1,5; en 100 %, sin cambio. DADO brillo en 50 % y en 150 % ENTONCES la vista del local en 3D
es la misma que con 100 %.

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

## No objetivos

- Esta capacidad NO ajusta el contraste, ni remapea los controles, ni ofrece otro idioma que el
  español.
- Esta capacidad NO cambia el brillo del local en 3D: sólo el de la interfaz.
- Esta capacidad NO guarda ni borra la partida: eso es de
  [`save-and-resume`](../save-and-resume/save-and-resume.md).
- Esta capacidad NO decide qué suena ni por qué bus: eso es de
  [`ambience`](../ambience/ambience.md). Sólo regula cuán fuerte sale cada bus.
- Esta capacidad NO ofrece perfiles, ranuras ni preferencias en la nube.

## Contratos

- **Entrada:** el + o el − de una barra, el valor arrastrado, el archivo de preferencias al
  arrancar.
- **Salida:** el valor de cada preferencia ya acotado a su rango y a su paso; si el gesto la
  cambió; el volumen de cada bus, el brillo y la escala de la interfaz, y el factor de giro.
- **Falla:** + en el máximo y − en el mínimo contestan que no cambió; un campo faltante, de otro
  tipo o fuera de rango vuelve con su defecto; un archivo ilegible o ausente devuelve todos los
  defectos; una escritura le contesta a quien la pidió si llegó al disco.

## Señales

- Preferencias cambiadas, una vez por cada gesto que cambia un valor. Un gesto en el tope no la
  emite.
- Configuraciones cerrada.

## Dependencias

- [`ambience`](../ambience/ambience.md) (consume): los cuatro buses que declara.
- [`player-actions`](../player-actions/player-actions.md) (alimenta): el factor de giro de la
  vista.
- [`investigation`](../investigation/investigation.md) (alimenta): el factor de giro de lo que
  se examina.
- [`save-and-resume`](../save-and-resume/save-and-resume.md) (consume): los dos menús desde
  donde se abre, y Esc para cerrarla. Borrar su guardado no toca las preferencias.

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
