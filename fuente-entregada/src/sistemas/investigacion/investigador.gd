class_name Investigador
extends Node

signal pista_nueva(pista: Pista)
signal nota_agregada(mensaje: Mensaje)

var _expediente: Expediente = null
var _enviadas := PackedStringArray()


func usar(recibido: Expediente) -> void:
	if recibido == _expediente:
		return
	if _expediente != null:
		_expediente.pista_nueva.disconnect(_al_anotar)
	_expediente = recibido
	_enviadas.clear()
	if _expediente != null:
		_expediente.pista_nueva.connect(_al_anotar)
		_publicar_notas()


func pedir_pista(
	origen: StringName, canal: Pista.Canal, jornada: int, permitido: bool
) -> Expediente.Resultado:
	if not permitido or _expediente == null:
		return Expediente.Resultado.DESCONOCIDA
	return _expediente.registrar_por_canal(origen, canal, jornada)


func _al_anotar(pista: Pista) -> void:
	_publicar_notas()
	pista_nueva.emit(pista)


func _publicar_notas() -> void:
	for mensaje: Mensaje in _expediente.mensajes_de_notas():
		if not _enviadas.has(mensaje.identidad):
			_enviadas.append(mensaje.identidad)
			nota_agregada.emit(mensaje)
