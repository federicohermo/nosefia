extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_la_mopa_en_la_mano_no_atraviesa_una_pared_delante() -> void:
	assert_int(await _comprobar_pared(Vector3(0, 0, -0.7), Vector3.ZERO)).is_zero()


func test_la_mopa_en_la_mano_no_atraviesa_una_pared_al_costado() -> void:
	assert_int(await _comprobar_pared(Vector3(0.4, 0, 0), Vector3(0, PI / 2, 0))).is_zero()


func test_la_mopa_se_retrae_aunque_la_pared_este_muy_cerca() -> void:
	assert_int(await _comprobar_pared(Vector3(0, 0, -0.3), Vector3.ZERO)).is_zero()


func test_la_mopa_inclinada_no_atraviesa_la_pared() -> void:
	for inclinacion: float in [deg_to_rad(-40), deg_to_rad(40)]:
		assert_int(await _comprobar_pared(Vector3(0, 0, -0.7), Vector3.ZERO, inclinacion)).is_zero()


func test_la_mopa_no_atraviesa_las_paredes_de_una_esquina() -> void:
	assert_int(await _comprobar_pared(Vector3(0, 0, -0.5), Vector3.ZERO, 0.0, true)).is_zero()


func _comprobar_pared(
	desplazamiento: Vector3, rotacion: Vector3, inclinacion: float = 0.0, esquina: bool = false
) -> int:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	for cuadro in 2:
		await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	jugador.global_position = Vector3(0, 10, 0)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.rotation = Vector3(inclinacion, 0, 0)
	var mopa: RigidBody3D = almacen.get_node("Objetos/Mopa")
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(mopa.get("datos"), mopa)).is_true()
	var pared := StaticBody3D.new()
	var colision := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(4, 4, 0.05)
	colision.shape = caja
	pared.add_child(colision)
	almacen.add_child(pared)
	pared.global_position = camara.global_position + desplazamiento
	pared.rotation = rotacion
	if esquina:
		var lateral := pared.duplicate() as StaticBody3D
		almacen.add_child(lateral)
		lateral.global_position = camara.global_position + Vector3.RIGHT * 0.4
		lateral.rotation = Vector3(0, PI / 2, 0)
	for cuadro in 4:
		await get_tree().physics_frame
		jugador.call("_acomodar_las_manos", 1.0 / 60.0)
	var forma: CollisionShape3D = mopa.get_node("Forma")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = forma.global_transform
	consulta.collision_mask = 1
	consulta.exclude = [mopa.get_rid(), (jugador as CollisionObject3D).get_rid()]
	var penetraciones := almacen.get_world_3d().direct_space_state.intersect_shape(consulta).size()
	var anterior := mopa.global_position
	for cuadro in 10:
		await get_tree().physics_frame
		jugador.call("_acomodar_las_manos", 1.0 / 60.0)
		consulta.transform = forma.global_transform
		penetraciones += almacen.get_world_3d().direct_space_state.intersect_shape(consulta).size()
		assert_float(mopa.global_position.distance_to(anterior)).is_less(0.005)
		anterior = mopa.global_position
	agarre.soltar(true)
	await get_tree().process_frame
	await get_tree().process_frame
	almacen.queue_free()
	await get_tree().process_frame
	return penetraciones
