## Qué ya se descubrió esta noche, y —lo que importa— si lo que se acaba de ver es nuevo.
##
## Existe por el mordisco del spec 006: examinar dos veces la misma lata no revela nada nuevo y
## el reloj corre igual, así que repetir es tiempo puro perdido. Ese `bool` es de lo que cuelga
## que la revelación se muestre como descubrimiento o como algo ya leído.
##
## No guarda el objeto sino su `id`: dos latas de tomate de la misma góndola son dos `Resource`
## distintos y el mismo secreto, y con la instancia como identidad el jugador cobraría el mismo
## hallazgo tantas veces como latas haya en la estantería.
class_name Hallazgos
extends RefCounted

var _vistos: Dictionary = {}


## Devuelve `true` **sólo si es la primera vez**.
##
## Lo que no revela nada —`null`, o un objeto sin revelación— no es un hallazgo y tampoco mueve
## la cuenta: examinar un cajón vacío no puede sumar al total de lo descubierto.
func registrar(objeto: ObjetoDelAlmacen) -> bool:
	if objeto == null or not objeto.tiene_revelacion():
		return false
	if _vistos.has(objeto.id):
		return false
	_vistos[objeto.id] = true
	return true


## La misma pregunta sin registrar nada: la hace la vista para decidir si lo que muestra es un
## descubrimiento. Si preguntarlo lo registrara, mirar el HUD marcaría el hallazgo como visto.
func ya_visto(objeto: ObjetoDelAlmacen) -> bool:
	return objeto != null and _vistos.has(objeto.id)


func cantidad() -> int:
	return _vistos.size()
