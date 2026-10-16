extends GdUnitTestSuite

const GUIONES := "res://assets/dialogos/compradores_jornada_2.tres"
const FEDE := "res://assets/characters/fede/idle.tres"
const MIA := "res://assets/characters/mia/idle.tres"

var _almacenes: Array[Node3D] = []
var _listas: Array[Array] = []
var _ruta_anterior: String


func before_test() -> void:
	_ruta_anterior = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://atencion_444_prueba.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	await _limpiar_almacenes()
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_anterior


func _limpiar_almacenes() -> void:
	get_tree().paused = false
	for almacen in _almacenes:
		almacen.get_node("Servicios/AudioDelAlmacen/Reproductor").silenciar()
		almacen.queue_free()
	_almacenes.clear()
	_listas.clear()
	for cuadro in 4:
		await get_tree().process_frame


func _fabrica(jornada: int) -> Array[Comprador]:
	var compradores := Compradores.de_la_jornada(jornada)
	_listas.append(compradores)
	return compradores


func _abrir(jornada: int = 2, checkpoint: bool = false, medir: bool = false) -> Node3D:
	assert_str(Guardado.ruta_por_defecto).is_not_equal(Guardado.RUTA_DEL_USUARIO)
	if checkpoint:
		(
			assert_bool(
				Guardado.new().escribir(
					PoliticaDeGuardado.datos(Partida.desde({"jornada": jornada}))
				)
			)
			. is_true()
		)
	var almacen: Node3D = load("res://src/escenas/almacen.tscn").instantiate()
	if not checkpoint:
		almacen.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	if medir:
		almacen.set("compradores_de_la_apertura", _fabrica)
	_almacenes.append(almacen)
	add_child(almacen)
	almacen.get_node("Jugador").set_physics_process(false)
	almacen.get("_reloj").set_process(false)
	for cuadro in 3:
		await get_tree().physics_frame
	assert_int(almacen.get("_partida").jornada()).is_equal(jornada)
	return almacen


func _puesto(almacen: Node3D) -> Node3D:
	return almacen.get_node("Estructura/Ventanilla")


func _atenciones(almacen: Node3D) -> Ventanilla:
	return almacen.get("_atenciones")


func _sprite(almacen: Node3D) -> AnimatedSprite3D:
	return _puesto(almacen).get("comprador_visible")


func _texto(almacen: Node3D) -> RichTextLabel:
	return _puesto(almacen).get("panel").get_node("Fisico/Dialogo/Texto")


func _inventario(almacen: Node3D) -> Inventario:
	return almacen.get("_repositor").estante().get("_inventario")


func _ir_a(almacen: Node3D, hora: int, minuto: int = 0, segundo: int = 0) -> void:
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var turno: Turno = reloj.get("_turno")
	var destino := float(posmod(hora - Reglas.HORA_DE_APERTURA, 24) * 3600 + minuto * 60 + segundo)
	var consumido := Reglas.DURACION_DEL_TURNO - turno.tiempo_restante()
	assert_float(destino).is_greater_equal(consumido)
	reloj.avanzar(maxf(0.0, destino - consumido) / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL)


func _entrada_actual(almacen: Node3D) -> String:
	return _atenciones(almacen).atencion().dialogo().entrada_actual()


func _pulsar_real(boton: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for presionado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = boton
		evento.pressed = presionado
		evento.position = get_viewport().get_visible_rect().get_center()
		evento.global_position = evento.position
		Input.parse_input_event(evento)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _esc_real() -> void:
	for presionado: bool in [true, false]:
		var evento := InputEventKey.new()
		evento.keycode = KEY_ESCAPE
		evento.pressed = presionado
		Input.parse_input_event(evento)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _apuntar(almacen: Node3D) -> void:
	var puesto := _puesto(almacen)
	var entrada: Tween = puesto.get("_entrada")
	if entrada != null:
		entrada.custom_step(20.0)
	var sprite := _sprite(almacen)
	sprite.stop()
	var textura := sprite.sprite_frames.get_frame_texture(&"idle", sprite.frame)
	var imagen := textura.get_image()
	var pixel := Vector2i(-1, -1)
	for y in range(imagen.get_height() / 4, imagen.get_height() / 2, 8):
		for x in range(imagen.get_width() / 8, imagen.get_width() * 7 / 8, 8):
			if imagen.get_pixel(x, y).a > 0.0:
				pixel = Vector2i(x, y)
				break
		if pixel.x >= 0:
			break
	assert_int(pixel.x).is_greater_equal(0)
	var local := (Vector2(pixel) + Vector2.ONE * 0.5 - textura.get_size() / 2.0) * sprite.pixel_size
	var punto := sprite.to_global(Vector3(local.x, -local.y, 0.0))
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.global_position = punto + sprite.global_basis.z
	camara.look_at(punto)
	for cuadro in 3:
		await get_tree().physics_frame
	var consulta := PhysicsRayQueryParameters3D.create(camara.global_position, punto, 3)
	consulta.exclude = [jugador.get_rid()]
	var golpe := jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	var objetivo: Node3D = puesto.get("objetivo")
	assert_object(golpe.get("collider")).is_same(objetivo)
	jugador.call("_leer_la_mira")
	assert_object(jugador.call("enfocado")).is_same(objetivo)


func _pulsar(almacen: Node3D) -> void:
	if not _puesto(almacen).get("_abierta"):
		await _apuntar(almacen)
	await _pulsar_real()


func _inicial(almacen: Node3D, cantidad: int) -> void:
	await _pulsar(almacen)
	assert_bool(_puesto(almacen).get("_abierta")).is_true()
	for indice in cantidad:
		assert_bool(_atenciones(almacen).atencion().dialogo().terminado()).is_false()
		assert_str(_texto(almacen).text).is_equal(_entrada_actual(almacen))
		await _pulsar_real()
		assert_bool(_puesto(almacen).get("_abierta")).is_equal(indice + 1 < cantidad)
	assert_bool(_atenciones(almacen).atencion().dialogo().terminado()).is_true()
	assert_bool(almacen.get_node("Jugador").call("suspendido")).is_false()


func _retirar(almacen: Node3D, producto: Producto) -> ObjetoAgarrable:
	almacen.get("_reposicion_manual").retirar(producto.id)
	var agarre: Agarre = almacen.get("_agarre")
	var cuerpo := agarre.cuerpo_sostenido() as ObjetoAgarrable
	assert_object(cuerpo).is_not_null()
	assert_object(agarre.manos().sostenido()).is_instanceof(UnidadDeProducto)
	if cuerpo != null:
		assert_int((cuerpo.datos as UnidadDeProducto).producto.id).is_equal(producto.id)
	return cuerpo


func _ticket(almacen: Node3D, pedido: Venta) -> ObjetoAgarrable:
	var caja: CajaRegistradora = almacen.get("_caja")
	caja.pedir_borrar()
	for producto in pedido.productos():
		for unidad in pedido.unidades_de(producto):
			caja.pedir_anotar(UnidadDeProducto.new(producto))
	caja.pedir_imprimir()
	var destino: Node3D = almacen.get("_puesto_de_la_caja").get("destino_de_los_tickets")
	for nodo in destino.get_children():
		var papel := nodo as ObjetoAgarrable
		if papel != null and papel.datos is Ticket and papel.visible:
			return papel
	(
		assert_bool(false)
		. override_failure_message("La impresora no produjo el ticket exacto")
		. is_true()
	)
	return null


func _entregar_ticket(almacen: Node3D, pedido: Venta) -> ObjetoAgarrable:
	var papel := _ticket(almacen, pedido)
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(papel.datos, papel)).is_true()
	await _pulsar(almacen)
	assert_object(agarre.cuerpo_sostenido()).is_null()
	return papel


func _comprar(almacen: Node3D, ticket_primero: bool = false) -> void:
	var atendida := _atenciones(almacen).atencion()
	var pedido := atendida.comprador().pedido()
	if ticket_primero:
		await _entregar_ticket(almacen, pedido)
		assert_bool(atendida.vendida()).is_false()
	for producto in pedido.productos():
		var cuerpo := _retirar(almacen, producto)
		var identidad := cuerpo.datos
		await _pulsar(almacen)
		assert_object(almacen.get("_agarre").cuerpo_sostenido()).is_null()
		assert_object(cuerpo.datos).is_same(identidad)
		assert_bool(cuerpo.visible).is_false()
	if not ticket_primero:
		assert_bool(atendida.vendida()).is_false()
		await _entregar_ticket(almacen, pedido)
	assert_bool(atendida.vendida()).is_true()
	assert_bool(atendida.despachada()).is_false()


func _despedida(almacen: Node3D, cantidad: int) -> void:
	var atendida := _atenciones(almacen).atencion()
	for indice in cantidad:
		assert_bool(_sprite(almacen).is_visible_in_tree()).is_true()
		assert_bool(atendida.despachada()).is_false()
		assert_str(_texto(almacen).text).is_equal(atendida.dialogo().entrada_actual())
		await _pulsar_real()
		assert_bool(atendida.despachada()).is_equal(indice + 1 == cantidad)
	assert_bool(_puesto(almacen).get("_abierta")).is_false()
	assert_bool(_sprite(almacen).visible).is_false()
	var retiradas: Array = _puesto(almacen).get("_retiradas")
	assert_array(retiradas).has_size(1)
	if not retiradas.is_empty():
		var retirada := retiradas[0] as AnimatedSprite3D
		var origen := retirada.global_transform
		var derecha := (almacen.get_node("Jugador/Giro/Camara") as Camera3D).global_basis.x
		retirada.call("_process", 0.1)
		assert_float((retirada.global_position - origen.origin).dot(derecha)).is_greater(0.0)
		assert_bool(retirada.global_basis.is_equal_approx(origen.basis)).is_true()
	await _pulsar_real()
	assert_array(_puesto(almacen).get("_retiradas")).has_size(1)


func _cantidades(almacen: Node3D, producto: Producto) -> Array[int]:
	var inventario := _inventario(almacen)
	return [
		inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO),
		inventario.unidades(producto, Inventario.Ubicacion.GONDOLA),
		inventario.afuera(producto)
	]


func _figura(almacen: Node3D, ruta: String) -> void:
	var sprite := _sprite(almacen)
	assert_bool(sprite.is_visible_in_tree()).is_true()
	assert_str(sprite.sprite_frames.resource_path).is_equal(ruta)
	assert_int(sprite.sprite_frames.get_frame_count(&"idle")).is_equal(8)
	assert_bool(sprite.sprite_frames.get_animation_loop(&"idle")).is_true()
	assert_bool(sprite.no_depth_test).is_false()
	assert_int(sprite.billboard).is_equal(BaseMaterial3D.BILLBOARD_DISABLED)
	assert_bool(_puesto(almacen).get("panel").visible).is_false()


# AC-CTR-057
func test_transicion_y_checkpoint_activan_la_agenda_productiva_de_jornada_2() -> void:
	for checkpoint: bool in [false, true]:
		var almacen := await _abrir(2 if checkpoint else 1, checkpoint, true)
		if not checkpoint:
			var reloj: RelojDelTurno = almacen.get("_reloj")
			for tarea: Tarea in almacen.get("_partida").obligatorias():
				reloj.completar(tarea)
			reloj.avanzar(Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL)
			assert_int(almacen.get("_partida").jornada()).is_equal(2)
			assert_bool(almacen.get("_ciclo").abrir_la_jornada()).is_true()
		var lista: Array = _listas.back()
		var tarea := _atenciones(almacen).tarea()
		var compartida: Array = tarea.get("_compradores")
		assert_array(lista).has_size(2)
		assert_array(compartida).has_size(2)
		for indice in 2:
			assert_object(compartida[indice]).is_same(lista[indice])
			assert_object(compartida[indice].pedido()).is_same(lista[indice].pedido())
		assert_object(tarea.get("_inventario")).is_same(_inventario(almacen))
		assert_int(_listas.size()).is_equal(1 if checkpoint else 2)
		assert_object(_atenciones(almacen).atencion()).is_null()
		_ir_a(almacen, 20, 30)
		assert_int(_atenciones(almacen).atencion().comprador().personaje).is_equal(
			DialogosDeCompradores.Personaje.FEDE
		)
		_figura(almacen, FEDE)
		_ir_a(almacen, 23, 30)
		assert_object(tarea.en_ventanilla()).is_null()
		_ir_a(almacen, 5)
		assert_int(_atenciones(almacen).atencion().comprador().personaje).is_equal(
			DialogosDeCompradores.Personaje.MIA
		)
		_figura(almacen, MIA)
		assert_array(tarea.get("_atenciones")).has_size(2)
		await _limpiar_almacenes()


# AC-CTR-001 AC-CTR-041 AC-CTR-063
func test_jornada_uno_y_genericas_tres_a_cinco_conservan_su_recorrido() -> void:
	for jornada in [1, 3, 4, 5]:
		var almacen := await _abrir(jornada)
		var compradores: Array = _atenciones(almacen).tarea().get("_compradores")
		assert_array(compradores).has_size(2)
		var nuevos := Compradores.de_la_jornada(jornada)
		for indice in 2:
			assert_object(compradores[indice]).is_not_same(nuevos[indice])
			assert_str(compradores[indice].nombre()).is_equal(nuevos[indice].nombre())
			assert_bool(nuevos[indice].tiene_horario()).is_equal(jornada == 1)
		if jornada == 1:
			_ir_a(almacen, 22)
			assert_int(_atenciones(almacen).atencion().comprador().personaje).is_equal(
				DialogosDeCompradores.Personaje.TIN
			)
			_ir_a(almacen, 4)
			assert_int(_atenciones(almacen).atencion().comprador().personaje).is_equal(
				DialogosDeCompradores.Personaje.TIA
			)
		else:
			_puesto(almacen).call("accionar")
			assert_bool(_atenciones(almacen).atencion().fisica()).is_false()
			assert_str(_atenciones(almacen).atencion().comprador().nombre()).is_equal(
				Compradores.padron()[0].nombre()
			)
			assert_bool(_puesto(almacen).get("panel").get("_cobrar").visible).is_true()
		await _limpiar_almacenes()


# AC-CTR-060
func test_el_primer_clic_y_las_iniciales_productivas_no_entregan() -> void:
	for mia: bool in [false, true]:
		var almacen := await _abrir()
		_ir_a(almacen, 5 if mia else 20, 0 if mia else 30)
		var atendida := _atenciones(almacen).atencion()
		var cuerpo := _retirar(almacen, atendida.comprador().pedido().productos()[0])
		var identidad := cuerpo.datos
		var agarre: Agarre = almacen.get("_agarre")
		await _apuntar(almacen)
		var camara: Camera3D = almacen.get_node("Jugador/Giro/Camara")
		var vista := camara.global_transform
		await _pulsar_real()
		var inicial := atendida.comprador().dialogos.inicial(atendida.comprador().personaje)
		assert_str(_entrada_actual(almacen)).is_equal(inicial.entrada_actual())
		assert_bool(almacen.get_node("Jugador").call("suspendido")).is_true()
		await _pulsar_real(MOUSE_BUTTON_RIGHT)
		assert_str(_entrada_actual(almacen)).is_equal(inicial.entrada_actual())
		await _esc_real()
		assert_bool(get_tree().paused).is_true()
		assert_object(agarre.cuerpo_sostenido()).is_same(cuerpo)
		await _esc_real()
		assert_bool(get_tree().paused).is_false()
		var reloj: RelojDelTurno = almacen.get("_reloj")
		var turno: Turno = reloj.get("_turno")
		var antes := turno.tiempo_restante()
		await get_tree().create_timer(0.05).timeout
		reloj.call("_process", 0.0)
		assert_float(turno.tiempo_restante()).is_less(antes)
		assert_str(_entrada_actual(almacen)).is_equal(inicial.entrada_actual())
		for indice in 1 if mia else 3:
			await _pulsar_real()
			inicial.avanzar()
			assert_bool(atendida.dialogo().terminado()).is_equal(inicial.terminado())
			assert_object(agarre.cuerpo_sostenido()).is_same(cuerpo)
			assert_object(agarre.manos().sostenido()).is_same(identidad)
			assert_bool(atendida.vendida()).is_false()
			if not inicial.terminado():
				assert_str(_entrada_actual(almacen)).is_equal(inicial.entrada_actual())
		assert_bool(almacen.get_node("Jugador").call("suspendido")).is_false()
		assert_bool(camara.global_transform.is_equal_approx(vista)).is_true()
		agarre.soltar(false)
		await _pulsar(almacen)
		assert_str(_entrada_actual(almacen)).is_not_equal(
			atendida.comprador().dialogos.inicial(atendida.comprador().personaje).entrada_actual()
		)
		await _pulsar_real()
		assert_bool(_puesto(almacen).get("_abierta")).is_false()
		await _limpiar_almacenes()


# AC-CTR-061 AC-CTR-041
func test_los_tickets_y_despedidas_productivos_completan_una_venta() -> void:
	for ticket_primero: bool in [false, true]:
		for mia: bool in [false, true]:
			var almacen := await _abrir()
			_ir_a(almacen, 5 if mia else 20, 0 if mia else 30)
			var compras: Array[bool] = []
			_atenciones(almacen).compra_realizada.connect(func() -> void: compras.append(true))
			await _inicial(almacen, 1 if mia else 3)
			var atendida := _atenciones(almacen).atencion()
			var pedido := atendida.comprador().pedido()
			var cantidades: Dictionary[Producto, Array] = {}
			for producto in pedido.productos():
				cantidades[producto] = _cantidades(almacen, producto)
			await _comprar(almacen, ticket_primero)
			assert_array(compras).has_size(1)
			for producto in pedido.productos():
				assert_int(_cantidades(almacen, producto)[0]).is_equal(cantidades[producto][0] - 1)
				assert_int(_cantidades(almacen, producto)[1]).is_equal(cantidades[producto][1])
				assert_int(_atenciones(almacen).tarea().vendidas_de(producto)).is_equal(1)
			await _despedida(almacen, 3 if mia else 2)
			assert_array(compras).has_size(1)
			assert_object(atendida.comprador().pedido()).is_same(pedido)
			await _limpiar_almacenes()


# AC-CTR-062
func test_fede_parcial_vence_a_las_2330_sin_despedida_y_devuelve_la_unidad() -> void:
	var almacen := await _abrir()
	_ir_a(almacen, 20, 30)
	await _inicial(almacen, 3)
	var atendida := _atenciones(almacen).atencion()
	var producto := atendida.comprador().pedido().productos()[0]
	var cantidades := _cantidades(almacen, producto)
	var cuerpo := _retirar(almacen, producto)
	var identidad := cuerpo.datos
	await _pulsar(almacen)
	var papel := await _entregar_ticket(almacen, atendida.comprador().pedido())
	await _pulsar(almacen)
	assert_bool(_puesto(almacen).get("_abierta")).is_true()
	_ir_a(almacen, 23, 30)
	assert_bool(atendida.despachada()).is_true()
	assert_bool(atendida.vendida()).is_false()
	assert_object(atendida.dialogo()).is_null()
	assert_bool(_puesto(almacen).get("_abierta")).is_false()
	for cuadro in 30:
		await get_tree().physics_frame
	assert_bool(is_instance_valid(papel)).is_false()
	assert_bool(is_instance_valid(cuerpo)).is_true()
	if is_instance_valid(cuerpo):
		assert_object(cuerpo.datos).is_same(identidad)
		assert_bool(cuerpo.visible).is_true()
		assert_bool(cuerpo.freeze).is_false()
		assert_bool(cuerpo.has_meta(&"recibido_por_comprador")).is_false()
		assert_array(almacen.get("_reposicion_manual").unidades_sueltas()).contains(cuerpo)
	assert_int(_cantidades(almacen, producto)[0]).is_equal(cantidades[0])
	assert_int(_atenciones(almacen).tarea().vendidas_de(producto)).is_zero()


# AC-CTR-062
func test_mia_incompleta_vence_antes_del_cierre_aun_con_dialogo_abierto() -> void:
	var almacen := await _abrir()
	_ir_a(almacen, 5)
	await _pulsar(almacen)
	var atendida := _atenciones(almacen).atencion()
	var entrada := _entrada_actual(almacen)
	await _esc_real()
	assert_bool(get_tree().paused).is_true()
	var turno: Turno = almacen.get("_reloj").get("_turno")
	var pausado := turno.tiempo_restante()
	await get_tree().create_timer(0.05, true).timeout
	assert_float(turno.tiempo_restante()).is_equal(pausado)
	assert_str(_entrada_actual(almacen)).is_equal(entrada)
	await _esc_real()
	var resultados: Array[bool] = []
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.turno_cerrado.connect(
		func(_cumplidas: int) -> void:
			resultados.append(
				(
					atendida.despachada()
					and not atendida.vendida()
					and not _atenciones(almacen).tarea().completada()
				)
			)
	)
	_ir_a(almacen, 8)
	assert_array(resultados).contains_exactly([true])
	assert_object(atendida.dialogo()).is_null()
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_false()
	assert_bool(reloj.corriendo()).is_false()
	assert_bool(_puesto(almacen).get("_abierta")).is_false()


# AC-CTR-062 AC-CTR-041
func test_la_venta_de_las_075959_cuenta_aunque_siga_la_despedida() -> void:
	var almacen := await _abrir()
	_ir_a(almacen, 20, 30)
	await _inicial(almacen, 3)
	await _comprar(almacen)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_false()
	await _despedida(almacen, 2)
	_ir_a(almacen, 5)
	await _inicial(almacen, 1)
	var atendida := _atenciones(almacen).atencion()
	for producto in atendida.comprador().pedido().productos():
		_retirar(almacen, producto)
		await _pulsar(almacen)
	_ir_a(almacen, 7, 59, 59)
	await _entregar_ticket(almacen, atendida.comprador().pedido())
	assert_bool(atendida.vendida()).is_true()
	assert_bool(atendida.despachada()).is_false()
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_true()
	var vencidas: Array[Comprador] = []
	_atenciones(almacen).comprador_vencido.connect(
		func(comprador: Comprador) -> void: vencidas.append(comprador)
	)
	_ir_a(almacen, 8)
	assert_bool(atendida.vendida()).is_true()
	assert_array(vencidas).not_contains(atendida.comprador())
	assert_bool(reloj.obligatoria(Tarea.Tipo.CAJA).completada()).is_true()


# AC-CTR-063
func test_dos_atenciones_del_mismo_recurso_tienen_cursores_independientes() -> void:
	var primero := await _abrir()
	var segundo := await _abrir()
	_ir_a(primero, 20, 30)
	_ir_a(segundo, 20, 30)
	var una := _atenciones(primero).atencion()
	var otra := _atenciones(segundo).atencion()
	assert_object(una.comprador().dialogos).is_same(otra.comprador().dialogos)
	var contenido: PackedStringArray = una.comprador().dialogos.get("fede").duplicate()
	# Dos escenas comparten el viewport: accionar cada objetivo real evita propagar el mismo
	# evento global a ambas ventanillas mientras se comprueba únicamente el aislamiento.
	_puesto(primero).get("objetivo").call("accionar")
	_puesto(segundo).get("objetivo").call("accionar")
	var primera := otra.dialogo().entrada_actual()
	_puesto(primero).call("_al_pulsar")
	assert_str(una.dialogo().entrada_actual()).is_not_equal(primera)
	assert_str(otra.dialogo().entrada_actual()).is_equal(primera)
	assert_object(una.dialogo()).is_not_same(otra.dialogo())
	assert_array(Array(una.comprador().dialogos.get("fede"))).is_equal(Array(contenido))


# AC-CTR-063 AC-CTR-041
func test_reabrir_la_jornada_limpia_introduccion_y_venta_sin_imagenes_heredadas() -> void:
	for vendida: bool in [false, true]:
		var almacen := await _abrir()
		_ir_a(almacen, 20, 30)
		var anterior := _atenciones(almacen).atencion()
		if vendida:
			await _inicial(almacen, 3)
			await _comprar(almacen)
		else:
			await _pulsar(almacen)
		var tarea := _atenciones(almacen).tarea()
		assert_bool(almacen.get("_ciclo").abrir_la_jornada()).is_true()
		assert_object(_atenciones(almacen).tarea()).is_not_same(tarea)
		assert_object(_atenciones(almacen).atencion()).is_null()
		assert_object(almacen.get("_agarre").cuerpo_sostenido()).is_null()
		assert_array(_puesto(almacen).get("_retiradas")).is_empty()
		assert_dict(_puesto(almacen).get("_recibidos")).is_empty()
		assert_object(_puesto(almacen).get("_imagen_de")).is_null()
		assert_bool(_sprite(almacen).visible).is_false()
		assert_bool(_atenciones(almacen).tarea().completada()).is_false()
		_ir_a(almacen, 20, 30)
		assert_object(_atenciones(almacen).atencion()).is_not_same(anterior)
		assert_bool(_atenciones(almacen).atencion().conversacion_iniciada()).is_false()
		assert_bool(_atenciones(almacen).atencion().vendida()).is_false()
		for producto in _atenciones(almacen).atencion().comprador().pedido().productos():
			assert_int(_atenciones(almacen).tarea().vendidas_de(producto)).is_zero()
		await _pulsar(almacen)
		assert_str(_entrada_actual(almacen)).is_equal(
			(
				_atenciones(almacen)
				. atencion()
				. comprador()
				. dialogos
				. inicial(DialogosDeCompradores.Personaje.FEDE)
				. entrada_actual()
			)
		)
		await _limpiar_almacenes()


# AC-STK-090
func test_duronga_del_deposito_se_vende_sin_consumir_reserva_ni_reponer() -> void:
	var almacen := await _abrir()
	var producto := Catalogo.de(Producto.Id.DURONGA)
	var repositor: Repositor = almacen.get("_repositor")
	# Elegir una apertura real reproducible que ejerza reserva positiva, sin sustituir stock.
	for semilla in range(1, 257):
		almacen.get("azar_de_la_apertura").seed = semilla
		almacen.call("_al_abrir_la_jornada", 2)
		if not repositor.estante().casilleros_vacios(producto).is_empty():
			break
	var inventario := _inventario(almacen)
	var vacios := repositor.estante().casilleros_vacios(producto)
	assert_array(vacios).is_not_empty()
	var cupos: Dictionary = almacen.get("_reposicion_manual").casilleros()
	assert_int(cupos[producto.id]).is_greater(0)
	var cantidades := _cantidades(almacen, producto)
	assert_int(inventario.vendibles(producto)).is_greater_equal(1)
	assert_int(cantidades[0] - vacios.size()).is_greater_equal(1)
	_ir_a(almacen, 20, 30)
	await _inicial(almacen, 3)
	var lista: Array = _atenciones(almacen).tarea().get("_compradores")
	assert_object(_atenciones(almacen).tarea().get("_inventario")).is_same(inventario)
	assert_object(_atenciones(almacen).atencion().comprador()).is_same(lista[0])
	assert_int(lista[0].pedido().unidades_de(Catalogo.de(Producto.Id.PRONGLES))).is_equal(1)
	await _comprar(almacen)
	assert_int(_atenciones(almacen).tarea().vendidas_de(producto)).is_equal(1)
	assert_int(_cantidades(almacen, producto)[0]).is_equal(cantidades[0] - 1)
	assert_int(_cantidades(almacen, producto)[1]).is_equal(cantidades[1])
	assert_array(repositor.estante().casilleros_vacios(producto)).is_equal(vacios)
	assert_int(_cantidades(almacen, producto)[0]).is_greater_equal(vacios.size())
	assert_int(almacen.get("_reposicion_manual").casilleros()[producto.id]).is_equal(
		cupos[producto.id]
	)
	for vendido: Producto in lista[0].pedido().productos():
		assert_int(_atenciones(almacen).tarea().vendidas_de(vendido)).is_equal(1)


func _mirar_balde(almacen: Node3D) -> void:
	var objetivo: Node3D = almacen.get_node("Objetos/Balde")
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var forma: CollisionShape3D = jugador.get_node("Cuerpo")
	var espacio := jugador.get_world_3d().direct_space_state
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.collision_mask = jugador.collision_mask
	consulta.exclude = [jugador.get_rid()]
	var encontrada := Vector3.INF
	for distancia: float in [0.6, 0.9, 1.2, 1.5]:
		for direccion: Vector3 in [Vector3.BACK, Vector3.LEFT, Vector3.FORWARD, Vector3.RIGHT]:
			var punto := objetivo.global_position + direccion * distancia
			var rayo := PhysicsRayQueryParameters3D.create(
				Vector3(punto.x, 3.0, punto.z), Vector3(punto.x, -1.0, punto.z), 1
			)
			rayo.exclude = [jugador.get_rid()]
			var golpe := espacio.intersect_ray(rayo)
			if golpe.get("collider") != almacen.get_node("Estructura/SueloSolido"):
				continue
			var pie: Vector3 = golpe.position + Vector3.UP * 0.005
			consulta.transform = Transform3D(Basis.IDENTITY, pie + forma.position)
			if espacio.intersect_shape(consulta, 1).is_empty():
				encontrada = pie
				break
		if encontrada.is_finite():
			break
	assert_bool(encontrada.is_finite()).is_true()
	if not encontrada.is_finite():
		return
	jugador.call("ubicar", Transform3D(Basis.IDENTITY, encontrada))
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.look_at(objetivo.global_position + Vector3.UP * 0.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_array(espacio.intersect_shape(consulta, 1)).is_empty()
	jugador.call("_leer_la_mira")
	assert_object(jugador.call("enfocado")).is_same(objetivo)


# AC-STK-091
func test_la_misma_unidad_poetico_tenida_se_vende_una_sola_vez() -> void:
	var almacen := await _abrir()
	_ir_a(almacen, 20, 30)
	await _inicial(almacen, 3)
	var poetico := Catalogo.de(Producto.Id.POETICO)
	var cantidades := _cantidades(almacen, poetico)
	var cuerpo := _retirar(almacen, poetico)
	var identidad := cuerpo.datos as UnidadDeProducto
	var retirado := _cantidades(almacen, poetico)
	var piso: PisoDelLocal = almacen.get("_limpiador").piso()
	piso.balde().llenar()
	await _mirar_balde(almacen)
	await _pulsar_real()
	assert_int(piso.balde().agua()).is_equal(ReglasDeLaLimpieza.Agua.AZUL)
	assert_bool(almacen.get("_partida").uso_de_poetico_en(2)).is_true()
	assert_object(almacen.get("_agarre").cuerpo_sostenido()).is_same(cuerpo)
	assert_object(almacen.get("_agarre").manos().sostenido()).is_same(identidad)
	assert_array(_cantidades(almacen, poetico)).is_equal(retirado)
	await _pulsar(almacen)
	assert_object(cuerpo.datos).is_same(identidad)
	assert_bool(cuerpo.visible).is_false()
	var atendida := _atenciones(almacen).atencion()
	for producto in atendida.comprador().pedido().productos():
		if producto.id == Producto.Id.POETICO:
			continue
		_retirar(almacen, producto)
		await _pulsar(almacen)
	await _entregar_ticket(almacen, atendida.comprador().pedido())
	assert_bool(atendida.vendida()).is_true()
	assert_object(cuerpo.datos).is_same(identidad)
	assert_int(_cantidades(almacen, poetico)[0]).is_equal(cantidades[0] - 1)
	assert_int(_cantidades(almacen, poetico)[1]).is_equal(cantidades[1])
	assert_bool(_inventario(almacen).vender_unidades([identidad])).is_false()
	assert_int(_cantidades(almacen, poetico)[0]).is_equal(cantidades[0] - 1)
	assert_int(_atenciones(almacen).tarea().vendidas_de(poetico)).is_equal(1)


# AC-STK-091 AC-CTR-062
func test_el_bidon_azul_no_satisface_poetico_ni_cambia_cantidades() -> void:
	var almacen := await _abrir()
	_ir_a(almacen, 20, 30)
	await _inicial(almacen, 3)
	var atendida := _atenciones(almacen).atencion()
	var azul: ObjetoAgarrable = almacen.get_node("Objetos/JabonAzul")
	var cantidades := _cantidades(almacen, Catalogo.de(Producto.Id.POETICO))
	assert_bool(azul.visible).is_false()
	assert_str(String(azul.datos.id)).is_equal("jabon_azul")
	assert_bool(azul.datos is UnidadDeProducto).is_false()
	# El cuerpo está ausente por #432; se ejerce el validador real con su identidad original,
	# sin volver visible el útil ni fabricar una unidad vendible.
	assert_int(_atenciones(almacen).pedir_interaccion(azul.datos)).is_equal(
		RecepcionDeCompra.Resultado.RECHAZADA
	)
	assert_bool(atendida.vendida()).is_false()
	assert_str(atendida.dialogo().entrada_actual()).starts_with("Yo no pedí esto. ")
	assert_array(_cantidades(almacen, Catalogo.de(Producto.Id.POETICO))).is_equal(cantidades)
	await _pulsar_real()
	for producto in atendida.comprador().pedido().productos():
		if producto.id != Producto.Id.POETICO:
			_retirar(almacen, producto)
			await _pulsar(almacen)
	await _entregar_ticket(almacen, atendida.comprador().pedido())
	assert_bool(atendida.vendida()).is_false()
	assert_int(_atenciones(almacen).tarea().vendidas_de(Catalogo.de(Producto.Id.POETICO))).is_zero()


func _segmento_cruza_el_antepecho(antepecho: MeshInstance3D, ojo: Vector3, punto: Vector3) -> bool:
	var inversa := antepecho.global_transform.affine_inverse()
	var desde := inversa * ojo
	var hasta := inversa * punto
	if antepecho.get_aabb().intersects_segment(desde, hasta) == null:
		return false
	var caras := antepecho.mesh.get_faces()
	for indice in range(0, caras.size(), 3):
		if (
			Geometry3D.segment_intersects_triangle(
				desde, hasta, caras[indice], caras[indice + 1], caras[indice + 2]
			)
			!= null
		):
			return true
	return false


func _pixel_opaco_detras_del_antepecho(
	sprite: AnimatedSprite3D, antepecho: MeshInstance3D, ojos: Array[Vector3]
) -> Vector3:
	var textura := sprite.sprite_frames.get_frame_texture(&"idle", sprite.frame)
	var imagen := textura.get_image()
	var caja: AABB = (
		sprite.global_transform.affine_inverse() * antepecho.global_transform * antepecho.get_aabb()
	)
	for y in range(0, imagen.get_height(), 4):
		for x in range(imagen.get_width() / 8, imagen.get_width() * 7 / 8, 4):
			if imagen.get_pixel(x, y).a == 0.0:
				continue
			var pixel := Vector2(x, y) + Vector2.ONE * 0.5
			if sprite.flip_h:
				pixel.x = textura.get_width() - pixel.x
			if sprite.flip_v:
				pixel.y = textura.get_height() - pixel.y
			var plano := (pixel - textura.get_size() / 2.0 + sprite.offset) * sprite.pixel_size
			var local := Vector3(plano.x, -plano.y, 0.0)
			if local.y >= caja.end.y - sprite.pixel_size:
				continue
			var candidato := sprite.to_global(local)
			var tapado := true
			for ojo in ojos:
				if not _segmento_cruza_el_antepecho(antepecho, ojo, candidato):
					tapado = false
					break
			if tapado:
				return candidato
	return Vector3.INF


# AC-CTR-063
func test_las_figuras_propias_ocultan_el_corte_inferior_y_conservan_orientacion() -> void:
	for mia: bool in [false, true]:
		var almacen := await _abrir()
		_ir_a(almacen, 5 if mia else 20, 0 if mia else 30)
		await _apuntar(almacen)
		var sprite := _sprite(almacen)
		var orientacion := sprite.global_basis
		var puesto := _puesto(almacen)
		var objetivo: Node3D = puesto.get("objetivo")
		var antepecho: MeshInstance3D = puesto.get("antepecho")
		var camara: Camera3D = almacen.get_node("Jugador/Giro/Camara")
		var ojos: Array[Vector3] = []
		for lado: float in [-0.2, 0.0, 0.2]:
			ojos.append(camara.global_position + sprite.global_basis.x * lado)
		assert_object(antepecho.mesh).is_not_null()
		assert_int(antepecho.mesh.get_faces().size()).is_greater_equal(3)
		var punto := _pixel_opaco_detras_del_antepecho(sprite, antepecho, ojos)
		(
			assert_bool(punto.is_finite())
			. override_failure_message(
				"No hay píxel opaco inferior ocluido por triángulos reales desde las tres miradas"
			)
			. is_true()
		)
		if not punto.is_finite():
			return
		for ojo in ojos:
			camara.global_position = ojo
			camara.look_at(punto)
			for cuadro in 3:
				await get_tree().physics_frame
			# Primero se prueba el hecho geométrico; la consulta de foco es el resultado.
			assert_bool(_segmento_cruza_el_antepecho(antepecho, ojo, punto)).is_true()
			assert_bool(objetivo.call("admite_foco_en", punto, camara.global_position)).is_false()
			almacen.get_node("Jugador").call("_leer_la_mira")
			assert_object(almacen.get_node("Jugador").call("enfocado")).is_not_same(objetivo)
			assert_bool(sprite.global_basis.is_equal_approx(orientacion)).is_true()
		assert_bool(sprite.no_depth_test).is_false()
		await _limpiar_almacenes()


# AC-CTR-064 AC-CTR-060 AC-CTR-061
func test_los_recursos_productivos_cargan_y_ejercen_la_atencion_de_jornada_2() -> void:
	var guiones := load(GUIONES) as DialogosDeCompradores
	assert_object(guiones).is_not_null()
	if guiones == null:
		return
	for mia: bool in [false, true]:
		var almacen := await _abrir()
		_ir_a(almacen, 5 if mia else 20, 0 if mia else 30)
		_figura(almacen, MIA if mia else FEDE)
		var atendida := _atenciones(almacen).atencion()
		assert_object(atendida.comprador().dialogos).is_same(guiones)
		await _pulsar(almacen)
		var inicial := guiones.inicial(atendida.comprador().personaje)
		for indice in 1 if mia else 3:
			assert_str(_texto(almacen).text).is_equal(inicial.entrada_actual())
			if (mia and indice == 0) or (not mia and indice == 2):
				var nombres: Array[String] = (
					["Terminator", "Fernet God", "Actroncito"]
					if mia
					else ["Poético", "Progres", "Duronga"]
				)
				for nombre in nombres:
					assert_str(_texto(almacen).text).contains(
						"[color=#e4f850]" + nombre + "[/color]"
					)
				assert_str(_texto(almacen).text).not_contains("[b]").not_contains("[meta")
			inicial.avanzar()
			await _pulsar_real()
		assert_bool(almacen.get_node("Jugador").call("suspendido")).is_false()
		await _comprar(almacen)
		var final := guiones.despedida(atendida.comprador().personaje)
		for indice in 3 if mia else 2:
			assert_str(_texto(almacen).text).is_equal(final.entrada_actual())
			final.avanzar()
			await _pulsar_real()
		assert_bool(atendida.despachada()).is_true()
		assert_bool(_puesto(almacen).get("panel").visible).is_false()
		assert_bool(almacen.get_node("Jugador").call("suspendido")).is_false()
		await _limpiar_almacenes()
