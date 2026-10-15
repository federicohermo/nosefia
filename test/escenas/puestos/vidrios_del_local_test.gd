extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_los_vidrios_fijos_del_frente_impiden_salir_del_local() -> void:
	var local: Node3D = auto_free(ALMACEN.instantiate())
	add_child(local)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = local.get("_jugador")
	var forma: CollisionShape3D = jugador.get_node("Cuerpo")
	var espacio := jugador.get_world_3d().direct_space_state
	var comprobados := 0
	for nodo: Node in local.get_node("Estructura").get_children():
		if not str(nodo.name).begins_with("local_vidrio_frente_"):
			continue
		var vidrio := nodo as MeshInstance3D
		var caja := vidrio.global_transform * vidrio.get_aabb()
		var centro := caja.get_center()
		centro.y = 0.12
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = forma.shape
		q.transform = Transform3D(Basis.IDENTITY, centro + Vector3.FORWARD) * forma.transform
		q.motion = Vector3.BACK * 2.0
		q.collision_mask = jugador.collision_mask
		q.exclude = [jugador.get_rid()]
		assert_float(espacio.cast_motion(q)[1]).override_failure_message(str(nodo.name)).is_less(
			1.0
		)
		comprobados += 1
	assert_int(comprobados).is_greater(0)
