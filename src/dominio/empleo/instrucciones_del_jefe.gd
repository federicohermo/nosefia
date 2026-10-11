class_name InstruccionesDelJefe
extends RefCounted

var _cantidad: int
var _paso_actual: int = 1
var _terminadas: bool = false


class Paso:
	extends RefCounted

	var foto: Mensaje
	var textos: Array[Mensaje] = []


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
				paso.textos.append(mensajes[indice])
		else:
			paso.textos.append(mensaje)
		pasos.append(paso)
		indice += 1
	if pasos.size() >= 4:
		# Figma reúne los cuatro primeros párrafos en dos pantallas.
		pasos[0].textos.append_array(pasos[1].textos)
		pasos[2].textos.append_array(pasos[3].textos)
		pasos[2].foto = pasos[3].foto
		pasos.remove_at(3)
		pasos.remove_at(1)
	return pasos


func paso_actual() -> int:
	return _paso_actual


func avanzar() -> void:
	if _terminadas:
		return
	if en_el_ultimo():
		_terminadas = true
	else:
		_paso_actual += 1


func volver() -> bool:
	if _terminadas or not se_puede_volver():
		return false
	_paso_actual -= 1
	return true


func se_puede_volver() -> bool:
	return _paso_actual > 1


func en_el_ultimo() -> bool:
	return _paso_actual == _cantidad


func terminadas() -> bool:
	return _terminadas
