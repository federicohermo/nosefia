class_name Locutor
extends Node

signal entrada_mostrada(entrada: String)
signal dialogo_cerrado

var _dialogo: Dialogo = null


func abrir(dialogo: Dialogo) -> bool:
	if _dialogo != null or dialogo == null or dialogo.terminado():
		return false
	_dialogo = dialogo
	entrada_mostrada.emit(_dialogo.entrada_actual())
	return true


## El diálogo avanza con el clic izquierdo, o con X del joystick, que es la acción de aceptar.
func recibir(evento: InputEvent) -> void:
	if _dialogo == null or not _es_avanzar(evento):
		return
	if _dialogo.avanzar():
		entrada_mostrada.emit(_dialogo.entrada_actual())
	else:
		cerrar()


func puede_abandonar() -> bool:
	return _dialogo == null or _dialogo.puede_abandonar()


func cerrar() -> bool:
	if _dialogo == null or not _dialogo.puede_abandonar():
		return false
	_dialogo = null
	dialogo_cerrado.emit()
	return true


static func _es_avanzar(evento: InputEvent) -> bool:
	var click := evento as InputEventMouseButton
	if click != null:
		return click.button_index == MOUSE_BUTTON_LEFT and click.pressed
	return evento is InputEventJoypadButton and evento.is_action_pressed(&"ui_accept")
