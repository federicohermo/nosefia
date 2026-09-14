extends GdUnitTestSuite

const GrupoDelPiso := preload("res://src/escenas/objetos/grupo_del_piso.gd")


func test_mover_enfocar_y_recoger_conserva_el_dibujo_de_cada_cuerpo() -> void:  # 042-AC7
	var mundo: Node3D = auto_free(Node3D.new())
	add_child(mundo)
	var grupo := GrupoDelPiso.new()
	var modelo := BoxMesh.new()
	grupo.preparar(modelo, 3)
	mundo.add_child(grupo)
	grupo.position = Vector3(4, 0, 0)
	var cuerpos: Array[RigidBody3D] = []
	for indice in 3:
		var cuerpo := RigidBody3D.new()
		cuerpo.freeze = true
		mundo.add_child(cuerpo)
		cuerpo.position = Vector3(indice, 2, -3)
		var vista := MeshInstance3D.new()
		vista.name = "Malla"
		vista.mesh = modelo
		vista.position = Vector3(0, -0.2, 0.1)
		cuerpo.add_child(vista)
		grupo.agregar(cuerpo)
		cuerpos.append(cuerpo)
	var vista: MeshInstance3D = cuerpos[1].get_node("Malla")
	cuerpos[1].rotation = Vector3(-0.3, 0.7, 0.2)
	grupo._physics_process(0.0)
	var esperado := grupo.global_transform.affine_inverse() * vista.global_transform
	assert_bool(grupo.get("_matrices")[1].is_equal_approx(esperado)).is_true()
	if DisplayServer.get_name() != "headless":
		assert_bool(grupo.multimesh.get_instance_transform(1).is_equal_approx(esperado)).is_true()
	vista.material_overlay = StandardMaterial3D.new()
	await get_tree().process_frame
	grupo._physics_process(0.0)
	assert_bool(vista.visible).is_true()
	assert_float(grupo.get("_matrices")[1].basis.determinant()).is_zero()
	assert_bool(cuerpos[0].get_node("Malla").visible).is_false()
	vista.material_overlay = null
	await get_tree().process_frame
	grupo._physics_process(0.0)
	assert_bool(vista.visible).is_false()
	assert_bool(grupo.get("_matrices")[1].is_equal_approx(esperado)).is_true()
	grupo.quitar(cuerpos[1])
	assert_bool(vista.visible).is_true()
	assert_int(grupo.multimesh.visible_instance_count).is_equal(2)
	assert_object(grupo.cuerpos[1]).is_same(cuerpos[2])
	var ultima: MeshInstance3D = cuerpos[2].get_node("Malla")
	esperado = grupo.global_transform.affine_inverse() * ultima.global_transform
	assert_bool(grupo.get("_matrices")[1].is_equal_approx(esperado)).is_true()
	grupo.quitar(cuerpos[0])
	grupo.quitar(cuerpos[2])
	assert_int(grupo.multimesh.visible_instance_count).is_zero()
	assert_array(grupo.cuerpos).is_empty()
