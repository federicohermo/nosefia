extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_la_mopa_apoyada_es_mayor_y_en_la_mano_conserva_su_tamano() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var mopa: RigidBody3D = almacen.get_node("Objetos/Mopa")
	var malla: MeshInstance3D = mopa.get("malla")
	var original := malla.mesh.get_aabb()
	var apoyada := malla.transform * original
	assert_float(apoyada.size.y / original.size.y).is_equal_approx(1.12, 0.001)
	assert_float(apoyada.position.y).is_equal_approx(original.position.y, 0.001)
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(mopa.get("datos"), mopa)).is_true()
	await get_tree().process_frame
	assert_bool(malla.transform.is_equal_approx(Transform3D.IDENTITY)).is_true()
	agarre.soltar(true)
	await get_tree().process_frame
	assert_float((malla.transform * original).size.y).is_equal_approx(apoyada.size.y, 0.001)
