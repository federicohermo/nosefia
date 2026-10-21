class_name InstruccionesDelJefe
extends RefCounted

var _cantidad: int
var _paso_actual: int = 1
var _terminadas: bool = false


class Paso:
	extends RefCounted

	var fotos: Array[Mensaje] = []
	var textos: Array[Mensaje] = []


func _init(cantidad: int) -> void:
	_cantidad = cantidad


## Sólo una jornada de introducción abre con instrucciones; en las demás, la noche sale directa.
static func de_la_jornada(mensajes: Array[Mensaje], jornada: int) -> Array[Mensaje]:
	var propios: Array[Mensaje] = []
	if (
		jornada < ReglasDeLaPartida.PRIMERA_JORNADA
		or jornada >= ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	):
		return propios
	for mensaje in mensajes:
		if mensaje.jornada == jornada and mensaje.momento == Mensaje.Momento.APERTURA:
			propios.append(mensaje)
	return propios


static func pasos_de(mensajes: Array[Mensaje]) -> Array[Paso]:
	var pasos: Array[Paso] = []
	var indice := 0
	while indice < mensajes.size():
		var paso := Paso.new()
		var mensaje := mensajes[indice]
		if mensaje.foto != null and mensaje.texto.is_empty():
			while (
				indice < mensajes.size()
				and mensajes[indice].foto != null
				and mensajes[indice].texto.is_empty()
			):
				paso.fotos.append(mensajes[indice])
				indice += 1
			if indice < mensajes.size():
				paso.textos.append(mensajes[indice])
		else:
			paso.textos.append(mensaje)
		pasos.append(paso)
		indice += 1
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
