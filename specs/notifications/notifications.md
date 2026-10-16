---
schema_version: 1
capability_id: CAP-NTF
status: draft
owner: por definir
provenance: GDD «Notificaciones»; ficha «Sistema de investigación (pistas e hipótesis)»; decisiones de los issues 309 y 385
---

# Capacidad: los avisos durante la noche

## Propósito

Hacer visibles la llegada y salida por cansancio de un comprador, el rechazo del lector lleno
y una pista nueva mientras el jugador reparte su atención entre las tareas.
Los avisos acompañan esos sucesos sin cambiar su resultado.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Notificación** | cartel breve con texto y símbolo de un suceso | ventana, diálogo |
| **Tipo** | llegada, salida por cansancio, lectura fallida por renglones llenos o pista nueva | prioridad |
| **Visible** | tipo cuyo tiempo todavía no se agotó | historial |
| **Comprador avisado** | la misma identidad que ya disparó su llegada durante el turno | mismo nombre |
| **Pista nueva** | pista cuyo registro acepta investigación por primera vez y desbloquea una hipótesis | objeto revelado, objeto examinado |

## Comportamiento normativo

### BR-NTF-001 — La llegada avisa una vez

CUANDO llega un comprador no avisado, el sistema DEBE mostrar «¡Hay un cliente!» y recordar su
identidad hasta el cierre del turno. SI esa misma identidad vuelve a llegar, ENTONCES el sistema NO
DEBE crear ni renovar la notificación. Una llegada sin comprador no cambia nada.

### BR-NTF-002 — Sólo el lector lleno avisa

CUANDO el lector rechaza una unidad porque sus tres renglones están llenos, el sistema DEBE mostrar
«No se pudo leer». Un rechazo por no ser un producto y una lectura anotada NO DEBEN crear ni renovar
notificaciones. Con el lector ausente en el programa manual tampoco avisa.

### BR-NTF-003 — Tres segundos en ejecución

El sistema DEBE mantener cada notificación durante tres segundos de juego en ejecución.
La llegada de un comprador con horario usa la excepción de BR-NTF-009.
MIENTRAS el juego está en pausa, el sistema NO DEBE consumir su tiempo. CUANDO el tiempo
alcanza la duración, el sistema DEBE retirar el tipo, también si un solo avance supera el
límite. Un avance de cero o negativo no cambia el estado.

### BR-NTF-004 — Un tipo visible no se duplica

CUANDO se avisa un tipo ya visible, el sistema DEBE dejarlo una sola vez, primero, con sus tres
segundos completos, sin renovar los otros tipos. La llegada del mismo comprador sigue la excepción
de BR-NTF-001 y la persistencia de BR-NTF-009.

### BR-NTF-005 — Los tipos conviven en orden

MIENTRAS hay varios tipos visibles, el sistema DEBE mostrar todos, del más nuevo al más
viejo. Consultar o modificar una copia de la lista de tipos no cambia lo que está visible.

### BR-NTF-006 — El cierre vacía el estado

CUANDO cierra el turno, el sistema DEBE retirar todas las notificaciones y olvidar las identidades
avisadas. La siguiente noche empieza sin avisos de la anterior.

### BR-NTF-007 — El cartel comunica sin tomar el control

El sistema DEBE dibujar los carteles claros en la esquina superior derecha, con el símbolo
del tipo a la izquierda y su texto en mayúsculas a la derecha. Llegada, lectura y pista van sin
punto final; la salida conserva el punto final de su diseño. El comprador
usa la figura con exclamación, el lector usa la cruz y la pista usa el signo de pregunta del diseño.
MIENTRAS computadora, ventanilla u otra interfaz de la jornada están abiertas, incluyendo los diálogos, el cartel
DEBE verse encima y DEBE dejar pasar el clic. El menú
de pausa DEBE dibujarse por encima del cartel.

TODOS los tipos DEBEN presentar su texto en una sola línea, con el tamaño de letra principal
del tema. El contenedor DEBE ajustar su ancho al símbolo, la separación, el texto y sus
márgenes, sin una franja vacía de ancho fijo. Los carteles DEBEN compartir el borde derecho
y centrar verticalmente símbolo y texto, sin recortarlos al cambiar la resolución.

### BR-NTF-008 — El comprador que vence avisa su salida

CUANDO una compra vence, el sistema DEBE mostrar «El cliente se cansó de esperar» una vez por
identidad y jornada. DEBE usar la duración, pausa, orden y deduplicación de los demás avisos.
Una compra completa NO DEBE producirlo. El cierre DEBE olvidar las identidades de salida.

### BR-NTF-009 — La llegada espera a la conversación

EN la primera jornada, el aviso de llegada DEBE permanecer hasta iniciar la conversación con
ese comprador, sin vencer por tiempo. Abrir o cerrar la ventanilla NO DEBE retirarlo.
El primer clic que inicia la conversación DEBE retirarlo una sola vez; reabrir o volver a
hablar NO DEBE recrearlo. Si el comprador vence antes, su salida DEBE retirar la llegada.
Un evento de otra identidad NO DEBE retirar el aviso del comprador que está esperando.
Los avisos de lectura y de cansancio DEBEN conservar su duración. Las jornadas posteriores
conservan el recorrido y duración anteriores hasta que tengan diálogos diseñados.

### BR-NTF-010 — Sólo una pista anotada avisa

CUANDO investigación confirma una pista nueva anotada que desbloquea una hipótesis, el sistema
DEBE mostrar «¡NUEVA PISTA!». El disparador es el registro aceptado, según la
[ficha «Notificaciones»](https://app.notion.com/p/3e486efecd9d808bb505c198429d316d).
Un resultado repetido o desconocido NO DEBE crear ni renovar el aviso.
Revelar o examinar un objeto sin registrar una pista NO DEBE producirlo.

El aviso de pista DEBE usar la duración y pausa de BR-NTF-003, la deduplicación de BR-NTF-004,
el orden de BR-NTF-005, el cierre de BR-NTF-006 y la presentación de BR-NTF-007.
Dos pistas distintas anotadas en el mismo cuadro DEBEN dejar un solo cartel de pista.
Una pista nueva con la pausa abierta DEBE aparecer y conservar sus tres segundos hasta reanudar.

## Criterios de aceptación

### AC-NTF-001 — Identidad y reapertura *(verifica BR-NTF-001, BR-NTF-004)*

DADO un comprador CUANDO llega ENTONCES hay un aviso de llegada. DADO ese aviso con dos segundos
consumidos CUANDO llega el mismo comprador ENTONCES sigue uno solo y sale al consumir el segundo
restante. Si vuelve después de vencido no avisa. Otro comprador sí renueva el tipo, que sigue
visible 2,9 segundos después de esa llegada.

### AC-NTF-002 — Motivo del rechazo *(verifica BR-NTF-002)*

DADO cero avisos CUANDO el lector rechaza por no ser un producto, está ausente o anota una lectura
ENTONCES siguen siendo cero. CUANDO rechaza por sus tres renglones llenos ENTONCES hay exactamente
un aviso de lectura fallida.

### AC-NTF-003 — Antes, en el límite y después *(verifica BR-NTF-003)*

DADO un aviso nuevo CUANDO se consumen 2,9 segundos ENTONCES sigue visible; al completar 3,0
segundos ya no está. Un único avance de diez segundos retira todos los avisos y deja el estado listo
para que uno nuevo dure sus tres segundos completos.

### AC-NTF-004 — Renovar un tipo conserva el otro *(verifica BR-NTF-004, BR-NTF-005)*

DADO dos tipos con dos segundos consumidos CUANDO se avisa otra lectura fallida ENTONCES hay dos
tipos, la lectura fallida primera. Un segundo después la llegada se retiró y queda la lectura
fallida, que todavía sigue visible a los 2,9 segundos desde su renovación.

### AC-NTF-005 — Dos tipos y una copia *(verifica BR-NTF-005)*

DADO el aviso de llegada CUANDO llega el rechazo por lector lleno ENTONCES la lista visible es
lectura fallida, llegada. Vaciar una copia consultada no retira ninguno de los dos.

### AC-NTF-006 — Cerrar y volver a avisar *(verifica BR-NTF-006, BR-NTF-001)*

DADO dos tipos visibles CUANDO cierra el turno ENTONCES hay cero, también en pantalla. Avisar luego
al mismo comprador vuelve a producir su notificación.

### AC-NTF-007 — Entradas sin efecto *(verifica BR-NTF-001, BR-NTF-003)*

DADO cero avisos CUANDO llega un comprador nulo ENTONCES siguen siendo cero. DADO uno con 2,9
segundos consumidos CUANDO se avanza cero o menos diez ENTONCES sigue uno; completar el 0,1 restante
lo retira.

### AC-NTF-008 — La pausa conserva el resto *(verifica BR-NTF-003)*

DADO un aviso con dos segundos consumidos CUANDO se pausa el juego y transcurren cuadros ENTONCES su
procesamiento queda suspendido y el aviso continúa. Al reanudar, 0,9 segundos no lo retiran y
completar el 0,1 restante sí.

### AC-NTF-009 — Texto, símbolos y esquina *(verifica BR-NTF-007)*

DADO llegada, lectura fallida y pista visibles CUANDO se presentan a 1920 × 1080 y 1280 × 720
ENTONCES sus carteles quedan dentro de la esquina superior derecha, sin recorte.
La cruz corresponde a «NO SE PUDO LEER» y
la figura con exclamación a «¡HAY UN CLIENTE!»; el signo de pregunta corresponde a «¡NUEVA PISTA!».
Los tres símbolos están a la izquierda de su texto. Los tres carteles usan la
fuente del tema de Manada y el fondo claro del diseño.

### AC-NTF-010 — Interfaces y clic *(verifica BR-NTF-007)*

DADO un cartel visible y la computadora abierta CUANDO se hace clic en la esquina que ocupa el
cartel ENTONCES el clic llega a la computadora. La pila se dibuja encima de computadora, ventanilla,
diálogos y programa manual; con la lista desplegable real abierta el aviso sigue visible. Al hacer
Esc en esa lista se abre la pausa, sus listas quedan cerradas y el menú de pausa se dibuja encima de
la pila. Reanudar conserva programa, selección y aviso; no reabre las listas automáticamente. Se
comprueba con capturas anteriores a Esc y durante pausa, a ambas resoluciones; comparar sólo los
índices de dibujo no prueba el orden de las ventanas.

### AC-NTF-011 — Vencimiento, duración y renovación *(verifica BR-NTF-008, BR-NTF-003, BR-NTF-004, BR-NTF-005, BR-NTF-006)*

DADO una compra vencida CUANDO se avisa la salida ENTONCES aparece su texto y símbolo, primero.
Repetir esa identidad no renueva. A los 2,9 segundos sigue; a los 3,0 desaparece.
La pausa conserva el resto. Otra identidad renueva el tipo sin duplicarlo ni renovar los otros.
Cerrar y comenzar otra jornada permite avisar otra vez la misma identidad.

### AC-NTF-012 — Espera y primer clic *(verifica BR-NTF-009, BR-NTF-001, BR-NTF-006)*

DADO un comprador de la primera noche CUANDO pasan más de tres segundos, se abre o se cierra
la ventanilla ENTONCES la llegada sigue visible. CUANDO el primer clic inicia su conversación
ENTONCES desaparece; avanzar diálogo y reabrir no la repiten. La salida antes de conversar y el
cierre del turno la retiran. Una identidad distinta no puede ocultarla.

### AC-NTF-013 — Una línea y ancho según el contenido *(verifica BR-NTF-007)*

DADO llegada, lectura fallida, cansancio y pista CUANDO se muestran a 1920 × 1080 y 1280 × 720
ENTONCES cada texto ocupa una sola línea con la letra principal del tema, queda completo
junto al símbolo y su cartel ajusta el ancho al contenido. Los cuatro comparten el borde
derecho dentro de la pantalla; el mensaje más largo ocupa un cartel más ancho.

### AC-NTF-014 — Registro nuevo, repetido y desconocido *(verifica BR-NTF-010)*

DADO cero avisos CUANDO se revela un objeto que no es pista, se repite una pista conocida
o se intenta registrar una desconocida ENTONCES no aparece ningún aviso de pista.
CUANDO investigación acepta una pista nueva ENTONCES aparece exactamente un cartel
«¡NUEVA PISTA!» con el signo de pregunta a su izquierda.
DADO ese aviso con dos segundos consumidos CUANDO se repite la pista o se intenta registrar
una desconocida ENTONCES sigue uno solo y desaparece al consumir el segundo restante.

### AC-NTF-015 — Dos pistas renuevan sólo su tipo *(verifica BR-NTF-010, BR-NTF-003, BR-NTF-004, BR-NTF-005)*

DADO cero avisos CUANDO se anotan dos pistas distintas en el mismo cuadro ENTONCES queda
un solo cartel de pista. DADO un aviso de pista y otro de lectura fallida, ambos con dos
segundos consumidos, CUANDO se anota otra pista nueva ENTONCES la lista es pista, lectura
fallida, sin duplicados. Un segundo después sólo queda pista; sigue visible a los 2,9 segundos
desde su renovación y desaparece al completar 3,0.

DADO cero avisos CUANDO se anota una pista, llega un comprador y el lector rechaza por lleno,
en ese orden y sin avance de tiempo, ENTONCES hay tres carteles: lectura fallida, llegada, pista.

### AC-NTF-016 — Pausa, cierre e interfaces con una pista *(verifica BR-NTF-010, BR-NTF-003, BR-NTF-006, BR-NTF-007)*

DADO el juego pausado CUANDO se anota una pista nueva ENTONCES el cartel aparece debajo del
menú de pausa y conserva sus tres segundos completos aunque transcurran cuadros.
CUANDO se reanuda ENTONCES sigue visible tras 2,9 segundos y desaparece al completar 3,0.
Un único avance de diez segundos también lo retira.

DADO el aviso de pista visible CUANDO se abren computadora, ventanilla o diálogos ENTONCES
el cartel se dibuja encima y el clic atraviesa sus controles hasta la interfaz abierta.
CUANDO se anota una pista justo antes del cierre ENTONCES el cierre retira el cartel;
la siguiente jornada comienza sin ningún aviso heredado.

## No objetivos

- Esta capacidad NO decide cuándo llegan o se despachan compradores ni acepta lecturas.
- Esta capacidad NO decide el abandono del comprador ni qué es una pista o qué hipótesis desbloquea.
- Esta capacidad NO incorpora logros.
- Esta capacidad NO guarda avisos entre sesiones.

## Contratos

- **Entrada:** identidad de quien llega o vence, motivo de lectura, confirmación de pista nueva
  anotada por investigación, tiempo en ejecución y cierre.
- **Salida:** tipos visibles ordenados, texto y símbolo correspondientes.
- **Falla:** identidad nula, motivo que no es lector lleno y tiempo no positivo no cambian nada.
  Una pista repetida o desconocida y una revelación sin pista no crean ni renuevan avisos.

## Señales

- Escucha llegada, vencimiento, rechazo, pista nueva anotada y cierre.
  No emite decisiones a las capacidades que los publican.

## Dependencias

- `counter-service` (consume): comprador llegado o vencido y motivo del rechazo del lector.
- `shift-cycle` (consume): cierre del turno.
- `player-actions` (consume): suspensión del procesamiento durante la pausa.
- [`investigation`](../investigation/investigation.md) (consume): confirmación de pista nueva
  anotada que desbloquea una hipótesis; una revelación de objeto no reemplaza esa confirmación.

## Preguntas abiertas

Ninguna para estos cuatro tipos. Los demás disparadores están fuera de sus objetivos.
