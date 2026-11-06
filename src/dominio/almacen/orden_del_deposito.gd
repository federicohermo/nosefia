class_name OrdenDelDeposito
extends RefCounted

enum Apoyo { ESTANTERIA, CAJA, LOCAL, OTRO }

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")


class Estado:
	extends RefCounted
	var producto: Producto.Id
	var en_mano: bool
	var apoyo: Apoyo
	var sobre: Producto.Id

	func _init(
		id: Producto.Id,
		mano: bool = false,
		donde: Apoyo = Apoyo.OTRO,
		debajo: Producto.Id = Producto.Id.ACTRONCITO
	) -> void:
		producto = id
		en_mano = mano
		apoyo = donde
		sobre = debajo


## Sigue cada apoyo hasta una estantería. Una caja que no llega la tolera sólo si es la única y
## está en la mano o en el local; una cadena incompleta o apilada sobre ella nunca ordena.
static func ordenadas(estados: Array[Estado]) -> bool:
	var por_producto: Dictionary[Producto.Id, Estado] = {}
	for estado in estados:
		por_producto[estado.producto] = estado
	var fuera: Array[Estado] = []
	for inicio in estados:
		if not _llega_a_una_estanteria(inicio, por_producto):
			fuera.append(inicio)
	if fuera.size() > ReglasDelCierre.CAJAS_TOLERADAS_EN_EL_LOCAL:
		return false
	for caja in fuera:
		if not (caja.en_mano or caja.apoyo == Apoyo.LOCAL):
			return false
	return true


static func _llega_a_una_estanteria(
	inicio: Estado, por_producto: Dictionary[Producto.Id, Estado]
) -> bool:
	var actual := inicio
	var visitadas: Array[Producto.Id] = []
	while true:
		if actual.en_mano:
			return false
		if actual.apoyo == Apoyo.ESTANTERIA:
			return true
		if actual.producto in visitadas or actual.apoyo != Apoyo.CAJA:
			return false
		visitadas.append(actual.producto)
		if not por_producto.has(actual.sobre):
			return false
		actual = por_producto[actual.sobre]
	return false
