class_name OrdenDelDeposito
extends RefCounted

enum Apoyo { ESTANTERIA, CAJA, OTRO }


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


## Sigue cada apoyo hasta una estantería o una mano; una cadena incompleta nunca ordena.
static func ordenadas(estados: Array[Estado]) -> bool:
	var por_producto: Dictionary[Producto.Id, Estado] = {}
	for estado in estados:
		por_producto[estado.producto] = estado
	for inicio in estados:
		var actual := inicio
		var visitadas: Array[Producto.Id] = []
		while not actual.en_mano and actual.apoyo != Apoyo.ESTANTERIA:
			if actual.producto in visitadas or actual.apoyo != Apoyo.CAJA:
				return false
			visitadas.append(actual.producto)
			if not por_producto.has(actual.sobre):
				return false
			actual = por_producto[actual.sobre]
	return true
