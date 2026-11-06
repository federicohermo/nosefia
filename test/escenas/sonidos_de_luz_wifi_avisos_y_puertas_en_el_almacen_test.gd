## Qué se pide a la tabla en el local de verdad cuando se corta y vuelve la luz, el jugador usa el
## router, entra y sale un cartel, y se fuerza la puerta del jefe. Qué stream tiene cada fila lo
## prueba la suite del dominio; acá se prueba que el local ate el evento.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const REPRODUCTOR := "Servicios/AudioDelAlmacen/Reproductor"
const TABLERO := "Estructura/tableroluz/StaticBody3D"
const ROUTER := "Estructura/Router"
const PILA := "Interfaz/PilaDeNotificaciones"
const PUERTA_DEL_JEFE := "Estructura/puertajefe/CuerpoDeLaHoja"
const EVENTOS := [
	EntradaSonora.Evento.LUZ_CORTADA,
	EntradaSonora.Evento.LUZ_VUELTA,
	EntradaSonora.Evento.WIFI_APAGADO,
	EntradaSonora.Evento.WIFI_PRENDIDO,
	EntradaSonora.Evento.NOTIFICACION_ENTRADA,
	EntradaSonora.Evento.NOTIFICACION_SALIDA,
	EntradaSonora.Evento.PUERTA_FORZADA_CON_LLAVE,
	EntradaSonora.Evento.PUERTA_FORZADA_CON_PALANCA,
	EntradaSonora.Evento.PUERTA_ABIERTA,
	EntradaSonora.Evento.PUERTA_TRABADA,
]

var _pedidos: Array = []


func after_test() -> void:
	get_tree().paused = false


func _local(jornada: int = AnomaliasDeLaJornada.JORNADA_DEL_CORTE) -> Node3D:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	local.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	add_child(local)
	local.get("_jugador").set_physics_process(false)
	local.get("_reloj").set_process(false)
	local.get_node(PILA).set_process(false)
	_pedidos = []
	var reproductor: ReproductorDeSonidos = local.get_node(REPRODUCTOR)
	reproductor.sonido_pedido.connect(
		func(evento: EntradaSonora.Evento) -> void:
			if EVENTOS.has(evento):
				_pedidos.append(evento)
	)
	return local


func _hasta_el_corte(local: Node3D) -> void:
	var hora := Vector2i(AnomaliasDeLaJornada.HORA_DEL_CORTE, AnomaliasDeLaJornada.MINUTO_DEL_CORTE)
	RelojDePrueba.avanzar_hasta(local.get("_reloj"), hora)


func _objeto(id: StringName) -> ObjetoDelAlmacen:
	var objeto := ObjetoDelAlmacen.new()
	objeto.id = id
	return objeto


func test_al_cortarse_la_luz_suena_el_corte_una_vez_y_el_router_no_suena() -> void:
	var local := _local()
	assert_array(_pedidos).is_empty()
	_hasta_el_corte(local)
	assert_array(_pedidos).is_equal([EntradaSonora.Evento.LUZ_CORTADA])


func test_al_volver_la_luz_suena_la_vuelta_una_vez_y_el_router_no_suena() -> void:
	var local := _local()
	_hasta_el_corte(local)
	local.get_node(TABLERO).accionar()
	local.get_node(TABLERO).accionar()
	assert_array(_pedidos).is_equal(
		[EntradaSonora.Evento.LUZ_CORTADA, EntradaSonora.Evento.LUZ_VUELTA]
	)


func test_abrir_una_jornada_con_el_corte_sin_restablecer_no_suena_la_vuelta() -> void:
	var local := _local()
	_hasta_el_corte(local)
	_pedidos.clear()
	var corte: Node = local.get("_corte")
	corte.abrir_jornada(AnomaliasDeLaJornada.JORNADA_DEL_CORTE + 1)
	assert_bool(corte.hay_luz()).is_true()
	assert_array(_pedidos).is_empty()


func test_apagar_y_prender_el_router_suena_cada_gesto() -> void:
	var local := _local()
	_hasta_el_corte(local)
	local.get_node(TABLERO).accionar()
	_pedidos.clear()
	var router: Node3D = local.get_node(ROUTER)
	router.accionar()
	assert_array(_pedidos).is_equal([EntradaSonora.Evento.WIFI_APAGADO])
	router.accionar()
	assert_array(_pedidos).is_equal(
		[EntradaSonora.Evento.WIFI_APAGADO, EntradaSonora.Evento.WIFI_PRENDIDO]
	)
	router.accionar()
	assert_array(_pedidos).has_size(2)


func test_un_cartel_que_entra_y_sale_suena_una_vez_cada_uno() -> void:
	var local := _local(ReglasDeLaPartida.PRIMERA_JORNADA)
	var pila: PilaDeNotificaciones = local.get_node(PILA)
	pila.avisar_pista()
	await get_tree().process_frame
	assert_array(_pedidos).is_equal([EntradaSonora.Evento.NOTIFICACION_ENTRADA])
	pila._process(Notificaciones.DURACION + 1.0)
	await get_tree().process_frame
	assert_array(_pedidos).is_equal(
		[EntradaSonora.Evento.NOTIFICACION_ENTRADA, EntradaSonora.Evento.NOTIFICACION_SALIDA]
	)


func test_varios_carteles_en_el_mismo_cuadro_suenan_una_sola_entrada_y_una_sola_salida() -> void:
	var local := _local(ReglasDeLaPartida.PRIMERA_JORNADA)
	var pila: PilaDeNotificaciones = local.get_node(PILA)
	pila.avisar_pista()
	pila.avisar_logro(Logros.Logro.values()[0])
	await get_tree().process_frame
	assert_array(_pedidos).is_equal([EntradaSonora.Evento.NOTIFICACION_ENTRADA])
	pila._process(Notificaciones.DURACION + 1.0)
	await get_tree().process_frame
	assert_array(_pedidos).is_equal(
		[EntradaSonora.Evento.NOTIFICACION_ENTRADA, EntradaSonora.Evento.NOTIFICACION_SALIDA]
	)


func test_vaciar_la_pila_no_suena_la_salida() -> void:
	var local := _local(ReglasDeLaPartida.PRIMERA_JORNADA)
	var pila: PilaDeNotificaciones = local.get_node(PILA)
	pila.avisar_pista()
	await get_tree().process_frame
	pila.vaciar()
	await get_tree().process_frame
	assert_array(_pedidos).is_equal([EntradaSonora.Evento.NOTIFICACION_ENTRADA])
	pila.avisar_pista()
	await get_tree().process_frame
	assert_array(_pedidos).is_equal(
		[EntradaSonora.Evento.NOTIFICACION_ENTRADA, EntradaSonora.Evento.NOTIFICACION_ENTRADA]
	)


func test_forzar_la_puerta_del_jefe_con_la_llave_suena_su_audio_y_no_el_de_abrir() -> void:
	var local := _local()
	var puerta: Node3D = local.get_node(PUERTA_DEL_JEFE)
	puerta.set("lo_que_se_lleva", func() -> ObjetoDelAlmacen: return _objeto(Partida.LLAVE))
	puerta.accionar()
	assert_array(_pedidos).is_equal([EntradaSonora.Evento.PUERTA_FORZADA_CON_LLAVE])


func test_forzar_la_puerta_del_jefe_con_la_palanca_suena_su_audio_y_no_el_de_abrir() -> void:
	var local := _local()
	var puerta: Node3D = local.get_node(PUERTA_DEL_JEFE)
	puerta.set("lo_que_se_lleva", func() -> ObjetoDelAlmacen: return _objeto(Partida.PALANCA))
	puerta.accionar()
	assert_array(_pedidos).is_equal([EntradaSonora.Evento.PUERTA_FORZADA_CON_PALANCA])


func test_la_puerta_del_jefe_sin_llave_ni_palanca_sigue_sin_abrir() -> void:
	var local := _local()
	var puerta: Node3D = local.get_node(PUERTA_DEL_JEFE)
	puerta.accionar()
	assert_array(_pedidos).is_equal([EntradaSonora.Evento.PUERTA_TRABADA])
