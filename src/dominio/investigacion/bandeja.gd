## Las lecturas y llegadas pertenecen a esta partida, nunca al recurso compartido del guión.
class_name Bandeja
extends RefCounted

var _conversaciones: Array[Conversacion] = []
var _leidos: Dictionary[Conversacion.Interlocutor, int] = {}
var _leidos_sin_fecha: Dictionary[Conversacion.Interlocutor, int] = {}
var _recibidos: Dictionary[Conversacion.Interlocutor, Array] = {}
var _jornada: int = 1
## Lo de jornadas anteriores a ésta no cuenta como nuevo, esté donde esté la marca de `_leidos`.
var _primera_jornada_nueva: int = 0
var _condiciones: Array[StringName] = []
var _quejas: QuejasDeLaJornada = null


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
	for quien: Conversacion.Interlocutor in _recibidos:
		var siguen: Array = []
		for recibido: Mensaje in _recibidos[quien]:
			if not recibido.de_la_noche:
				siguen.append(recibido)
		_recibidos[quien] = siguen


## Las quejas de la noche: sus mensajes salen de ellas y no de un guión, así que no hay una copia
## que se desactualice. Sin quejas, los chats de los compradores no tienen mensajes.
func usar_quejas(quejas: QuejasDeLaJornada) -> void:
	_quejas = quejas


func conversaciones() -> Array[Conversacion]:
	var visibles: Array[Conversacion] = []
	for conversacion in _conversaciones:
		if (
			conversacion.jornada_de_menu <= _jornada
			and (
				conversacion.abre_sin_mensajes
				or not mensajes_de(conversacion.interlocutor).is_empty()
			)
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
	if _quejas != null:
		for de_la_queja: Mensaje in _quejas.mensajes_de(quien):
			if de_la_queja.jornada <= _jornada:
				todos.append(de_la_queja)
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
	return _posiciones_sin_leer(quien).size()


func no_leidos_totales() -> int:
	var sin_leer := 0
	for conversacion in _conversaciones:
		sin_leer += no_leidos(conversacion.interlocutor)
	return sin_leer


## El lugar, en `mensajes_de`, del primer mensaje sin leer; -1 si el chat está al día.
func primer_no_leido(quien: Conversacion.Interlocutor) -> int:
	var sin_leer := _posiciones_sin_leer(quien)
	return -1 if sin_leer.is_empty() else sin_leer[0]


## Al continuar una partida: sólo cuentan como nuevos los mensajes de `jornada` en adelante. Las
## devoluciones sin jornada tienen la 0, y por eso también quedan leídas.
func dar_por_leidos_los_anteriores_a(jornada: int) -> void:
	_primera_jornada_nueva = jornada


func marcar_leida(quien: Conversacion.Interlocutor) -> bool:
	if not _leidos.has(quien) or no_leidos(quien) == 0:
		return false
	var mensajes := mensajes_de(quien)
	var sin_fecha := _cantidad_sin_fecha(mensajes)
	_leidos[quien] = mensajes.size() - sin_fecha
	_leidos_sin_fecha[quien] = sin_fecha
	return true


func adjunto_de(quien: Conversacion.Interlocutor, indice: int) -> Mensaje:
	var mensajes := mensajes_de(quien)
	if indice < 0 or indice >= mensajes.size() - 1 or mensajes[indice].foto == null:
		return null
	var origen := mensajes[indice]
	for posicion in range(indice + 1, mensajes.size()):
		var siguiente := mensajes[posicion]
		if siguiente.jornada != origen.jornada or siguiente.momento != origen.momento:
			return null
		if siguiente.propio:
			return null
		if origen.texto.is_empty():
			if siguiente.foto != null and siguiente.texto.is_empty():
				continue
		return siguiente if siguiente.foto == null and siguiente.dice_algo() else null
	return null


func pista_de(quien: Conversacion.Interlocutor, identidad: String, tramo: String) -> String:
	if identidad.is_empty():
		return ""
	for mensaje: Mensaje in mensajes_de(quien):
		if mensaje.identidad == identidad:
			return mensaje.pista_del_tramo(tramo)
	return ""


## Las sin fecha van detrás de las fechadas, así que un fechado nuevo las corre: se cuentan aparte
## para que la marca de lectura de las fechadas no se desplace sobre ellas.
func _posiciones_sin_leer(quien: Conversacion.Interlocutor) -> Array[int]:
	var posiciones: Array[int] = []
	var mensajes := mensajes_de(quien)
	var fechados := mensajes.size() - _cantidad_sin_fecha(mensajes)
	var leidos_fechados: int = _leidos.get(quien, 0)
	var leidos_sin_fecha: int = _leidos_sin_fecha.get(quien, 0)
	for posicion in mensajes.size():
		var leido := (
			posicion - fechados < leidos_sin_fecha
			if posicion >= fechados
			else posicion < leidos_fechados
		)
		if not leido and mensajes[posicion].jornada >= _primera_jornada_nueva:
			posiciones.append(posicion)
	return posiciones


static func _cantidad_sin_fecha(mensajes: Array[Mensaje]) -> int:
	var cuantos := 0
	for mensaje in mensajes:
		if mensaje.momento == Mensaje.Momento.SIN_FECHA:
			cuantos += 1
	return cuantos


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
