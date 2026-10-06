extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const BAJO_EL_CIELORRASO := Vector3(10.86, 2.0, -4.58)


func test_agrandar_la_mopa_apoyada_no_cambia_la_gravedad_de_sus_fibras() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var mopa: RigidBody3D = almacen.get_node("Objetos/Mopa")
	mopa.freeze = true
	mopa.top_level = true
	mopa.global_position = Vector3(0, 10, 0)
	mopa.global_basis = Basis.IDENTITY
	var fibras: MeshInstance3D = mopa.get_node("Malla")
	fibras.set_physics_process(false)
	fibras.scale = Vector3.ONE * 1.12
	for cuadro in 120:
		fibras.call("_physics_process", 1.0 / 60.0)
	var pinturas: Array = fibras.get("_pinturas")
	assert_array(pinturas).is_not_empty()
	var caida: Vector3 = (pinturas[0] as ShaderMaterial).get_shader_parameter("caida")
	assert_float(caida.length()).is_less(0.00001)


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


func test_el_cielorraso_sobre_la_cabeza_no_es_el_apoyo_de_las_fibras() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var mopa: RigidBody3D = almacen.get_node("Objetos/Mopa")
	mopa.freeze = true
	mopa.top_level = true
	var fibras: MeshInstance3D = mopa.get_node("Malla")
	fibras.set_physics_process(false)
	var pinturas: Array = fibras.get("_pinturas")
	assert_array(pinturas).is_not_empty()
	var espacio := almacen.get_world_3d().direct_space_state
	var techo: Dictionary = espacio.intersect_ray(
		PhysicsRayQueryParameters3D.create(
			BAJO_EL_CIELORRASO, BAJO_EL_CIELORRASO + Vector3.UP * 3.0
		)
	)
	assert_str(str((techo.collider as Node).get_parent().name)).is_equal("bano_cielorraso")
	var cielorraso: float = (techo.position as Vector3).y
	assert_float(cielorraso).is_equal_approx(3.14, 0.001)
	for grados: float in [105.0, 135.0, 180.0]:
		mopa.global_basis = Basis(Vector3.RIGHT, deg_to_rad(grados))
		for luz: float in [0.2, 0.1, 0.02]:
			var cabeza := Vector3(BAJO_EL_CIELORRASO.x, cielorraso - luz, BAJO_EL_CIELORRASO.z)
			mopa.global_position += cabeza - fibras.to_global(Vector3(0.0, -0.83, 0.0))
			fibras.call("_physics_process", 1.0 / 60.0)
			var raices := fibras.to_global(Vector3(0.0, -0.774, 0.0)).y
			for pintura: ShaderMaterial in pinturas:
				(
					assert_float(float(pintura.get_shader_parameter("suelo_y")))
					. override_failure_message("a %s° y a %s m del cielorraso" % [grados, luz])
					. is_less(raices)
				)
