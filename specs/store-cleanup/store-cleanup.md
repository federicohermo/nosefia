---
schema_version: 1
capability_id: CAP-CLN
status: ratified
owner: por definir
provenance: GDD «Limpiar» y «Sacar la basura»; ficha «9. Tarea: Limpieza»; migración de los specs 010, 015, 043; ajustes del dueño sobre duración de la mopa, mezcla, enjuague y agua temporal
---

# Capacidad: dejar el local en orden

## Propósito

Las dos obligatorias que se pagan caminando: borrar las manchas de la jornada y llevar las bolsas
al fondo. Lo único que tienen que hacer bien es **costar recorrido**: una tarea que se cierra con
un clic no le disputa nada a la investigación. Limpiar cuesta ir al baño: cada mancha pide su
jabón, el jabón se mezcla en el balde, y cambiar de jabón es vaciar el balde y volver a llenarlo.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Mancha** | lo que hay que borrar: moho, caca o polvo, en un lugar del local, del depósito o del baño | suciedad |
| **Jabón** | uno de los tres bidones del baño: azul, rosa o amarillo | detergente, producto |
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

El sistema DEBE poner **3 bolsas por jornada**, y ese número DEBE ser mayor que las manos
disponibles. Con una sola mano son tres viajes de ida y vuelta, y no hay forma de hacerlo en uno.

### BR-CLN-008 — El contenedor está lejos

El contenedor del depósito DEBE ser fijo y estar a **6 metros o más** de las tareas del local
y de donde arrancan las bolsas. Esa separación DEBE ser mayor al alcance de la mira.

### BR-CLN-009 — La bolsa cuenta por el tiro al contenedor

CUANDO una bolsa se tira con clic izquierdo al contenedor completamente abierto, el sistema
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

El sistema DEBE tener **tres tipos de mancha**, y a cada uno lo borra **un solo jabón**: al moho,
el azul; a la caca, el rosa; al polvo, el amarillo. Cada tipo DEBE verse de su color —el moho
verde, la caca marrón, y el polvo del local como un charco celeste y transparente—, que es lo
que le dice al jugador qué jabón buscar. El agua del balde también DEBE verse transparente,
conservando el color del jabón cuando está teñida.

### BR-CLN-013 — Las manchas de la jornada

CUANDO se abre una jornada, el sistema DEBE poner **cuatro manchas**: dos de polvo en el local
—en el piso frente a la puerta de entrada y en el piso entre dos góndolas—, una de moho en el
depósito —en una pared, cerca de la puerta al local— y una de caca en el baño —en el piso, al lado
del inodoro—. Todas las jornadas arrancan con esas cuatro, sucias, aunque la noche anterior se
hayan borrado.

### BR-CLN-014 — Los útiles arrancan en el baño

CUANDO se abre una jornada, el sistema DEBE dejar la mopa, el balde y los tres jabones en su
lugar del baño, con el balde vacío y la mopa seca, aunque la noche anterior hayan quedado en otro
lado, en la mano, llenos o mojados. Los cinco se levantan; el lavatorio y el inodoro no.

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

### BR-CLN-025 — Tapa del contenedor de basura

CUANDO abre una jornada, el contenedor DEBE tener la tapa completamente abierta. El clic
derecho sobre el cuerpo o la tapa DEBE alternar abrir y cerrar con cualquier mano, sin cambiar
lo sostenido. Otro derecho durante el giro DEBE invertirlo. La bisagra y la colisión DEBEN
acompañar la tapa y el giro DEBE detenerse ante un objeto sin atravesarlo ni comprimirlo.
Sólo la tapa completamente abierta DEBE permitir recibir objetos; cerrar corta ese permiso
desde el inicio del giro y abrir lo recupera al alcanzar el tope.

### BR-CLN-026 — Tirar consume el izquierdo y retira lo sostenido

CUANDO se hace clic izquierdo sobre cuerpo o tapa completamente abierta con un objeto que
entra, el sistema DEBE retirarlo de la mano y de la jornada: oculto, sin colisión ni foco.
Una caja del depósito NO DEBE entrar. Con mano vacía, caja o tapa cerrada o girando, el gesto
DEBE conservar manos y tarea sin soltar genéricamente. Abrir NO DEBE tirar automáticamente.
Con el jugador suspendido por examen, pausa o cierre, ambos clics NO DEBEN tirar ni alternar.
Al abrir otra noche, los objetos de arranque tirados DEBEN volver a sus padres y poses de
arranque, visibles, físicos y recogibles, con mopa seca, balde vacío y bolsas sin depositar.
Las unidades y tickets tirados DEBEN retirarse con los demás creados en la noche anterior.

### BR-CLN-027 — Pertenencia a las habitaciones

El sistema DEBE distinguir el interior del local, del depósito y del baño, incluidos sus pasos
de acceso, según piso, paredes y techos existentes. Cada habitación DEBE admitir una unión
finita de volúmenes locales sin rellenar huecos, ensanchar pasos ni elevar techos bajos. Un
punto fuera de las tres DEBE clasificarse afuera. Trasladar o rotar el conjunto NO DEBE agrandar
sus interiores ni cambiar la pertenencia de un punto que conserva su posición relativa.

### BR-CLN-028 — El desorden cuenta una vez al cierre

CUANDO termina la jornada, el sistema DEBE anotar un llamado por desorden si queda alguna
unidad suelta dentro de cualquier habitación, una caja dentro y fuera del depósito o un útil
dentro y fuera del baño. El cuerpo sostenido DEBE excluirse por identidad, salvo mientras se
examina: entonces cuenta en su posición física. Lo ya tirado al contenedor DEBE excluirse.
Una bolsa o un ticket adentro no DEBE producir desorden. Varios cuerpos desordenados DEBEN producir un
único motivo. La foto DEBE tomarse antes de registrar el legajo, armar el parte y guardar.

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


## Criterios de aceptación

### AC-CLN-007 — Tres bolsas son más que las manos *(verifica BR-CLN-007)*

DADO las bolsas de la jornada ENTONCES son 3, con identidades distintas, y son más que las manos
disponibles.

### AC-CLN-008 — El viaje llega al contenedor *(verifica BR-CLN-008)*

DADO el almacén armado CUANDO se miden los puntos funcionales de las tareas del local y el
arranque de las tres bolsas ENTONCES el contenedor fijo está en el depósito y a 6 metros o más
de todos ellos, por encima del alcance de la mira. Las posiciones se derivan del local vigente.

### AC-CLN-009 — Soltar no deposita *(verifica BR-CLN-009)*

DADO una bolsa soltada en el piso a menos de 1 metro del contenedor o por su boca física
CUANDO queda suelta ENTONCES no cuenta y se puede recoger. CUANDO después se la tira con clic
izquierdo sobre cuerpo o tapa completamente abierta ENTONCES sí cuenta.


### AC-CLN-011 — El orden y la idempotencia *(verifica BR-CLN-010)*

DADO algo que no es bolsa CUANDO se intenta contarlo ENTONCES se rechaza por «no es basura».
DADO una bolsa ya depositada CUANDO se intenta contar otra vez ENTONCES se rechaza por «ya
depositada» y la cantidad sigue igual.

### AC-CLN-012 — Las dos obligatorias cierran *(verifica BR-CLN-011)*

DADO las cuatro manchas de la jornada borradas ENTONCES limpiar está cumplida; DADO las tres
bolsas depositadas ENTONCES la basura está cumplida; con una sola pendiente en cada caso, no.

### AC-CLN-014 — Cada jabón borra un solo tipo *(verifica BR-CLN-012)*

DADO una mancha de moho, una de caca y una de polvo, y la mopa mojada de cada uno de los tres
jabones ENTONCES de los nueve pares se borran exactamente tres: moho con azul, caca con rosa y
polvo con amarillo.

### AC-CLN-015 — El color de cada mancha *(verifica BR-CLN-012)*

DADO las manchas de la jornada en la escena ENTONCES la de moho se ve verde —el verde es su canal
más alto—, la de caca marrón —rojo sobre verde sobre azul, y oscura— y las dos del local negras,
con el dibujo de polvo de la guía y transparencia entre los trazos que deja ver el piso.

### AC-CLN-016 — Las cuatro de la jornada *(verifica BR-CLN-013)*

DADO una jornada ENTONCES tiene 4 manchas: 2 de polvo, 1 de moho y 1 de caca, ninguna borrada;
DADO todas borradas CUANDO se abre la jornada siguiente ENTONCES son las mismas cuatro, sucias
otra vez.

### AC-CLN-017 — Cada mancha en su lugar *(verifica BR-CLN-013)*

DADO el almacén armado ENTONCES una de polvo está en el piso del local, a menos de 2,5 metros de
la puerta de entrada y del lado de adentro; la otra de polvo, en el piso, entre las dos góndolas
del medio del local; la de moho, en una pared del depósito, a menos de 2,5 metros de la puerta al
local; y la de caca, en el piso del baño, a menos de 1,2 metros del inodoro. Ninguna queda debajo
de un mueble ni tapada: la mira enfoca cada una.

### AC-CLN-018 — Los útiles vuelven al baño *(verifica BR-CLN-014)*

DADO la mopa mojada y soltada en el local, el balde teñido y soltado en el depósito, y un jabón en
la mano CUANDO se abre la jornada siguiente ENTONCES los cinco útiles están en su lugar del baño,
con la mano vacía, el balde vacío y la mopa seca. DADO el lavatorio o el inodoro CUANDO se los
quiere agarrar ENTONCES se rechaza por no levantable.

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

DADO el balde en su ubicación inicial del baño CUANDO se lleva la mopa hasta cualquiera
de las manchas del almacén ENTONCES se agota antes de poder limpiarla, incluso tomando
el trayecto más corto y aprovechando el alcance de interacción. DADO el balde acercado
a la zona de limpieza ENTONCES hay carga suficiente para caminar unos pasos y limpiar.

### AC-CLN-028 — Menor alcance en movimiento *(verifica BR-CLN-022)*

DADO dos mopas recién mojadas CUANDO una recorre metros en el mismo tiempo en que la otra
espera quieta ENTONCES la que caminó tiene menos carga y se agota antes. DADO la mopa quieta
CUANDO transcurre menos que la duración en reposo ENTONCES sigue mojada, y al cumplirla queda
seca. Dividir el trayecto entre cuadros no modifica el resultado ni permite recuperar carga.

### AC-CLN-029 — Enjuague sin cambiar el resto del local *(verifica BR-CLN-023)*

DADO la mopa con cualquiera de los tres jabones, seca o parcialmente gastada CUANDO se usa sobre
el inodoro ENTONCES queda húmeda de agua sin jabón, con carga completa y color de agua limpia;
el balde y las cuatro manchas conservan su estado. DADO un balde con agua sin jabón CUANDO se
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
todos los charcos y conserva únicamente las cuatro manchas propias de la jornada.

### AC-CLN-033 — Mezcla visible sin salto ni reinicio *(verifica BR-CLN-016)*

DADO agua sin jabón CUANDO se acepta un jabón ENTONCES la mezcla empieza con el aspecto previo,
muestra ambos líquidos durante la transición y termina con el color del jabón; el estado del
agua acepta inmediatamente mojar la mopa de ese jabón. Una actualización repetida no reinicia
la transición; un uso rechazado no la dispara. Vaciar o abrir otra jornada cancela la mezcla.

### AC-CLN-034 — Tapa que se abre y se cierra *(verifica BR-CLN-025)*

DADO el contenedor al empezar una jornada ENTONCES tiene la tapa abierta. CUANDO se usa el
cuerpo o la tapa con clic derecho, con mano vacía o cargada, ENTONCES gira hasta cerrarse sin
cambiar la mano; otro derecho invierte el giro hasta abrirse. La tapa y su colisión conservan
la bisagra en ambos estados y durante el movimiento. Abrir otra jornada restaura la tapa
abierta. Dividir el tiempo entre cuadros conserva el giro. Con un objeto en el recorrido de
cierre, la tapa se detiene sin atravesarlo ni comprimirlo; al retirarlo continúa cerrándose.

### AC-CLN-035 — Sólo plenamente abierta recibe *(verifica BR-CLN-025, BR-CLN-026)*

DADO una bolsa sostenida y la tapa cerrada o a mitad de cualquiera de sus giros CUANDO se
pulsa izquierdo sobre cuerpo o tapa ENTONCES la bolsa sigue en la mano y no cuenta. CUANDO
termina de abrir ENTONCES sigue sostenida; un izquierdo posterior la tira. Cerrar desactiva
el permiso desde el inicio del giro.

### AC-CLN-036 — Cada objeto aceptado sale de la jornada *(verifica BR-CLN-026, BR-CLN-009)*

DADO por turno bolsa, mopa, balde, cada jabón, unidad y ticket sostenidos CUANDO se pulsa
izquierdo sobre el contenedor completamente abierto ENTONCES queda mano vacía y el mismo
cuerpo oculto, sin colisión ni foco. Sólo la bolsa aumenta lo depositado.

### AC-CLN-037 — Los dos destinos consumen el gesto *(verifica BR-CLN-026)*

DADO cuerpo y tapa, por turno, con mano vacía, caja sostenida o tapa no abierta CUANDO se
pulsa izquierdo ENTONCES no hay soltar adicional, la carga conserva su padre y la tarea no
cambia. La caja rechazada sigue disponible y la mano vacía sigue vacía.

### AC-CLN-038 — Los tirados vuelven con la noche nueva *(verifica BR-CLN-026, BR-CLN-014)*

DADO mopa mojada, balde teñido y bolsa tirados CUANDO abre otra noche ENTONCES vuelven a sus
padres y lugares originales, visibles, físicos y recogibles; mopa seca, balde vacío y bolsa
sin depositar. DADO un ticket y una unidad tirados ENTONCES se retiran junto con los demás
creados en la noche anterior, sin dejar entradas inválidas en la lista de tirados.
La vuelta conserva el estado físico original: un útil móvil elevado 0,5 m vuelve a caer
y apoyarse. Consultar los descartados entrega una copia independiente y la noche nueva
vacía ese registro, sin leer cuerpos ya liberados.

### AC-CLN-039 — La suspensión bloquea ambos gestos *(verifica BR-CLN-026)*

DADO algo sostenido y el control suspendido por examen, pausa o cierre CUANDO se pulsan
izquierdo y derecho sobre cuerpo o tapa ENTONCES manos, objetos, tarea y tapa siguen iguales.
CUANDO se reanuda ENTONCES el derecho alterna y el izquierdo tira sólo completamente abierta.

### AC-CLN-040 — Interiores, techos y pasos exactos *(verifica BR-CLN-027)*

DADO el almacén al abrir ENTONCES todas las cajas están en depósito, los cinco útiles en baño
y el jugador en local. CUANDO se consultan centros de los pasos ENTONCES pertenecen a su
habitación destino; un punto junto al lateral o sobre un techo bajo queda afuera. DADO una
unión disjunta trasladada y girada 45° ENTONCES sus partes conservan pertenencia y sus huecos
siguen afuera, incluso cuando caen dentro de una envolvente mayor.

### AC-CLN-041 — Suelta no significa visible ni apoyada en el piso *(verifica BR-CLN-028)*

DADO una unidad suelta en local, depósito o baño, incluso agrupada o apoyada en caja o góndola,
CUANDO cierra ENTONCES hay desorden. DADO la unidad colocada, devuelta o sostenida sin examen
ENTONCES no lo produce. El cuerpo de repuesto no cuenta como unidad suelta.

### AC-CLN-042 — Cada clase tiene su habitación *(verifica BR-CLN-027, BR-CLN-028)*

DADO una caja en local CUANDO cierra ENTONCES hay desorden; en depósito o su paso, no.
DADO un útil en local o depósito ENTONCES hay desorden; en baño o su paso, no. DADO una bolsa
adentro ENTONCES no produce desorden. DADO la lista vacía ENTONCES no hay ninguno de los motivos.

### AC-CLN-043 — La mano excluye sólo su cuerpo *(verifica BR-CLN-028, BR-CLN-029)*

DADO dos cajas distintas con los mismos datos y una sostenida CUANDO la otra queda desordenada
o afuera ENTONCES conserva su motivo. DADO el cuerpo sostenido CUANDO inicia un examen real
ENTONCES cuenta por su posición; al terminar vuelve a excluirse. Esto también vale para una
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
lleva 6 medios desde cero antes de armar el parte y escribir el checkpoint. DADO esos cuerpos
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
y contenedor. DADO tickets dentro de local, depósito o baño CUANDO cierra ENTONCES no producen
desorden ni afuera; uno o varios afuera producen un único motivo de afuera. Recuperarlos al
interior o sostenerlos sin examen elimina ese motivo. DADO dos cuerpos con los mismos datos
ENTONCES sólo se excluye el sostenido; un examen real lo hace contar por su posición física
y terminarlo vuelve a excluirlo. Un ticket aceptado por el inodoro se libera sin volver a
consultarlo al cerrar; uno tirado al contenedor sigue vivo y queda excluido por ese destino,
sin anotar papel en el inodoro. Abrir otra noche retira ambos del registro activo.

### AC-CLN-049 — Tres motivos son siete con GRAVE *(verifica BR-CLN-028, BR-CLN-029, BR-CLN-030)*

DADO deuda cero, un ticket aceptado en el inodoro, una caja desordenada y una unidad afuera
CUANDO termina la jornada con GRAVE ENTONCES el cierre registra siete medios antes del parte
y checkpoint y no despide. CUANDO la noche siguiente termina impecable y sin motivos ENTONCES
conserva siete. Un evento durante la placa no contamina esa noche siguiente y repetir el
cierre no suma otra vez.

## No objetivos

- Esta capacidad NO dibuja: declara de qué color se ven cada mancha, el agua del balde y la punta
  de la mopa, y la escena lo pinta.
- Esta capacidad NO saca un jabón en la jornada 2 ni lo cambia por otro producto: la ficha lo
  pide, y depende de las anomalías.

## Contratos

- **Entrada:** qué se lleva en la mano, sobre qué se usa —una mancha, el balde, el lavatorio,
  el inodoro o piso despejado—, tiempo real y recorrido de la mopa, el permiso de la tapa y
  el pedido de tirar lo sostenido y el estado físico de los cuerpos al cerrar.
- **Salida:** cómo salió cada uso, qué tiene el balde y la carga restante de la mopa, qué manchas
  quedan, el color de cada cosa, el agua temporal, cuántas bolsas faltan y si cada obligatoria
  está cumplida, qué objeto se tiró y los motivos únicos del cierre.
- **Falla:** ocho motivos de rechazo para limpiar —sin efecto, balde vacío, balde ya lleno, balde
  ya teñido, mopa seca, sin jabón, jabón equivocado y ya limpia (BR-CLN-015 a BR-CLN-020)—;
  mano vacía, no entra y tapa no abierta al tirar; no es basura y ya depositada al contar.
  Ningún rechazo cambia el estado.

## Señales

- El balde lleno, teñido y vaciado; la mopa mojada; la pasada que borra una mancha; el uso
  rechazado, con su motivo; la bolsa depositada y el objeto tirado.

## Dependencias

- [`player-actions`](../player-actions/player-actions.md) (consume): qué se lleva en la mano,
  sobre qué se usa y qué se tira.
- [`store-stock`](../store-stock/store-stock.md) (alimenta): la unidad tirada deja de estar
  afuera y se descuenta del depósito.
- [`shift-cycle`](../shift-cycle/shift-cycle.md) (alimenta): avisa cuándo cada obligatoria quedó
  cumplida.

## Preguntas abiertas

- **OQ-CLN-001 — ¿Las manchas aparecen durante la noche o están todas desde el principio?**
  - Por qué sigue abierta: hoy están las cuatro desde la apertura. El GDD no lo dice.
  - Decide: el dueño del repo.
  - Bloquea: nada. Cambiaría `BR-CLN-013`.
- **OQ-CLN-002 — ¿Qué manchas hay en las jornadas 2 a 5?**
  - Por qué sigue abierta: la ficha las deja «A definir». Hasta entonces, las cinco jornadas
    arrancan con las cuatro de la primera.
  - Decide: el dueño del repo.
  - Bloquea: nada. Cambiaría `BR-CLN-013`.
