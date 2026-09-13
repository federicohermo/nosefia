extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_la_raiz_agrupa_por_rol_y_conserva_sus_enlaces() -> void:  # 041-AC4 041-AC5
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	assert_int(almacen.get_child_count()).is_less(10)
	for propiedad in almacen.get_property_list():
		if propiedad.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and propiedad.name.begins_with("_"):
			var valor: Variant = almacen.get(propiedad.name)
			assert_bool(valor != null).override_failure_message(propiedad.name).is_true()
	assert_int(almacen.get("_cajas_de_productos").size()).is_equal(6)
	assert_int(almacen.get("_bolsas").size()).is_equal(3)


func test_los_puestos_reemplazados_usan_mallas_del_modelo() -> void:  # 041-AC8 041-AC9
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	for ruta in ["Estructura/compu/StaticBody3D", "Estructura/gondola01/StaticBody3D"]:
		var cuerpo := almacen.get_node_or_null(ruta)
		assert_object(cuerpo).is_not_null()
		assert_bool(cuerpo.is_in_group("interactuable")).is_true()
		assert_bool(cuerpo.has_method("interactuar")).is_true()
		var mallas: Variant = cuerpo.get("mallas")
		assert_bool(mallas is Array and not mallas.is_empty()).is_true()
	assert_bool(almacen.has_node("Escritorio")).is_false()
	assert_bool(almacen.has_node("Estante")).is_false()


func test_la_computadora_tiene_apoyo_y_no_queda_tapada_por_otro_cuerpo() -> void:  # 041-AC3
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cuerpo: StaticBody3D = almacen.get_node("Estructura/compu/StaticBody3D")
	var apoyo: Node3D = almacen.get_node(cuerpo.get_meta("apoyo"))
	assert_object(apoyo).is_same(almacen.get_node("Estructura/EscritorioComputadora"))
	var espacio := almacen.get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(
		cuerpo.global_position, cuerpo.global_position + Vector3.DOWN
	)
	consulta.exclude = [cuerpo.get_rid()]
	var golpe := espacio.intersect_ray(consulta)
	assert_dict(golpe).is_not_empty()
	assert_object(golpe.get("collider")).is_same(apoyo.get_node("StaticBody3D"))
	consulta = PhysicsRayQueryParameters3D.create(
		cuerpo.global_position + Vector3(0, 1, 1), cuerpo.global_position
	)
	golpe = espacio.intersect_ray(consulta)
	assert_object(golpe.get("collider")).is_same(cuerpo)


func test_el_surtido_fijo_no_muestra_stock_que_el_dominio_no_tiene() -> void:  # 041-AC9
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	var estructura := almacen.get_node("Estructura")
	for nombre in [
		"at\u00fan",
		"at\u00fan_02",
		"durextra",
		"snackpapas1",
		"snacks2",
		"snacks2_02",
		"snacks2_03",
		"snacks2_04",
		"burgaloo",
		"burgaloo_001",
		"burgaloo_002",
		"burgaloo_003",
		"Zucarachas",
		"Zucarachas2",
		"gondola01/malbardocig"
	]:
		var malla: MeshInstance3D = estructura.get_node(nombre)
		assert_bool(malla.visible).override_failure_message(nombre).is_false()
		assert_int(malla.get_node("StaticBody3D").collision_layer).is_zero()
	for ruta in ["compu", "gondola01"]:
		var malla: MeshInstance3D = estructura.get_node(ruta)
		assert_object(malla.mesh).is_instanceof(ArrayMesh)
