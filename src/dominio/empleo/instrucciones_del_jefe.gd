class_name InstruccionesDelJefe
extends RefCounted

var _cantidad: int
var _a_la_vista: int = 1
var _terminadas: bool = false


class Paso:
	extends RefCounted

	var foto: Mensaje
	var texto: Mensaje


func _init(cantidad: int) -> void:
	_cantidad = cantidad


static func pasos_de(mensajes: Array[Mensaje]) -> Array[Paso]:
	var pasos: Array[Paso] = []
	var indice := 0
	while indice < mensajes.size():
		var paso := Paso.new()
		var mensaje := mensajes[indice]
		if mensaje.foto != null and mensaje.texto.is_empty():
			paso.foto = mensaje
			indice += 1
			if indice < mensajes.size():
				paso.texto = mensajes[indice]
		else:
			paso.texto = mensaje
		pasos.append(paso)
		indice += 1
	return pasos


func a_la_vista() -> int:
	return _a_la_vista


func avanzar() -> void:
	if _terminadas:
		return
	if en_el_ultimo():
		_terminadas = true
	else:
		_a_la_vista += 1


func volver() -> bool:
	if _terminadas or not se_puede_volver():
		return false
	_a_la_vista -= 1
	return true


func se_puede_volver() -> bool:
	return _a_la_vista > 1


func en_el_ultimo() -> bool:
	return _a_la_vista == _cantidad


func terminadas() -> bool:
	return _terminadas
