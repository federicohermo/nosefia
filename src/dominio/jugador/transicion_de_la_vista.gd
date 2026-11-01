## Cómo se mueve la vista entre la altura de pie y la agachado.
##
## Es estático y no guarda estado, como `RetornoDeLaMano`: la altura de ahora vive en quien la
## mueve. Eso es lo que deja invertir el movimiento a mitad de camino sin una regla aparte: se
## parte de la altura que haya, y se va hacia el otro destino.
class_name TransicionDeLaVista
extends RefCounted


## La altura para el cuadro que viene. Recorre el trecho entero entre las dos posturas en
## `DURACION_DEL_AGACHE`, a paso parejo, y no se pasa del destino.
##
## `delta` entra como parámetro y no se lee del motor: así se prueba sin una escena, y la duración
## es la misma a 60 cuadros por segundo que a 144.
static func siguiente(actual: float, destino: float, delta: float) -> float:
	var trecho := ReglasDelJugador.ALTURA_DE_LA_CAMARA - ReglasDelJugador.ALTURA_AGACHADO
	return move_toward(actual, destino, trecho / ReglasDelJugador.DURACION_DEL_AGACHE * delta)
