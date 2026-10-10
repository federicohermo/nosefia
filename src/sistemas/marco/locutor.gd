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


func recibir(evento: InputEvent) -> void:
	if _dialogo == null or not evento is InputEventMouseButton:
		return
	var click := evento as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
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
