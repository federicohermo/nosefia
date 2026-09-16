## Cuánto de lo que contesta el brazo se aplica en un cuadro.
##
## El `SpringArm3D` del jugador contesta a qué distancia hay lugar para lo que se lleva, y esa
## respuesta salta de golpe: pasar por la esquina de un mueble la manda al mínimo y la devuelve
## al máximo en dos cuadros. Seguirla al pie se ve como una ráfaga. Acá se decide cuánto se
## recorre por vez.
##
## **La ida y la vuelta no son simétricas, y es deliberado.** Meter la mano contra el cuerpo es
## instantáneo, porque suavizarlo dejaría lo que se lleva adentro de la madera justo el rato que
## dura el suavizado — que es el problema que el brazo existe para tapar. Lo que se suaviza es
## sacarla, donde no hay nada que atravesar.
##
## Es estático y no guarda estado: el largo de cada mano vive en quien la mueve. Guardarlo acá
## obligaría a una instancia por brazo y a acordarse de limpiarla.
class_name RetornoDeLaMano
extends RefCounted

## Cuánto tarda la vuelta en recorrer dos tercios de lo que le falta, en segundos.
const TIEMPO_DE_VUELTA := 0.12


## El largo del brazo para el cuadro que viene.
##
## `delta` entra como parámetro y no se lee del motor, que es lo que hace que esto se pueda
## probar sin levantar una escena. Y entra en la exponencial en vez de multiplicar un paso fijo:
## sin eso la mano volvería al doble de velocidad a 120 cuadros por segundo que a 60.
static func siguiente(actual: float, libre: float, delta: float) -> float:
	# Un `0.0` no es «no hay lugar»: es que el brazo todavía no barrió. Está medido de los dos
	# lados —el barrido solapado se descarta y devuelve el largo entero, y el brazo contesta
	# cero hasta el primer cuadro de física—, así que el cero sólo puede ser eso.
	if libre <= 0.0:
		return actual
	if libre <= actual:
		return libre
	return lerpf(actual, libre, 1.0 - exp(-delta / TIEMPO_DE_VUELTA))
