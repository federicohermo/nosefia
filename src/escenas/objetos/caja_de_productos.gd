## Caja del dep?sito: pide una unidad para llevar en la mano.
extends StaticBody3D

signal producto_pedido(id: Producto.Id)

## Qué producto despacha esta caja. Es un `Producto.Id` y no un `String` suelto porque el
## conjunto es cerrado: un `"yerva"` no rompe nada, y el producto simplemente no llega nunca.
@export var producto: Producto.Id = Producto.Id.YERBA
@export var mallas: Array[MeshInstance3D] = []


## El repositor entrega la unidad mediante la se?al; el mueble queda fijo.
func interactuar() -> ObjetoDelAlmacen:
	producto_pedido.emit(producto)
	return null
