## La planilla de registrar: cuántas unidades de cada producto anotó el jugador como vendidas.
class_name RegistroDeVentas
extends RefCounted

const TOPE_POR_FILA := 99

var _atender: TareaDeAtender
var _productos: Array[Producto] = []

var _unidades_por_id: Dictionary = {}


func _init(productos: Array[Producto], atender: TareaDeAtender) -> void:
	_atender = atender
	for producto in productos:
		if producto == null or _unidades_por_id.has(producto.id):
			continue
		_productos.append(producto)
		_unidades_por_id[producto.id] = 0


func productos() -> Array[Producto]:
	return _productos.duplicate()


func sumar(producto: Producto) -> bool:
	return _mover(producto, 1)


func restar(producto: Producto) -> bool:
	return _mover(producto, -1)


func unidades_de(producto: Producto) -> int:
	if producto == null:
		return 0
	var unidades: int = _unidades_por_id.get(producto.id, 0)
	return unidades


func total() -> int:
	var suma := 0
	for producto in _productos:
		suma += producto.precio * unidades_de(producto)
	return suma


func coincide() -> bool:
	for producto in _productos:
		if unidades_de(producto) != _atender.vendidas_de(producto):
			return false
	return true


func _mover(producto: Producto, paso: int) -> bool:
	if producto == null or not _unidades_por_id.has(producto.id):
		return false
	var nuevas := unidades_de(producto) + paso
	if nuevas < 0 or nuevas > TOPE_POR_FILA:
		return false
	_unidades_por_id[producto.id] = nuevas
	return true
