## Pide una escena en otro hilo y avisa cuando está lista o cuando falló.
##
## Cada pedido termina en una sola señal: `lista` o `fallo`. Un pedido con la carga en curso no
## arranca otra.
class_name CargaEnSegundoPlano
extends Node

signal lista(escena: PackedScene)
signal fallo

var _ruta := ""
var _progreso := 0.0


func _init() -> void:
	set_process(false)


## El motor guarda cada pedido hasta que alguien retira la escena. Si el nodo muere antes, la
## retira acá: sin eso, la carga sigue en otro hilo mientras el juego se cierra.
func _notification(que: int) -> void:
	if que == NOTIFICATION_PREDELETE and not _ruta.is_empty():
		ResourceLoader.load_threaded_get(_ruta)


func pedir(ruta: String) -> void:
	if not _ruta.is_empty():
		return
	_ruta = ruta
	_progreso = 0.0
	if ResourceLoader.load_threaded_request(ruta, "PackedScene") != OK:
		_terminar()
		fallo.emit.call_deferred()
		return
	set_process(true)


func progreso() -> float:
	return _progreso


func _process(_delta: float) -> void:
	var avance: Array = []
	var estado := ResourceLoader.load_threaded_get_status(_ruta, avance)
	if estado == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_progreso = avance[0]
		return
	var escena := (
		ResourceLoader.load_threaded_get(_ruta) as PackedScene
		if estado == ResourceLoader.THREAD_LOAD_LOADED
		else null
	)
	_terminar()
	if escena == null:
		fallo.emit()
		return
	_progreso = 1.0
	lista.emit(escena)


func _terminar() -> void:
	_ruta = ""
	set_process(false)
