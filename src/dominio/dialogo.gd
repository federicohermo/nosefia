class_name Dialogo
extends RefCounted

enum Clase { CONVERSACION, PENSAMIENTO }

var _entradas: PackedStringArray
var _clase: Clase
var _indice: int = 0
var _ultima: String = ""


func _init(entradas: PackedStringArray = [], clase: Clase = Clase.CONVERSACION) -> void:
	_entradas = entradas.duplicate()
	_clase = clase
	_ultima = entrada_actual()


func entrada_actual() -> String:
	return "" if terminado() else _entradas[_indice]


func ultima_entrada_mostrada() -> String:
	return _ultima


func avanzar() -> bool:
	if terminado():
		return false
	_indice += 1
	if terminado():
		return false
	_ultima = entrada_actual()
	return true


func terminado() -> bool:
	return _indice >= _entradas.size()


func puede_abandonar() -> bool:
	return _clase == Clase.PENSAMIENTO or terminado()
