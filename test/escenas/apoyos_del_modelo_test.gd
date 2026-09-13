extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_cada_mancha_se_enfoca_desde_un_apoyo_caminable_a_un_metro() -> void:  # 041-AC1
	var almacen := await _abrir()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Camara")
	var forma: CollisionShape3D = jugador.get_node("Cuerpo")
	for mancha: Node3D in almacen.get("_limpieza").manchas():
		var encontrada := false
		for direccion: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var pie := mancha.global_position + direccion
			var apoyo := _rayo(jugador, pie + Vector3.UP, pie + Vector3.DOWN)
			if apoyo.is_empty():
				continue
			if apoyo.collider != almacen.get_node("Estructura/almacen/StaticBody3D"):
				continue
			pie.y = apoyo.position.y + 0.01
			var consulta := PhysicsShapeQueryParameters3D.new()
			consulta.shape = forma.shape
			consulta.transform = Transform3D(Basis.IDENTITY, pie + forma.position)
			consulta.exclude = [jugador.get_rid()]
			if not jugador.get_world_3d().direct_space_state.intersect_shape(consulta).is_empty():
				continue
			jugador.global_position = pie
			jugador.velocity = Vector3.ZERO
			camara.look_at(mancha.global_position + Vector3.UP * 0.03)
			for cuadro in 4:
				await get_tree().physics_frame
			if jugador.get("_enfocado") == mancha:
				encontrada = true
				break
		assert_bool(encontrada).override_failure_message(str(mancha.name)).is_true()


func test_los_objetos_y_manchas_quedan_sobre_el_modelo() -> void:  # 041-AC2 041-AC3
	var almacen := await _abrir()
	var objetos: Array[Node] = almacen.get_node("Objetos").get_children()
	objetos.append_array(almacen.get("_limpieza").manchas())
	for objeto: Node3D in objetos:
		for malla: MeshInstance3D in objeto.find_children("*", "MeshInstance3D", true, false):
			if not malla.is_visible_in_tree():
				continue
			var limites := malla.global_transform * malla.get_aabb()
			var pie := limites.get_center()
			pie.y = limites.position.y
			var apoyo := _rayo(objeto, pie + Vector3.UP * 0.1, pie + Vector3.DOWN)
			assert_bool(apoyo.is_empty()).override_failure_message(str(objeto.name)).is_false()
			if not apoyo.is_empty():
				assert_object(apoyo.collider).is_same(
					almacen.get_node("Estructura/almacen/StaticBody3D")
				)
				(
					assert_float(pie.y - apoyo.position.y)
					. override_failure_message(
						"%s: base %f, apoyo %f" % [objeto.name, pie.y, apoyo.position.y]
					)
					. is_between(-0.01, 0.06)
				)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	assert_bool(jugador.is_on_floor()).is_true()
	var piso := _rayo(
		jugador, jugador.global_position + Vector3.UP * 0.1, jugador.global_position + Vector3.DOWN
	)
	assert_bool(piso.is_empty()).is_false()
	if not piso.is_empty():
		# El motor mantiene un margen de contacto entre la cápsula y el piso.
		assert_float(jugador.global_position.y - piso.position.y).is_between(-0.01, 0.06)


func test_las_manchas_superan_el_alcance_entre_si() -> void:  # 041-AC6
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	var manchas: Array = almacen.get("_limpieza").manchas()
	for indice in manchas.size():
		for otra in range(indice + 1, manchas.size()):
			var a: Vector3 = manchas[indice].position
			var b: Vector3 = manchas[otra].position
			assert_float(Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))).is_greater(
				ReglasDelJugador.ALCANCE_DE_LA_MIRA
			)


func _abrir() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	for cuadro in 60:
		await get_tree().physics_frame
	return almacen


func _rayo(objeto: Node3D, desde: Vector3, hasta: Vector3) -> Dictionary:
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta)
	if objeto is CollisionObject3D:
		consulta.exclude = [objeto.get_rid()]
	return objeto.get_world_3d().direct_space_state.intersect_ray(consulta)
