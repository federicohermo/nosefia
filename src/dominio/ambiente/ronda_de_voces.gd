## A qué voz le toca el sonido siguiente.
##
## Es aritmética pura: no sabe qué es un reproductor ni qué suena — el nombre de ese nodo del
## motor no se escribe acá ni en un comentario, y hay un caso que lo verifica. Reparte por turno y
## vuelve al principio, que es lo que evita que dos sonidos seguidos se pisen en la misma voz —el
## segundo cortaría al primero— sin tener que preguntar cuál está libre, que en headless no se
## puede contestar: está medido que el estado de reproducción
## nunca cambia con el driver dummy.
class_name RondaDeVoces
extends RefCounted

## Cuántas voces tiene el local para los sonidos que no van en bucle.
##
## Ocho es un primer valor y el piso importa: con menos de cinco, cinco pedidos seguidos se
## pisarían entre ellos y no habría cómo distinguir un sonido perdido de uno que nunca se pidió.
## El bucle no gasta ninguna — tiene la suya.
const VOCES_DEL_LOCAL := 8

var _voces: int
var _proxima: int = 0


func _init(voces: int) -> void:
	_voces = maxi(voces, 0)


func voces() -> int:
	return _voces


## El índice de la voz que sigue, o `-1` si no hay ninguna.
##
## El `-1` no es un caso del juego: es el que evita que una ronda vacía divida por cero y se lleve
## puesta la corrida entera. Quien lo recibe no ocupa ninguna voz.
func siguiente() -> int:
	if _voces <= 0:
		return -1
	var indice := _proxima
	_proxima = (_proxima + 1) % _voces
	return indice
