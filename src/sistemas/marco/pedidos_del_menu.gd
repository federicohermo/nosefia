## Lo que pide cada opción del menú de inicio. Es el único lugar del juego que lo cierra.
##
## Emite un solo pedido: el segundo clic llega mientras la escena cambia o el juego se cierra.
class_name PedidosDelMenu
extends Node

signal nuevo_juego_pedido
signal continuar_pedido
signal confirmacion_pedida
signal salir_pedido

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
			if _menu.nuevo_juego_pide_confirmacion():
				confirmacion_pedida.emit()
			else:
				confirmar_nuevo_juego()
		MenuDeInicio.Opcion.CONTINUAR:
			_pidio = true
			continuar_pedido.emit()
		MenuDeInicio.Opcion.SALIR:
			_pidio = true
			salir_pedido.emit()


## Recién acá se borra el guardado: cancelar la confirmación no pasa por esta función.
func confirmar_nuevo_juego() -> void:
	if _pidio:
		return
	_pidio = true
	_guardado.borrar()
	nuevo_juego_pedido.emit()


func _cerrar_el_juego() -> void:
	get_tree().quit()
