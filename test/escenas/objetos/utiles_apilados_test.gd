extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_retirar_el_balde_despierta_y_deja_caer_el_jabon_que_sostenia() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	jugador.global_position = Vector3(9.0, 0.11, -5.5)
	var balde: RigidBody3D = almacen.get_node("Objetos/Balde")
	var jabon: RigidBody3D = almacen.get_node("Objetos/JabonRosa")
	balde.global_transform = Transform3D(Basis.IDENTITY, Vector3(10.5, 0.259, -5.5))
	jabon.global_transform = Transform3D(Basis.IDENTITY, Vector3(10.5, 0.777, -5.5))
	for cuadro in 120:
		await get_tree().physics_frame
	assert_array(jabon.get_colliding_bodies()).contains([balde])
	jabon.sleeping = true
	var altura := jabon.global_position.y
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(balde.get("datos"), balde)).is_true()
	for cuadro in 60:
		await get_tree().physics_frame
	assert_bool(jabon.freeze).is_false()
	assert_float(jabon.global_position.y).is_less(altura - 0.15)
