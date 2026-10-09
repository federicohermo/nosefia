class_name AgendaDeCompradores
extends RefCounted

enum Tipo { LLEGO, VENCIO }

var _compradores: Array[Comprador] = []
var _llegados: Array[Comprador] = []
var _salidos: Array[Comprador] = []
var _presente: Comprador = null


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
		if tiempo >= comprador.horario.x and not _llegados.has(comprador):
			_llegados.append(comprador)
			_presente = comprador
			eventos.append(Evento.new(Tipo.LLEGO, comprador))
		if tiempo >= comprador.horario.y and not _salidos.has(comprador):
			_salidos.append(comprador)
			if _presente == comprador:
				_presente = null
			if not completas.has(comprador):
				eventos.append(Evento.new(Tipo.VENCIO, comprador))
	return eventos


func presente() -> Comprador:
	return _presente
