---
schema_version: 1
capability_id: CAP-INV
status: draft
owner: por definir
provenance: GDD «Investigación» y «La computadora»; migración de los specs 006, 009, 018
---

# Capacidad: la investigación

## Propósito

Darle al minuto que no se paga algo que comprar. Lo único que tiene que hacer bien es
**acumular**: lo que se descubre una noche tiene que seguir descubierto la siguiente, y repetir
no puede rendir. Sin eso, se puede pasar la noche examinando latas y al cierre no cambió nada.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Revelación** | lo que un objeto esconde y sólo se ve al examinarlo | secreto, lore |
| **Hallazgo** | la primera vez que se ve una revelación. La segunda no lo es | descubrimiento |

## Comportamiento normativo

### BR-INV-001 — Examinar revela, mirar no

El sistema DEBE mostrar la revelación de un objeto **sólo al examinarlo**. Un objeto sin nada
abajo contesta lo mismo las dos veces. Si la revelación se viera sin examinar, examinar no
costaría tiempo.

### BR-INV-002 — Una revelación en blanco no revela

SI el texto de la revelación está vacío o es sólo espacios, ENTONCES el sistema DEBE tratarla
como si no existiera. El jugador pagó el minuto igual.

### BR-INV-003 — Repetir no rinde

CUANDO se examina un objeto ya visto, el sistema DEBE decir que no es un hallazgo nuevo y no
mover la cuenta. La identidad es la del objeto y no la de la instancia: dos latas iguales de la
misma góndola son el mismo secreto.

### BR-INV-004 — Preguntar no registra

El sistema DEBE ofrecer preguntar si algo ya se vio **sin marcarlo como visto**. Si preguntarlo
lo registrara, mirar la pantalla cerraría el hallazgo.

### BR-INV-005 — La computadora tiene tres apps

El sistema DEBE ofrecer **caja, chats y notas**. La caja es tarea del jefe y las otras dos son
investigación: es lo que pone las dos puntas de la tensión a un clic una de otra.

### BR-INV-006 — La computadora no cobra tiempo

Abrir la computadora o cambiar de app NO DEBE descontar un segundo del turno. Lo que cuesta es
que el reloj no se detuvo mientras el jugador leía.

### BR-INV-007 — Reabrir vuelve donde se dejó

CUANDO se cierra y se vuelve a abrir la computadora, el sistema DEBE mostrar la última app
elegida. Con la computadora cerrada, cambiar de app no hace nada: reabrir en una app que el
jugador nunca eligió sería un salto.

### BR-INV-008 — Lo leído es de la partida, no del guión

El sistema DEBE llevar **fuera del guión de cada conversación** qué está leído. Una marca adentro
del guión sobrevive a la partida entera: el jugador empezaría la noche dos con todo leído.

### BR-INV-009 — Leer un chat es leerlo entero

CUANDO se abre una conversación, el sistema DEBE dejarla en cero mensajes sin leer, y DEBE llevar
la cuenta **por interlocutor**. Con un contador global, leer al jefe apagaría el aviso de los
otros.

### BR-INV-010 — Una nota sin título no se guarda

SI el título está vacío o es sólo espacios, ENTONCES el sistema DEBE rechazar la nota. Un renglón
sin título es una entrada que el jugador no va a poder encontrar después. El cuerpo sí puede
estar vacío.

### BR-INV-011 — El cuaderno y la bandeja no son de la pantalla

El sistema DEBE conservar lo anotado y lo leído al cambiar de app o cerrar la computadora.

### BR-INV-017 — Pensar no clava al jugador

MIENTRAS se muestra lo que reveló algo no levantable, el sistema DEBE dejar al jugador irse. Es
un pensamiento, no un examen.

### BR-INV-018 — Se examina lo enfocado sin agarrarlo

CUANDO se pide examinar con las manos vacías y la mira sobre un levantable, el sistema DEBE
acercarlo a la cara, retener al jugador y revelar, igual que con lo que se lleva. Examinarlo NO
DEBE llenar las manos. Con algo en la mano, se examina lo que se lleva.

CUANDO termina ese examen, el sistema DEBE devolver el objeto a donde estaba: el mismo lugar, la
misma orientación, y el mismo estado de física y de colisión.

### BR-INV-019 — Lo examinado gira a pedido

MIENTRAS se examina algo, el sistema DEBE girarlo con las teclas de movimiento: los costados
sobre el eje vertical, adelante y atrás sobre el horizontal, a una velocidad fija por segundo.
El mouse DEBE girarlo sólo mientras se arrastra con el clic apretado. Sin tecla y sin arrastre,
lo examinado NO DEBE girar.

El jugador termina el examen sólo con la tecla de examinar. Durante el examen, el clic NO DEBE
terminarlo, ni agarrar, ni soltar, ni colocar.

### BR-INV-020 — La jornada nueva no hereda un examen

CUANDO se abre una jornada con un examen en curso, el sistema DEBE terminarlo antes de vaciar
las manos. Lo del mundo vuelve a su lugar, lo que se llevaba queda a los pies, y el jugador no
queda retenido.

## Criterios de aceptación

### AC-INV-001 — Examinar revela *(verifica BR-INV-001)*

DADO un objeto con revelación CUANDO se lo mira sin examinar ENTONCES se lee sólo su nombre; al
examinarlo, el nombre y el texto.

### AC-INV-002 — El texto en blanco no cuenta *(verifica BR-INV-002)*

DADO un objeto con una revelación de un espacio CUANDO se lo examina ENTONCES se lee sólo el
nombre y no es un hallazgo.

### AC-INV-003 — La segunda vez no suma *(verifica BR-INV-003)*

DADO un objeto ya examinado CUANDO se lo examina otra vez ENTONCES no es un hallazgo nuevo y la
cuenta sigue en 1.

### AC-INV-004 — Dos objetos con la misma identidad *(verifica BR-INV-003)*

DADO dos instancias con la misma identidad CUANDO se examinan las dos ENTONCES la cuenta es 1.

### AC-INV-005 — Consultar no marca *(verifica BR-INV-004)*

DADO un objeto sin examinar CUANDO se pregunta dos veces si ya se vio ENTONCES las dos contestan
que no, y la cuenta sigue en 0.

### AC-INV-006 — Las tres apps *(verifica BR-INV-005)*

DADO la computadora ENTONCES sus apps son exactamente caja, chats y notas.

### AC-INV-007 — Abrir no descuenta *(verifica BR-INV-006)*

DADO un turno entero CUANDO se abre la computadora y se cambia de app ENTONCES el turno no bajó
un solo segundo.

### AC-INV-008 — Reabrir vuelve a la última app *(verifica BR-INV-007)*

DADO la computadora abierta en chats CUANDO se cierra y se vuelve a abrir ENTONCES está en chats;
y con la computadora cerrada, cambiar de app no cambia nada.

### AC-INV-009 — Lo leído no vive en el guión *(verifica BR-INV-008)*

DADO una conversación leída CUANDO se la vuelve a cargar de disco en otra partida ENTONCES está
sin leer.

### AC-INV-010 — Leer apaga sólo su pestaña *(verifica BR-INV-009)*

DADO tres conversaciones con mensajes sin leer CUANDO se lee una ENTONCES ésa queda en 0 y las
otras dos conservan los suyos.

### AC-INV-011 — La nota sin título se rechaza *(verifica BR-INV-010)*

DADO un título de sólo espacios CUANDO se escribe la nota ENTONCES no se guarda y el cuaderno
sigue con las que tenía; con título y cuerpo vacío, se guarda.

### AC-INV-012 — Cambiar de app no borra *(verifica BR-INV-011)*

DADO dos notas escritas y un chat leído CUANDO se cambia de app y se vuelve ENTONCES las notas
siguen y el chat sigue leído.

### AC-INV-019 — El pensamiento no retiene *(verifica BR-INV-017)*

DADO lo que reveló algo no levantable, de una sola entrada, CUANDO todavía no se avanzó
ENTONCES ya se puede abandonar.

### AC-INV-020 — Examinar sin agarrar *(verifica BR-INV-018)*

DADO las manos vacías y la mira sobre un levantable CUANDO se pide examinar ENTONCES está en
examen, el jugador queda retenido, se revela, y las manos siguen vacías. DADO algo en la mano y
la mira sobre otro levantable ENTONCES se examina lo que se lleva.

### AC-INV-021 — Lo examinado vuelve a su lugar *(verifica BR-INV-018)*

DADO un levantable del mundo en examen, girado CUANDO se pide examinar otra vez ENTONCES está
en el mismo lugar, con la misma orientación y el mismo estado de física y de colisión de antes. Una tercera vez lo vuelve a examinar, y no es hallazgo.

### AC-INV-022 — Las teclas giran lo examinado *(verifica BR-INV-019)*

DADO algo en examen CUANDO se aprieta el costado derecho medio segundo ENTONCES gira sobre el
eje vertical la velocidad fija por medio segundo, y adelante lo gira sobre el horizontal. Sin
entrada, o con dos teclas opuestas, no gira.

### AC-INV-023 — El mouse gira sólo arrastrando *(verifica BR-INV-019)*

DADO algo en examen CUANDO se mueve el mouse sin clic ENTONCES no gira; con el clic apretado,
gira.

### AC-INV-024 — El clic no cierra el examen *(verifica BR-INV-019)*

DADO algo en examen CUANDO se hace clic ENTONCES sigue en examen y las manos no cambian. La
tecla de examinar lo termina.

### AC-INV-025 — La jornada abre sin examen *(verifica BR-INV-020)*

DADO un examen en curso CUANDO se abre la jornada ENTONCES no hay nada en examen y el jugador no
está retenido. Sin examen en curso, no se avisa que terminó un examen.

## No objetivos

- Esta capacidad NO escribe el contenido: qué revela cada objeto y qué dice cada chat es
  contenido, y entra como dato.
- Esta capacidad NO descuenta tiempo del turno.

## Contratos

- **Entrada:** el objeto examinado, la entrada de movimiento y los segundos del cuadro, el
  arrastre del mouse, la app elegida, la conversación abierta, y el título y el
  cuerpo de una nota.
- **Salida:** el texto visible, si fue hallazgo, cuántos mensajes sin leer hay y las notas.
- **Falla:** una revelación vacía y una nota sin título se rechazan sin cambiar nada.

## Señales

- El hallazgo nuevo y la computadora abierta.

## Dependencias

- [`player-actions`](../player-actions/player-actions.md) (consume): qué objeto se está
  examinando.

## Preguntas abiertas

Ninguna.
