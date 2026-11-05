class_name GestorDelPedido
extends Node

@export var reloj: RelojDelTurno


## La tarea cuenta mientras el último pedido enviado con wifi sea el de las cajas vacías
## (BR-SHF-032); el reloj rechaza lo que llega con el turno cerrado.
func revisar(pedido: PedidoAlProveedor, vacias: Array[Producto.Id]) -> void:
	var tarea := reloj.obligatoria(Tarea.Tipo.PEDIR_AL_PROVEEDOR)
	if pedido.cumplido(vacias):
		reloj.completar(tarea)
	else:
		reloj.descumplir(tarea)
