## Las lecturas y llegadas pertenecen a esta partida, nunca al recurso compartido del guión.
class_name Bandeja
extends RefCounted

var _conversaciones: Array[Conversacion] = []
var _leidos: Dictionary[Conversacion.Interlocutor, int] = {}
var _recibidos: Dictionary[Conversacion.Interlocutor, Array] = {}
var _jornada: int = 1


func _init(conversaciones: Array[Conversacion]) -> void:
	for conversacion in conversaciones:
		if conversacion == null or _leidos.has(conversacion.interlocutor):
			continue
		_conversaciones.append(conversacion)
		_leidos[conversacion.interlocutor] = 0
		_recibidos[conversacion.interlocutor] = []
	_conversaciones.sort_custom(
		func(a: Conversacion, b: Conversacion) -> bool: return a.interlocutor < b.interlocutor
	)


func abrir_jornada(jornada: int) -> void:
	_jornada = jornada


func conversaciones() -> Array[Conversacion]:
	var visibles: Array[Conversacion] = []
	for conversacion in _conversaciones:
		if not mensajes_de(conversacion.interlocutor).is_empty():
			visibles.append(conversacion)
	return visibles


func conversacion_de(quien: Conversacion.Interlocutor) -> Conversacion:
	for conversacion in _conversaciones:
		if conversacion.interlocutor == quien:
			return conversacion
	return null


func mensajes_de(quien: Conversacion.Interlocutor) -> Array[Mensaje]:
	var visibles: Array[Mensaje] = []
	var conversacion := conversacion_de(quien)
	if conversacion == null:
		return visibles
	for mensaje in conversacion.mensajes:
		if mensaje != null and mensaje.jornada <= _jornada:
			visibles.append(mensaje)
	visibles.append_array(_recibidos[quien])
	return visibles


func recibir(quien: Conversacion.Interlocutor, mensaje: Mensaje) -> bool:
	if mensaje == null or not _recibidos.has(quien):
		return false
	_recibidos[quien].append(mensaje)
	return true


func esta_leida(quien: Conversacion.Interlocutor) -> bool:
	return _leidos.has(quien) and no_leidos(quien) == 0


func no_leidos(quien: Conversacion.Interlocutor) -> int:
	return maxi(0, mensajes_de(quien).size() - _leidos.get(quien, 0))


func no_leidos_totales() -> int:
	var sin_leer := 0
	for conversacion in _conversaciones:
		sin_leer += no_leidos(conversacion.interlocutor)
	return sin_leer


func marcar_leida(quien: Conversacion.Interlocutor) -> bool:
	if not _leidos.has(quien) or no_leidos(quien) == 0:
		return false
	_leidos[quien] = mensajes_de(quien).size()
	return true


func adjunto_de(quien: Conversacion.Interlocutor, indice: int) -> Mensaje:
	var mensajes := mensajes_de(quien)
	if indice < 0 or indice >= mensajes.size() - 1 or mensajes[indice].foto == null:
		return null
	var siguiente := mensajes[indice + 1]
	return siguiente if siguiente.foto == null and siguiente.dice_algo() else null
