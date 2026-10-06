extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Util := preload("res://src/escenas/objetos/util_de_limpieza.gd")
const Fibras := preload("res://src/escenas/objetos/fibras_de_la_mopa.gd")


func test_la_mopa_horizontal_mojada_no_deja_un_volumen_rigido_detras_de_la_cabeza() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: Node = almacen.get("_jugador")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	var mopa := almacen.get_node("Objetos/Mopa") as Util
	var fibras := mopa.malla as Fibras
	fibras.set_physics_process(false)
	var limpiador: Limpiador = almacen.get("_limpiador")
	var llenar := limpiador.usar(
		ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO
	)
	assert_int(llenar).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_LLENADO)
	var agarrado := (almacen.get("_agarre") as Agarre).pedir_agarrar(mopa.datos, mopa)
	assert_bool(agarrado).is_true()
	var mojar := limpiador.usar(ReglasDeLaLimpieza.ID_DE_LA_MOPA, ReglasDeLaLimpieza.ID_DEL_BALDE)
	assert_int(mojar).is_equal(ReglasDeLaLimpieza.Resultado.MOPA_MOJADA)
	var bajada: Tween = mopa.get("_bajada")
	assert_object(bajada).is_not_null()
	if bajada == null:
		return
	bajada.pause()
	bajada.custom_step(ReglasDeLaLimpieza.DURACION_DE_LA_MOJADA + .001)
	(almacen.get("_agarre") as Agarre).soltar(false)
	assert_bool(limpiador.piso().mopa().esta_mojada()).is_true()
	var piso := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(4.0, .2, 4.0)
	forma.shape = caja
	piso.add_child(forma)
	almacen.add_child(piso)
	piso.global_position = Vector3(30, 0, 0)
	mopa.freeze = false
	mopa.top_level = true
	mopa.global_transform = Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(30, .27, 0))
	# El piso recién añadido debe entrar al servidor físico antes del raycast de las fibras.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var antes := mopa.carga.transform
	var agua := limpiador.piso().mopa().color()
	for paso: int in 30:
		fibras.call("_physics_process", 1.0 / 60.0)
	var rigidas: Array = fibras.get("_rigidas")
	assert_array(rigidas).is_not_empty()
	var articulacion: Transform3D = rigidas[0].get_shader_parameter("articulacion")
	# Premisa: el cuerpo está horizontal y la cabeza sí pivota hacia el piso.
	assert_float(absf(mopa.global_basis.y.dot(Vector3.UP))).is_less(0.001)
	assert_float(articulacion.basis.get_rotation_quaternion().get_angle()).is_greater(0.2)
	var pinturas: Array = fibras.get("_pinturas")
	assert_int(pinturas.size()).is_equal(2)
	for pintura: ShaderMaterial in pinturas:
		assert_float(pintura.get_shader_parameter("humedad")).is_greater(0.0)
		assert_that(pintura.get_shader_parameter("color_del_agua")).is_equal(agua)
	# El tinte debe viajar en las fibras articuladas, no añadir otra superficie rígida.
	var triangulos_rigidos := 0
	if mopa.carga.visible and mopa.carga.mesh != null:
		triangulos_rigidos = int(mopa.carga.mesh.get_faces().size() / 3.0)
	assert_int(triangulos_rigidos).is_equal(0)
	assert_bool(mopa.carga.transform.is_equal_approx(antes)).is_true()


func test_mojar_y_secar_las_fibras_conserva_el_anclaje_para_mojar_y_gotear() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var mopa := almacen.get_node("Objetos/Mopa") as Util
	var antes := mopa.carga.transform
	var agua := Color(0.72, 0.89, 0.98)
	mopa.mostrar_la_carga(true, agua)
	assert_that(mopa.color_de_la_carga()).is_equal(agua)
	var pinturas: Array = mopa.malla.get("_pinturas")
	assert_int(pinturas.size()).is_equal(2)
	for pintura: ShaderMaterial in pinturas:
		assert_float(pintura.get_shader_parameter("humedad")).is_greater(0.5)
	mopa.mostrar_la_carga(false, agua)
	for pintura: ShaderMaterial in pinturas:
		assert_float(pintura.get_shader_parameter("humedad")).is_equal(0.0)
	assert_bool(mopa.carga.visible).is_false()
	assert_bool(mopa.carga.transform.is_equal_approx(antes)).is_true()
