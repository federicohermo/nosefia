## El nodo que pide los sonidos adentro del motor: busca la fila, elige la voz y le pone el
## `stream` y el bus.
##
## **No verifica que suene, y no puede.** Está medido que en `--headless` —que es exactamente cómo
## corre el nodo `tests`— un `play()` deja `playing == false` doscientos frames después: el driver
## dummy no mezcla. El criterio obvio sería rojo permanente y el arreglo tentador sería apagar el
## test. Lo que este archivo deja verificable es **qué se le pidió al reproductor**: qué `stream`
## quedó puesto, por qué bus, en qué voz y en qué lugar.
class_name ReproductorDeSonidos
extends Node

signal sonido_pedido(evento: EntradaSonora.Evento)
signal sonido_rechazado(evento: EntradaSonora.Evento, motivo: Motivo)

## Por qué no sonó. Es un conjunto cerrado y por eso es un `enum`: un `String` suelto dejaría el
## aviso mudo justo donde el bug tampoco se ve.
enum Motivo { SIN_FILA, BUS_NO_DECLARADO, SIN_SONIDO, SIN_VOZ, SIN_POSICION }

var _tabla: TablaDeSonidos = null
var _ronda := RondaDeVoces.new(RondaDeVoces.VOCES_DEL_LOCAL)
var _ronda_del_espacio := RondaDeVoces.new(RondaDeVoces.VOCES_DEL_LOCAL)
var _voces: Array[AudioStreamPlayer] = []
var _voces_del_espacio: Array[AudioStreamPlayer3D] = []

## Una voz plana por evento en bucle, creada la primera vez que se pide.
var _bucles: Dictionary = {}

## Los reproductores de cada evento en bucle que suena desde emisores.
var _emisores_en_bucle: Dictionary = {}

## Las posiciones de cada emisor de la escena, por su nombre.
var _posiciones: Dictionary = {}

var _suenan: Dictionary = {}
var _oyente := Vector3.ZERO

## Un contador de golpes por objeto, por su `get_instance_id()`: la regla es de cada objeto.
var _golpes: Dictionary = {}


## Las voces se crean acá y no en el `.tscn`: cuántas hay lo dice `RondaDeVoces`, y ocho nodos
## escritos a mano en una escena serían ese número copiado donde nadie lo mira.
func _ready() -> void:
	for indice in range(_ronda.voces()):
		var voz := AudioStreamPlayer.new()
		voz.name = "Voz%d" % indice
		add_child(voz)
		_voces.append(voz)
	for indice in range(_ronda_del_espacio.voces()):
		var voz := AudioStreamPlayer3D.new()
		voz.name = "VozDelEspacio%d" % indice
		add_child(voz)
		_voces_del_espacio.append(voz)


## El tope se recalcula en cada cuadro porque el jugador camina. Sin cámara no hay oído.
func _process(_delta: float) -> void:
	if _emisores_en_bucle.is_empty():
		return
	var camara := get_viewport().get_camera_3d()
	if camara != null:
		actualizar_emisores(camara.global_position)


## Le entrega al reproductor la tabla de la partida.
func arrancar(tabla: TablaDeSonidos) -> void:
	_tabla = tabla


func tabla() -> TablaDeSonidos:
	return _tabla


## Anota los emisores fijos de la escena: cada hijo es un emisor, con su nombre, y suena desde
## sus propios hijos o, si no tiene, desde sí mismo.
func registrar_emisores(raiz: Node3D) -> void:
	for emisor: Node in raiz.get_children():
		var puntos: Array[Vector3] = []
		for punto: Node in emisor.get_children():
			puntos.append((punto as Node3D).global_position)
		if puntos.is_empty():
			puntos.append((emisor as Node3D).global_position)
		_posiciones[StringName(emisor.name)] = puntos


## Las voces planas que reparte la ronda, para que un caso pueda mirar qué quedó pedido.
func voces() -> Array[AudioStreamPlayer]:
	return _voces.duplicate()


## Las voces del espacio que reparte su ronda.
func voces_en_el_espacio() -> Array[AudioStreamPlayer3D]:
	return _voces_del_espacio.duplicate()


## La voz plana de un evento en bucle. Cada bucle tiene la suya: la música no corta al ambiente.
func voz_en_bucle(evento: EntradaSonora.Evento) -> AudioStreamPlayer:
	if not _bucles.has(evento):
		var voz := AudioStreamPlayer.new()
		voz.name = "Bucle%d" % evento
		add_child(voz)
		_bucles[evento] = voz
	return _bucles[evento]


## Los reproductores de un evento en bucle que suena desde emisores, uno por posición.
func emisores_en_bucle(evento: EntradaSonora.Evento) -> Array[AudioStreamPlayer3D]:
	var emisores: Array[AudioStreamPlayer3D] = []
	emisores.assign(_emisores_en_bucle.get(evento, []))
	return emisores


## Pide el sonido de un evento, y devuelve `true` **sólo si lo pidió**.
##
## Los rechazos se declaran por señal en vez de en silencio: un bus mal escrito cae a `Master`
## sin que el motor diga una palabra, y ésa es exactamente la falla que este método existe para
## cerrar. `lugar` es el objeto que lo produjo, si lo hay: una fila del espacio suena desde ahí.
func pedir(
	evento: EntradaSonora.Evento,
	sonoridad: EntradaSonora.Sonoridad = EntradaSonora.Sonoridad.NINGUNA,
	golpe: ContadorDeGolpes.Golpe = null,
	lugar: Node3D = null
) -> bool:
	var entrada := _fila_que_suena(evento, sonoridad)
	if entrada == null:
		return false
	if golpe == null:
		golpe = ContadorDeGolpes.pleno()
	if entrada.en_bucle:
		return _sonar_en_bucle(entrada)
	var voz: Node = null
	if entrada.posicional:
		var posiciones := _posiciones_de(entrada, lugar)
		if posiciones.is_empty():
			sonido_rechazado.emit(evento, Motivo.SIN_POSICION)
			return false
		voz = _siguiente(_voces_del_espacio, _ronda_del_espacio)
		if voz != null:
			(voz as AudioStreamPlayer3D).global_position = posiciones[0]
	else:
		voz = _siguiente(_voces, _ronda)
	if voz == null:
		sonido_rechazado.emit(evento, Motivo.SIN_VOZ)
		return false
	_poner(voz, entrada, _bus_filtrado(entrada.bus, golpe.corte_hz), golpe.volumen_db)
	sonido_pedido.emit(evento)
	return true


## Pide el sonido de un evento que trae su origen: el objeto que lo produjo, si lo hay, y la
## rapidez de su contacto. La sonoridad sale del objeto, y el golpe de su contador.
func recibir(evento: EntradaSonora.Evento, origen: Object = null, rapidez: float = 0.0) -> bool:
	var datos := _datos_de(origen)
	if datos == null:
		return pedir(evento, EntradaSonora.Sonoridad.NINGUNA, null, origen as Node3D)
	var clave := origen.get_instance_id()
	if not _golpes.has(clave):
		_golpes[clave] = ContadorDeGolpes.new()
	var golpe: ContadorDeGolpes.Golpe = (_golpes[clave] as ContadorDeGolpes).al_evento(
		evento, rapidez
	)
	if golpe == null:
		return false
	return pedir(evento, datos.sonoridad, golpe, origen as Node3D)


## Pausa los emisores que el tope deja afuera y suelta los que entran, según dónde está el oído.
func actualizar_emisores(oyente: Vector3) -> void:
	_oyente = oyente
	for evento: EntradaSonora.Evento in _emisores_en_bucle:
		var emisores: Array = _emisores_en_bucle[evento]
		var distancias: Array[float] = []
		for emisor: AudioStreamPlayer3D in emisores:
			distancias.append(emisor.global_position.distance_to(oyente))
		var suenan := EmisoresDelAmbiente.que_suenan(distancias, EmisoresDelAmbiente.TOPE)
		_suenan[evento] = suenan
		for indice in range(emisores.size()):
			(emisores[indice] as AudioStreamPlayer3D).stream_paused = not suenan.has(indice)


## Los índices de los emisores de ese bucle que dejó sonar el último tope. Se guardan aparte
## porque en headless el motor no recuerda la pausa de un reproductor que no mezcla.
func emisores_que_suenan(evento: EntradaSonora.Evento) -> Array[int]:
	var suenan: Array[int] = []
	suenan.assign(_suenan.get(evento, []))
	return suenan


## Corta un bucle. Lo usa el cierre de la jornada para la música.
func callar(evento: EntradaSonora.Evento) -> void:
	voz_en_bucle(evento).stream = null
	for emisor: AudioStreamPlayer3D in _emisores_en_bucle.get(evento, []):
		emisor.queue_free()
	_emisores_en_bucle.erase(evento)
	_suenan.erase(evento)


## Deja todas las voces sin nada pedido.
##
## Se limpia el `stream` y no se llama a `stop()`: `stop()` deja el stream puesto, y lo que un
## caso puede leer en headless es justamente el stream. Con `stop()` el silencio no sería
## verificable.
func silenciar() -> void:
	for voz in _voces:
		voz.stream = null
	for voz in _voces_del_espacio:
		voz.stream = null
	for evento: EntradaSonora.Evento in _bucles.keys() + _emisores_en_bucle.keys():
		callar(evento)


## La fila de ese par si puede sonar, o `null` después de declarar por qué no.
func _fila_que_suena(
	evento: EntradaSonora.Evento, sonoridad: EntradaSonora.Sonoridad
) -> EntradaSonora:
	if _tabla == null:
		push_error("Reproductor sin arrancar: revisar audio_del_almacen.gd")
		return null
	var entrada := _tabla.de(evento, sonoridad)
	var motivo := -1
	if entrada == null:
		motivo = Motivo.SIN_FILA
	elif not entrada.es_valida():
		motivo = Motivo.BUS_NO_DECLARADO
	elif not entrada.tiene_sonido():
		motivo = Motivo.SIN_SONIDO
	if motivo < 0:
		return entrada
	sonido_rechazado.emit(evento, motivo)
	return null


## Un bucle plano suena en su voz; uno del espacio, en un reproductor por posición de su emisor.
## Si ya suena, no empieza de nuevo.
func _sonar_en_bucle(entrada: EntradaSonora) -> bool:
	if not entrada.posicional:
		var voz := voz_en_bucle(entrada.evento)
		if voz.stream == entrada.stream:
			return true
		_poner(voz, entrada, entrada.bus, 0.0)
		sonido_pedido.emit(entrada.evento)
		return true
	if _emisores_en_bucle.has(entrada.evento):
		return true
	var posiciones := _posiciones_de(entrada, null)
	if posiciones.is_empty():
		sonido_rechazado.emit(entrada.evento, Motivo.SIN_POSICION)
		return false
	var emisores: Array[AudioStreamPlayer3D] = []
	for posicion in posiciones:
		var emisor := AudioStreamPlayer3D.new()
		emisor.name = "Emisor%d_%d" % [entrada.evento, emisores.size()]
		emisor.max_distance = EmisoresDelAmbiente.ALCANCE
		add_child(emisor)
		emisor.global_position = posicion
		_poner(emisor, entrada, entrada.bus, EmisoresDelAmbiente.VOLUMEN_DB)
		emisores.append(emisor)
	_emisores_en_bucle[entrada.evento] = emisores
	actualizar_emisores(_oyente)
	sonido_pedido.emit(entrada.evento)
	return true


## Desde dónde suena una fila del espacio: el objeto, si lo hay, o las posiciones de su emisor.
func _posiciones_de(entrada: EntradaSonora, lugar: Node3D) -> Array[Vector3]:
	var posiciones: Array[Vector3] = []
	if is_instance_valid(lugar) and lugar.is_inside_tree():
		posiciones.append(lugar.global_position)
		return posiciones
	posiciones.assign(_posiciones.get(entrada.emisor, []))
	return posiciones


## La voz que sigue en esa ronda, o `null` si la ronda está vacía.
func _siguiente(voces_de_la_ronda: Array, ronda: RondaDeVoces) -> Node:
	var indice := ronda.siguiente()
	if indice < 0:
		return null
	return voces_de_la_ronda[indice]


## Una voz plana y una del espacio no comparten una clase del motor, pero sí estas propiedades.
func _poner(voz: Node, entrada: EntradaSonora, bus: String, volumen_db: float) -> void:
	voz.set(&"stream", entrada.stream)
	voz.set(&"bus", bus)
	voz.set(&"volume_db", volumen_db)
	voz.call(&"play")


## Los datos de dominio del objeto que produjo el evento, o `null` si no es un objeto.
func _datos_de(origen: Object) -> ObjetoDelAlmacen:
	if not is_instance_valid(origen):
		return null
	if not origen.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR):
		return null
	return origen.call(ReglasDeLosObjetos.METODO_INTERACTUAR) as ObjetoDelAlmacen


## El bus por el que sale un sonido con ese corte pasa-altos. Sin corte es el bus de la fila.
##
## Un reproductor del motor no filtra solo: el filtro vive en un bus. Se crea uno por corte, la
## primera vez que se pide, y manda al bus de la fila para que su volumen siga mandando.
func _bus_filtrado(bus: String, corte_hz: float) -> String:
	if corte_hz <= 0.0:
		return bus
	var nombre := "%s · pasa-altos %d Hz" % [bus, int(corte_hz)]
	if AudioServer.get_bus_index(nombre) < 0:
		AudioServer.add_bus()
		var indice := AudioServer.bus_count - 1
		AudioServer.set_bus_name(indice, nombre)
		AudioServer.set_bus_send(indice, bus)
		var filtro := AudioEffectHighPassFilter.new()
		filtro.cutoff_hz = corte_hz
		AudioServer.add_bus_effect(indice, filtro)
	return nombre
