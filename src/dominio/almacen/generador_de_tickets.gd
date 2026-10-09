## El programa anota unidades y copia sus renglones al papel.
class_name GeneradorDeTickets
extends RefCounted

enum Resultado { ANOTADO, NO_ES_PRODUCTO, LLENO }

const RENGLONES := 3

var _renglones: Array[Producto] = []


func anotar(objeto: ObjetoDelAlmacen) -> Resultado:
	var unidad := objeto as UnidadDeProducto
	if unidad == null or unidad.producto == null:
		return Resultado.NO_ES_PRODUCTO
	if _renglones.size() == RENGLONES:
		return Resultado.LLENO
	_renglones.append(unidad.producto)
	return Resultado.ANOTADO


func renglones() -> Array[Producto]:
	return _renglones.duplicate()


func borrar() -> void:
	_renglones.clear()


func imprimir() -> Ticket:
	if _renglones.is_empty():
		return null
	return Ticket.new(_renglones)
