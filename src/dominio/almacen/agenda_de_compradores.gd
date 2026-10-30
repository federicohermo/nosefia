class_name AgendaDeCompradores
extends RefCounted

enum Tipo { LLEGO, VENCIO }

var _compradores: Array[Comprador] = []
var _llegados: Array[Comprador] = []
var _salidos: Array[Comprador] = []
## Cuándo se retiró cada comprador: al completar su compra o al vencer, lo que pase primero.
var _retiros: Dictionary[Comprador, float] = {}


class Evento:
	extends RefCounted
	var tipo: Tipo
	var comprador: Comprador

	func _init(un_tipo: Tipo, un_comprador: Comprador) -> void:
		tipo = un_tipo
		comprador = un_comprador


func _init(compradores: Array[Comprador]) -> void:
	_compradores.assign(compradores)


func avanzar(tiempo: float, completas: Array[Comprador] = []) -> Array[Evento]:
	var eventos: Array[Evento] = []
	for comprador in _compradores:
		var horario := _horario_de(comprador)
		if horario.x < 0.0:
			continue
		if tiempo >= horario.x and not _llegados.has(comprador):
			_llegados.append(comprador)
			eventos.append(Evento.new(Tipo.LLEGO, comprador))
		if completas.has(comprador) and not _retiros.has(comprador):
			_retiros[comprador] = minf(tiempo, horario.y)
		if tiempo >= horario.y and not _salidos.has(comprador):
			_salidos.append(comprador)
			if not completas.has(comprador):
				_retiros[comprador] = horario.y
				eventos.append(Evento.new(Tipo.VENCIO, comprador))
	return eventos


## Su ventana, o `Vector2(-1, -1)` si todavía no se retiró el comprador del que depende.
func _horario_de(comprador: Comprador) -> Vector2:
	if comprador.llega_tras == null:
		return comprador.horario
	if not _retiros.has(comprador.llega_tras):
		return Vector2(-1.0, -1.0)
	var llegada := _retiros[comprador.llega_tras] + comprador.demora_de_llegada
	return Vector2(llegada, llegada + comprador.permanencia)
