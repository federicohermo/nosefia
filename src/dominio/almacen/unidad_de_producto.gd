## Una unidad reservada del depósito que se puede llevar y examinar.
class_name UnidadDeProducto
extends ObjetoDelAlmacen

var producto: Producto


func _init(un_producto: Producto = null) -> void:
	producto = un_producto
	if producto != null:
		id = StringName("producto_%d" % producto.id)
		nombre = producto.nombre
