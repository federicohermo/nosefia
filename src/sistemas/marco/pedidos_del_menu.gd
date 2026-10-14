## Lo que pide cada opción del menú de inicio. Es el único lugar del juego que lo cierra.
##
## Emite un solo pedido: el segundo clic llega mientras la escena cambia o el juego se cierra.
class_name PedidosDelMenu
extends Node

signal nuevo_juego_pedido
signal continuar_pedido
signal salir_pedido
signal configuraciones_pedida

var _pidio := false
var _menu: MenuDeInicio
var _guardado: Guardado


func _ready() -> void:
	salir_pedido.connect(_cerrar_el_juego)


func preparar(menu: MenuDeInicio, guardado: Guardado) -> void:
	_menu = menu
	_guardado = guardado


func elegir(opcion: MenuDeInicio.Opcion) -> void:
	if _pidio or not _menu.habilitada(opcion):
		return
	match opcion:
		MenuDeInicio.Opcion.NUEVO_JUEGO:
			_pidio = true
			_guardado.borrar()
			nuevo_juego_pedido.emit()
		MenuDeInicio.Opcion.CONTINUAR:
			_pidio = true
			continuar_pedido.emit()
		MenuDeInicio.Opcion.SALIR:
			_pidio = true
			salir_pedido.emit()
		# No traba el menú: configuraciones se cierra y el menú sigue ahí.
		MenuDeInicio.Opcion.CONFIGURACIONES:
			configuraciones_pedida.emit()


## Vuelve a aceptar un pedido. Sirve cuando la escena no llegó a cambiar.
func rearmar() -> void:
	_pidio = false


func _cerrar_el_juego() -> void:
	get_tree().quit()
