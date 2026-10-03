extends GdUnitTestSuite


func test_la_superficie_distribuye_la_suciedad_por_toda_la_mancha() -> void:
	var mancha: Node3D = auto_free(
		load("res://src/escenas/objetos/mancha_en_el_piso.tscn").instantiate()
	)
	get_tree().root.add_child(mancha)
	var superficie := mancha.get_node("Malla") as MeshInstance3D
	var arrays := superficie.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var coordenadas: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_int(coordenadas.size()).is_equal(vertices.size())
	assert_bool(coordenadas.has(Vector2(0.5, 0.5))).is_true()
	var minimo := Vector2.ONE
	var maximo := Vector2.ZERO
	for coordenada: Vector2 in coordenadas:
		minimo = minimo.min(coordenada)
		maximo = maximo.max(coordenada)
	assert_float(minimo.x).is_less(0.15)
	assert_float(minimo.y).is_less(0.15)
	assert_float(maximo.x).is_greater(0.85)
	assert_float(maximo.y).is_greater(0.85)
