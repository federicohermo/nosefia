---
schema_version: 1
capability_id: CAP-NTF
status: ratified
owner: por definir
provenance: GDD «Notificaciones»; decisiones del issue 309
---

# Capacidad: los avisos durante la noche

## Propósito

Hacer visibles la llegada y salida por cansancio de un comprador y el rechazo del lector lleno mientras el jugador
reparte su atención entre las tareas. Los avisos acompañan esos sucesos sin cambiar su resultado.

## Lenguaje de la capacidad

| Término | Significado acá | Evitar |
|---|---|---|
| **Notificación** | cartel breve con texto y símbolo de un suceso | ventana, diálogo |
| **Tipo** | llegada, salida por cansancio o lectura fallida por renglones llenos | prioridad |
| **Visible** | tipo cuyo tiempo todavía no se agotó | historial |
| **Comprador avisado** | la misma identidad que ya disparó su llegada durante el turno | mismo nombre |

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
MIENTRAS el juego está en pausa, el sistema NO DEBE consumir su tiempo. CUANDO el tiempo
alcanza la duración, el sistema DEBE retirar el tipo, también si un solo avance supera el
límite. Un avance de cero o negativo no cambia el estado.

### BR-NTF-004 — Un tipo visible no se duplica

CUANDO se avisa un tipo ya visible, el sistema DEBE dejarlo una sola vez, primero, con sus tres
segundos completos, sin renovar los otros tipos. La llegada del mismo comprador sigue la excepción
de BR-NTF-001.

### BR-NTF-005 — Los tipos conviven en orden

MIENTRAS hay varios tipos visibles, el sistema DEBE mostrar todos, del más nuevo al más
viejo. Consultar o modificar una copia de la lista de tipos no cambia lo que está visible.

### BR-NTF-006 — El cierre vacía el estado

CUANDO cierra el turno, el sistema DEBE retirar todas las notificaciones y olvidar las identidades
avisadas. La siguiente noche empieza sin avisos de la anterior.

### BR-NTF-007 — El cartel comunica sin tomar el control

El sistema DEBE dibujar los carteles claros en la esquina superior derecha, con el símbolo
del tipo a la izquierda y su texto en mayúsculas a la derecha. Llegada y lectura van sin punto
final; la salida conserva el punto final de su diseño. El comprador
usa la figura con exclamación y el lector usa la cruz del diseño. MIENTRAS computadora,
ventanilla u otra interfaz de la jornada están abiertas, incluyendo los diálogos, el cartel
DEBE verse encima y DEBE dejar pasar el clic. El menú
de pausa DEBE dibujarse por encima del cartel.

### BR-NTF-008 — El comprador que vence avisa su salida

CUANDO una compra vence, el sistema DEBE mostrar «El cliente se cansó de esperar» una vez por
identidad y jornada. DEBE usar la duración, pausa, orden y deduplicación de los demás avisos.
Una compra completa NO DEBE producirlo. El cierre DEBE olvidar las identidades de salida.

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

DADO los dos tipos visibles CUANDO se presentan a 1920 × 1080 y 1280 × 720 ENTONCES sus carteles
quedan dentro de la esquina superior derecha, sin recorte. La cruz corresponde a «NO SE PUDO LEER» y
la figura con exclamación a «¡HAY UN CLIENTE!», ambas a la izquierda del texto. Los dos usan la
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

## No objetivos

- Esta capacidad NO decide cuándo llegan o se despachan compradores ni acepta lecturas.
- Esta capacidad NO decide el abandono del comprador ni incorpora hipótesis o logros.
- Esta capacidad NO guarda avisos entre sesiones.

## Contratos

- **Entrada:** identidad de quien llega o vence, motivo de lectura, tiempo en ejecución y cierre.
- **Salida:** tipos visibles ordenados, texto y símbolo correspondientes.
- **Falla:** identidad nula, motivo que no es lector lleno y tiempo no positivo no cambian nada.

## Señales

- Escucha llegada, vencimiento, rechazo y cierre. No emite decisiones a las capacidades que los publican.

## Dependencias

- `counter-service` (consume): comprador llegado o vencido y motivo del rechazo del lector.
- `shift-cycle` (consume): cierre del turno.
- `player-actions` (consume): suspensión del procesamiento durante la pausa.

## Preguntas abiertas

Ninguna para estos tres tipos. Los demás disparadores están fuera de sus objetivos.
