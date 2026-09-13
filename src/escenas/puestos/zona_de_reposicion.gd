## El foco y el clic comparten el mismo casillero amplio.
extends StaticBody3D

signal colocacion_pedida(producto: Producto.Id)

@export var producto: Producto.Id
@export var mallas: Array[MeshInstance3D] = []
@export var material_de_foco: Material


func interactuar() -> ObjetoDelAlmacen:
	colocacion_pedida.emit(producto)
	return null
