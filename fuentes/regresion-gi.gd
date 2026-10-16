func test_colilla_levantable_toma_luz_dinamica() -> void:
	var escena := load("res://src/escenas/objetos/colilla.tscn") as PackedScene
	var colilla: RigidBody3D = auto_free(escena.instantiate())
	var mallas := colilla.find_children("*", "MeshInstance3D", true, false)
	assert_array(mallas).is_not_empty()
	for malla: MeshInstance3D in mallas:
		assert_int(malla.gi_mode).is_equal(GeometryInstance3D.GI_MODE_DYNAMIC)
