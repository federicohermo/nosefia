extends GdUnitTestSuite


func test_las_gotas_del_mundo_no_alejan_el_objeto_examinado() -> void:
	var objeto: Node3D = auto_free(Node3D.new())
	var cuerpo := MeshInstance3D.new()
	cuerpo.mesh = BoxMesh.new()
	objeto.add_child(cuerpo)
	var esperado := Examen._radio(objeto)
	var gotas := MultiMeshInstance3D.new()
	gotas.multimesh = MultiMesh.new()
	gotas.multimesh.mesh = BoxMesh.new()
	gotas.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	gotas.multimesh.instance_count = 1
	gotas.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(12, 1, -7)))
	gotas.top_level = true
	gotas.custom_aabb = AABB(Vector3(12.0, 1.0, -7.0), Vector3.ONE)
	objeto.add_child(gotas)
	assert_float(Examen._radio(objeto)).is_equal(esperado)


func test_la_geometria_oculta_no_cambia_la_distancia_de_examen() -> void:
	var objeto: Node3D = auto_free(Node3D.new())
	var cuerpo := MeshInstance3D.new()
	cuerpo.mesh = BoxMesh.new()
	objeto.add_child(cuerpo)
	var esperado := Examen._radio(objeto)
	var oculto := Node3D.new()
	oculto.visible = false
	objeto.add_child(oculto)
	var efecto := MeshInstance3D.new()
	efecto.mesh = BoxMesh.new()
	efecto.position = Vector3.ONE * 20.0
	oculto.add_child(efecto)
	assert_float(Examen._radio(objeto)).is_equal(esperado)
