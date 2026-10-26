---
schema_version: 1
capability_id: CAP-CLN
status: ratified
owner: por definir
provenance: GDD «Limpiar» y «Sacar la basura»; fichas «9. Tarea: Limpieza», «Particulares de cada jornada» y «Contenedor de basura»; decisiones de #370 y #372; migración de los specs 010, 015, 043; ajustes del dueño sobre duración de la mopa, mezcla, enjuague y agua temporal; fichas Limpieza, Particulares y Contenedor revisadas el 2026-10-15; decisiones de #425; anomalía J2 y sustitución por Poético de #432, 2026-10-15; ocho jornadas de #526; cuartito de limpieza de #541; exención de Poético en el desorden de #517, ficha «Llamados de atención extra» revisada el 2026-10-20
---

# Capacidad: dejar el local en orden

## Propósito

Las dos obligatorias que se pagan caminando: borrar las manchas de la jornada y llevar las bolsas
al fondo. Lo único que tienen que hacer bien es **costar recorrido**: una tarea que se cierra con
un clic no le disputa nada a la investigación. Limpiar cuesta ir al cuartito y al baño: cada mancha pide su
jabón, el jabón se mezcla en el balde, y cambiar de jabón es vaciar el balde y volver a llenarlo.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Mancha** | lo que hay que borrar: moho, caca o polvo, en un lugar del local, del depósito o del baño, sobre el piso, una pared o el techo | suciedad |
| **Jabón** | uno de los tres bidones del cuartito: azul, rosa o amarillo | detergente, producto |
| **Cuartito** | el cuarto de limpieza detrás de la puerta del fondo del depósito, donde se guardan los útiles | depósito de limpieza, baño |
| **Balde** | donde se prepara la mezcla: vacío, con agua, o con agua teñida de un jabón | cubeta |
| **Mopa** | con lo que se borra una mancha: seca, o mojada de lo que tenía el balde | trapo, escoba |
| **Lavatorio** | donde se llena el balde | pileta, canilla |
| **Inodoro** | donde se vacía el balde y se enjuaga la mopa | — |
| **Charco temporal** | agua que deja una mopa húmeda sobre piso despejado y se evapora; no es una mancha de la jornada | suciedad, tarea |
| **Útiles** | la mopa, el balde y los tres jabones: lo que se levanta para limpiar | herramientas |
| **Pasada** | pasar la mopa por una mancha | — |
| **Bolsa** | una unidad de basura que hay que llevar al contenedor | residuo |
| **Contenedor** | el del depósito, donde se tiran objetos y cuentan las bolsas | zona, esfera |

## Comportamiento normativo

### BR-CLN-007 — Tres bolsas y una mano

CUANDO se abre una jornada que declara tirar la basura, el sistema DEBE poner una bolsa en cada
uno de los tres tachos: compradores cerca de la entrada del local, escritorio y baño. Las demás
jornadas DEBEN abrir con los tres tachos sin bolsa y ninguna bolsa en el mundo. La cantidad de
bolsas sale de esos tres orígenes y DEBE ser mayor que las manos disponibles. La apertura que
declara esta particular es la jornada 5.

### BR-CLN-008 — El contenedor está lejos

El contenedor del depósito DEBE ser fijo y estar a **6 metros o más** de las tareas del local
y de cada uno de los tres tachos donde arrancan las bolsas. Esa separación DEBE ser mayor al
alcance de la mira.

### BR-CLN-009 — La bolsa cuenta por el tiro al contenedor

CUANDO una bolsa se tira con el primario al cuerpo del contenedor completamente abierto, el sistema
DEBE contarla como depositada. Soltarla en el piso cerca o por la boca física NO DEBE contarla
ni impedir recogerla y tirarla después.

### BR-CLN-010 — Los dos rechazos de depositar, en orden

CUANDO se cuenta una bolsa, el sistema DEBE rechazar por **no es basura** primero y por **ya
depositada** después. Repetir el mismo depósito NO DEBE aumentar la cuenta.

### BR-CLN-011 — Cada obligatoria cierra con lo suyo

CUANDO no queda una sola mancha, el sistema DEBE dar limpiar por cumplida. CUANDO no queda una
sola bolsa sin depositar, DEBE dar la basura por cumplida. Las dos se comparan contra lo que la noche
declaró y nunca contra un número escrito.

### BR-CLN-012 — Cada mancha pide su jabón

El sistema DEBE tener **tres tipos de mancha**, y a cada uno lo borra **una sola mezcla**: azul para
moho, rosa para caca y amarilla para polvo. Cada tipo DEBE verse de su color —el moho
verde, la caca marrón y el polvo negro o gris, con transparencia entre sus trazos que deja ver la
superficie de abajo—, que es lo que le dice al jugador qué jabón buscar. El agua del balde también DEBE verse transparente,
conservando el color del jabón cuando está teñida.

### BR-CLN-013 — Las manchas de la jornada

CUANDO se abre una jornada, el sistema DEBE poner las manchas que esa jornada declara, cada una
con su tipo, su habitación y su superficie:

| Jornada | Tipo | Habitación | Superficie | Lugar |
|---|---|---|---|---|
| 3 | polvo | local | piso | frente al mostrador |
| 3 | polvo | local | pared | sobre la pared con la puerta del baño |
| 3 | moho | depósito | pared | al lado de la puerta del cuartito de limpieza |
| 3 | caca | baño | piso | al lado de un inodoro |
| 4 | polvo | local | piso | frente a la puerta de entrada |
| 4 | polvo | local | piso | entre dos góndolas |
| 4 | polvo | local | piso | en el rincón opuesto al mostrador |
| 4 | moho | depósito | pared | cerca de la puerta al local |
| 4 | moho | depósito | pared | arriba de la caja eléctrica |
| 4 | caca | baño | piso | al lado del inodoro donde no estuvo la caca de piso de la jornada 3 |
| 4 | caca | baño | pared | al lado del otro inodoro |
| 5 | polvo | local | piso | detrás del mostrador |
| 5 | polvo | local | piso | cerca de las heladeras |
| 5 | polvo | local | piso | frente a la puerta del baño |
| 5 | moho | depósito | pared | en una esquina, cerca del techo |
| 5 | moho | depósito | pared | al lado del contenedor |
| 5 | polvo | baño | piso | frente a la puerta del baño |
| 5 | moho | baño | techo | en una esquina que no es la de la puerta |
| 5 | caca | baño | piso | bajo la puerta de un cubículo |

La jornada 3 suma 4, con 2 de polvo, 1 de moho y 1 de caca. La 4 suma 7, con 3 de polvo,
2 de moho y 2 de caca. La 5 suma 8, con 4 de polvo, 3 de moho y 1 de caca. Las jornadas 1 y 2
DEBEN arrancar sin manchas. La caca de piso de la jornada 4 DEBE estar al lado del inodoro donde
no estuvo la de la jornada 3. Las jornadas 6, 7 y 8 DEBEN arrancar con las de la 4
(`OQ-CLN-002`). Cada jornada DEBE arrancar con todas sus manchas sucias, aunque la anterior las
haya borrado.

Una mancha que la jornada no declara NO DEBE verse, ni detener la mira, ni reservar el sector de
un charco temporal, ni contar para limpiar. Una mancha de pared o de techo DEBE borrarse con la
misma pasada y el mismo alcance que una del piso, apuntándola con la mira desde un punto libre del
piso. El paso del jugador DEBE tocar sólo las manchas del piso: una de pared o de techo NO DEBE
ondular cuando el jugador camina a su lado o debajo.

### BR-CLN-014 — Los útiles disponibles arrancan en el cuartito

CUANDO se abre una jornada, el sistema DEBE dejar la mopa, el balde y los jabones disponibles
en su lugar del cuartito, con el balde vacío y la mopa seca, aunque la noche anterior hayan quedado
en otro lado, en la mano, llenos o mojados. En jornada 5 sólo DEBEN estar rosa y amarillo; en
las demás, los tres. La disponibilidad la decide BR-ANO-001 de
[`anomalies`](../anomalies/anomalies.md). Los útiles presentes DEBEN ser levantables; lavatorio
e inodoro NO DEBEN serlo.

### BR-CLN-015 — El balde se llena en el lavatorio

CUANDO se usa el balde sobre el lavatorio, SI el balde está vacío, ENTONCES el sistema DEBE
llenarlo de agua sin jabón, que se ve **celeste**. SI ya tiene agua, con jabón o sin él, ENTONCES
DEBE rechazarlo por **balde ya lleno** y dejarlo como estaba: llenar no lava el jabón.
El llenado aceptado DEBE mostrar el nivel subiendo rápidamente desde el fondo, con una
transición. El agua está disponible desde la aceptación; repintar no reinicia el gesto.

### BR-CLN-016 — El jabón tiñe el agua

CUANDO se usa un jabón sobre el balde, SI el balde tiene agua sin jabón, ENTONCES el sistema DEBE
teñirla de ese jabón, y el agua DEBE verse del color del jabón. SI el balde está vacío, ENTONCES
DEBE rechazarlo por **balde vacío**. SI el agua ya está teñida —del mismo jabón o de otro—,
ENTONCES DEBE rechazarlo por **balde ya teñido** y dejar el color que tenía.
La incorporación aceptada de jabón DEBE verse como una mezcla gradual de líquidos, sin un salto
de color. La animación no retrasa la disponibilidad del jabón ni se reinicia al actualizar el
dibujo; vaciar el balde o abrir otra jornada la cancela.

### BR-CLN-017 — El balde se vacía en el inodoro

CUANDO se usa el balde sobre el inodoro, SI tiene agua, ENTONCES el sistema DEBE vaciarlo, con
jabón o sin él. SI está vacío, ENTONCES DEBE rechazarlo por **balde vacío**. Cambiar de jabón es
vaciar el balde y volver a llenarlo.
El vaciado aceptado DEBE mostrar el nivel bajando rápidamente antes de ocultar el agua,
conservando su color durante la descarga. El balde queda vacío desde la aceptación. Una
nueva carga parte del nivel visible actual; abrir otra jornada cancela estas transiciones.

### BR-CLN-018 — La mopa se moja de lo que tiene el balde

CUANDO se usa la mopa sobre el balde, SI el balde tiene agua, ENTONCES el sistema DEBE dejar la
mopa mojada de lo mismo —agua sola, o agua con su jabón—, aunque antes estuviera mojada de otra
cosa, y su punta DEBE verse del color del agua. Mojar la mopa no gasta el agua del balde. SI el
balde está vacío, ENTONCES DEBE rechazarlo por **balde vacío** y dejar la mopa como estaba.

### BR-CLN-019 — Sólo el jabón que corresponde borra

CUANDO se pasa la mopa por una mancha, SI la mopa está mojada del jabón que borra esa mancha,
ENTONCES el sistema DEBE borrar la mancha mientras conserve carga útil. Borrar no descuenta
carga adicional al tiempo y recorrido. SI no, ENTONCES DEBE rechazar la pasada sin cambiar nada,
en este orden: **ya limpia**, si la mancha ya se borró; **mopa seca**; **sin jabón**, si está mojada de
agua sola; y **jabón equivocado**.

### BR-CLN-020 — Cada uso contesta qué pasó

CUANDO se usa lo que se lleva sobre una mancha, el balde, el lavatorio o el inodoro, el sistema
DEBE contestar lo que hizo o por qué no hizo nada. SI el par no es uno de los gestos de limpiar
—otro objeto en la mano, o la mano vacía—, ENTONCES DEBE contestar **sin efecto** y no cambiar
nada.

### BR-CLN-021 — Limpiar se puede dejar por la mitad

MIENTRAS dura la jornada, el sistema DEBE conservar qué tiene el balde, de qué está mojada la mopa
y qué manchas quedan. Soltar un útil o cambiar de mano no recarga ni vacía el balde. La mopa
sigue perdiendo su carga por el tiempo transcurrido, incluso apoyada o examinada.

### BR-CLN-022 — La carga de la mopa tiene duración y recorrido limitados

MIENTRAS dura la jornada, el sistema DEBE descontar la carga de la mopa por tiempo real y,
cuando se lleva en la mano, por distancia recorrida. Los dos límites —una duración en reposo
y un recorrido— los declara el dominio. CUANDO se agota, ENTONCES DEBE quedar seca y
rechazar la limpieza. Remojarla en un balde con agua recupera la carga completa. La punta
DEBE perder intensidad de color y gotear durante el desgaste, sin generar nuevas manchas ni
reservar partículas sin límite. La pausa detiene el desgaste. Caminar DEBE agotarla antes
que esperar quieta el mismo tiempo, sin acortar la duración máxima en reposo. Los charcos
temporales producidos por una pasada intencional de agua no son manchas nuevas.

### BR-CLN-023 — Enjuagar la mopa

CUANDO se usa la mopa sobre el inodoro, ENTONCES el sistema DEBE quitarle cualquier jabón y
dejarla húmeda de agua sin jabón, con carga completa, incluso si estaba seca. El balde y las
manchas DEBEN conservar su estado. Mojarla en un balde con agua sin jabón produce el mismo
enjuague, sin gastar ni teñir su agua.

### BR-CLN-024 — Agua temporal sobre piso despejado

CUANDO se usa una mopa con carga de agua sin jabón sobre un piso horizontal despejado, ENTONCES
el sistema DEBE dejar un charco temporal en el punto alcanzado por la mira. La pasada no limpia
manchas ni modifica tareas, penalizaciones o el agua del balde. Una mopa seca o con jabón no
produce este charco; agua sola sobre una mancha conserva el rechazo por falta de jabón.

El charco DEBE quedar enteramente fuera de los sectores de las manchas de la jornada, incluidos
los ya limpiados, y fuera de paredes, muebles y superficies que no sean suelo. Una superficie
fuera del alcance de interacción u oculta por un obstáculo DEBE rechazarse. El rechazo no cambia
la carga ni el piso.

El agua temporal DEBE desaparecer gradualmente tras la duración definida para los charcos,
detener su evaporación durante la pausa y desaparecer al abrir otra jornada. La cantidad
simultánea DEBE estar acotada; repetir pasadas no reserva nodos sin límite. Los charcos no
obstruyen el movimiento ni la mira.

### BR-CLN-025 — La tapa alterna con el primario y no desecha

CUANDO abre una jornada, el contenedor DEBE tener la tapa completamente abierta. El primario
—clic izquierdo por defecto— sobre la tapa DEBE alternar abrir y cerrar con cualquier mano,
sin cambiar lo sostenido ni desecharlo. Otro primario durante el giro DEBE invertirlo.
El secundario NO DEBE alternar. La tapa y el cuerpo DEBEN ser objetivos distintos: el cuerpo
recibe según BR-CLN-026 y NO DEBE alternar además la tapa con el mismo clic.
La bisagra y la colisión DEBEN acompañar la tapa y el giro DEBE detenerse ante un objeto sin
atravesarlo ni comprimirlo. Sólo la tapa completamente abierta DEBE permitir recibir objetos;
cerrar corta ese permiso desde el inicio del giro y abrir lo recupera al alcanzar el tope.

### BR-CLN-026 — Tirar al cuerpo consume el primario y retira lo sostenido

CUANDO se hace el primario sobre el cuerpo del contenedor completamente abierto con un objeto que
entra, el sistema DEBE retirarlo de la mano y de la jornada: oculto, sin colisión ni foco.
Una caja del depósito NO DEBE entrar. Con mano vacía, caja o tapa cerrada o girando, el primario sobre el cuerpo
DEBE conservar manos y tarea sin soltar genéricamente. Abrir NO DEBE tirar automáticamente.
Con el jugador suspendido por examen, pausa o cierre, ambos clics NO DEBEN tirar ni alternar.
El secundario NO DEBE desechar. Accionar la tapa NO DEBE desechar además lo sostenido.
Al abrir otra noche, los objetos de arranque tirados y disponibles en esa jornada DEBEN volver
a sus padres y poses de arranque, visibles, físicos y recogibles, con mopa seca y balde vacío.
El bidón azul DEBE permanecer ausente durante jornada 5, según BR-CLN-014. Las bolsas DEBEN seguir
la declaración de la jornada nueva: fuera del mundo si no declara basura, o en su tacho y sin
depositar si la declara, nunca sueltas por haber sido tiradas en la noche anterior.
Las unidades y tickets tirados DEBEN retirarse con los demás creados en la noche anterior.

### BR-CLN-027 — Pertenencia a las habitaciones

El sistema DEBE distinguir el interior del local, del depósito, del baño y del cuartito,
incluidos sus pasos de acceso, según piso, paredes y techos existentes. Cada habitación DEBE admitir una unión
finita de volúmenes locales sin rellenar huecos, ensanchar pasos ni elevar techos bajos. Un
punto fuera de las cuatro DEBE clasificarse afuera. Trasladar o rotar el conjunto NO DEBE agrandar
sus interiores ni cambiar la pertenencia de un punto que conserva su posición relativa.

### BR-CLN-028 — El desorden cuenta una vez al cierre

CUANDO termina la jornada, el sistema DEBE anotar un llamado por desorden si queda alguna
unidad suelta dentro de cualquier habitación, una caja fuera del depósito o un útil
fuera del cuartito. Una única caja en el local NO DEBE producir desorden; dos o más cajas en el
local sí, y una caja apoyada en el baño o en el cuartito también, aunque sea la única. La caja
sostenida cuenta como la única permitida, también en el baño: con una caja en la mano, otra caja
en el local produce desorden. Las unidades de Poético quedan exentas sólo en lo que fija BR-CLN-037. Los demás cuerpos sostenidos DEBEN excluirse por identidad. Mientras se examina, cualquier
cuerpo sostenido cuenta en su posición física. Lo ya tirado al contenedor DEBE excluirse.
Una bolsa o un ticket adentro no DEBE producir desorden. Varios cuerpos desordenados DEBEN producir un
único motivo. La foto DEBE tomarse antes de registrar el legajo, armar la devolución y guardar.

### BR-CLN-029 — Lo que queda afuera conserva su cuerpo

CUANDO termina la jornada, el sistema DEBE anotar un llamado si queda al menos un cuerpo
levantable afuera, excluyendo el sostenido sin examen y lo tirado al contenedor. Varios cuerpos
afuera DEBEN producir un único motivo, independiente del desorden. Recuperarlo antes del cierre
DEBE eliminar ese motivo; una unidad recuperada y suelta adentro puede producir desorden.
Las superficies existentes de pavimento exterior DEBEN sostener los cuerpos soltados por el
hueco real de ventanilla, conservándolos recogibles dentro del alcance vigente, sin extender
soporte sobre huecos que el pavimento no ocupa ni duplicar su dibujo.

### BR-CLN-030 — Papel en el inodoro

CUANDO se acepta tirar al menos un ticket al inodoro durante una jornada abierta, el sistema
DEBE anotar un único llamado por papel en el inodoro, aunque se tiren varios. Este motivo
DEBE sumar un medio apercibimiento al cierre, además de la banda y de los otros motivos.
Vaciar el balde o enjuagar la mopa NO DEBE anotarlo. Un evento sin jornada abierta o con
partida terminada NO DEBE sumar ni quedar pendiente para otra noche.

### BR-CLN-031 — Tirar objetos importantes

CUANDO se acepta tirar al contenedor un objeto que no sea bolsa ni ticket durante una jornada
abierta, el sistema DEBE anotar un único llamado por objeto importante tirado. Varios objetos
importantes tirados DEBEN producir un solo motivo en esa noche. Las bolsas y los tickets
DEBEN conservar su descarte normal sin este motivo. Una unidad ordinaria, la mopa, el balde
y los jabones NO DEBEN considerarse exentos. El motivo DEBE sumar un medio al cierre, además
de la banda y los demás motivos, y reiniciarse al abrir otra noche sin borrar la deuda.
Un gesto rechazado o fuera de jornada abierta NO DEBE anotar este motivo.

### BR-CLN-032 — El primario sobre un tacho entrega su única bolsa

CUANDO el jugador enfoca un tacho con bolsa y hace el primario con la mano vacía, el sistema
DEBE ponerle esa bolsa en la mano y dejar el tacho sin bolsa. Con la mano ocupada o el tacho
vacío, NO DEBE cambiar manos, tacho ni cuenta. Otro primario NO DEBE producir una segunda bolsa.
Ningún gesto DEBE devolver una bolsa al tacho. El secundario NO DEBE extraer bolsas.
El primario sobre el tacho con mano ocupada NO DEBE tirar ni soltar el objeto.
La suspensión del control NO DEBE permitir extraer la bolsa.

Cada tacho DEBE ser enfocable, con contorno desde piso libre dentro del alcance vigente.
«Con basura» DEBE verse como una bolsa en la boca del tacho; «sin basura», como el mismo tacho
sin ella. En la boca, la bolsa NO DEBE interceptar la mira ni tener colisión propia. Al sacarla,
DEBE ser un levantable con su identidad original. Extraer NO DEBE contar como depositar:
sólo el tiro aceptado al cuerpo del contenedor lo hace. Una bolsa sacada y rescatada DEBE
volver libre a su origen, sin reponer el tacho ni crear otra identidad. Sólo la jornada que
declara basura DEBE permitir extraer; las demás DEBEN conservar los tachos sin bolsa.

### BR-CLN-033 — Poético prepara azul sólo durante la quinta jornada

MIENTRAS la jornada es 5, CUANDO se usa con clic izquierdo una unidad real del producto Poético
sobre el balde, el sistema DEBE aplicar los mismos permisos, rechazos y mezcla azul del jabón
azul (BR-CLN-016). La identidad DEBE ser la del producto, no su nombre visible. En las demás
jornadas Poético NO DEBE actuar como jabón, y ningún otro producto DEBE adquirir ese efecto.
La referencia de controles y el uso DEBEN consultar el mismo permiso por jornada: «echar jabón»
sólo donde está habilitado. El rechazo NO DEBE convertirse en soltar ni en otra operación.
Sobre lavatorio, inodoro o mancha Poético NO DEBE preparar mezcla ni limpiar directamente.

### BR-CLN-034 — Sustituir jabón no consume mercadería

CUANDO Poético tiñe el balde de azul, el sistema DEBE conservar la misma unidad en la mano, sin
consumirla, transformarla, venderla ni descontarla otra vez del inventario. Vaciar y rellenar
DEBE permitir reutilizarla. El agua y la mopa DEBEN tener los mismos colores, carga, desgaste y
efectos que con el bidón azul: borrar moho y rechazar caca o polvo. La unidad DEBE conservar su
venta y devolución normales. El bidón azul DEBE conservar identidad, envase y subtítulo de
marca «2», sin presentarse como Poético.

### BR-CLN-035 — El uso aceptado identifica qué preparó la mezcla

CUANDO un teñido se acepta, el sistema DEBE publicar el resultado junto con la identidad del
objeto utilizado. Una mezcla azul preparada con Poético DEBE distinguirse de una preparada
con el bidón azul. Pausa, examen y cierre DEBEN bloquear el uso; un rechazo NO DEBE publicar
un teñido aceptado ni alterar agua, mopa, manchas, mano o inventario.

### BR-CLN-036 — El primario ejecuta los pares de limpieza y el descarte de papel

CUANDO el primario encuentra balde/lavatorio, jabón/balde, mopa/balde, mopa/inodoro,
mopa/mancha o balde/inodoro, el sistema DEBE pedir respectivamente llenar, teñir, mojar,
enjuagar, limpiar o vaciar, conservando los resultados y rechazos de BR-CLN-015 a BR-CLN-023.
El secundario NO DEBE ejecutar esos pares. Un rechazo DEBE conservar el útil en la mano,
sin soltarlo ni cambiar el agua, carga o manchas por un efecto adicional.
El agua temporal sobre piso despejado DEBE conservar el secundario y BR-CLN-024.

CUANDO se hace el primario con un ticket propio sobre el inodoro, el sistema DEBE pedir su
descarte y, si se acepta, anotar papel según BR-CLN-030 una sola vez. El secundario NO DEBE
desechar papel. Un objeto distinto de ticket NO DEBE descartarse por ese destino.

### BR-CLN-037 — Poético suelto no desordena durante la jornada que lo usa de jabón

MIENTRAS la jornada es aquella en que Poético sustituye al jabón azul (BR-CLN-033), el sistema
NO DEBE contar para el desorden de BR-CLN-028 ninguna unidad del producto Poético, esté donde
esté dentro de cualquier habitación y la haya usado o no el jugador. La identidad DEBE ser la
del producto, no su nombre visible. Esa unidad NO DEBE contarse como unidad suelta ni como útil
fuera del cuartito. Cualquier otra unidad suelta DEBE seguir produciendo desorden, y
una unidad de Poético junto a otra unidad suelta produce desorden por la otra. En las demás
jornadas, una unidad de Poético suelta DEBE contar como cualquier otra unidad. La exención
alcanza sólo al desorden: una unidad de Poético afuera DEBE conservar el motivo de BR-CLN-029,
y la caja de Poético fuera del depósito DEBE contar como cualquier otra caja. La regla DEBE resolverse con la jornada y la identidad del producto como
datos del cierre, sin que la escena filtre cuerpos.

## Criterios de aceptación

### AC-CLN-007 — Tres bolsas son más que las manos *(verifica BR-CLN-007)*

DADO la jornada 5 abierta CUANDO se consultan los tachos ENTONCES hay 3 con una bolsa cada uno,
con identidades distintas, más bolsas que manos disponibles y ninguna depositada. DADO las
jornadas 1, 4, 6 y 8 abiertas ENTONCES los tres tachos están sin bolsa y no hay bolsas en el mundo.

### AC-CLN-008 — El viaje llega al contenedor *(verifica BR-CLN-008)*

DADO el almacén armado CUANDO se miden los puntos funcionales de las tareas del local y
los tres tachos ENTONCES el contenedor fijo está en el depósito y a 6 metros o más
de todos ellos, por encima del alcance de la mira. Las posiciones se derivan del local vigente.

### AC-CLN-009 — Soltar no deposita *(verifica BR-CLN-009)*

DADO una bolsa soltada en el piso a menos de 1 metro del contenedor o por su boca física
CUANDO queda suelta ENTONCES no cuenta y se puede recoger. CUANDO después se la tira con el
primario sobre el cuerpo completamente abierto ENTONCES sí cuenta; sobre la tapa no deposita.

### AC-CLN-011 — El orden y la idempotencia *(verifica BR-CLN-010)*

DADO algo que no es bolsa CUANDO se intenta contarlo ENTONCES se rechaza por «no es basura».
DADO una bolsa ya depositada CUANDO se intenta contar otra vez ENTONCES se rechaza por «ya
depositada» y la cantidad sigue igual.

### AC-CLN-012 — Las dos obligatorias cierran *(verifica BR-CLN-011)*

DADO las manchas de la jornada borradas ENTONCES limpiar está cumplida; DADO las tres
bolsas de la jornada 5 depositadas ENTONCES la basura está cumplida; con una sola pendiente en
cada caso, no. En una jornada sin basura declarada, cero bolsas NO suma una obligatoria.

### AC-CLN-014 — Cada jabón borra un solo tipo *(verifica BR-CLN-012)*

DADO una mancha de moho, una de caca y una de polvo, y la mopa mojada de cada uno de los tres
jabones ENTONCES de los nueve pares se borran exactamente tres: moho con azul, caca con rosa y
polvo con amarillo.

### AC-CLN-015 — El color de cada mancha *(verifica BR-CLN-012)*

DADO las manchas de la jornada en la escena ENTONCES la de moho se ve verde —el verde es su canal
más alto—, la de caca marrón —rojo sobre verde sobre azul, y oscura— y las de polvo negras,
con el dibujo de polvo de la guía y transparencia entre los trazos que deja ver el piso.

### AC-CLN-016 — Las manchas de cada jornada *(verifica BR-CLN-013)*

DADO la jornada 1 y la 2 ENTONCES no tienen manchas. DADO la 3 ENTONCES tiene 4 manchas,
2 de polvo, 1 de moho y 1 de caca. DADO la 4 ENTONCES tiene 7, con 3 de polvo, 2 de moho y
2 de caca. DADO la 5 ENTONCES tiene 8, con 4 de polvo, 3 de moho y 1 de caca. DADO la 6, la 7
y la 8 ENTONCES tienen las mismas 7 de la 4. En cada una, cada mancha lleva el tipo, la
habitación, la superficie y el lugar declarados, y ninguna arranca borrada. DADO la caca de
piso de la jornada 3 CUANDO abre la 4 ENTONCES la caca de piso está junto al otro inodoro.
DADO la 3 con sus 4 borradas CUANDO abre la 4 ENTONCES sus 7 están sucias. DADO la 4 con sus
7 borradas CUANDO abre la 5 ENTONCES sus 8 están sucias. DADO la 5 con sus 8 borradas CUANDO
abre la 6 ENTONCES sus 7 están sucias.

### AC-CLN-017 — Cada mancha en su habitación y su superficie *(verifica BR-CLN-013, BR-CLN-027)*

DADO las jornadas 3, 4 y 5, por turno, ENTONCES cada mancha de la noche está en la habitación que
declara su lugar, según la pertenencia de `BR-CLN-027`, y sobre la superficie que declara: mira
hacia arriba en el piso, en horizontal en la pared y hacia abajo en el techo. Ninguna queda debajo
de un mueble ni tapada, y la mira enfoca cada una desde un punto libre del piso dentro del
alcance vigente. Las manchas de otra noche no se ven y la mira no las enfoca.

### AC-CLN-018 — Los útiles disponibles vuelven al cuartito *(verifica BR-CLN-014)*

DADO la mopa mojada en el local, el balde teñido en depósito y un jabón en mano CUANDO se abre
cada jornada ENTONCES se vacía la mano y vuelven al cuartito los útiles disponibles, con balde vacío
y mopa seca: cuatro en la 5 —mopa, balde, rosa y amarillo— y cinco en las demás. El azul no
está en la quinta y su lugar queda vacío. Ningún útil queda en el baño. Lavatorio e inodoro se
rechazan al intentar agarrarlos.

### AC-CLN-019 — Llenar el balde *(verifica BR-CLN-015)*

DADO el balde vacío CUANDO se usa sobre el lavatorio ENTONCES tiene agua sin jabón y el agua se ve
celeste: el azul es su canal más alto y ninguno baja de 0,6. DADO el balde con agua, o teñido de
azul, CUANDO se usa sobre el lavatorio ENTONCES el resultado es «balde ya lleno» y sigue igual: con
agua, o azul.

### AC-CLN-020 — Teñir el balde *(verifica BR-CLN-016)*

DADO el balde con agua sin jabón CUANDO se usa el jabón rosa ENTONCES el agua está teñida de rosa
y se ve del color del jabón rosa. DADO el balde vacío CUANDO se usa un jabón ENTONCES el resultado
es «balde vacío» y sigue vacío. DADO el balde teñido de rosa CUANDO se usa el amarillo, o el rosa
otra vez, ENTONCES el resultado es «balde ya teñido» y sigue rosa.

### AC-CLN-021 — Vaciar el balde *(verifica BR-CLN-017)*

DADO el balde teñido de rosa CUANDO se usa sobre el inodoro ENTONCES queda vacío; CUANDO después
se lo llena y se usa el jabón amarillo ENTONCES el agua es amarilla. DADO el balde vacío CUANDO se
usa sobre el inodoro ENTONCES el resultado es «balde vacío».

### AC-CLN-022 — Mojar la mopa *(verifica BR-CLN-018)*

DADO el balde con agua sin jabón CUANDO se usa la mopa sobre él ENTONCES la mopa queda mojada de
agua y su punta se ve del color del agua. DADO la mopa mojada de azul y el balde teñido de
amarillo CUANDO se la moja ENTONCES queda mojada de amarillo, y el balde sigue teñido de amarillo.
DADO el balde vacío CUANDO se moja la mopa ENTONCES el resultado es «balde vacío» y la mopa sigue
seca.

### AC-CLN-023 — Borrar una mancha *(verifica BR-CLN-019)*

DADO una mancha de polvo CUANDO se pasa la mopa seca ENTONCES el resultado es «mopa seca»; mojada
de agua, «sin jabón»; mojada de azul, «jabón equivocado»; y en los tres casos la mancha sigue.
CUANDO se pasa mojada de amarillo ENTONCES la mancha se borra, la mopa sigue mojada de amarillo y
puede borrar la otra de polvo mientras conserve carga; agotada debe volver al balde.
DADO una mancha ya borrada CUANDO se pasa la mopa seca ENTONCES el resultado es «ya limpia».

### AC-CLN-024 — Lo que no es un gesto de limpiar *(verifica BR-CLN-020)*

DADO la mano vacía, o una bolsa en la mano CUANDO se usa sobre una mancha, sobre el balde, sobre
el lavatorio o sobre el inodoro ENTONCES el resultado es «sin efecto» y el balde, la mopa y las
manchas siguen como estaban.

### AC-CLN-025 — La mezcla espera *(verifica BR-CLN-021)*

DADO el balde teñido de azul y la mopa mojada de azul CUANDO se sueltan en otro cuarto, se agarra
y se suelta otra cosa y se los vuelve a agarrar ENTONCES el balde sigue teñido de azul y la mopa
con la carga que reste tras el tiempo y recorrido transcurridos;
DADO una mancha borrada, sigue borrada.

### AC-CLN-026 — La carga caduca sin depender de los cuadros *(verifica BR-CLN-022)*

DADO una mopa recién mojada CUANDO transcurre la duración máxima en reposo ENTONCES queda
seca y no borra una mancha. Dividir el mismo tiempo y recorrido entre cuadros produce
la misma carga restante. Los valores negativos no recuperan producto.

### AC-CLN-027 — Acercar el balde permite limpiar *(verifica BR-CLN-022)*

DADO la mopa recién mojada CUANDO se recorre su distancia máxima ENTONCES llega seca y
la mancha sigue. CUANDO se moja nuevamente en el balde cercano ENTONCES recupera toda
la carga y borra la mancha correspondiente. La punta pierde color y gotea durante el viaje.

DADO el balde acercado a la zona de limpieza ENTONCES hay carga suficiente para caminar unos
pasos y limpiar.

### AC-CLN-028 — Menor alcance en movimiento *(verifica BR-CLN-022)*

DADO dos mopas recién mojadas CUANDO una recorre metros en el mismo tiempo en que la otra
espera quieta ENTONCES la que caminó tiene menos carga y se agota antes. DADO la mopa quieta
CUANDO transcurre menos que la duración en reposo ENTONCES sigue mojada, y al cumplirla queda
seca. Dividir el trayecto entre cuadros no modifica el resultado ni permite recuperar carga.

### AC-CLN-029 — Enjuague sin cambiar el resto del local *(verifica BR-CLN-023)*

DADO la mopa con cualquiera de los tres jabones, seca o parcialmente gastada CUANDO se usa sobre
el inodoro ENTONCES queda húmeda de agua sin jabón, con carga completa y color de agua limpia;
el balde y las manchas conservan su estado. DADO un balde con agua sin jabón CUANDO se
enjuaga la mopa en él ENTONCES se obtiene lo mismo y el balde conserva su agua.

### AC-CLN-030 — Charco de agua separado de la suciedad *(verifica BR-CLN-024)*

DADO una mopa húmeda de agua sin jabón y un piso despejado dentro del alcance CUANDO se la usa
sobre ese piso ENTONCES aparece un charco sin colisiones ni foco de interacción, sin modificar
las manchas, las tareas o el balde. Con mopa seca o con jabón no aparece.

### AC-CLN-031 — Los sectores de las manchas quedan libres *(verifica BR-CLN-024)*

DADO un punto fuera de una mancha pero un charco que alcanzaría su sector CUANDO se intenta
dejar agua ENTONCES se rechaza sin cambiar carga o manchas, incluso si la mancha ya se limpió.
Sobre la mancha sucia el agua sola sigue rechazándose por falta de jabón. Sobre una pared, un
mueble, detrás de un obstáculo o fuera de alcance tampoco aparece un charco.

### AC-CLN-032 — Evaporación, pausa y cantidad acotada *(verifica BR-CLN-024)*

DADO un charco recién creado ENTONCES sigue visible antes de los cuatro segundos de juego,
pierde opacidad y desaparece al cumplirlos. La pausa no avanza ese tiempo. Repetir pasadas más
veces que el límite simultáneo conserva como máximo ese límite. Abrir una jornada elimina
todos los charcos y conserva únicamente las manchas propias de la jornada.

### AC-CLN-033 — Mezcla visible sin salto ni reinicio *(verifica BR-CLN-016)*

DADO agua sin jabón CUANDO se acepta un jabón ENTONCES la mezcla empieza con el aspecto previo,
muestra ambos líquidos durante la transición y termina con el color del jabón; el estado del
agua acepta inmediatamente mojar la mopa de ese jabón. Una actualización repetida no reinicia
la transición; un uso rechazado no la dispara. Vaciar o abrir otra jornada cancela la mezcla.

### AC-CLN-034 — La tapa alterna sin desechar *(verifica BR-CLN-025)*

DADO el contenedor al abrir ENTONCES tiene la tapa abierta. DADO mano vacía y, por separado,
bolsa sostenida CUANDO se hace primario sobre la tapa ENTONCES gira para cerrar sin cambiar
la mano ni depositar; otro primario invierte el giro. El secundario no alterna. La bisagra
y colisión acompañan ambos estados y el movimiento; un objeto en el recorrido detiene el
cierre sin atravesarlo ni comprimirlo y retirarlo permite continuar. Dividir el tiempo entre
cuadros conserva el giro y abrir otra jornada restaura la tapa abierta.

### AC-CLN-035 — Sólo el cuerpo plenamente abierto recibe *(verifica BR-CLN-025, BR-CLN-026)*

DADO una bolsa sostenida y tapa cerrada o girando CUANDO se hace primario sobre el cuerpo
ENTONCES la bolsa sigue sostenida y no cuenta. Terminar de abrir no la tira; el primario
posterior sobre el cuerpo sí. DADO la tapa abierta CUANDO se pulsa sobre ella ENTONCES
comienza a cerrar, conserva la bolsa y corta el permiso desde el inicio.

### AC-CLN-036 — Cada objeto aceptado sale de la jornada *(verifica BR-CLN-026, BR-CLN-009)*

DADO por turno bolsa, mopa, balde, cada jabón, unidad y ticket sostenidos CUANDO se pulsa
izquierdo sobre el contenedor completamente abierto ENTONCES queda mano vacía y el mismo
cuerpo oculto, sin colisión ni foco. Sólo la bolsa aumenta lo depositado.

### AC-CLN-037 — El rechazo consume el gesto *(verifica BR-CLN-026, BR-CLN-025)*

DADO el cuerpo del contenedor con mano vacía, caja sostenida o tapa no abierta, por turno,
CUANDO se hace primario ENTONCES no hay soltado adicional, la carga conserva su lugar y la
tarea no cambia. DADO bolsa sostenida CUANDO se hace secundario sobre cuerpo o tapa
ENTONCES no se tira ni se suelta, no cuenta y la tapa conserva su estado.

### AC-CLN-038 — Los tirados vuelven con la noche nueva *(verifica BR-CLN-026, BR-CLN-014)*

DADO mopa mojada y balde teñido tirados CUANDO abre otra noche ENTONCES vuelven a sus
padres y lugares originales, visibles, físicos y recogibles; mopa seca y balde vacío.
DADO una bolsa tirada en la jornada 5 CUANDO abre otra noche ENTONCES no está en el mundo.
DADO un ticket y una unidad tirados ENTONCES se retiran junto con los demás
creados en la noche anterior, sin dejar entradas inválidas en la lista de tirados.
La vuelta conserva el estado físico original: un útil móvil elevado 0,5 m vuelve a caer
y apoyarse. Consultar los descartados entrega una copia independiente y la noche nueva
vacía ese registro, sin leer cuerpos ya liberados.

### AC-CLN-039 — La suspensión bloquea ambos destinos *(verifica BR-CLN-026, BR-CLN-025)*

DADO algo sostenido y control suspendido por examen, pausa o cierre CUANDO se pulsan ambos
gestos sobre cuerpo o tapa ENTONCES manos, objetos, tarea y tapa siguen iguales. Al reanudar,
el primario sobre la tapa alterna sin tirar, y sobre el cuerpo tira sólo si está completamente
abierta; el secundario sigue sin ejecutar ninguno de esos gestos.

### AC-CLN-040 — Interiores, techos y pasos exactos *(verifica BR-CLN-027)*

DADO el almacén al abrir ENTONCES todas las cajas están en depósito, los útiles disponibles en cuartito
y el jugador en local. CUANDO se consultan centros de los pasos ENTONCES pertenecen a su
habitación destino; un punto junto al lateral o sobre un techo bajo queda afuera. DADO una
unión disjunta trasladada y girada 45° ENTONCES sus partes conservan pertenencia y sus huecos
siguen afuera, incluso cuando caen dentro de una envolvente mayor.

### AC-CLN-041 — Suelta no significa visible ni apoyada en el piso *(verifica BR-CLN-028)*

DADO una unidad suelta en local, depósito, baño o cuartito, incluso agrupada o apoyada en caja o góndola,
CUANDO cierra ENTONCES hay desorden. DADO la unidad colocada, devuelta o sostenida sin examen
ENTONCES no lo produce. El cuerpo de repuesto no cuenta como unidad suelta.

### AC-CLN-042 — Cada clase tiene su habitación *(verifica BR-CLN-027, BR-CLN-028)*

DADO una caja en cuartito CUANDO cierra ENTONCES hay desorden; en depósito o su paso, no.
DADO un útil en local, depósito o baño ENTONCES hay desorden; en cuartito o su paso, no. DADO un
útil en el umbral de la puerta del cuartito ENTONCES del lado del cuartito no produce desorden y
del lado del depósito sí. DADO una bolsa adentro, también en el cuartito, ENTONCES no produce
desorden. DADO la lista vacía ENTONCES no hay ninguno de los motivos.

### AC-CLN-043 — La mano excluye sólo su cuerpo *(verifica BR-CLN-028, BR-CLN-029)*

DADO dos cajas distintas con los mismos datos y una sostenida CUANDO la otra queda desordenada
o afuera ENTONCES conserva su motivo. DADO el cuerpo sostenido CUANDO inicia un examen real
ENTONCES cuenta por su posición; al terminar vuelve a tratarse como sostenido. Esto también vale para una
unidad que salió del grupo de sueltas al agarrarse. Mover y devolver lo sostenido conserva su
identidad; soltar, entregar y vaciar dejan la mano sin cuerpo.

### AC-CLN-044 — Afuera y recuperación *(verifica BR-CLN-028, BR-CLN-029)*

DADO una bolsa, caja, unidad o útil afuera CUANDO cierra ENTONCES hay un único motivo por
afuera, aunque haya varios. CUANDO se recuperan antes del cierre y se sostienen, colocan o
devuelven ENTONCES no hay ese motivo; una unidad recuperada y suelta adentro produce desorden.

### AC-CLN-045 — El pavimento sostiene lo soltado *(verifica BR-CLN-029)*

DADO las seis superficies existentes del pavimento ENTONCES su soporte coincide con sus
triángulos y no cubre los huecos ajenos. CUANDO se suelta un cuerpo por los bordes libres del
hueco real de ventanilla por ambos laterales libres, derivados del vidrio, las jambas y la
forma del cuerpo, ENTONCES cae, se apoya estable en el pavimento y puede recogerse dentro del
alcance vigente. El espacio numérico entre vidrio y dintel no constituye un paso superior.

### AC-CLN-046 — Dos motivos antes del registro *(verifica BR-CLN-028, BR-CLN-029)*

DADO caja desordenada y unidad afuera CUANDO agota la jornada con GRAVE ENTONCES el legajo
lleva 6 medios desde cero antes de armar la devolución y escribir el checkpoint. DADO esos cuerpos
tirados al contenedor ENTONCES no generan motivos; abrir otra noche vacía el registro de tirados
y restaura los persistentes, sin consultar unidades o tickets ya retirados.

### AC-CLN-047 — El papel aceptado cuenta una vez *(verifica BR-CLN-030)*

DADO una noche impecable CUANDO se aceptan uno o dos tickets propios en el inodoro ENTONCES
el cierre suma un medio. Vaciar el balde o enjuagar la mopa no lo suma. DADO un evento antes
de abrir, después del cierre o con partida terminada ENTONCES no cambia la deuda ni contamina
la siguiente noche. Abrir otra noche permite anotar de nuevo el mismo motivo.

### AC-CLN-048 — Tickets activos, mano, examen y destinos *(verifica BR-CLN-027, BR-CLN-028, BR-CLN-029, BR-CLN-030)*

DADO tickets propios activos ENTONCES la consulta entrega una copia independiente y omite
cuerpos liberados o pendientes de liberar; conserva los válidos de ranura, mundo, mano, examen
y contenedor. DADO tickets dentro de local, depósito, baño o cuartito CUANDO cierra ENTONCES no producen
desorden ni afuera; uno o varios afuera producen un único motivo de afuera. Recuperarlos al
interior o sostenerlos sin examen elimina ese motivo. DADO dos cuerpos con los mismos datos
ENTONCES sólo se excluye el sostenido; un examen real lo hace contar por su posición física
y terminarlo vuelve a excluirlo. Un ticket aceptado por el inodoro se libera sin volver a
consultarlo al cerrar; uno tirado al contenedor sigue vivo y queda excluido por ese destino,
sin anotar papel en el inodoro. Abrir otra noche retira ambos del registro activo.

### AC-CLN-049 — Tres motivos son siete con GRAVE *(verifica BR-CLN-028, BR-CLN-029, BR-CLN-030)*

DADO deuda cero, un ticket aceptado en el inodoro, una caja desordenada y una unidad afuera
CUANDO termina la jornada con GRAVE ENTONCES el cierre registra siete medios antes de la devolución
y del checkpoint y no despide. CUANDO la noche siguiente termina impecable y sin motivos ENTONCES
conserva siete. Un evento durante la devolución no contamina esa noche siguiente y repetir el
cierre no suma otra vez.

### AC-CLN-050 — Las excepciones son bolsas y tickets *(verifica BR-CLN-031)*

DADO una bolsa o un ticket CUANDO se acepta tirarlo al contenedor ENTONCES no agrega el
motivo de objeto importante y la bolsa sigue contando para su obligatoria. DADO una unidad
ordinaria, la mopa, el balde o cualquiera de los tres jabones ENTONCES no está exento.
La ausencia de objeto no constituye una excepción válida ni un descarte aceptado.

### AC-CLN-051 — El descarte importante cuenta una vez por noche *(verifica BR-CLN-026, BR-CLN-031)*

DADO una noche impecable CUANDO se tira una unidad o una mopa al contenedor abierto ENTONCES
el cierre suma un medio y el objeto tirado no produce desorden ni afuera. DADO dos importantes
tirados en la misma noche ENTONCES suman un solo medio. CUANDO abre otra noche, tirar otro
importante permite anotar de nuevo el motivo; una noche impecable sin motivos conserva la deuda.

### AC-CLN-052 — Tres motivos permiten continuar y cuatro despiden *(verifica BR-CLN-028, BR-CLN-029, BR-CLN-030, BR-CLN-031)*

DADO deuda cero, un objeto importante tirado al contenedor, desorden y otro objeto afuera
CUANDO termina la noche con GRAVE ENTONCES registra siete medios, los guarda y permite
continuar. DADO además un ticket aceptado en el inodoro ENTONCES registra ocho medios,
despide y borra el guardado de la partida terminada. Al continuar desde siete, los objetos persistentes vuelven
a poder usarse y una noche impecable sin motivos conserva los siete medios.

### AC-CLN-053 — Extraer una vez con el primario *(verifica BR-CLN-032)*

DADO jornada 5, tacho con bolsa y mano vacía CUANDO se pulsa primario ENTONCES esa identidad
queda sostenida y el tacho sin bolsa, sin aumentar depositadas. CUANDO se vacía la mano y se
repite ENTONCES no entrega nada. DADO otro tacho con bolsa y mano ocupada CUANDO se pulsa
primario ENTONCES conserva bolsa y mano, sin soltar. El secundario no extrae con ninguna mano.

### AC-CLN-054 — De los tres tachos al contenedor *(verifica BR-CLN-032, BR-CLN-007, BR-CLN-009, BR-CLN-011)*

DADO la jornada 5 CUANDO se enfoca cada tacho desde un punto libre del piso dentro del alcance
vigente ENTONCES aparece su contorno y la mira no se detiene en la bolsa. CUANDO se hace clic
izquierdo con la mano vacía ENTONCES la bolsa queda en la mano y desaparece de la boca de ese
tacho. CUANDO se tiran dos al contenedor con la tapa abierta ENTONCES la basura sigue pendiente;
tirar la tercera la cumple y sube el HUD en 1. Repetir la misma identidad no vuelve a sumar.

### AC-CLN-055 — Otros gestos y otras noches conservan el estado *(verifica BR-CLN-032, BR-CLN-007)*

DADO jornadas 1, 4, 6 y 8 CUANDO se pulsa primario o secundario sobre los tres tachos
ENTONCES no sale bolsa ni cambia la mano. DADO jornada 5 CUANDO se pulsa secundario, o
primario con control suspendido, ENTONCES no sale bolsa. DADO mano vacía CUANDO se pulsan
dos primarios seguidos ENTONCES sale sólo una bolsa; mirar otro tacho con ella sostenida no
la devuelve ni extrae la del segundo ni la suelta.

### AC-CLN-056 — Rescatar conserva bolsa y tacho agotado *(verifica BR-CLN-032, BR-CLN-010)*

DADO una bolsa extraída CUANDO la red de seguridad la rescata ENTONCES vuelve a su origen como
cuerpo libre y recogible con izquierdo, con la misma identidad, y el tacho sigue sin bolsa.
CUANDO se recoge y tira al contenedor ENTONCES cuenta una sola vez; usar de nuevo el tacho no
crea otra bolsa.

### AC-CLN-057 — La bolsa pendiente no cruza de noche *(verifica BR-CLN-007, BR-CLN-011, BR-CLN-026)*

DADO la jornada 5 con dos bolsas depositadas y la tercera, por turno, en el tacho, en el piso o
en la mano, CUANDO cierra ENTONCES la basura queda pendiente. CUANDO abre la jornada 6 ENTONCES
la mano está vacía, los tres tachos están sin bolsa y ninguna bolsa está en el mundo.

### AC-CLN-058 — El paso toca sólo el piso *(verifica BR-CLN-013)*

DADO la jornada 4 y después la 5 CUANDO el jugador da un paso al lado de cada mancha de pared, y
debajo de la de techo, ENTONCES ninguna recibe el toque del paso ni ondula. DADO una mancha del
piso de la misma noche CUANDO el jugador da un paso a su lado ENTONCES sí lo recibe.

### AC-CLN-059 — El charco reserva sólo las manchas de la noche *(verifica BR-CLN-024, BR-CLN-013)*

DADO la jornada 4 y la mopa húmeda de agua sin jabón CUANDO se intenta dejar agua sobre el sector
de un lugar del piso que sólo declara la jornada 5 ENTONCES aparece el charco; CUANDO se intenta
sobre el sector de una mancha del piso de la jornada 4, ya limpia, ENTONCES se rechaza. DADO la
jornada 5 ENTONCES vale lo mismo al revés: el sector de un lugar del piso que sólo declara la 4
recibe el charco, y el de una mancha de la 5 lo rechaza. DADO la jornada 1 ENTONCES ningún lugar
del piso reserva su sector.

### AC-CLN-060 — Limpiar se cumple con la última mancha de la noche *(verifica BR-CLN-011, BR-CLN-013, BR-CLN-019)*

DADO la jornada 3 CUANDO se borran 3 de sus 4 manchas ENTONCES limpiar no está cumplida.
CUANDO se borra la cuarta ENTONCES se cumple, una sola vez. DADO la jornada 4 CUANDO se borran
6 de sus 7 manchas ENTONCES no está cumplida. CUANDO se borra la séptima ENTONCES se cumple,
una sola vez. DADO la jornada 5 CUANDO se borran 7 de sus 8 ENTONCES no está cumplida. CUANDO
se borra la octava ENTONCES se cumple, una sola vez. Cada
mancha, también las de pared y la de techo, se borra pasándole la mopa mojada del jabón que pide,
apuntándola con la mira desde un punto libre del piso. Las manchas del mismo tipo en la misma
habitación se borran por separado y cuenta cada una.

### AC-CLN-061 — Sustitución limitada por jornada e identidad *(verifica BR-CLN-033)*

DADO una unidad real de Poético retirada de caja y luego una de góndola, en casos separados,
CUANDO se usa con izquierdo sobre agua sin jabón en jornada 5 ENTONCES tiñe azul y conserva la
unidad. En jornadas 1, 4 y 6 no tiñe ni ofrece «echar jabón». Otro producto renombrado Poético
no tiñe en ninguna jornada. En jornada 5 lavatorio, inodoro y manchas no reciben efecto de Poético.

### AC-CLN-062 — Vacío y teñido rechazan sin caída *(verifica BR-CLN-033, BR-CLN-035)*

DADO jornada 5 y Poético en mano CUANDO se usa sobre balde vacío ENTONCES responde «balde vacío»;
sobre agua azul, rosa o amarilla, «balde ya teñido». En todos los casos permanecen idénticos
agua, mopa, manchas, mano y cantidades de mercadería, sin soltar ni publicar teñido aceptado.
La consulta previa de controles no ejecuta el uso. Un clic aceptado publica una sola operación.

### AC-CLN-063 — La mezcla sustituta limpia sólo moho *(verifica BR-CLN-034, BR-CLN-018, BR-CLN-019, BR-CLN-022)*

DADO jornada 5 y agua teñida con Poético CUANDO se moja la mopa ENTONCES agua y punta muestran
el azul del jabón azul y la carga es la declarada para la mopa. CUANDO se pasa por moho ENTONCES
lo borra; sobre caca y polvo rechaza por jabón equivocado. Los límites de tiempo y recorrido
son los mismos del bidón azul; usar Poético no cambia las manchas declaradas de la jornada.

### AC-CLN-064 — Dos mezclas usan el mismo envase *(verifica BR-CLN-034)*

DADO Poético en mano y balde con agua limpia en jornada 5 CUANDO tiñe, se vacía y rellena el balde
y se vuelve a teñir ENTONCES ambas mezclas se aceptan, la misma unidad sigue en mano y las
cantidades de caja, depósito, góndola y unidades afuera no cambian por los teñidos. No hay venta
ni envase vacío nuevo. Devolver o vender esa unidad conserva el recorrido normal de mercadería.
El bidón azul sigue siendo marca «2», con identidad y envase distintos de Poético.

### AC-CLN-065 — Volver de la ausencia restaura el azul *(verifica BR-CLN-014, BR-CLN-026)*

DADO el azul tirado al contenedor en jornada 4 CUANDO se abre la 5 dos veces ENTONCES sigue
oculto, sin foco ni colisión. CUANDO abre la 6 ENTONCES vuelve a padre, pose, visibilidad y
colisiones originales y puede recogerse; mopa seca y balde vacío. No se restaura Poético como
si fuera un bidón de limpieza.

### AC-CLN-066 — Sólo un uso aceptado publica su identidad *(verifica BR-CLN-035)*

DADO jornada 5 CUANDO Poético tiñe agua limpia ENTONCES se publica un teñido aceptado con la
identidad de Poético. DADO el bidón azul en una jornada disponible CUANDO tiñe ENTONCES el
resultado identifica ese bidón. DADO pausa, examen, cierre, balde vacío o ya teñido ENTONCES
no se publica teñido aceptado ni cambian mano o estados de limpieza.

### AC-CLN-067 — Los seis pares usan el primario y conservan su efecto *(verifica BR-CLN-036, BR-CLN-015, BR-CLN-016, BR-CLN-017, BR-CLN-018, BR-CLN-019, BR-CLN-023)*

DADO balde vacío sobre lavatorio, jabón sobre agua sola, mopa sobre balde con agua,
mopa sobre inodoro, mopa del jabón correcto sobre mancha y balde lleno sobre inodoro,
por turno CUANDO se hace un primario ENTONCES ocurre exactamente llenar, teñir, mojar,
enjuagar, borrar o vaciar respectivamente, con el útil sostenido, las animaciones vigentes
y sin efecto secundario adicional. El secundario no ejecuta ninguno de esos seis usos.

### AC-CLN-068 — El uso rechazado no suelta ni recarga *(verifica BR-CLN-036, BR-CLN-020, BR-CLN-024)*

DADO balde ya lleno al llenar, balde vacío o teñido al teñir, balde vacío al mojar o vaciar,
mopa seca, sin jabón o con jabón incorrecto al limpiar CUANDO se hace primario ENTONCES se
conservan los rechazos vigentes, el útil sigue sostenido y no hay soltado, recarga ni otro
cambio de agua o manchas. DADO mopa con agua sola sobre piso despejado CUANDO se hace
secundario ENTONCES conserva el charco temporal; el primario sin par declarado conserva dejar.

### AC-CLN-069 — El papel se descarta una sola vez por primario *(verifica BR-CLN-036, BR-CLN-030)*

DADO ticket propio sostenido CUANDO se pulsa primario sobre el inodoro ENTONCES se acepta
un descarte, desaparece el papel y se anota un motivo único de papel. Repetir con mano vacía,
un ticket ajeno o ya retirado no agrega descartes ni motivos. DADO ticket sostenido CUANDO
se pulsa secundario ENTONCES no se descarta ni suelta; balde y mopa conservan sus usos sin
anotar papel. La aceptación conserva el medio apercibimiento declarado en BR-CLN-030.

### AC-CLN-070 — Una sola caja en el local no desordena *(verifica BR-CLN-028)*

DADO exactamente una caja en el local, ninguna en baño ni cuartito y el resto en depósito CUANDO
cierra ENTONCES no hay desorden por cajas. DADO dos cajas en el local ENTONCES hay desorden. DADO
una caja apoyada en el baño, aunque sea la única, ENTONCES hay desorden. DADO una caja en el local
y otra apoyada en el baño ENTONCES hay desorden. DADO una caja sostenida y las demás en el depósito
ENTONCES no hay desorden. DADO una caja sostenida dentro del baño y ninguna otra ENTONCES no hay
desorden. DADO una caja sostenida y otra en el local ENTONCES hay desorden: la sostenida es la
única permitida. DADO un útil sostenido y una caja en el local ENTONCES no hay desorden. DADO una
caja en el local sin otras cajas y una unidad suelta ENTONCES hay desorden por la unidad, y el
motivo sigue siendo único.

### AC-CLN-071 — Poético suelto no desordena sólo en su jornada *(verifica BR-CLN-037, BR-CLN-028, BR-CLN-029)*

DADO la jornada en que Poético sustituye al jabón azul y una o varias unidades de Poético sueltas
en local, depósito, baño o cuartito, sin otro cuerpo desordenado, CUANDO cierra ENTONCES no hay
desorden. DADO esa jornada, una unidad de Poético suelta y otra unidad suelta de un producto
distinto CUANDO cierra ENTONCES hay desorden, y el motivo es único. DADO esa jornada y una unidad
de Poético afuera CUANDO cierra ENTONCES no hay desorden y sí el motivo de afuera. DADO esa
jornada, una unidad de Poético suelta y dos cajas en el local ENTONCES hay desorden por las cajas.
DADO la jornada inmediata anterior y la inmediata posterior, cada una con una unidad de Poético
suelta como único cuerpo desordenado, CUANDO cierra ENTONCES hay desorden. DADO esa jornada y una
unidad de Poético sostenida o devuelta a su casillero ENTONCES no hay desorden, igual que con
cualquier unidad. DADO esa jornada y una caja de Poético apoyada en el baño, como única caja,
ENTONCES hay desorden.

## No objetivos

- Esta capacidad NO dibuja: declara de qué color se ven cada mancha, el agua del balde y la punta
  de la mopa, y la escena lo pinta.
- Esta capacidad NO decide qué anomalía ocurre: consume la disponibilidad y sustitución por
  jornada de [`anomalies`](../anomalies/anomalies.md) y resuelve su efecto de limpieza.

## Contratos

- **Entrada:** la jornada que abre, qué se lleva en la mano, sobre qué se usa —una mancha, el balde, el lavatorio,
  el inodoro o piso despejado—, tiempo real y recorrido de la mopa, el permiso de la tapa y
  el gesto primario o secundario, el destino cuerpo/tapa del contenedor,
  el pedido de tirar lo sostenido y el estado físico de los cuerpos al cerrar.
- **Salida:** cómo salió cada uso, qué tiene el balde y la carga restante de la mopa, qué manchas
  quedan, el color de cada cosa, el agua temporal, cuántas bolsas faltan y si cada obligatoria
  está cumplida, qué objeto se tiró y los motivos únicos del cierre.
- **Falla:** ocho motivos de rechazo para limpiar —sin efecto, balde vacío, balde ya lleno, balde
  ya teñido, mopa seca, sin jabón, jabón equivocado y ya limpia (BR-CLN-015 a BR-CLN-020)—;
  mano vacía, no entra y tapa no abierta al tirar; no es basura y ya depositada al contar.
  Ningún rechazo cambia el estado.
- **Tachos:** recibe la jornada, el tacho enfocado y si la mano está vacía; entrega la identidad
  de su única bolsa o ningún objeto. Mano ocupada, tacho sin bolsa o control suspendido no cambian
  nada. Retirar una bolsa cambia la apariencia del tacho, no la cuenta de depositadas.

## Señales

- El balde lleno, teñido con identidad de lo utilizado y vaciado; la mopa mojada; la pasada
  que borra una mancha; el uso rechazado, con su motivo; la bolsa depositada y el objeto tirado.
- La bolsa sacada, sólo cuando un tacho entrega su bolsa.

## Dependencias

- [`player-actions`](../player-actions/player-actions.md) (consume): qué se lleva en la mano,
  sobre qué se usa y qué se tira.
- [`store-stock`](../store-stock/store-stock.md) (alimenta): la unidad tirada deja de estar
  afuera y se descuenta del depósito.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (alimenta y consume): avisa cuándo cada obligatoria quedó
  cumplida; consume si la jornada declara basura para preparar sus tachos y contar sólo esa tarea.

- [`anomalies`](../anomalies/anomalies.md) (consume): qué bidón falta y qué producto puede
  sustituirlo en la jornada.
- [`employment-record`](../employment-record/employment-record.md) (alimenta): el teñido
  aceptado con identidad permite conservar el hecho de uso de Poético para la devolución.

## Preguntas abiertas

- **OQ-CLN-001 — ¿Las manchas aparecen durante la noche o están todas desde el principio?**
  - Por qué sigue abierta: hoy están todas desde la apertura. El GDD no lo dice.
  - Decide: el dueño del repo.
  - Bloquea: nada. Cambiaría `BR-CLN-013`.
- **OQ-CLN-002 — ¿Qué manchas hay en las jornadas 6 a 8?**
  - Por qué sigue abierta: sus filas de la ficha dependen en parte de manchas en el cuartito de
    limpieza, que #541 dejó fuera, y de manchas en el techo del local y del depósito, que hoy quedan
    fuera del alcance de la mira. Hasta entonces, las jornadas 6, 7 y 8 arrancan con las de la 4.
  - Decide: el dueño del repo.
  - Bloquea: nada. Cambiaría `BR-CLN-013`.
