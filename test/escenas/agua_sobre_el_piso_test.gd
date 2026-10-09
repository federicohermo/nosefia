extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const PisoParaAgua := preload("res://src/escenas/objetos/piso_para_agua.gd")


func test_instanciar_y_descartar_el_almacen_sin_abrirlo_no_deja_nodos_huerfanos() -> void:
	var antes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var almacen: Node3D = ALMACEN.instantiate()
	var charcos: Node = almacen.get("_limpieza").get("_charcos")
	almacen.free()
	assert_int(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))).is_equal(antes)
	assert_bool(is_instance_valid(charcos)).is_false()
	# El rojo también libera el dibujo que quedó sin padre, para no contaminar otros casos.
	if is_instance_valid(charcos):
		charcos.free()


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	for cuadro in 2:
		await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_process(false)
	jugador.set_physics_process(false)
	almacen.get("_limpieza").set_physics_process(false)
	return almacen


func _sectores(almacen: Node3D) -> Array[Node3D]:
	var sectores: Array[Node3D] = []
	sectores.assign(almacen.get("_limpieza").manchas())
	return sectores


func _golpe(almacen: Node3D, punto: Vector3) -> Dictionary:
	var consulta := PhysicsRayQueryParameters3D.create(punto + Vector3.UP, punto + Vector3.DOWN, 3)
	return almacen.get_world_3d().direct_space_state.intersect_ray(consulta)


func _usar(jugador: Node3D) -> void:
	var evento := InputEventAction.new()
	evento.action = ReglasDelJugador.ACCION_USAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func test_el_uso_sobre_piso_libre_llega_sin_convertir_el_suelo_en_interactuable() -> void:
	var almacen := await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	var suelo := almacen.get_node("Estructura/SueloSolido") as StaticBody3D
	var punto := Vector3(2.695, 0.103, 1.5)
	var golpe := _golpe(almacen, punto)
	assert_array([suelo, almacen.get_node("Estructura/almacen/StaticBody3D")]).contains(
		golpe.get("collider")
	)
	assert_bool(suelo.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_false()
	var camara := jugador.get_node("Giro/Camara") as Camera3D
	camara.global_position = punto + Vector3(0, 1.2, 0.7)
	camara.look_at(punto)
	jugador.set("_enfocado", null)
	var recibidos: Array[Vector3] = []
	jugador.connect(
		"uso_sobre_superficie_pedido",
		func(lugar: Vector3, _normal: Vector3, _cuerpo: PhysicsBody3D) -> void:
			recibidos.append(lugar)
	)
	_usar(jugador)
	assert_int(recibidos.size()).is_equal(1)
	if not recibidos.is_empty():
		assert_float(recibidos[0].distance_to(golpe.position)).is_less(0.002)
	jugador.call("suspender")
	_usar(jugador)
	assert_int(recibidos.size()).is_equal(1)


func test_el_disco_completo_de_agua_se_reserva_fuera_de_las_manchas() -> void:  # AC-CLN-031
	var almacen := await _almacen()
	var suelo := almacen.get_node("Estructura/SueloSolido") as StaticBody3D
	var sectores := _sectores(almacen)
	var casco := almacen.get_node("Estructura/almacen/StaticBody3D") as StaticBody3D
	var golpe := _golpe(almacen, Vector3(2.695, 0.103, 1.5))
	assert_array([suelo, casco]).contains(golpe.get("collider"))
	assert_bool(PisoParaAgua.admite(golpe, suelo, sectores, [], casco)).is_true()
	var mancha: Node3D = almacen.get("_limpieza").manchas()[1]
	var punto := mancha.global_position + Vector3.FORWARD * 1.19
	golpe = _golpe(almacen, punto)
	assert_array([suelo, casco]).contains(golpe.get("collider"))
	assert_float(punto.distance_to(mancha.global_position)).is_greater(0.96)
	assert_bool(PisoParaAgua.admite(golpe, suelo, sectores, [], casco)).is_false()
	mancha.call("mostrar", false, Color.BLACK)
	for cuadro in 2:
		await get_tree().physics_frame
	assert_bool(PisoParaAgua.admite(golpe, suelo, sectores, [], casco)).is_false()


func test_una_superficie_horizontal_de_un_mueble_no_es_piso() -> void:  # AC-CLN-031
	var almacen := await _almacen()
	var suelo := almacen.get_node("Estructura/SueloSolido") as StaticBody3D
	var mesa := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(1, 0.1, 1)
	forma.shape = caja
	mesa.add_child(forma)
	almacen.add_child(mesa)
	mesa.position = Vector3(1.5, 0.8, 1)
	for cuadro in 2:
		await get_tree().physics_frame
	var golpe := _golpe(almacen, mesa.global_position)
	assert_object(golpe.get("collider")).is_same(mesa)
	assert_float((golpe.normal as Vector3).y).is_greater(0.99)
	assert_bool(PisoParaAgua.admite(golpe, suelo, _sectores(almacen))).is_false()


# AC-CLN-030
func test_agua_limpia_deja_charco_sin_cambiar_las_manchas_y_la_jornada_lo_borra() -> void:
	var almacen := await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	var limpiador: Limpiador = almacen.get("_limpiador")
	var agarre: Agarre = almacen.get("_agarre")
	var mopa: RigidBody3D = almacen.get_node("Objetos/Mopa")
	var puesto: Node3D = almacen.get("_limpieza")
	var charcos: Node3D = puesto.get("_charcos")
	assert_bool(agarre.pedir_agarrar(mopa.get("datos"), mopa)).is_true()
	(
		assert_int(
			limpiador.usar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, ReglasDeLaLimpieza.ID_DEL_INODORO)
		)
		. is_equal(ReglasDeLaLimpieza.Resultado.MOPA_MOJADA)
	)
	var punto := Vector3(2.695, 0.103, 1.5)
	var golpe := _golpe(almacen, punto)
	(
		assert_array([puesto.get("suelo"), almacen.get_node("Estructura/almacen/StaticBody3D")])
		. contains(golpe.get("collider"))
	)
	var camara := jugador.get_node("Giro/Camara") as Camera3D
	camara.global_position = punto + Vector3(0, 1.2, 0.7)
	camara.look_at(punto)
	jugador.set("_enfocado", null)
	assert_int(limpiador.piso().lugares().size()).is_equal(4)
	assert_bool(limpiador.piso().esta_limpio()).is_false()
	_usar(jugador)
	assert_int(charcos.call("cantidad")).is_equal(1)
	assert_int(limpiador.piso().lugares().size()).is_equal(4)
	assert_bool(limpiador.piso().esta_limpio()).is_false()
	assert_bool(limpiador.piso().balde().tiene_agua()).is_false()
	almacen.call("_al_abrir_la_jornada", 2)
	assert_int(charcos.call("cantidad")).is_zero()
	assert_int(limpiador.piso().lugares().size()).is_equal(4)


# AC-CLN-029
func test_enjuagar_en_el_inodoro_anima_hacia_ese_inodoro_y_no_hacia_el_balde() -> void:
	var almacen := await _almacen()
	var agarre: Agarre = almacen.get("_agarre")
	var mopa: RigidBody3D = almacen.get_node("Objetos/Mopa")
	var inodoro := almacen.get_node("Estructura/inodoro/StaticBody3D") as PhysicsBody3D
	var puesto: Node3D = almacen.get("_limpieza")
	assert_bool(agarre.pedir_agarrar(mopa.get("datos"), mopa)).is_true()
	puesto.call("_al_pedir_uso", inodoro)
	assert_int((almacen.get("_limpiador") as Limpiador).piso().mopa().agua()).is_equal(
		ReglasDeLaLimpieza.Agua.LIMPIA
	)
	assert_object(mopa.get("contacto_del_movimiento")).is_same(inodoro)


func test_rechaza_una_concavidad_entre_las_muestras_del_borde() -> void:  # AC-CLN-031
	var suelo: StaticBody3D = auto_free(StaticBody3D.new())
	add_child(suelo)
	suelo.position = Vector3(40, 0, 0)
	# La esquina (.225, .09) queda dentro del disco, pero entre las direcciones 0° y 45°.
	for limites: Rect2 in [Rect2(-1, -1, 1.225, 2), Rect2(.225, -1, .775, 1.09)]:
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(limites.size.x, .1, limites.size.y)
		forma.shape = caja
		var centro := limites.get_center()
		forma.position = Vector3(centro.x, -.05, centro.y)
		suelo.add_child(forma)
	for cuadro in 2:
		await get_tree().physics_frame
	var punto := suelo.global_position
	var golpe := _golpe(suelo, punto)
	assert_object(golpe.get("collider")).is_same(suelo)
	for lado in 8:
		var borde := punto + Vector3(cos(TAU * lado / 8), 0, sin(TAU * lado / 8)) * .25
		assert_object(_golpe(suelo, borde).get("collider")).is_same(suelo)
	var sin_suelo := punto + Vector3(.228, 0, .095)
	assert_float(sin_suelo.distance_to(punto)).is_less(.25)
	assert_bool(_golpe(suelo, sin_suelo).is_empty()).is_true()
	var sectores: Array[Node3D] = []
	(
		assert_bool(PisoParaAgua.admite(_golpe(suelo, punto + Vector3.LEFT * .5), suelo, sectores))
		. is_true()
	)
	(
		assert_bool(
			PisoParaAgua.admite(_golpe(suelo, punto + Vector3(.2, 0, -.3)), suelo, sectores)
		)
		. is_true()
	)
	assert_bool(PisoParaAgua.admite(golpe, suelo, sectores)).is_false()


func test_la_mira_no_deja_agua_fuera_de_alcance_ni_detras_de_un_obstaculo() -> void:  # AC-CLN-031
	var almacen := await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	var punto := Vector3(2.695, 0.103, 1.5)
	var camara := jugador.get_node("Giro/Camara") as Camera3D
	var recibidos: Array[PhysicsBody3D] = []
	jugador.connect(
		"uso_sobre_superficie_pedido",
		func(_punto: Vector3, _normal: Vector3, cuerpo: PhysicsBody3D) -> void:
			recibidos.append(cuerpo)
	)
	jugador.set("_enfocado", null)
	camara.global_position = punto + Vector3.UP * (ReglasDelJugador.ALCANCE_DE_LA_MIRA + 0.2)
	camara.look_at(punto, Vector3.FORWARD)
	_usar(jugador)
	assert_array(recibidos).is_empty()
	var obstaculo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(0.5, 0.15, 0.5)
	forma.shape = caja
	obstaculo.add_child(forma)
	almacen.add_child(obstaculo)
	obstaculo.global_position = punto + Vector3.UP * 0.5
	for cuadro in 2:
		await get_tree().physics_frame
	camara.global_position = punto + Vector3.UP * 1.2
	camara.look_at(punto, Vector3.FORWARD)
	_usar(jugador)
	assert_int(recibidos.size()).is_equal(1)
	assert_object(recibidos[0]).is_same(obstaculo)
	assert_int(almacen.get("_limpieza").get("_charcos").cantidad()).is_zero()


# AC-CLN-033
func test_el_producto_aceptado_mezcla_el_balde_y_repintar_no_corta_la_transicion() -> void:
	var almacen := await _almacen()
	var limpiador: Limpiador = almacen.get("_limpiador")
	var puesto: Node3D = almacen.get("_limpieza")
	var balde: Node3D = almacen.get_node("Objetos/Balde")
	var superficie: MeshInstance3D = balde.get("carga")
	limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	var anterior: Color = superficie.call("color_de_la_superficie")
	limpiador.usar(&"jabon_amarillo", ReglasDeLaLimpieza.ID_DEL_BALDE)
	var pintura := superficie.material_override as ShaderMaterial
	assert_float(pintura.get_shader_parameter("progreso_de_mezcla")).is_zero()
	assert_that(pintura.get_shader_parameter("color_previo")).is_equal(anterior)
	assert_that(superficie.call("color_de_la_superficie")).is_equal(
		limpiador.piso().balde().color()
	)
	puesto.call("repintar")
	assert_float(pintura.get_shader_parameter("progreso_de_mezcla")).is_zero()
	superficie.call("_physics_process", 0.21)
	var progreso: float = pintura.get_shader_parameter("progreso_de_mezcla")
	assert_int(limpiador.usar(&"jabon_rosa", ReglasDeLaLimpieza.ID_DEL_BALDE)).is_equal(
		ReglasDeLaLimpieza.Resultado.BALDE_YA_TENIDO
	)
	assert_float(pintura.get_shader_parameter("progreso_de_mezcla")).is_equal(progreso)
	limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_INODORO)
	assert_bool(superficie.visible).is_true()
	assert_float(pintura.get_shader_parameter("progreso_de_mezcla")).is_equal(1.0)
	superficie.call("_physics_process", .25)
	assert_bool(superficie.visible).is_false()


# AC-CLN-019, AC-CLN-021: el dominio acepta inmediatamente, el nivel se dibuja en transición.
func test_las_senales_llenan_y_vacian_con_nivel_gradual_sin_reiniciar_al_repintar() -> void:
	var almacen := await _almacen()
	var limpiador: Limpiador = almacen.get("_limpiador")
	var puesto: Node3D = almacen.get("_limpieza")
	var balde: Node3D = almacen.get_node("Objetos/Balde")
	var agua := balde.get("carga") as MeshInstance3D
	agua.set_physics_process(false)
	var reposo := agua.position.y
	limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	assert_bool(limpiador.piso().balde().tiene_agua()).is_true()
	assert_bool(agua.visible).is_true()
	assert_float(agua.position.y).is_less(reposo - 0.1)
	agua.set_physics_process(false)
	agua.call("_physics_process", .125)
	var medio := agua.position.y
	assert_float(medio).is_greater(reposo - .2)
	assert_float(medio).is_less(reposo)
	puesto.call("repintar")
	assert_float(agua.position.y).is_equal(medio)
	agua.call("_physics_process", .125)
	assert_float(agua.position.y).is_equal_approx(reposo, .00001)
	limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_INODORO)
	assert_bool(limpiador.piso().balde().tiene_agua()).is_false()
	assert_bool(agua.visible).is_true()
	var color: Color = agua.call("color_de_la_superficie")
	assert_float(color.a).is_greater(.0)
	puesto.call("repintar")
	assert_bool(agua.visible).is_true()
	agua.call("_physics_process", .125)
	assert_float(agua.position.y).is_less(reposo)
	assert_bool(agua.visible).is_true()
	almacen.call("_al_abrir_la_jornada", 2)
	assert_bool(agua.visible).is_false()
	assert_float(agua.position.y).is_equal_approx(reposo, .00001)
