## El nodo que pide los sonidos adentro del motor: busca la fila, elige la voz y le pone el
## `stream` y el bus.
##
## **No verifica que suene, y no puede.** Está medido que en `--headless` —que es exactamente cómo
## corre el nodo `tests`— un `play()` deja `playing == false` doscientos frames después: el driver
## dummy no mezcla. El criterio obvio sería rojo permanente y el arreglo tentador sería apagar el
## test. Lo que este archivo deja verificable es **qué se le pidió al reproductor**: qué `stream`
## quedó puesto, por qué bus, en qué voz y en qué lugar.
##
## **Traduce, no decide.** Qué suena, por dónde, si va en bucle y si sale del espacio son
## preguntas de la tabla; a qué voz le toca, de la ronda; qué emisor suena, del tope. Los `if` de
## acá son valores que devolvió el dominio.
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

## Lo que cada voz del espacio necesita para apagarse: su volumen y su bus sin obstáculos, el
## objeto que la produjo, su nivel de apagado y su bus propio, si ya lo necesitó.
var _bases: Dictionary = {}
var _salidas: Dictionary = {}
var _origenes: Dictionary = {}
var _niveles: Dictionary = {}
var _buses_propios: Dictionary = {}

## El sorteo de las variantes, y la última que sonó de cada evento.
var _azar := RandomNumberGenerator.new()
var _anteriores: Dictionary = {}


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


## Los buses propios se crean en juego y se borran con el reproductor: si no, cada partida
## dejaría los suyos en el mezclador.
func _exit_tree() -> void:
	for nombre: String in _buses_propios.values():
		var indice := AudioServer.get_bus_index(nombre)
		if indice >= 0:
			AudioServer.remove_bus(indice)
	_buses_propios.clear()


## El tope se recalcula en cada cuadro porque el jugador camina. Sin cámara no hay oído.
func _process(_delta: float) -> void:
	if _emisores_en_bucle.is_empty():
		return
	var camara := get_viewport().get_camera_3d()
	if camara != null:
		actualizar_emisores(camara.global_position)


## El apagado va por cuadro de física porque tira rayos contra el mundo.
func _physics_process(delta: float) -> void:
	if _niveles.is_empty():
		return
	var camara := get_viewport().get_camera_3d()
	if camara != null:
		actualizar_apagado(camara.global_position, delta)


## Le entrega al reproductor la tabla de la partida.
func arrancar(tabla: TablaDeSonidos) -> void:
	_tabla = tabla


func tabla() -> TablaDeSonidos:
	return _tabla


## Fija la semilla del sorteo de variantes. En el juego queda la que el motor pone al azar.
func sembrar(semilla: int) -> void:
	_azar.seed = semilla
	_anteriores.clear()


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
	if entrada.posicional:
		_preparar_apagado(voz, lugar)
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


## Acerca el apagado de cada voz del espacio a los obstáculos que hay entre ella y el oído.
func actualizar_apagado(oyente: Vector3, segundos: float) -> void:
	_oyente = oyente
	for clave in _niveles.keys():
		if not is_instance_valid(clave):
			_olvidar(clave)
			continue
		var voz := clave as AudioStreamPlayer3D
		if voz.stream == null or voz.stream_paused:
			continue
		if not is_instance_valid(_origenes[voz]):
			_origenes[voz] = null
		var cantidad := obstaculos_entre(oyente, voz.global_position, _origenes[voz])
		_niveles[voz] = ApagadoPorObstaculos.acercar(_niveles[voz], cantidad, segundos)
		_aplicar_apagado(voz)


## Cuántos obstáculos hay entre dos puntos, hasta el máximo que apaga. Una pared cuenta; una
## puerta, sólo cerrada. `propio` es lo que produjo el sonido, que no se tapa a sí mismo.
func obstaculos_entre(desde: Vector3, hasta: Vector3, propio: Object) -> int:
	var espacio := get_viewport().world_3d.direct_space_state
	var excluidos: Array[RID] = []
	if propio is CollisionObject3D and is_instance_valid(propio):
		excluidos.append((propio as CollisionObject3D).get_rid())
	var cantidad := 0
	for _rayo in range(ApagadoPorObstaculos.MAXIMO * 4):
		var consulta := PhysicsRayQueryParameters3D.create(desde, hasta)
		consulta.exclude = excluidos
		var choque := espacio.intersect_ray(consulta)
		if choque.is_empty():
			break
		excluidos.append(choque.rid)
		if _tapa(choque.collider):
			cantidad += 1
			if cantidad >= ApagadoPorObstaculos.MAXIMO:
				break
	return cantidad


## Corta un bucle. Lo usa el cierre de la jornada para la música.
func callar(evento: EntradaSonora.Evento) -> void:
	voz_en_bucle(evento).stream = null
	for emisor: AudioStreamPlayer3D in _emisores_en_bucle.get(evento, []):
		_olvidar(emisor)
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
		if voz.stream == entrada.variante(0):
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
		_preparar_apagado(emisor, null)
		emisores.append(emisor)
	_emisores_en_bucle[entrada.evento] = emisores
	actualizar_emisores(_oyente)
	sonido_pedido.emit(entrada.evento)
	return true


## Anota lo que la voz necesita para apagarse, y la apaga ya: un sonido que empieza del otro
## lado de una pared empieza apagado, sin transición.
func _preparar_apagado(voz: AudioStreamPlayer3D, origen: Object) -> void:
	_bases[voz] = voz.volume_db
	_salidas[voz] = voz.bus
	_origenes[voz] = origen
	var camara := get_viewport().get_camera_3d()
	var oido := camara.global_position if camara != null else _oyente
	var cantidad := obstaculos_entre(oido, voz.global_position, origen)
	_niveles[voz] = float(mini(cantidad, ApagadoPorObstaculos.MAXIMO))
	_aplicar_apagado(voz)


## Un reproductor del motor no filtra solo: el pasa-bajos vive en un bus propio de la voz, que
## manda al bus de su fila. Sin obstáculos, la voz sale directo por el de su fila.
func _aplicar_apagado(voz: AudioStreamPlayer3D) -> void:
	var nivel: float = _niveles[voz]
	var salida: String = _salidas[voz]
	voz.volume_db = _bases[voz] + ApagadoPorObstaculos.volumen_db(nivel)
	if nivel <= 0.0:
		voz.bus = salida
		return
	if not _buses_propios.has(voz):
		_buses_propios[voz] = "Apagado %d" % voz.get_instance_id()
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, _buses_propios[voz])
		AudioServer.add_bus_effect(AudioServer.bus_count - 1, AudioEffectLowPassFilter.new())
	var indice := AudioServer.get_bus_index(_buses_propios[voz])
	AudioServer.set_bus_send(indice, salida)
	var filtro := AudioServer.get_bus_effect(indice, 0) as AudioEffectLowPassFilter
	filtro.cutoff_hz = ApagadoPorObstaculos.corte_hz(nivel)
	voz.bus = _buses_propios[voz]


## Suelta lo anotado de una voz que ya no existe. Su bus propio se borra con el reproductor.
func _olvidar(voz: Object) -> void:
	_bases.erase(voz)
	_salidas.erase(voz)
	_origenes.erase(voz)
	_niveles.erase(voz)


## Si ese cuerpo tapa el sonido: lo fijo, salvo una puerta abierta.
func _tapa(cuerpo: Object) -> bool:
	if cuerpo.has_method(ApagadoPorObstaculos.METODO_DE_LA_PUERTA):
		var puerta := cuerpo.call(ApagadoPorObstaculos.METODO_DE_LA_PUERTA) as Puerta
		return puerta != null and not puerta.abierta()
	return cuerpo is StaticBody3D


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
	var indice := EleccionDeVariante.siguiente(
		entrada.cantidad_de_variantes(), _anteriores.get(entrada.evento, -1), _azar
	)
	_anteriores[entrada.evento] = indice
	voz.set(&"stream", entrada.variante(indice))
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
