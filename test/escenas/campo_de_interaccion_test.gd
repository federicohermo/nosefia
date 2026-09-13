extends GdUnitTestSuite

const JUGADOR := preload("res://src/escenas/jugador.tscn")
const ALMACEN := preload("res://src/escenas/almacen.tscn")
const BOLSA := preload("res://src/escenas/objetos/objeto_agarrable.tscn")


func test_la_bolsa_pequena_se_enfoca_fuera_del_centro() -> void:  # 038-AC11
	var jugador := _jugador()
	var bolsa: RigidBody3D = auto_free(BOLSA.instantiate())
	bolsa.freeze = true
	add_child(bolsa)
	var ojo: Vector3 = jugador.get_node("Camara").global_position
	var angulo := deg_to_rad(8.0)
	bolsa.global_position = ojo + Vector3(sin(angulo), 0, -cos(angulo)) * 1.5
	await _actualizar(jugador)
	assert_object(jugador.get("_enfocado")).is_same(bolsa)
	var forma: BoxShape3D = bolsa.get_node("Forma").shape
	assert_float(forma.size.x).is_equal_approx(0.12, 0.00001)
	assert_float(ojo.distance_to(bolsa.global_position)).is_equal_approx(1.5, 0.001)


func test_el_campo_y_el_clic_usan_los_cuerpos_de_los_muebles() -> void:  # 038-AC12
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var avisos: Array[Node3D] = []
	jugador.objetivo_enfocado.connect(
		func(objetivo: Node3D, _distancia: float) -> void: avisos.append(objetivo)
	)
	var computadora: Node3D = almacen.get_node("Estructura/compu/StaticBody3D")
	_mirar(jugador, computadora.global_position + Vector3(0, 1, 1), computadora.global_position)
	await _actualizar(jugador)
	assert_object(jugador.get("_enfocado")).is_same(computadora)
	assert_array(avisos).contains([computadora])
	_clic()
	assert_bool(computadora.get("pantalla").visible).is_true()
	computadora.call("cerrar")
	var caja: Node3D = almacen.get("_cajas_de_productos")[0]
	caja.call("interactuar")
	var agarre: Agarre = almacen.get("_agarre")
	assert_object(agarre.manos().sostenido()).is_instanceof(UnidadDeProducto)
	var estante: Node3D = almacen.get("_reposicion_manual").get_node("ZonaDeYerba")
	var zona: AABB = almacen.get("_reposicion_manual").zona(Producto.Id.YERBA)
	_mirar(jugador, zona.get_center() + Vector3(0, 0, 1.5), zona.get_center())
	await _actualizar(jugador)
	assert_object(jugador.get("_enfocado")).is_same(estante)
	assert_array(avisos).contains([estante])
	_clic()
	assert_object(agarre.manos().sostenido()).is_null()
	var repositor: Repositor = almacen.get("_repositor")
	assert_int(repositor.estante().unidades_en_gondola(Catalogo.todos()[0])).is_equal(1)


func test_la_pared_del_modelo_tapa_un_objeto_dentro_del_alcance() -> void:  # 038-AC13
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var bolsa: RigidBody3D = auto_free(BOLSA.instantiate())
	bolsa.freeze = true
	add_child(bolsa)
	bolsa.global_position = Vector3(0, 1.8, 7.5)
	var ojo := Vector3(0, 1.8, 8.7)
	_mirar(jugador, ojo, bolsa.global_position)
	await _actualizar(jugador)
	assert_bool(jugador.get_node("Camara/CampoDeInteraccion").overlaps_body(bolsa)).is_true()
	var consulta := PhysicsRayQueryParameters3D.create(ojo, bolsa.global_position)
	consulta.exclude = [jugador.get_rid()]
	var golpe := jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	assert_object(golpe.get("collider")).is_same(
		almacen.get_node("Estructura/almacen/StaticBody3D")
	)
	assert_float(ojo.distance_to(bolsa.global_position)).is_less(
		ReglasDelJugador.ALCANCE_DE_LA_MIRA
	)
	assert_object(jugador.get("_enfocado")).is_null()


func test_importa_la_superficie_y_no_el_origen_ni_la_jerarquia_de_mallas() -> void:  # 038-AC13
	var jugador := _jugador()
	var cuerpo: StaticBody3D = auto_free(StaticBody3D.new())
	cuerpo.add_to_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
	add_child(cuerpo)
	cuerpo.position = Vector3(15, 0, 0)
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(1, 1, 0.2)
	forma.shape = caja
	cuerpo.add_child(forma)
	forma.global_position = Vector3(0, ReglasDelJugador.ALTURA_DE_LA_CAMARA, -1.5)
	var malla: MeshInstance3D = auto_free(MeshInstance3D.new())
	var geometria := BoxMesh.new()
	geometria.size = caja.size
	malla.mesh = geometria
	add_child(malla)
	malla.global_transform = forma.global_transform
	await _actualizar(jugador)
	assert_object(jugador.get("_enfocado")).is_same(cuerpo)
	assert_bool(cuerpo.is_ancestor_of(malla)).is_false()
	assert_float(jugador.global_position.distance_to(cuerpo.global_position)).is_greater(
		ReglasDelJugador.ALCANCE_DE_LA_MIRA
	)


func _jugador() -> CharacterBody3D:
	var jugador: CharacterBody3D = auto_free(JUGADOR.instantiate())
	add_child(jugador)
	jugador.set_physics_process(false)
	return jugador


func _mirar(jugador: CharacterBody3D, ojo: Vector3, punto: Vector3) -> void:
	jugador.global_position = ojo - Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	jugador.get_node("Camara").look_at(punto)


func _actualizar(jugador: CharacterBody3D) -> void:
	for cuadro in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")


func _clic() -> void:
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	get_viewport().push_input(clic)
	clic = clic.duplicate()
	clic.pressed = false
	get_viewport().push_input(clic)
