## La cuenta que decide si el turno alcanza, y cuánto sobra para investigar.
##
## La tensión central de *No se fía* es aritmética —cada minuto investigando es un minuto que no
## se dedica a las tareas—, y hasta acá esa aritmética no la afirmaba nadie: la duración del
## turno, los costos y el ritmo los fijan tres archivos que no se nombran entre sí, y los tres
## pueden estar bien por separado con un turno imposible de cumplir. Esto es la balanza.
##
## **Recibe los cuatro números y no importa ninguno**, ni siquiera `Reglas` o `Ritmo`, que son de
## esta misma capa. Es lo que la hace ejercitable con valores inventados: una versión que leyera
## `Reglas.DURACION_DEL_TURNO` adentro sólo se podría probar con el turno real, que es justo el
## caso que no sirve para verificar una resta.
class_name Presupuesto
extends RefCounted


## Lo que sobra del turno después de cumplir las tareas y de caminar lo que haya que caminar.
##
## Es un `float` con signo y no un booleano a propósito: **cuánto** falta o sobra es la
## información con la que se rebalancea, y es lo que hace que el test de balance falle diciendo
## qué tocar y en cuánto en vez de sólo que falló.
##
## `duracion` y `costos` van en segundos de ficción; `segundos_de_trayecto`, en segundos reales
## de reloj de pared, que es la unidad en la que se camina — de ahí que sea el único término que
## pasa por `ritmo`.
static func margen(
	duracion: float, costos: Array[float], segundos_de_trayecto: float, ritmo: float
) -> float:
	var suma_de_costos := 0.0
	# Los costos entran como lista y no como parámetros sueltos para que definir una tarea más
	# no toque este archivo: acá no hay escrito cuántas tareas son.
	for costo: float in costos:
		suma_de_costos += costo
	return duracion - suma_de_costos - ritmo * segundos_de_trayecto


## Si el turno da para cumplir las tareas y todavía queda algo.
##
## La comparación es estricta y el cero es `false`: un turno que se consume exacto cumpliendo y
## caminando no deja un segundo para investigar, y en este juego investigar no es opcional, es
## la mitad del bucle.
static func alcanza(
	duracion: float, costos: Array[float], segundos_de_trayecto: float, ritmo: float
) -> bool:
	return margen(duracion, costos, segundos_de_trayecto, ritmo) > 0.0
