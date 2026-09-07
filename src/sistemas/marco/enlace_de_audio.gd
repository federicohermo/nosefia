## Ata las señales del juego a los sonidos de la tabla, **sin nombrar una sola clase**.
##
## Qué señal dispara qué evento es un dato de la fila, así que este archivo recibe una lista de
## fuentes, les pregunta al motor qué señales declaran y conecta las que coinciden. Es lo que
## desacopla el audio de los otros siete specs: si una señal todavía no existe, su fila **queda
## sin fuente y se declara** en vez de romper nada.
##
## **La aridad se lee del motor.** `get_signal_list()` informa los argumentos de cada señal, así
## que una tabla de aridades escrita a mano se desincronizaría el día que una señal gane un
## parámetro — y el síntoma sería una conexión que falla recién en runtime.
class_name EnlaceDeAudio
extends Node

signal enlace_terminado(enlazados: int, sin_fuente: int)

## Entra por `@export` y no como autoload: está medido que `gate_de_capas.py` no ve un autoload
## nombrado por su nombre global.
@export var reproductor: ReproductorDeSonidos

var _tabla: TablaDeSonidos = null
var _enlazados: Array = []
var _sin_fuente: Array = []


func arrancar(tabla: TablaDeSonidos) -> void:
	_tabla = tabla


## Los eventos que quedaron atados a una señal de verdad.
func enlazados() -> Array:
	return _enlazados.duplicate()


## Los eventos cuya señal no la declara ninguna de las fuentes. **Es un estado normal**: el timbre
## del comprador no tiene quién lo toque hasta que un spec lo escriba, y el ambiente del local no
## lo dispara ninguna señal.
func sin_fuente() -> Array:
	return _sin_fuente.duplicate()


## Recorre el `enum` entero y conecta lo que se pueda.
##
## Es idempotente: llamarlo dos veces no duplica una conexión ni una fila de los dos rubros, y de
## eso se agarra el cableado para poder rehacer el enlace al abrir cada jornada sin que el mismo
## sonido se pida dos veces por evento.
func enlazar_todo(fuentes: Array) -> void:
	_enlazados = []
	_sin_fuente = []
	if _tabla == null or reproductor == null:
		push_error("Enlace de audio sin cablear: revisar audio_del_almacen.gd")
		return
	for evento: EntradaSonora.Evento in EntradaSonora.Evento.values():
		if _enlazar(evento, fuentes):
			_enlazados.append(evento)
			continue
		_sin_fuente.append(evento)
	enlace_terminado.emit(_enlazados.size(), _sin_fuente.size())


## Ata un evento a la primera fuente que declare su señal, y devuelve si lo ató.
func _enlazar(evento: EntradaSonora.Evento, fuentes: Array) -> bool:
	var entrada := _tabla.de(evento)
	if entrada == null or not entrada.tiene_fuente() or not entrada.es_valida():
		return false
	for fuente: Object in fuentes:
		if fuente == null or not fuente.has_signal(entrada.senal):
			continue
		var destino := _pedir.bind(evento)
		var argumentos := _aridad_de(fuente, entrada.senal)
		if argumentos > 0:
			# `unbind()` descarta los argumentos que la señal manda y este método no usa. Sin él,
			# conectar una señal de dos parámetros a un método de uno falla **en runtime**, que
			# es justo cuando ya no hay nadie mirando.
			destino = destino.unbind(argumentos)
		if not fuente.is_connected(entrada.senal, destino):
			fuente.connect(entrada.senal, destino)
		return true
	return false


## Cuántos argumentos manda esa señal, según el motor.
func _aridad_de(fuente: Object, senal: StringName) -> int:
	for declarada: Dictionary in fuente.get_signal_list():
		if declarada.get("name", "") == String(senal):
			var argumentos: Array = declarada.get("args", [])
			return argumentos.size()
	return 0


func _pedir(evento: EntradaSonora.Evento) -> void:
	reproductor.pedir(evento)
