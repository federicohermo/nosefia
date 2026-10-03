extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func test_las_fibras_reaccionan_al_movimiento_y_se_asientan_al_parar() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var mopa: RigidBody3D = almacen.get_node("Objetos/Mopa")
	mopa.freeze = true
	mopa.top_level = true
	mopa.global_basis = Basis.IDENTITY
	var fibras: MeshInstance3D = mopa.get_node("Malla")
	fibras.set_physics_process(false)
	var pinturas: Array = fibras.get("_pinturas")
	assert_int(pinturas.size()).is_equal(2)
	for pintura: ShaderMaterial in pinturas:
		assert_object(pintura.shader).is_not_null()
	fibras.call("_physics_process", 1.0 / 60.0)
	for paso in 12:
		mopa.global_position.x += 0.001 * (paso + 1)
		fibras.call("_physics_process", 1.0 / 60.0)
	var flexion: Vector2 = pinturas[0].get_shader_parameter("flexion")
	assert_float(flexion.length()).is_greater(0.01)
	assert_float(flexion.length()).is_less(0.075)
	for paso in 240:
		fibras.call("_physics_process", 1.0 / 60.0)
	flexion = pinturas[0].get_shader_parameter("flexion")
	assert_float(flexion.length()).is_less(0.0001)
	mopa.rotation.z = PI / 4.0
	for paso in 120:
		fibras.call("_physics_process", 1.0 / 60.0)
	flexion = pinturas[0].get_shader_parameter("flexion")
	assert_float(flexion.length()).is_greater(0.01)
	mopa.global_position.x += 2.0
	fibras.call("_physics_process", 1.0 / 60.0)
	flexion = pinturas[0].get_shader_parameter("flexion")
	assert_vector(flexion).is_equal(Vector2.ZERO)


func test_las_fibras_se_mueven_llevando_la_mopa_y_el_agua_tine_sus_puntas() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	var mopa: RigidBody3D = almacen.get_node("Objetos/Mopa")
	assert_bool((almacen.get("_agarre") as Agarre).pedir_agarrar(mopa.get("datos"), mopa)).is_true()
	var fibras: MeshInstance3D = mopa.get_node("Malla")
	assert_bool(fibras.is_physics_processing()).is_true()
	var pinturas: Array = fibras.get("_pinturas")
	var maximo := 0.0
	for paso in 30:
		jugador.position.x += 0.015 * sin(paso * 0.3)
		await get_tree().physics_frame
		var flexion: Vector2 = pinturas[0].get_shader_parameter("flexion")
		maximo = maxf(maximo, flexion.length())
	assert_float(maximo).is_greater(0.01)
	var agua := Color(0.9, 0.4, 0.6)
	mopa.call("mostrar_la_carga", true, agua)
	for pintura: ShaderMaterial in pinturas:
		assert_float(pintura.get_shader_parameter("humedad")).is_greater(0.5)
		assert_that(pintura.get_shader_parameter("color_del_agua")).is_equal(agua)
	var punta: MeshInstance3D = mopa.get_node("Punta")
	assert_float(punta.get_aabb().size.x).is_less(0.16)
	mopa.call("mostrar_la_carga", false, agua)
	for pintura: ShaderMaterial in pinturas:
		assert_float(pintura.get_shader_parameter("humedad")).is_equal(0.0)
