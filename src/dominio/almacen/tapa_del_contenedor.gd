## La apertura y el permiso de descarte se ejercen sin levantar una escena.
class_name TapaDelContenedor
extends RefCounted

const ANGULO_ABIERTA := deg_to_rad(78.0)
const VELOCIDAD_DEL_GIRO := 3.0

var _abierta := true
var _angulo := ANGULO_ABIERTA


func alternar() -> void:
	_abierta = not _abierta


func abierta() -> bool:
	return _abierta


func angulo() -> float:
	return _angulo


func angulo_siguiente(segundos: float) -> float:
	return move_toward(_angulo, _destino(), VELOCIDAD_DEL_GIRO * maxf(segundos, 0.0))


func avanzar(segundos: float, paso_libre := true) -> float:
	if paso_libre:
		_angulo = angulo_siguiente(segundos)
	return _angulo


func en_destino() -> bool:
	return is_equal_approx(_angulo, _destino())


func _destino() -> float:
	return ANGULO_ABIERTA if _abierta else 0.0


func recibe_objetos() -> bool:
	return _abierta and is_equal_approx(_angulo, ANGULO_ABIERTA)


func reiniciar() -> void:
	_abierta = true
	_angulo = ANGULO_ABIERTA
