class_name CelularDelEmpleado
extends Node

signal celular_abierto
signal celular_cerrado
signal menu_mostrado
signal chat_abierto(quien: Conversacion.Interlocutor)
signal foto_ampliada(foto: Mensaje, adjunto: Mensaje)
signal foto_cerrada
signal no_leidos_cambiados(sin_leer: int)
signal mensaje_recibido(quien: Conversacion.Interlocutor, mensaje: Mensaje)

var _bandeja := Bandeja.new(Conversacion.desde_disco())
var _celular := Celular.new(_bandeja)


func celular() -> Celular:
	return _celular


func bandeja() -> Bandeja:
	return _bandeja


func abrir_jornada(jornada: int) -> void:
	cerrar_jornada()
	_bandeja.abrir_jornada(jornada)
	_celular.habilitar(true)
	no_leidos_cambiados.emit(_bandeja.no_leidos_totales())


func cerrar_jornada() -> void:
	var estaba_abierto := _celular.abierto()
	_celular.habilitar(false)
	if estaba_abierto:
		celular_cerrado.emit()


func pedir_alternar(control_tomado: bool) -> void:
	if not _celular.alternar(control_tomado):
		return
	if _celular.abierto():
		celular_abierto.emit()
		menu_mostrado.emit()
	else:
		celular_cerrado.emit()


func pedir_chat(quien: Conversacion.Interlocutor) -> void:
	if _celular.abrir_chat(quien):
		chat_abierto.emit(quien)
		no_leidos_cambiados.emit(_bandeja.no_leidos_totales())


func pedir_volver() -> void:
	if _celular.volver_al_menu():
		menu_mostrado.emit()


func pedir_foto(indice: int) -> void:
	if _celular.ampliar(indice):
		foto_ampliada.emit(
			_bandeja.mensajes_de(_celular.chat())[indice],
			_bandeja.adjunto_de(_celular.chat(), indice)
		)


func pedir_cerrar_foto() -> void:
	if _celular.cerrar_foto():
		foto_cerrada.emit()


func mostrar_fijo(quien: Conversacion.Interlocutor) -> void:
	var estaba_abierto := _celular.abierto()
	if not _celular.fijar_en(quien):
		return
	if not estaba_abierto:
		celular_abierto.emit()
	chat_abierto.emit(quien)
	no_leidos_cambiados.emit(_bandeja.no_leidos_totales())


func soltar() -> void:
	if _celular.soltar():
		celular_cerrado.emit()


func recibir(quien: Conversacion.Interlocutor, mensaje: Mensaje) -> void:
	if _bandeja.recibir(quien, mensaje):
		mensaje_recibido.emit(quien, mensaje)
		no_leidos_cambiados.emit(_bandeja.no_leidos_totales())
