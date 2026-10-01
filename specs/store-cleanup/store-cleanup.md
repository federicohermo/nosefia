---
schema_version: 1
capability_id: CAP-CLN
status: ratified
owner: por definir
provenance: GDD «Limpiar» y «Sacar la basura»; ficha «9. Tarea: Limpieza»; migración de los specs 010, 015, 043
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
| **Inodoro** | donde se vacía el balde | — |
| **Útiles** | la mopa, el balde y los tres jabones: lo que se levanta para limpiar | herramientas |
| **Pasada** | pasar la mopa por una mancha | — |
| **Bolsa** | una unidad de basura que hay que llevar al descarte | residuo |
| **Descarte** | el fondo, y el único lugar donde una bolsa cuenta | contenedor, tacho |

## Comportamiento normativo

### BR-CLN-007 — Tres bolsas y una mano

El sistema DEBE poner **3 bolsas por jornada**, y ese número DEBE ser mayor que las manos
disponibles. Con una sola mano son tres viajes de ida y vuelta, y no hay forma de hacerlo en uno.

### BR-CLN-008 — El descarte está lejos

El descarte DEBE estar a **6 metros o más** de las tareas del local y de donde arrancan las
bolsas, y esa distancia DEBE ser mayor al alcance de la mira.

### BR-CLN-009 — La bolsa cuenta sólo adentro de la zona

SI la bolsa se suelta fuera del radio del descarte —**1,5 metros**—, ENTONCES el sistema DEBE
rechazar el depósito y **no quemar la bolsa**: la misma bolsa adentro de la zona sí deposita. El
borde entra.

### BR-CLN-010 — Los tres rechazos de depositar, en orden

CUANDO se deposita, el sistema DEBE rechazar por **no es basura** primero, por **ya depositada**
después, y por **fuera de la zona** al final. Los dos primeros son propiedades de la cosa y del
estado; el último es el único que depende de dónde está parado el jugador.

### BR-CLN-011 — Cada obligatoria cierra con lo suyo

CUANDO no queda una sola mancha, el sistema DEBE dar limpiar por cumplida. CUANDO no queda una
sola bolsa adentro, DEBE dar la basura por cumplida. Las dos se comparan contra lo que la noche
declaró y nunca contra un número escrito.

### BR-CLN-012 — Cada mancha pide su jabón

El sistema DEBE tener **tres tipos de mancha**, y a cada uno lo borra **un solo jabón**: al moho,
el azul; a la caca, el rosa; al polvo, el amarillo. Cada tipo DEBE verse de su color —el moho
verde, la caca marrón, el polvo negro o gris—, que es lo que le dice al jugador qué jabón buscar.

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

### BR-CLN-016 — El jabón tiñe el agua

CUANDO se usa un jabón sobre el balde, SI el balde tiene agua sin jabón, ENTONCES el sistema DEBE
teñirla de ese jabón, y el agua DEBE verse del color del jabón. SI el balde está vacío, ENTONCES
DEBE rechazarlo por **balde vacío**. SI el agua ya está teñida —del mismo jabón o de otro—,
ENTONCES DEBE rechazarlo por **balde ya teñido** y dejar el color que tenía.

### BR-CLN-017 — El balde se vacía en el inodoro

CUANDO se usa el balde sobre el inodoro, SI tiene agua, ENTONCES el sistema DEBE vaciarlo, con
jabón o sin él. SI está vacío, ENTONCES DEBE rechazarlo por **balde vacío**. Cambiar de jabón es
vaciar el balde y volver a llenarlo.

### BR-CLN-018 — La mopa se moja de lo que tiene el balde

CUANDO se usa la mopa sobre el balde, SI el balde tiene agua, ENTONCES el sistema DEBE dejar la
mopa mojada de lo mismo —agua sola, o agua con su jabón—, aunque antes estuviera mojada de otra
cosa, y su punta DEBE verse del color del agua. Mojar la mopa no gasta el agua del balde. SI el
balde está vacío, ENTONCES DEBE rechazarlo por **balde vacío** y dejar la mopa como estaba.

### BR-CLN-019 — Sólo el jabón que corresponde borra

CUANDO se pasa la mopa por una mancha, SI la mopa está mojada del jabón que borra esa mancha,
ENTONCES el sistema DEBE borrar la mancha, y la mopa DEBE seguir mojada: con una mojada se borran
todas las manchas de ese jabón. SI no, ENTONCES DEBE rechazar la pasada sin cambiar nada, en este
orden: **ya limpia**, si la mancha ya se borró; **mopa seca**; **sin jabón**, si está mojada de
agua sola; y **jabón equivocado**.

### BR-CLN-020 — Cada uso contesta qué pasó

CUANDO se usa lo que se lleva sobre una mancha, el balde, el lavatorio o el inodoro, el sistema
DEBE contestar lo que hizo o por qué no hizo nada. SI el par no es uno de los gestos de limpiar
—otro objeto en la mano, o la mano vacía—, ENTONCES DEBE contestar **sin efecto** y no cambiar
nada.

### BR-CLN-021 — Limpiar se puede dejar por la mitad

MIENTRAS dura la jornada, el sistema DEBE conservar qué tiene el balde, de qué está mojada la mopa
y qué manchas quedan. Cambian sólo con los gestos de esta capacidad: soltar un útil, llevarlo a
otro cuarto o hacer otra tarea no los toca.

## Criterios de aceptación

### AC-CLN-007 — Tres bolsas son más que las manos *(verifica BR-CLN-007)*

DADO las bolsas de la jornada ENTONCES son 3, con identidades distintas, y son más que las manos
disponibles.

### AC-CLN-008 — El fondo está lejos *(verifica BR-CLN-008)*

DADO las posiciones del descarte, de las tareas del local y de las bolsas en la escena ENTONCES
ninguna está a menos de 6 metros del descarte, y 6 es mayor al alcance de la mira.

### AC-CLN-009 — El borde de la zona *(verifica BR-CLN-009)*

DADO una bolsa soltada a exactamente 1,5 metros del centro ENTONCES se deposita; a 1,6 metros, el
resultado es «fuera de la zona» y la misma bolsa se puede depositar después adentro.

### AC-CLN-010 — El radio de la escena es el de la regla *(verifica BR-CLN-009)*

DADO la zona de descarte de la escena ENTONCES su radio es el mismo número que declara la regla.

### AC-CLN-011 — El orden de los rechazos *(verifica BR-CLN-010)*

DADO algo que no es una bolsa, soltado fuera de la zona ENTONCES el resultado es «no es basura»;
DADO una bolsa ya depositada, soltada fuera de la zona, es «ya depositada».

### AC-CLN-012 — Las dos obligatorias cierran *(verifica BR-CLN-011)*

DADO las cuatro manchas de la jornada borradas ENTONCES limpiar está cumplida; DADO las tres
bolsas en el descarte ENTONCES la basura está cumplida; con una sola pendiente en cada caso, no.

### AC-CLN-014 — Cada jabón borra un solo tipo *(verifica BR-CLN-012)*

DADO una mancha de moho, una de caca y una de polvo, y la mopa mojada de cada uno de los tres
jabones ENTONCES de los nueve pares se borran exactamente tres: moho con azul, caca con rosa y
polvo con amarillo.

### AC-CLN-015 — El color de cada mancha *(verifica BR-CLN-012)*

DADO las manchas de la jornada en la escena ENTONCES la de moho se ve verde —el verde es su canal
más alto—, la de caca marrón —rojo sobre verde sobre azul, y oscura— y las de polvo grises —los
tres canales a menos de 0,05 entre sí—.

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
borra la otra de polvo sin volver al balde. DADO una mancha ya borrada CUANDO se pasa la mopa
seca ENTONCES el resultado es «ya limpia».

### AC-CLN-024 — Lo que no es un gesto de limpiar *(verifica BR-CLN-020)*

DADO la mano vacía, o una bolsa en la mano CUANDO se usa sobre una mancha, sobre el balde, sobre
el lavatorio o sobre el inodoro ENTONCES el resultado es «sin efecto» y el balde, la mopa y las
manchas siguen como estaban.

### AC-CLN-025 — La mezcla espera *(verifica BR-CLN-021)*

DADO el balde teñido de azul y la mopa mojada de azul CUANDO se sueltan en otro cuarto, se agarra
y se suelta otra cosa y se los vuelve a agarrar ENTONCES el balde sigue teñido de azul y la mopa
mojada de azul; DADO una mancha borrada, sigue borrada.

## No objetivos

- Esta capacidad NO mide distancias: las recibe ya medidas. El dominio no sabe de física.
- Esta capacidad NO dibuja: declara de qué color se ven cada mancha, el agua del balde y la punta
  de la mopa, y la escena lo pinta.
- Esta capacidad NO saca un jabón en la jornada 2 ni lo cambia por otro producto: la ficha lo
  pide, y depende de las anomalías.

## Contratos

- **Entrada:** qué se lleva en la mano, sobre qué se usa —una mancha, el balde, el lavatorio o el
  inodoro— y a qué distancia del descarte se soltó la bolsa.
- **Salida:** cómo salió cada uso, qué tiene el balde y de qué está mojada la mopa, qué manchas
  quedan, el color de cada cosa, cuántas bolsas faltan, y si cada obligatoria está cumplida.
- **Falla:** ocho motivos de rechazo para limpiar —sin efecto, balde vacío, balde ya lleno, balde
  ya teñido, mopa seca, sin jabón, jabón equivocado y ya limpia (BR-CLN-015 a BR-CLN-020)— y tres
  para la basura (BR-CLN-009 y BR-CLN-010), cada uno con su motivo. Ninguno cambia el estado.

## Señales

- El balde lleno, teñido y vaciado; la mopa mojada; la pasada que borra una mancha; el uso
  rechazado, con su motivo; y la bolsa depositada.

## Dependencias

- [`player-actions`](../player-actions/player-actions.md) (consume): qué se lleva en la mano,
  sobre qué se usa y a qué distancia se soltó.
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
- **OQ-CLN-003 — ¿Qué textura tiene cada tipo de mancha?**
  - Por qué sigue abierta: la ficha le da una textura a cada tipo, para cuando la paranoia apague
    los colores, y el arte todavía no tiene texturas de manchas. Por decisión del usuario del
    2026-09-29, mientras tanto las tres son la misma mancha teñida de su color.
  - Decide: el dueño del repo, con el arte.
  - Bloquea: nada. Cambiaría cómo se distingue cada tipo en `BR-CLN-012`.
