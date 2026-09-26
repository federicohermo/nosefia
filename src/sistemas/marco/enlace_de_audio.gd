## Ata las señales del juego a los sonidos de la tabla, **sin nombrar una sola clase**.
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


## Los eventos cuya señal no la declara ninguna de las fuentes. **Es un estado normal**: el
## ambiente del local no lo dispara ninguna señal, así que su fila la deja vacía.
##
## Vacía, y no con el nombre de una señal que todavía no existe: un nombre inventado cae acá
## igual, en silencio y para siempre. Hay un caso que verifica que cada señal de la tabla la
## declare alguien de verdad.
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
	for fuente: Object in fuentes:
		if _conectar(evento, fuente):
			return true
	return false


## Conecta la señal del evento en esa fuente, si la declara, y devuelve si quedó conectada.
##
## El sonido recibe los dos primeros argumentos de la señal: el origen —el objeto que lo produjo—
## y un detalle, como la rapidez de un contacto. `unbind()` descarta el resto. Sin él, conectar
## una señal de tres parámetros a un método de tres falla **en runtime**, que es justo cuando ya
## no hay nadie mirando.
func _conectar(evento: EntradaSonora.Evento, fuente: Object) -> bool:
	var entrada := _tabla.alguna_de(evento)
	if entrada == null or not entrada.tiene_fuente() or not entrada.es_valida():
		return false
	if fuente == null or not fuente.has_signal(entrada.senal):
		return false
	var argumentos := _aridad_de(fuente, entrada.senal)
	var destino: Callable
	match argumentos:
		0:
			destino = _al_emitir.bind(null, null, evento)
		1:
			destino = _al_emitir.bind(null, evento)
		2:
			destino = _al_emitir.bind(evento)
		_:
			destino = _al_emitir.bind(evento).unbind(argumentos - 2)
	if not fuente.is_connected(entrada.senal, destino):
		fuente.connect(entrada.senal, destino)
	return true


## Cuántos argumentos manda esa señal, según el motor.
func _aridad_de(fuente: Object, senal: StringName) -> int:
	for declarada: Dictionary in fuente.get_signal_list():
		if declarada.get("name", "") == String(senal):
			var argumentos: Array = declarada.get("args", [])
			return argumentos.size()
	return 0


## Pide el sonido con su origen. Un objeto que llega como origen pasa a ser fuente él también:
## así sus contactos suenan sin que nadie lo pase en la lista, aunque se cree en juego.
func _al_emitir(origen: Variant, detalle: Variant, evento: EntradaSonora.Evento) -> void:
	var objeto: Object = origen if is_instance_valid(origen) else null
	if objeto != null:
		for otro: EntradaSonora.Evento in EntradaSonora.Evento.values():
			_conectar(otro, objeto)
	var rapidez: float = detalle if detalle is float else 0.0
	reproductor.recibir(evento, objeto, rapidez)
