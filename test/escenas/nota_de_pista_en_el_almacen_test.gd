extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

var _almacen: Node3D
var _ruta_guardado: String


func _abrir(jornada: int) -> void:
	_almacen = ALMACEN.instantiate()
	_almacen.set("_partida", Partida.desde(PartidaSerializada.sanear({"jornada": jornada})))
	get_tree().root.add_child(_almacen)


func _celular() -> CelularDelEmpleado:
	return _almacen.get_node("Interfaz/CelularDelEmpleado")


func _notas() -> Array[Mensaje]:
	return _celular().bandeja().mensajes_de(Conversacion.Interlocutor.NOTAS)


func _pedidos_de_sonido() -> Array[EntradaSonora.Evento]:
	var reproductor: ReproductorDeSonidos = _almacen.get_node(
		"Servicios/AudioDelAlmacen/Reproductor"
	)
	var pedidos: Array[EntradaSonora.Evento] = []
	reproductor.sonido_pedido.connect(
		func(evento: EntradaSonora.Evento) -> void:
			if evento != EntradaSonora.Evento.NOTIFICACION_ENTRADA:
				pedidos.append(evento)
	)
	return pedidos


func test_anotar_una_pista_suena_enviado_una_vez_y_no_recibido() -> void:  # AC-AMB-029
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1
	_abrir(jornada)
	var pedidos := _pedidos_de_sonido()
	var investigador: Investigador = _almacen.get("_investigador")
	var antes := _notas().size()
	var sin_leer := _celular().bandeja().no_leidos(Conversacion.Interlocutor.NOTAS)
	assert_int(investigador.pedir_pista(&"colilla", Pista.Canal.LEVANTAR, jornada, true)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	var nuevas := _notas().size() - antes
	assert_int(nuevas).is_greater(1)
	assert_array(pedidos).is_equal([EntradaSonora.Evento.NOTA_ANOTADA])
	assert_int(_celular().bandeja().no_leidos(Conversacion.Interlocutor.NOTAS)).is_equal(
		sin_leer + nuevas
	)


func test_sin_pista_nueva_no_suena_ni_al_retomar() -> void:  # AC-AMB-030
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1
	_abrir(jornada)
	var investigador: Investigador = _almacen.get("_investigador")
	investigador.pedir_pista(&"colilla", Pista.Canal.LEVANTAR, jornada, true)
	var pedidos := _pedidos_de_sonido()
	assert_int(investigador.pedir_pista(&"colilla", Pista.Canal.LEVANTAR, jornada, true)).is_equal(
		Expediente.Resultado.REPETIDA
	)
	assert_int(investigador.pedir_pista(&"ajena", Pista.Canal.LEVANTAR, jornada, true)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_array(pedidos).is_empty()
	var retomado := Expediente.new(CasoDeInvestigacion.de_la_partida())
	retomado.registrar_por_canal(&"colilla", Pista.Canal.LEVANTAR, jornada)
	var notas := _notas().duplicate()
	investigador.usar(retomado)
	assert_array(pedidos).is_empty()
	assert_array(_notas()).is_equal(notas)


func test_el_mensaje_de_otro_chat_sigue_sonando_recibido() -> void:  # AC-AMB-031
	_abrir(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)
	var pedidos := _pedidos_de_sonido()
	var mensaje := Mensaje.new()
	mensaje.texto = "Prueba de llegada"
	_celular().recibir(_celular().bandeja().conversaciones()[0].interlocutor, mensaje)
	assert_array(pedidos).is_equal([EntradaSonora.Evento.MENSAJE_DEL_CELULAR])


func before_test() -> void:
	_ruta_guardado = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://nota_764.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_guardado
