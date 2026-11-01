## El impulso con que el jugador patea una unidad de producto que está en el piso.
##
## Es una cuenta sin estado: de la velocidad del jugador y de dónde está la unidad sale a qué
## costado del camino se corre y con cuánta velocidad. Quien la aplica es el cuerpo del jugador.
class_name Patada
extends RefCounted

## Provisional: cuánto se corre la unidad no lo fija nadie todavía (OQ-PLY-006), y lo calibra el
## dueño jugando. Es la fracción de la velocidad del jugador que recibe la unidad, y tiene que
## dejarla a menos de lo que alcanza la mira. Con 1 saldría disparada; con 0 no se movería.
const FRACCION_DE_LA_VELOCIDAD := 0.5


## Devuelve la velocidad horizontal que se le suma a `objeto`, o cero si no se patea.
##
## `posicion_relativa` es dónde está `objeto` respecto del jugador. Con el jugador quieto, o con
## algo que no es una unidad de producto, no hay patada. La unidad se corre hacia el costado del
## camino —el lado en que está— y nunca hacia adelante: así el jugador la deja atrás.
static func impulso(
	velocidad: Vector3, posicion_relativa: Vector3, objeto: ObjetoDelAlmacen
) -> Vector3:
	if not objeto is UnidadDeProducto:
		return Vector3.ZERO
	var camino := Vector3(velocidad.x, 0.0, velocidad.z)
	if camino.is_zero_approx():
		return Vector3.ZERO
	var costado := Vector3(-camino.z, 0.0, camino.x).normalized()
	# Justo sobre el camino no hay lado que elegir, y se corre hacia la derecha de quien camina.
	var lado := -1.0 if posicion_relativa.dot(costado) < 0.0 else 1.0
	return costado * lado * camino.length() * FRACCION_DE_LA_VELOCIDAD
