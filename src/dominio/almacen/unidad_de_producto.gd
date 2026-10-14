## Una unidad reservada del depósito que se puede llevar y examinar.
class_name UnidadDeProducto
extends ObjetoDelAlmacen

var producto: Producto


func _init(un_producto: Producto = null) -> void:
	producto = un_producto
	if producto != null:
		id = StringName("producto_%d" % producto.id)
		nombre = producto.nombre
		sonoridad = Catalogo.sonoridad_de(producto.id)


## Cada unidad dice el texto de su producto, no su nombre del catálogo.
func texto_al_examinar() -> String:
	if producto == null:
		return ""
	return SubtitulosAlExaminar.de_producto(producto.id)
