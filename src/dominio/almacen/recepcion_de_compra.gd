class_name RecepcionDeCompra
extends RefCounted

enum Resultado { BLOQUEADA, RECHAZADA, ACEPTADA, COMPLETA, DIALOGO }

var _pedido: Venta
var _unidades: Array[UnidadDeProducto] = []
var _ticket: Ticket = null


func _init(pedido: Venta) -> void:
	_pedido = pedido


func recibir(objeto: ObjetoDelAlmacen, conversacion_terminada: bool) -> Resultado:
	if not conversacion_terminada or completa():
		return Resultado.BLOQUEADA
	if objeto is UnidadDeProducto:
		var unidad := objeto as UnidadDeProducto
		if _unidades.has(unidad) or pendientes(unidad.producto) <= 0:
			return Resultado.RECHAZADA
		_unidades.append(unidad)
	elif objeto is Ticket:
		if _ticket != null or not _coincide(objeto as Ticket):
			return Resultado.RECHAZADA
		_ticket = objeto as Ticket
	else:
		return Resultado.RECHAZADA
	return Resultado.COMPLETA if completa() else Resultado.ACEPTADA


func pendientes(producto: Producto) -> int:
	if producto == null:
		return 0
	var faltan := _pedido.unidades_de(producto)
	for unidad in _unidades:
		if unidad.producto.id == producto.id:
			faltan -= 1
	return faltan


func unidades() -> Array[UnidadDeProducto]:
	return _unidades.duplicate()


func completa() -> bool:
	if _ticket == null:
		return false
	for producto in _pedido.productos():
		if pendientes(producto) > 0:
			return false
	return true


func _coincide(ticket: Ticket) -> bool:
	var cantidades: Dictionary[Producto.Id, int] = {}
	for producto in ticket.renglones():
		if producto == null or _pedido.unidades_de(producto) == 0:
			return false
		cantidades[producto.id] = cantidades.get(producto.id, 0) + 1
	for producto in _pedido.productos():
		if cantidades.get(producto.id, 0) != _pedido.unidades_de(producto):
			return false
	return true
