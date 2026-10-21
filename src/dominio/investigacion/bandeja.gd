## Las lecturas y llegadas pertenecen a esta partida, nunca al recurso compartido del guión.
class_name Bandeja
extends RefCounted

var _conversaciones: Array[Conversacion] = []
var _leidos: Dictionary[Conversacion.Interlocutor, int] = {}
var _recibidos: Dictionary[Conversacion.Interlocutor, Array] = {}
var _jornada: int = 1
var _condiciones: Array[StringName] = []


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


func abrir_jornada(jornada: int, condiciones: Array[StringName] = []) -> void:
	_jornada = jornada
	_condiciones = condiciones.duplicate()


func conversaciones() -> Array[Conversacion]:
	var visibles: Array[Conversacion] = []
	for conversacion in _conversaciones:
		if (
			conversacion.jornada_de_menu <= _jornada
			and not mensajes_de(conversacion.interlocutor).is_empty()
		):
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
		if mensaje != null and mensaje.jornada <= _jornada and mensaje.vale_para(_condiciones):
			visibles.append(mensaje)
	var fechados: Array[Dictionary] = []
	var sin_fecha: Array[Mensaje] = []
	var todos: Array[Mensaje] = visibles.duplicate()
	for recibido: Mensaje in _recibidos[quien]:
		if recibido.jornada <= _jornada:
			todos.append(recibido)
	for posicion: int in todos.size():
		var mensaje := todos[posicion]
		if mensaje.momento == Mensaje.Momento.SIN_FECHA:
			sin_fecha.append(mensaje)
		else:
			(
				fechados
				. append(
					{
						"mensaje": mensaje,
						"posicion": posicion,
						"orden": mensaje.orden if not mensaje.identidad.is_empty() else posicion,
					}
				)
			)
	fechados.sort_custom(_antes)
	visibles.clear()
	for entrada: Dictionary in fechados:
		visibles.append(entrada.mensaje)
	# El legado conserva su posición previa y su orden: no se reconstruye un cierre sin fecha.
	visibles.append_array(sin_fecha)
	return visibles


func recibir(quien: Conversacion.Interlocutor, mensaje: Mensaje) -> bool:
	if mensaje == null or not _recibidos.has(quien):
		return false
	if not mensaje.identidad.is_empty():
		for recibido: Mensaje in _recibidos[quien]:
			if recibido.identidad == mensaje.identidad:
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


func pista_de(quien: Conversacion.Interlocutor, identidad: String, tramo: String) -> String:
	if identidad.is_empty():
		return ""
	for mensaje: Mensaje in mensajes_de(quien):
		if mensaje.identidad == identidad:
			return mensaje.pista_del_tramo(tramo)
	return ""


static func _antes(a: Dictionary, b: Dictionary) -> bool:
	var uno: Mensaje = a.mensaje
	var otro: Mensaje = b.mensaje
	if uno.jornada != otro.jornada:
		return uno.jornada < otro.jornada
	if uno.momento != otro.momento:
		return uno.momento < otro.momento
	# La posición suple el orden ausente; todos los pares usan la misma clave de comparación.
	if a.orden != b.orden:
		return a.orden < b.orden
	return a.posicion < b.posicion
