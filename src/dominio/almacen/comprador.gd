## Quién viene a la ventanilla: cómo se llama, qué pide y con cuánto paga.
##
## Un comprador no hace nada, **es** — igual que `Producto`. Cuánto marca la caja, si hay stock y
## cómo se despacha son de `Atencion`; acá no hay una sola cuenta.
##
## **El pedido es una `Venta` del 005 y se guarda por referencia**, no copiado: con una copia,
## `Inventario.cobrar()` descontaría contra un pedido y la pantalla mostraría otro, los dos con
## las mismas líneas hasta que alguien agregue una — y ahí se separan sin un solo error.
##
## **Lo que paga es un `int`**, como todo el dinero del juego: un `float` dejaría diferencias de
## un centavo que el jugador no puede ver y que ninguna aserción de igualdad caza. Puede no
## coincidir con el total, y ésa es la mitad del spec que no es una tarea: es el único lugar
## donde el juego puede mentir en vivo.
class_name Comprador
extends RefCounted

var _nombre: String
var _pedido: Venta
var _paga: int


## Los argumentos van con prefijo para no sombrear los campos que asignan.
func _init(un_nombre: String, un_pedido: Venta, lo_que_paga: int) -> void:
	_nombre = un_nombre
	_pedido = un_pedido
	_paga = lo_que_paga


func nombre() -> String:
	return _nombre


func pedido() -> Venta:
	return _pedido


func paga() -> int:
	return _paga
