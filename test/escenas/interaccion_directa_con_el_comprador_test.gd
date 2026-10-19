extends GdUnitTestSuite

const OBJETO := "res://src/escenas/objetos/objeto_agarrable.tscn"

var _almacenes: Array[Node3D] = []


func after_test() -> void:
	get_tree().paused = false
	for almacen in _almacenes:
		almacen.get_node("Servicios/AudioDelAlmacen/Reproductor").silenciar()
		almacen.queue_free()
	_almacenes.clear()
	for _cuadro in 4:
		await get_tree().process_frame


func _abrir() -> Node3D:
	var almacen: Node3D = load("res://src/escenas/almacen.tscn").instantiate()
	almacen.set("_partida", Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA}))
	_almacenes.append(almacen)
	add_child(almacen)
	almacen.get_node("Jugador").set_physics_process(false)
	almacen.get_node("Servicios/RelojDelTurno").set_process(false)
	for _cuadro in 3:
		await get_tree().physics_frame
	return almacen


func _pulsar(almacen: Node3D) -> void:
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	if puesto.get("_abierta"):
		var evento := InputEventAction.new()
		evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
		evento.pressed = true
		puesto.call("_input", evento)
	else:
		puesto.get_node("Comprador/Objetivo").call("accionar")


# AC-CTR-014, AC-CTR-065, AC-PLY-091
func test_el_primer_clic_muestra_la_primera_entrada_sin_saltarla() -> void:
	var almacen := await _abrir()
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var atenciones: Ventanilla = almacen.get("_atenciones")
	reloj.avanzar(120.0)
	await _apuntar(almacen)
	var jugador: Node3D = almacen.get_node("Jugador")
	jugador.call("_leer_la_mira")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var vista := camara.global_transform
	await _pulsar_real()
	assert_object(atenciones.atencion().dialogo()).is_not_null()
	if atenciones.atencion().dialogo() == null:
		return
	assert_str(atenciones.atencion().dialogo().entrada_actual()).is_not_empty()
	var inicial := atenciones.atencion().dialogo().entrada_actual()
	assert_bool(almacen.get_node("Jugador").get("_control").esta_suspendido()).is_true()
	await _pulsar_real()
	assert_str(atenciones.atencion().dialogo().entrada_actual()).is_not_equal(inicial)
	var segunda := atenciones.atencion().dialogo().entrada_actual()
	await _pulsar_real()
	assert_str(atenciones.atencion().dialogo().entrada_actual()).is_not_equal(segunda)
	assert_bool(jugador.call("suspendido")).is_true()
	await _pulsar_real()
	assert_bool(atenciones.atencion().dialogo().terminado()).is_true()
	assert_bool(jugador.call("suspendido")).is_false()
	assert_bool(camara.global_transform.is_equal_approx(vista)).is_true()


func test_el_hueco_vacio_no_abre_panel() -> void:  # AC-PLY-055, AC-PLY-092
	var almacen := await _abrir()
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	assert_bool(puesto.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_false()
	var objetivo: StaticBody3D = puesto.get("objetivo")
	assert_int(objetivo.collision_layer).is_zero()
	assert_bool((objetivo.get("forma") as CollisionShape3D).disabled).is_true()
	assert_object(puesto.get_node_or_null("Vidrio")).is_null()
	puesto.call("accionar")
	assert_bool(puesto.get("panel").visible).is_false()
	assert_bool(almacen.get_node("Jugador").get("_control").esta_suspendido()).is_false()


func _interaccion_real(almacen: Node3D) -> void:
	await _apuntar(almacen)
	almacen.get_node("Jugador").call("_leer_la_mira")
	await _pulsar_real()


func test_la_recepcion_real_conserva_pedido_y_rechazo_y_vende_una_vez() -> void:  # AC-CTR-048
	var almacen := await _abrir()
	var atendida := _una_entrada(almacen)
	var pedido := atendida.comprador().pedido()
	var agarre: Agarre = almacen.get("_agarre")
	var compras: Array[bool] = []
	(almacen.get("_atenciones") as Ventanilla).compra_realizada.connect(
		func() -> void: compras.append(true)
	)
	await _interaccion_real(almacen)
	await _pulsar_real()
	await _interaccion_real(almacen)
	assert_int(atendida.dialogo().entrada_actual().count("[color=#e4f850]")).is_equal(
		pedido.productos().size()
	)
	await _pulsar_real()
	var incorrecto: ObjetoAgarrable = load(OBJETO).instantiate()
	incorrecto.datos = Ticket.new([])
	almacen.add_child(incorrecto)
	assert_bool(agarre.pedir_agarrar(incorrecto.datos, incorrecto)).is_true()
	await _interaccion_real(almacen)
	assert_object(agarre.cuerpo_sostenido()).is_same(incorrecto)
	assert_str(atendida.dialogo().entrada_actual()).starts_with(DialogosDeCompradores.RECHAZO)
	await _pulsar_real()
	assert_object(agarre.cuerpo_sostenido()).is_same(incorrecto)
	assert_object(agarre.entregar()).is_same(incorrecto)
	incorrecto.queue_free()
	var productos: Array[Producto] = []
	for producto in pedido.productos():
		almacen.get("_reposicion_manual").retirar(producto.id)
		var cuerpo := agarre.cuerpo_sostenido()
		assert_object(cuerpo).is_not_null()
		await _interaccion_real(almacen)
		assert_object(agarre.cuerpo_sostenido()).is_null()
		assert_bool(cuerpo.visible).is_false()
		assert_object(cuerpo.get_parent()).is_same(almacen.get_node("Estructura/Ventanilla"))
		assert_object(atendida.comprador().pedido()).is_same(pedido)
		assert_bool(atendida.vendida()).is_false()
		productos.append(producto)
	var ticket: ObjetoAgarrable = load(OBJETO).instantiate()
	ticket.datos = Ticket.new(productos)
	almacen.add_child(ticket)
	assert_bool(agarre.pedir_agarrar(ticket.datos, ticket)).is_true()
	await _interaccion_real(almacen)
	assert_object(agarre.cuerpo_sostenido()).is_null()
	assert_array(compras).has_size(1)
	assert_bool(atendida.vendida()).is_true()
	assert_bool(atendida.despachada()).is_false()
	await _pulsar_real()
	assert_bool(atendida.despachada()).is_true()
	await _pulsar_real()
	assert_array(compras).has_size(1)
	assert_object(atendida.comprador().pedido()).is_same(pedido)
	assert_bool(almacen.get_node("Jugador").get("_control").esta_suspendido()).is_false()


func _una_entrada(almacen: Node3D) -> Atencion:
	var atenciones: Ventanilla = almacen.get("_atenciones")
	(almacen.get("_reloj") as RelojDelTurno).avanzar(120.0)
	var comprador := atenciones.atencion().comprador()
	var guion := DialogosDeCompradores.new()
	guion.tin = PackedStringArray(["Inicial"])
	guion.despedida_tin = PackedStringArray(["Despedida"])
	comprador.dialogos = guion
	return atenciones.atencion()


func test_cada_guion_de_una_entrada_devuelve_el_control_una_vez() -> void:  # AC-CTR-047, AC-PLY-091
	var almacen := await _abrir()
	var atendida := _una_entrada(almacen)
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	var jugador: Node3D = almacen.get_node("Jugador")
	var finales: Array[bool] = []
	(almacen.get("_atenciones") as Ventanilla).conversacion_terminada.connect(
		func() -> void: finales.append(true)
	)
	for etapa: int in [0, 1, 2, 3]:
		if etapa == 2:
			var agarre: Agarre = almacen.get("_agarre")
			var objeto: ObjetoAgarrable = load(OBJETO).instantiate()
			objeto.datos = UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))
			almacen.add_child(objeto)
			assert_bool(agarre.pedir_agarrar(objeto.datos, objeto)).is_true()
		elif etapa == 3:
			var agarre: Agarre = almacen.get("_agarre")
			agarre.soltar(true)
			var inventario: Inventario = atendida.get("_inventario")
			var productos: Array[Producto] = []
			for producto in atendida.comprador().pedido().productos():
				atendida.interactuar(Estante.new(inventario, Catalogo.todos()).retirar(producto))
				productos.append(producto)
			assert_int(atendida.interactuar(Ticket.new(productos))).is_equal(
				RecepcionDeCompra.Resultado.COMPLETA
			)
			puesto.call("_repintar")
		if etapa < 3:
			_pulsar(almacen)
		assert_bool(puesto.get("_abierta")).is_true()
		assert_bool(jugador.get("_control").esta_suspendido()).is_true()
		var entrada := atendida.dialogo().entrada_actual()
		var derecho := InputEventAction.new()
		derecho.action = ReglasDelJugador.ACCION_USAR
		derecho.pressed = true
		puesto.call("_input", derecho)
		assert_str(atendida.dialogo().entrada_actual()).is_equal(entrada)
		assert_bool(puesto.get("_abierta")).is_true()
		OS.delay_msec(250)
		await get_tree().process_frame
		assert_str(atendida.dialogo().entrada_actual()).is_equal(entrada)
		_pulsar(almacen)
		assert_bool(puesto.get("_abierta")).is_false()
		assert_bool(jugador.get("_control").esta_suspendido()).is_false()
		assert_array(finales).has_size(etapa + 1)


func test_la_referencia_distingue_inicial_pendiente_y_terminada() -> void:  # AC-PLY-094
	var almacen := await _abrir()
	var atendida := _una_entrada(almacen)
	var objetivo: Node3D = almacen.get_node("Estructura/Ventanilla/Comprador/Objetivo")
	var ticket := Ticket.new([])
	var antes: ReferenciaDeControles.Contexto = objetivo.call("contexto_de_interaccion", ticket)
	assert_int(antes.primario).is_equal(ReferenciaDeControles.Linea.HABLAR)
	assert_bool(atendida.conversacion_iniciada()).is_false()
	_pulsar(almacen)
	var durante: ReferenciaDeControles.Contexto = objetivo.call("contexto_de_interaccion", ticket)
	assert_int(durante.primario).is_equal(ReferenciaDeControles.Linea.HABLAR)
	_pulsar(almacen)
	var vacia: ReferenciaDeControles.Contexto = objetivo.call("contexto_de_interaccion", null)
	var ocupada: ReferenciaDeControles.Contexto = objetivo.call("contexto_de_interaccion", ticket)
	assert_int(vacia.primario).is_equal(ReferenciaDeControles.Linea.HABLAR)
	assert_int(ocupada.primario).is_equal(ReferenciaDeControles.Linea.ENTREGAR)
	assert_bool(atendida.vendida()).is_false()


# AC-CTR-049, AC-PLY-094, AC-PLY-079
func test_vencimiento_y_cierre_quitan_objetivo_y_atencion() -> void:
	var almacen := await _abrir()
	var atendida := _una_entrada(almacen)
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	var objetivo: Node3D = puesto.get_node("Comprador/Objetivo")
	_pulsar(almacen)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.avanzar(120.0)
	assert_bool(atendida.despachada()).is_true()
	assert_bool(puesto.get("_abierta")).is_false()
	objetivo.call("accionar")
	assert_object(atendida.dialogo()).is_null()
	assert_bool(puesto.get("_abierta")).is_false()
	reloj.avanzar(240.0)
	_pulsar(almacen)
	assert_bool(puesto.get("_abierta")).is_true()
	reloj.avanzar(240.0)
	assert_bool(puesto.get("_abierta")).is_false()
	assert_bool(almacen.get_node("Jugador").get("_control").esta_suspendido()).is_true()


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


func _apuntar(almacen: Node3D, transparente: bool = false, distancia: float = 1.0) -> Vector3:
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	var entrada: Tween = puesto.get("_entrada")
	if entrada != null:
		entrada.custom_step(20.0)
	var sprite: AnimatedSprite3D = puesto.get("comprador_visible")
	sprite.stop()
	var textura := sprite.sprite_frames.get_frame_texture(&"idle", sprite.frame)
	var imagen := textura.get_image()
	var pixel := Vector2i(-1, -1)
	for y in range(imagen.get_height() / 4, imagen.get_height() / 2, 8):
		for x in range(imagen.get_width() / 8, imagen.get_width() * 7 / 8, 8):
			if (imagen.get_pixel(x, y).a == 0.0) == transparente:
				pixel = Vector2i(x, y)
				break
		if pixel.x >= 0:
			break
	assert_int(pixel.x).is_greater_equal(0)
	var local := Vector2(pixel) + Vector2.ONE * 0.5 - textura.get_size() / 2.0
	local *= sprite.pixel_size
	var punto := sprite.to_global(Vector3(local.x, -local.y, 0.0))
	var jugador: Node3D = almacen.get_node("Jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.global_position = punto + sprite.global_basis.z * distancia
	camara.look_at(punto)
	for _cuadro in 3:
		await get_tree().physics_frame
	var consulta := PhysicsRayQueryParameters3D.create(camara.global_position, punto, 3)
	consulta.exclude = [(jugador as CollisionObject3D).get_rid()]
	var golpe := jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	assert_object(golpe.get("collider")).is_same(puesto.get_node("Comprador/Objetivo"))
	return punto


func _esc_real() -> void:
	for presionado: bool in [true, false]:
		var evento := InputEventKey.new()
		evento.keycode = KEY_ESCAPE
		evento.pressed = presionado
		Input.parse_input_event(evento)
		Input.flush_buffered_events()
		await get_tree().process_frame


func test_la_mira_real_rechaza_transparencia_y_alcance() -> void:  # AC-PLY-092
	var almacen := await _abrir()
	_una_entrada(almacen)
	var jugador: Node3D = almacen.get_node("Jugador")
	var objetivo: Node3D = almacen.get_node("Estructura/Ventanilla/Comprador/Objetivo")
	await _apuntar(almacen)
	var campo: Area3D = jugador.get_node("Giro/Camara/CampoDeInteraccion")
	assert_array(campo.get_overlapping_bodies()).contains(objetivo)
	jugador.call("_leer_la_mira")
	assert_object(jugador.call("enfocado")).is_same(objetivo)
	await _apuntar(almacen, true)
	jugador.call("_leer_la_mira")
	assert_object(jugador.call("enfocado")).is_not_same(objetivo)
	await _apuntar(almacen, false, ReglasDelJugador.ALCANCE_DE_LA_MIRA + 0.1)
	jugador.call("_leer_la_mira")
	assert_object(jugador.call("enfocado")).is_not_same(objetivo)


# AC-CTR-065, AC-PLY-091, AC-PLY-079
func test_el_clic_real_inicial_y_final_conserva_la_mano() -> void:
	for clase: String in ["vacia", "unidad", "ticket", "caja", "mopa"]:
		await _probar_clic_real(clase)
		assert_bool(_almacenes.back().get_node("Jugador").call("suspendido")).is_false()
		await after_test()


func _probar_clic_real(clase: String) -> void:
	var almacen := await _abrir()
	var atendida := _una_entrada(almacen)
	var agarre: Agarre = almacen.get("_agarre")
	var papel: Node3D = null
	if clase in ["unidad", "ticket"]:
		papel = load(OBJETO).instantiate()
		var datos: ObjetoDelAlmacen = Ticket.new([])
		if clase == "unidad":
			datos = UnidadDeProducto.new(Catalogo.de(Producto.Id.MAROLINI))
		papel.set("datos", datos)
		almacen.add_child(papel)
	elif clase == "caja":
		papel = almacen.get("_cajas_de_productos")[0]
	elif clase == "mopa":
		papel = almacen.get_node("Objetos/Mopa")
	if papel != null:
		assert_bool(agarre.pedir_agarrar(papel.get("datos"), papel)).is_true()
	var soltados: Array[Node3D] = []
	agarre.objeto_soltado.connect(func(cuerpo: Node3D) -> void: soltados.append(cuerpo))
	await _apuntar(almacen)
	var jugador: Node3D = almacen.get_node("Jugador")
	jugador.call("_leer_la_mira")
	assert_object(jugador.call("enfocado")).is_same(
		almacen.get_node("Estructura/Ventanilla/Comprador/Objetivo")
	)
	await _pulsar_real()
	assert_str(atendida.dialogo().entrada_actual()).is_equal("Inicial")
	assert_bool(jugador.call("suspendido")).is_true()
	assert_object(agarre.cuerpo_sostenido()).is_same(papel)
	await _pulsar_real(MOUSE_BUTTON_RIGHT)
	assert_str(atendida.dialogo().entrada_actual()).is_equal("Inicial")
	assert_bool(jugador.call("suspendido")).is_true()
	await _esc_real()
	assert_bool(get_tree().paused).is_true()
	assert_str(atendida.dialogo().entrada_actual()).is_equal("Inicial")
	assert_object(agarre.cuerpo_sostenido()).is_same(papel)
	await _esc_real()
	assert_bool(get_tree().paused).is_false()
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var turno: Turno = reloj.get("_turno")
	var antes := turno.tiempo_restante()
	await get_tree().create_timer(0.05).timeout
	reloj.call("_process", 0.0)
	assert_float(turno.tiempo_restante()).is_less(antes)
	assert_str(atendida.dialogo().entrada_actual()).is_equal("Inicial")
	await _pulsar_real()
	assert_bool(atendida.dialogo().terminado()).is_true()
	assert_bool(jugador.call("suspendido")).is_false()
	assert_object(agarre.cuerpo_sostenido()).is_same(papel)
	assert_array(soltados).is_empty()
	assert_bool(atendida.vendida()).is_false()


func test_el_contorno_usa_el_frame_actual_y_restaura_el_sprite() -> void:  # AC-PLY-093
	var almacen := await _abrir()
	_una_entrada(almacen)
	var jugador: Node3D = almacen.get_node("Jugador")
	var objetivo: Node3D = almacen.get_node("Estructura/Ventanilla/Comprador/Objetivo")
	var sprite: AnimatedSprite3D = objetivo.get("figura_de_foco")
	var previo := sprite.material_overlay
	await _apuntar(almacen)
	jugador.call("_leer_la_mira")
	var material := sprite.material_overlay as ShaderMaterial
	assert_object(material).is_not_null()
	if material == null:
		return
	assert_that(material.get_shader_parameter("color")).is_equal(IndicacionDelFoco.COLOR)
	for cuadro: int in [0, 3]:
		sprite.set_frame_and_progress(cuadro, 0.0)
		assert_object(material.get_shader_parameter("figura")).is_same(
			sprite.sprite_frames.get_frame_texture(&"idle", cuadro)
		)
	assert_bool(sprite.no_depth_test).is_false()
	jugador.call("suspender")
	assert_object(sprite.material_overlay).is_same(previo)
	jugador.call("reanudar")


# AC-PLY-092, AC-PLY-093
func test_el_antepecho_oculta_el_busto_y_no_ofrece_atencion() -> void:
	var almacen := await _abrir()
	_una_entrada(almacen)
	await _apuntar(almacen)
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	var objetivo: Node3D = puesto.get("objetivo")
	var sprite: AnimatedSprite3D = puesto.get("comprador_visible")
	var antepecho: MeshInstance3D = puesto.get("antepecho")
	var textura := sprite.sprite_frames.get_frame_texture(&"idle", sprite.frame)
	var imagen := textura.get_image()
	var alto := sprite.to_local(antepecho.global_position).y
	var fila := int(textura.get_height() / 2.0 - alto / sprite.pixel_size)
	var columna := -1
	for x in range(imagen.get_width() / 4, imagen.get_width() * 3 / 4):
		if imagen.get_pixel(x, fila).a > 0.0:
			columna = x
			break
	assert_int(columna).is_greater_equal(0)
	var local := Vector3(
		(float(columna) + 0.5 - textura.get_width() / 2.0) * sprite.pixel_size, alto, 0.0
	)
	var punto := sprite.to_global(local)
	var jugador: Node3D = almacen.get_node("Jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.global_position = punto + sprite.global_basis.z
	camara.look_at(punto)
	for _cuadro in 3:
		await get_tree().physics_frame
	assert_bool(objetivo.call("admite_foco_en", punto, camara.global_position)).is_false()
	jugador.call("_leer_la_mira")
	assert_object(jugador.call("enfocado")).is_not_same(objetivo)
	assert_object(sprite.material_overlay).is_null()


# AC-PLY-092, AC-PLY-093, AC-CTR-049
func test_la_retirada_no_conserva_objetivo_ni_contorno_y_cambia_la_figura() -> void:
	var almacen := await _abrir()
	_una_entrada(almacen)
	await _apuntar(almacen)
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	var jugador: Node3D = almacen.get_node("Jugador")
	var objetivo: Node3D = puesto.get("objetivo")
	var sprite: AnimatedSprite3D = puesto.get("comprador_visible")
	var cuadros := sprite.sprite_frames
	jugador.call("_leer_la_mira")
	var contorno := sprite.material_overlay
	assert_object(contorno).is_not_null()
	assert_int(objetivo.get("collision_layer")).is_equal(2)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	reloj.avanzar(120.0)
	for _cuadro in 3:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")
	assert_object(jugador.call("enfocado")).is_not_same(objetivo)
	assert_object(sprite.material_overlay).is_null()
	assert_int(objetivo.get("collision_layer")).is_zero()
	assert_bool((objetivo.get("forma") as CollisionShape3D).disabled).is_true()
	var retiradas: Array = puesto.get("_retiradas")
	assert_array(retiradas).is_not_empty()
	for retirada: AnimatedSprite3D in retiradas:
		assert_object(retirada.material_overlay).is_null()
		assert_array(retirada.find_children("*", "CollisionObject3D", true, false)).is_empty()
	reloj.avanzar(240.0)
	await _apuntar(almacen)
	jugador.call("_leer_la_mira")
	assert_object(jugador.call("enfocado")).is_same(objetivo)
	assert_object(sprite.sprite_frames).is_not_same(cuadros)
	assert_object(sprite.material_overlay).is_not_null().is_not_same(contorno)
	assert_int(objetivo.get("collision_layer")).is_equal(2)
	assert_bool((objetivo.get("forma") as CollisionShape3D).disabled).is_false()


# AC-PLY-092, AC-PLY-055, AC-PLY-056
func test_la_consulta_generica_no_es_una_barrera_y_se_apaga_en_fisico() -> void:
	var almacen := await _abrir()
	almacen.call("_al_abrir_la_jornada", 6)
	for _cuadro in 3:
		await get_tree().physics_frame
	var puesto: Node3D = almacen.get_node("Estructura/Ventanilla")
	var acceso: CollisionShape3D = puesto.get("acceso_al_cobro")
	assert_bool(puesto.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
	assert_bool(acceso.disabled).is_false()
	var centro := acceso.global_position
	var normal := puesto.global_basis.z
	var espacio := puesto.get_world_3d().direct_space_state
	var rayo := PhysicsRayQueryParameters3D.create(centro - normal, centro + normal, 3)
	assert_object(espacio.intersect_ray(rayo).get("collider")).is_same(puesto)
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var volumen := PhysicsShapeQueryParameters3D.new()
	volumen.shape = cuerpo.shape
	volumen.transform.origin = centro
	volumen.collision_mask = jugador.collision_mask
	volumen.exclude = [jugador.get_rid()]
	for contacto: Dictionary in espacio.intersect_shape(volumen):
		assert_object(contacto.get("collider")).is_not_same(puesto)
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[0]
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var barrido := PhysicsShapeQueryParameters3D.new()
	barrido.shape = forma.shape
	barrido.transform = Transform3D(forma.global_basis, centro - normal * 0.5)
	barrido.motion = normal
	barrido.collision_mask = caja.collision_mask
	barrido.exclude = [caja.get_rid(), jugador.get_rid()]
	assert_float(espacio.cast_motion(barrido)[0]).is_equal(1.0)
	puesto.call("accionar")
	assert_bool(puesto.get("panel").visible).is_true()
	assert_bool(jugador.suspendido()).is_true()
	puesto.call("cerrar")
	almacen.call("_al_abrir_la_jornada", 4)
	for _cuadro in 3:
		await get_tree().physics_frame
	assert_bool(puesto.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_false()
	assert_bool(acceso.disabled).is_true()
	assert_object(espacio.intersect_ray(rayo).get("collider")).is_not_same(puesto)
	puesto.call("accionar")
	assert_bool(puesto.get("panel").visible).is_false()
