## Los usos que no tenían sonido, en el almacén entero: que el cableado de la raíz los ate y que el
## reproductor pida el audio de su fila una vez, por su bus y desde su lugar.
##
## Ningún caso afirma que algo suena: en headless el driver no mezcla. Se mira qué se pidió.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const REPRODUCTOR := "Servicios/AudioDelAlmacen/Reproductor"
const EMISORES := "Servicios/AudioDelAlmacen/Emisores"

const MOPA := ReglasDeLaLimpieza.ID_DE_LA_MOPA
const BALDE := ReglasDeLaLimpieza.ID_DEL_BALDE
const LAVATORIO := ReglasDeLaLimpieza.ID_DEL_LAVATORIO
const INODORO := ReglasDeLaLimpieza.ID_DEL_INODORO

var _almacen: Node3D
var _pedidos: Array[EntradaSonora.Evento] = []
var _rechazados: Array[EntradaSonora.Evento] = []


func before_test() -> void:
	_pedidos = []
	_rechazados = []


func after_test() -> void:
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null


func _abrir() -> void:
	_almacen = ALMACEN.instantiate()
	_almacen.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	# Se escucha antes de entrar al árbol: abrir el almacén ya arranca el ambiente.
	var reproductor: ReproductorDeSonidos = _almacen.get_node(REPRODUCTOR)
	reproductor.sonido_pedido.connect(
		func(evento: EntradaSonora.Evento) -> void: _pedidos.append(evento)
	)
	reproductor.sonido_rechazado.connect(
		func(evento: EntradaSonora.Evento, _motivo: ReproductorDeSonidos.Motivo) -> void:
			_rechazados.append(evento)
	)
	add_child(_almacen)
	await get_tree().physics_frame
	var jugador: Node3D = _almacen.get("_jugador")
	jugador.set_process(false)
	jugador.set_physics_process(false)


func _reproductor() -> ReproductorDeSonidos:
	return _almacen.get_node(REPRODUCTOR)


## Las voces planas que tienen pedido ese audio.
func _voces_con(audio: String) -> Array[AudioStreamPlayer]:
	var voces: Array[AudioStreamPlayer] = []
	for voz in _reproductor().voces():
		if voz.stream != null and voz.stream.resource_path.get_file().get_basename() == audio:
			voces.append(voz)
	return voces


## El bus de la fila por el que sale una voz: el apagado la pasa por un bus propio que manda ahí.
static func _sale_por(bus: String) -> String:
	if EntradaSonora.BUSES.has(bus):
		return bus
	return String(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)))


func test_un_ticket_en_el_inodoro_pide_su_audio_una_vez() -> void:
	await _abrir()
	var caja: CajaRegistradora = _almacen.get("_caja")
	var evento := EntradaSonora.Evento.TICKET_DESECHADO
	assert_bool(caja.pedir_desechar(Ticket.new(), LAVATORIO)).is_false()
	assert_bool(caja.pedir_desechar(null, INODORO)).is_false()
	assert_bool(caja.pedir_desechar(ObjetoDelAlmacen.new(), INODORO)).is_false()
	assert_int(_pedidos.count(evento)).is_zero()
	assert_bool(caja.pedir_desechar(Ticket.new(), INODORO)).is_true()
	assert_int(_pedidos.count(evento)).is_equal(1)
	assert_bool(_rechazados.has(evento)).is_false()
	var voces := _voces_con("SFX_NOLEV_Inodoro")
	assert_int(voces.size()).is_equal(1)
	if voces.size() == 1:
		assert_str(voces[0].bus).is_equal(EntradaSonora.BUS_DE_EFECTOS)
	assert_array(_voces_con("SFX_OBJETO_Mopa_MojarEnBalde")).is_empty()


func test_recibir_un_mensaje_pide_su_audio_una_vez_y_leer_no() -> void:
	await _abrir()
	var celular: CelularDelEmpleado = _almacen.get("_celular")
	var evento := EntradaSonora.Evento.MENSAJE_DEL_CELULAR
	var quien := celular.bandeja().conversaciones()[0].interlocutor
	var mensaje := Mensaje.new()
	mensaje.texto = "Prueba de llegada"
	celular.recibir(quien, null)
	assert_int(_pedidos.count(evento)).is_zero()
	celular.recibir(quien, mensaje)
	assert_int(_pedidos.count(evento)).is_equal(1)
	celular.pedir_alternar(false)
	celular.pedir_chat(quien)
	assert_int(celular.bandeja().no_leidos(quien)).is_zero()
	assert_int(_pedidos.count(evento)).is_equal(1)
	assert_bool(_rechazados.has(evento)).is_false()
	var voces := _voces_con("SFX_INTERFAZ_Celular_Mensaje_A")
	voces.append_array(_voces_con("SFX_INTERFAZ_Celular_Mensaje_B"))
	assert_int(voces.size()).is_equal(1)
	if voces.size() == 1:
		assert_str(voces[0].bus).is_equal(EntradaSonora.BUS_DE_INTERFAZ)


func test_el_jabon_equivocado_pide_limpiar_una_vez_y_la_mancha_queda() -> void:
	await _abrir()
	var limpiador: Limpiador = _almacen.get("_limpiador")
	var lugar: PisoDelLocal.Lugar = limpiador.piso().lugares()[0]
	var pedida: ReglasDeLaLimpieza.Agua = ReglasDeLaLimpieza.AGUA_QUE_BORRA[
		limpiador.piso().mancha_de(lugar).tipo()
	]
	var equivocado: StringName = &""
	for jabon: StringName in ReglasDeLaLimpieza.JABONES:
		if ReglasDeLaLimpieza.JABONES[jabon] != pedida:
			equivocado = jabon
			break
	limpiador.usar(BALDE, LAVATORIO)
	limpiador.usar(equivocado, BALDE)
	limpiador.usar(MOPA, BALDE)
	var evento := EntradaSonora.Evento.PASADA_CON_JABON_EQUIVOCADO
	assert_int(limpiador.pasar(MOPA, lugar)).is_equal(ReglasDeLaLimpieza.Resultado.JABON_EQUIVOCADO)
	assert_int(_pedidos.count(evento)).is_equal(1)
	assert_bool(_pedidos.has(EntradaSonora.Evento.PASADA_DADA)).is_false()
	assert_bool(limpiador.piso().mancha_de(lugar).esta_limpia()).is_false()
	var voces := _voces_con("SFX_OBJETO_Mopa_Limpiar")
	assert_int(voces.size()).is_equal(1)
	if voces.size() == 1:
		assert_str(voces[0].bus).is_equal(EntradaSonora.BUS_DE_EFECTOS)


func test_el_exterior_suena_desde_la_ventanilla_junto_al_neon_y_la_musica() -> void:
	await _abrir()
	var audio: Node = _almacen.get("_audio")
	var reproductor := _reproductor()
	audio.call("arrancar_el_ambiente")
	audio.call("arrancar_el_ambiente")
	var evento := EntradaSonora.Evento.AMBIENTE_EXTERIOR
	var exterior := reproductor.emisores_en_bucle(evento)
	assert_int(exterior.size()).is_equal(1)
	assert_int(_pedidos.count(evento)).is_equal(1)
	assert_bool(_rechazados.has(evento)).is_false()
	if exterior.size() != 1:
		return
	var ventanilla: Node3D = _almacen.get_node(EMISORES).get_node("Ventanilla")
	assert_vector(exterior[0].global_position).is_equal_approx(
		ventanilla.global_position, Vector3.ONE * 0.001
	)
	assert_str(exterior[0].stream.resource_path.get_file()).is_equal("AMB_PROXIMIDAD_Exterior.ogg")
	assert_str(_sale_por(exterior[0].bus)).is_equal(EntradaSonora.BUS_DE_AMBIENTE)
	assert_float(exterior[0].max_distance).is_equal(EmisoresDelAmbiente.ALCANCE)
	(
		assert_int(reproductor.emisores_en_bucle(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL).size())
		. is_greater(0)
	)
	var musica := reproductor.voz_en_bucle(EntradaSonora.Evento.MUSICA_DE_LA_NOCHE)
	assert_object(musica.stream).is_not_null()
	audio.call("callar_la_musica")
	assert_object(musica.stream).is_null()
	assert_int(reproductor.emisores_en_bucle(evento).size()).is_equal(1)
	(
		assert_int(reproductor.emisores_en_bucle(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL).size())
		. is_greater(0)
	)


func test_el_exterior_se_oye_cerca_de_la_ventanilla_y_no_mas_alla_del_alcance() -> void:
	await _abrir()
	var audio: Node = _almacen.get("_audio")
	var reproductor := _reproductor()
	audio.call("arrancar_el_ambiente")
	var evento := EntradaSonora.Evento.AMBIENTE_EXTERIOR
	var exterior := reproductor.emisores_en_bucle(evento)
	assert_int(exterior.size()).is_equal(1)
	if exterior.size() != 1:
		return
	var emisor := exterior[0]
	var habitaciones: Node3D = _almacen.get("_habitaciones")
	var ventanilla: Node3D = _almacen.get_node(EMISORES).get_node("Ventanilla")
	var recorrido := {"ventanilla": ventanilla.global_position}
	for nombre: String in ["local", "deposito", "bano"]:
		var cajas: Array[AABB] = habitaciones.get(nombre)
		assert_array(cajas).is_not_empty()
		if not cajas.is_empty():
			recorrido[nombre] = habitaciones.to_global(cajas[0].get_center())
	for nombre: String in recorrido:
		var punto: Vector3 = recorrido[nombre]
		reproductor.actualizar_emisores(punto)
		assert_array(reproductor.emisores_que_suenan(evento)).is_equal([0])
		var distancia := emisor.global_position.distance_to(punto)
		var obstaculos := reproductor.obstaculos_entre(punto, emisor.global_position, null)
		print("[exterior] %s a %.2f m, %d obstáculos" % [nombre, distancia, obstaculos])
		match nombre:
			"ventanilla", "local":
				assert_float(distancia).is_less(EmisoresDelAmbiente.ALCANCE)
				assert_int(obstaculos).is_zero()
			"deposito":
				assert_float(distancia).is_greater(EmisoresDelAmbiente.ALCANCE)
			"bano":
				assert_int(obstaculos).is_greater(0)
