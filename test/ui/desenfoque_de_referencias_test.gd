extends GdUnitTestSuite


class Caminante:
	extends Node3D

	func _physics_process(delta: float) -> void:
		position.z += delta * 3.0


func _escenario(interpolado: bool) -> Dictionary:
	var ventana: SubViewport = auto_free(SubViewport.new())
	ventana.own_world_3d = true
	add_child(ventana)
	var padre := Caminante.new()
	padre.physics_interpolation_mode = (
		Node.PHYSICS_INTERPOLATION_MODE_ON if interpolado else Node.PHYSICS_INTERPOLATION_MODE_OFF
	)
	ventana.add_child(padre)
	var camara := Camera3D.new()
	camara.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	padre.add_child(camara)
	camara.current = true
	var efecto := DesenfoqueDeReferencias.new()
	ventana.add_child(efecto)
	return {"padre": padre, "camara": camara, "efecto": efecto}


func test_la_mascara_sigue_la_camara_que_hereda_traslacion_interpolada() -> void:
	var escenario := _escenario(true)
	var camara: Camera3D = escenario.camara
	var efecto: DesenfoqueDeReferencias = escenario.efecto
	camara.get_global_transform_interpolated()
	var peor := 0.0
	var movimiento := 0.0
	var origen := camara.global_position
	for _cuadro in 60:
		await get_tree().process_frame
		efecto._process(0.0)
		var mascara: Camera3D = efecto.get("_camara")
		var dibujada := camara.get_global_transform_interpolated()
		peor = maxf(peor, mascara.global_position.distance_to(dibujada.origin))
		movimiento = maxf(movimiento, camara.global_position.distance_to(origen))
	assert_float(movimiento).is_greater(0.01)
	assert_float(peor).override_failure_message("desfasaje de %.2f mm" % (peor * 1000)).is_less(
		0.001
	)


func test_sin_ancestro_interpolado_la_mascara_sigue_el_giro_actual() -> void:
	var escenario := _escenario(false)
	var padre: Node3D = escenario.padre
	padre.set_physics_process(false)
	var camara: Camera3D = escenario.camara
	var efecto: DesenfoqueDeReferencias = escenario.efecto
	for cuadro in 5:
		await get_tree().process_frame
		camara.position = Vector3(cuadro, 0, 0)
		camara.rotation.y = cuadro * 0.2
		efecto._process(0.0)
		var mascara: Camera3D = efecto.get("_camara")
		assert_bool(mascara.global_transform.is_equal_approx(camara.global_transform)).is_true()
