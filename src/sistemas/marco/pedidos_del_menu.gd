## Lo que pide cada opción del menú de inicio. Es el único lugar del juego que lo cierra.
##
## Emite un solo pedido: el segundo clic llega mientras la escena cambia o el juego se cierra.
class_name PedidosDelMenu
extends Node

signal nuevo_juego_pedido
signal salir_pedido

var _pidio := false


func _ready() -> void:
	salir_pedido.connect(_cerrar_el_juego)


func elegir(opcion: MenuDeInicio.Opcion) -> void:
	if _pidio:
		return
	match opcion:
		MenuDeInicio.Opcion.NUEVO_JUEGO:
			_pidio = true
			nuevo_juego_pedido.emit()
		MenuDeInicio.Opcion.SALIR:
			_pidio = true
			salir_pedido.emit()


func _cerrar_el_juego() -> void:
	get_tree().quit()
