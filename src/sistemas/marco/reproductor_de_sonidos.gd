## El nodo que pide los sonidos adentro del motor: busca la fila, elige la voz y le pone el
## `stream` y el bus.
##
## **No verifica que suene, y no puede.** Está medido que en `--headless` —que es exactamente cómo
## corre el nodo `tests`— un `play()` deja `playing == false` doscientos frames después: el driver
## dummy no mezcla. El criterio obvio sería rojo permanente y el arreglo tentador sería apagar el
## test. Lo que este archivo deja verificable es **qué se le pidió al reproductor**: qué `stream`
## quedó puesto, por qué bus y en qué voz.
##
## **Traduce, no decide.** Qué suena, por dónde y si va en bucle son preguntas de la tabla; a qué
## voz le toca, de la ronda. Los `if` de acá son valores que devolvió el dominio.
class_name ReproductorDeSonidos
extends Node

signal sonido_pedido(evento: EntradaSonora.Evento)
signal sonido_rechazado(evento: EntradaSonora.Evento, motivo: Motivo)

## Por qué no sonó. Es un conjunto cerrado y por eso es un `enum`: un `String` suelto dejaría el
## aviso mudo justo donde el bug tampoco se ve.
enum Motivo { SIN_FILA, BUS_NO_DECLARADO, SIN_SONIDO, SIN_VOZ }

var _tabla: TablaDeSonidos = null
var _ronda := RondaDeVoces.new(RondaDeVoces.VOCES_DEL_LOCAL)
var _voces: Array[AudioStreamPlayer] = []
var _ambiente: AudioStreamPlayer = null


## Las voces se crean acá y no en el `.tscn`: cuántas hay lo dice `RondaDeVoces`, y ocho nodos
## escritos a mano en una escena serían ese número copiado donde nadie lo mira.
func _ready() -> void:
	for indice in range(_ronda.voces()):
		_voces.append(_voz_nueva("Voz%d" % indice))
	_ambiente = _voz_nueva("VozEnBucle")


## Le entrega al reproductor la tabla de la partida.
func arrancar(tabla: TablaDeSonidos) -> void:
	_tabla = tabla


func tabla() -> TablaDeSonidos:
	return _tabla


## Las voces que reparte la ronda, para que un caso pueda mirar qué quedó pedido en cada una.
func voces() -> Array[AudioStreamPlayer]:
	return _voces.duplicate()


## La voz reservada a lo que va en bucle. Es aparte a propósito: adentro de la ronda, el ambiente
## se cortaría solo al quinto efecto.
func ambiente() -> AudioStreamPlayer:
	return _ambiente


## Pide el sonido de un evento, y devuelve `true` **sólo si lo pidió**.
##
## Los cuatro rechazos se declaran por señal en vez de en silencio: un bus mal escrito cae a
## `Master` sin que el motor diga una palabra, y ésa es exactamente la falla que este método
## existe para cerrar.
func pedir(evento: EntradaSonora.Evento) -> bool:
	if _tabla == null:
		push_error("Reproductor sin arrancar: revisar audio_del_almacen.gd")
		return false
	var entrada := _tabla.de(evento)
	if entrada == null:
		sonido_rechazado.emit(evento, Motivo.SIN_FILA)
		return false
	if not entrada.es_valida():
		sonido_rechazado.emit(evento, Motivo.BUS_NO_DECLARADO)
		return false
	if not entrada.tiene_sonido():
		sonido_rechazado.emit(evento, Motivo.SIN_SONIDO)
		return false
	var voz := _voz_para(entrada)
	if voz == null:
		sonido_rechazado.emit(evento, Motivo.SIN_VOZ)
		return false
	voz.stream = entrada.stream
	voz.bus = entrada.bus
	voz.play()
	sonido_pedido.emit(evento)
	return true


## Deja todas las voces sin nada pedido.
##
## Se limpia el `stream` y no se llama a `stop()`: `stop()` deja el stream puesto, y lo que un
## caso puede leer en headless es justamente el stream. Con `stop()` el silencio no sería
## verificable.
func silenciar() -> void:
	for voz in _voces:
		voz.stream = null
	_ambiente.stream = null


## La voz que le toca a esta fila, o `null` si la ronda está vacía.
func _voz_para(entrada: EntradaSonora) -> AudioStreamPlayer:
	if entrada.en_bucle:
		return _ambiente
	var indice := _ronda.siguiente()
	if indice < 0:
		return null
	return _voces[indice]


func _voz_nueva(nombre: String) -> AudioStreamPlayer:
	var voz := AudioStreamPlayer.new()
	voz.name = nombre
	add_child(voz)
	return voz
