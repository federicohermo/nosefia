## La caja del depósito de la que salen las unidades: se la toca y entrega una para la mano.
##
## Es cáscara y se nota en que no hay una sola condición ni un solo número: cuántas se pueden
## reservar lo sabe `Estante`, y por qué se rechaza lo publica `Repositor`. Acá viven el cuerpo
## del mueble y qué producto despacha.
##
## **Avisa hacia arriba en vez de llamar a nadie**, y por eso no necesita guardarse de un
## cableado nulo: una señal sin escuchas no hace nada, mientras que una llamada a un nodo sin
## cablear muere en el primer cuadro con un error que no nombra al `.tscn`.
##
## **No toca el stock.** Sacar de acá no descuenta nada del depósito: la unidad se mueve recién
## cuando el `Repositor` la coloca en la góndola, y ésa es la invariante entera del spec.
extends StaticBody3D

signal producto_pedido(id: Producto.Id)

## Qué producto despacha esta caja. Es un `Producto.Id` y no un `String` suelto porque el
## conjunto es cerrado: un `"actronsito"` no rompe nada, y el producto simplemente no llega nunca.
@export var producto: Producto.Id = Producto.Id.ACTRONCITO
@export var mallas: Array[MeshInstance3D] = []


## El contrato de «con esto se puede interactuar» es este método más el grupo del `.tscn`, y no
## un tipo: `sistemas/` no puede nombrar un `class_name` de `escenas/` y `dominio/` tampoco.
##
## Devuelve `null` porque de la caja no se levanta nada: quien arma el cuerpo de la unidad es
## `reposicion_manual.gd`, que escucha esta señal.
func interactuar() -> ObjetoDelAlmacen:
	producto_pedido.emit(producto)
	return null
