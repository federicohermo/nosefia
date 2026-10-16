func test_el_nuevo_corte_conserva_volumen_sin_rellenar_huecos() -> void:
	var almacen: Node3D = await _almacen()
	var colilla := almacen.get_node("Objetos/Colilla") as RigidBody3D
	var corte_colilla := INF
	for forma: CollisionShape3D in colilla.find_children("*", "CollisionShape3D", true, false):
		var lados := forma.shape.get_debug_mesh().get_aabb().size * forma.global_basis.get_scale()
		corte_colilla = minf(corte_colilla, minf(lados.x, minf(lados.y, lados.z)) / 2.0)
	assert_float(corte_colilla).is_greater(0.0)
	assert_float(_corte(almacen)).is_equal_approx(corte_colilla, 0.00001)
	var medidos := 0
	var afuera: Array[String] = []
	for forma: CollisionShape3D in almacen.find_children(
		"VolumenColilla*", "CollisionShape3D", true, false
	):
		assert_bool(forma.disabled).is_false()
		assert_object(forma.shape).is_instanceof(ConvexPolygonShape3D)
		var malla := forma.get_parent().get_parent() as MeshInstance3D
		assert_object(malla).is_not_null()
		var caras := malla.mesh.get_faces()
		for indice: int in caras.size():
			caras[indice] = malla.global_transform * caras[indice]
		var frontera := forma.shape.get_debug_mesh().get_faces()
		var centro := Vector3.ZERO
		for punto: Vector3 in frontera:
			centro += forma.global_transform * punto / frontera.size()
		for indice: int in range(0, frontera.size(), 3):
			var a := forma.global_transform * frontera[indice]
			var b := forma.global_transform * frontera[indice + 1]
			var c := forma.global_transform * frontera[indice + 2]
			for punto: Vector3 in [
				a, b, c, (a + b) / 2.0, (b + c) / 2.0, (c + a) / 2.0, (a + b + c) / 3.0
			]:
				medidos += 1
				if not _punto_adentro(caras, punto + punto.direction_to(centro) * EPSILON):
					afuera.append(str(almacen.get_path_to(forma)))
	assert_int(medidos).is_greater(0)
	(
		assert_array(afuera)
		. override_failure_message("volúmenes fuera de su malla: %s" % afuera)
		. is_empty()
	)
	assert_array(_sin_volumen(almacen, corte_colilla)).is_empty()
