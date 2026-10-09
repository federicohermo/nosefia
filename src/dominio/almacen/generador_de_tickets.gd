## El programa anota unidades y copia sus renglones al papel.
class_name GeneradorDeTickets
extends RefCounted

enum Resultado { ANOTADO, NO_ES_PRODUCTO, LLENO, SIN_LECTOR }

const RENGLONES := 3
const JORNADA_SIN_LECTOR := 3

var _renglones: Array[Producto] = []
var _manual := false


func _init() -> void:
	_renglones.resize(RENGLONES)


func anotar(objeto: ObjetoDelAlmacen) -> Resultado:
	if _manual:
		return Resultado.SIN_LECTOR
	var unidad := objeto as UnidadDeProducto
	if unidad == null or unidad.producto == null:
		return Resultado.NO_ES_PRODUCTO
	var vacio := _renglones.find(null)
	if vacio == -1:
		return Resultado.LLENO
	_renglones[vacio] = unidad.producto
	return Resultado.ANOTADO


func renglones() -> Array[Producto]:
	var llenos: Array[Producto] = []
	for producto in _renglones:
		if producto != null:
			llenos.append(producto)
	return llenos


func borrar() -> void:
	_renglones.fill(null)


func imprimir() -> Ticket:
	var llenos := renglones()
	if llenos.is_empty():
		return null
	return Ticket.new(llenos)


static func para_la_jornada(jornada: int) -> GeneradorDeTickets:
	var generador := GeneradorDeTickets.new()
	generador._manual = jornada >= JORNADA_SIN_LECTOR
	return generador


func es_manual() -> bool:
	return _manual


func elegir(renglon: int, producto: Producto) -> bool:
	if not _manual or renglon < 0 or renglon >= RENGLONES:
		return false
	_renglones[renglon] = producto
	return true


func en_el_renglon(renglon: int) -> Producto:
	return _renglones[renglon] if renglon >= 0 and renglon < RENGLONES else null
