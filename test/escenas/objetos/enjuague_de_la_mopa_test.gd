extends GdUnitTestSuite

const Util := preload("res://src/escenas/objetos/util_de_limpieza.gd")
const OBJETOS := preload("res://src/escenas/puestos/objetos_del_almacen.tscn")
const PUNTO := Vector3(10.945, .44, -1.78)


func _objetos() -> Dictionary:
	var objetos: Node3D = auto_free(OBJETOS.instantiate())
	add_child(objetos)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var mopa := objetos.get_node("Mopa") as Util
	var balde := objetos.get_node("Balde") as Util
	balde.freeze = true
	var ancla: Node3D = auto_free(Node3D.new())
	add_child(ancla)
	ancla.global_position = Vector3(10.3, 1.6, -2.2)
	var agarre: Agarre = auto_free(Agarre.new())
	add_child(agarre)
	agarre.punto_de_carga = ancla
	agarre.punto_de_soltado = ancla
	assert_bool(agarre.pedir_agarrar(mopa.datos, mopa)).is_true()
	var inodoro: StaticBody3D = auto_free(StaticBody3D.new())
	add_child(inodoro)
	# La raíz del cuerpo no es el desagüe: el destino entra en coordenadas mundiales.
	inodoro.global_position = Vector3(5, 2, 9)
	await get_tree().physics_frame
	return {"mopa": mopa, "balde": balde, "inodoro": inodoro, "agarre": agarre}


# AC-CLN-029: la presentación baja al punto de enjuague sin cambiar la carga ni la colisión.
func test_la_animacion_de_enjuague_llega_al_punto_mundial_y_regresa_a_la_mano() -> void:
	var objetos := await _objetos()
	var mopa: Util = objetos.mopa
	var inodoro: StaticBody3D = objetos.inodoro
	var carga := mopa.carga.transform
	var forma := mopa.get_node("Forma") as CollisionShape3D
	var colision := forma.transform
	var orientacion := Basis(Vector3.UP, .3)
	mopa.mostrar_la_mojada(inodoro, PUNTO, orientacion)
	var animacion: Tween = mopa.get("_bajada")
	assert_object(animacion).is_not_null()
	animacion.pause()
	animacion.custom_step(ReglasDeLaLimpieza.DURACION_DE_LA_MOJADA * .4 + .00001)
	assert_vector(mopa.carga.global_position).is_equal_approx(PUNTO, Vector3.ONE * .00001)
	assert_bool(mopa.global_basis.is_equal_approx(orientacion)).is_true()
	assert_object(mopa.contacto_del_movimiento).is_same(inodoro)
	assert_bool(mopa.carga.transform.is_equal_approx(carga)).is_true()
	assert_bool(forma.transform.is_equal_approx(colision)).is_true()
	animacion.custom_step(ReglasDeLaLimpieza.DURACION_DE_LA_MOJADA * .6 + .00002)
	assert_vector(mopa.position).is_equal_approx(Vector3.ZERO, Vector3.ONE * .00001)
	assert_bool(mopa.basis.is_equal_approx(mopa.orientacion_en_mano)).is_true()
	assert_object(mopa.contacto_del_movimiento).is_null()
	assert_float(float(mopa.malla.get("_inmersion"))).is_equal(0.0)


func test_el_enjuague_salva_el_borde_y_entra_vertical_sin_limitar_como_un_balde() -> void:
	var objetos := await _objetos()
	var mopa: Util = objetos.mopa
	var inodoro: StaticBody3D = objetos.inodoro
	var desde := mopa.carga.global_position
	mopa.call("_mover_la_mopa", .15, inodoro, PUNTO, Basis.IDENTITY)
	assert_float(mopa.carga.global_position.y).is_greater(maxf(desde.y, PUNTO.y) + .04)
	assert_object(mopa.contacto_del_movimiento).is_same(inodoro)
	assert_float(float(mopa.malla.get("_inmersion"))).is_equal(0.0)
	mopa.call("_mover_la_mopa", .85, inodoro, PUNTO, Basis.IDENTITY)
	var diferencia := mopa.carga.global_position - PUNTO
	# Con la cabeza de 8 cm, cinco cm de desvío quedan dentro de la abertura.
	assert_float(Vector2(diferencia.x, diferencia.z).length()).is_less(.05)
	assert_float(mopa.carga.global_position.y).is_greater(.61)
	mopa.call("_mover_la_mopa", 1.0, inodoro, PUNTO, Basis.IDENTITY)
	assert_vector(mopa.carga.global_position).is_equal_approx(PUNTO, Vector3.ONE * .00001)
	assert_float(float(mopa.malla.get("_inmersion"))).is_equal(0.0)


func test_el_balde_conserva_su_destino_y_el_limite_de_fibras_originales() -> void:
	var objetos := await _objetos()
	var mopa: Util = objetos.mopa
	var balde: Util = objetos.balde
	balde.global_position = Vector3(10.7, .258, -2.0)
	mopa.call("_mover_la_mopa", 1.0, balde)
	assert_vector(balde.to_local(mopa.carga.global_position)).is_equal_approx(
		Vector3(0, .07, 0), Vector3.ONE * .00001
	)
	assert_float(float(mopa.malla.get("_inmersion"))).is_equal(1.0)
	mopa.call("_mover_la_mopa", .0, balde)
	assert_float(float(mopa.malla.get("_inmersion"))).is_equal(0.0)


func test_soltar_durante_el_enjuague_cancela_la_animacion_y_los_contactos() -> void:
	var objetos := await _objetos()
	var mopa: Util = objetos.mopa
	var agarre: Agarre = objetos.agarre
	mopa.mostrar_la_mojada(objetos.inodoro, PUNTO, Basis.IDENTITY)
	var animacion: Tween = mopa.get("_bajada")
	animacion.pause()
	animacion.custom_step(ReglasDeLaLimpieza.DURACION_DE_LA_MOJADA * .2)
	assert_object(mopa.contacto_del_movimiento).is_same(objetos.inodoro)
	agarre.soltar(true)
	assert_object(mopa.get("_bajada")).is_null()
	assert_object(mopa.contacto_del_movimiento).is_null()
	assert_float(float(mopa.malla.get("_inmersion"))).is_equal(0.0)


func test_el_asiento_no_levanta_las_fibras_separandolas_de_la_base_sumergida() -> void:
	var objetos := await _objetos()
	var mopa: Util = objetos.mopa
	var inodoro: StaticBody3D = objetos.inodoro
	var asiento := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(.4, .02, .5)
	asiento.shape = caja
	inodoro.add_child(asiento)
	inodoro.global_position = Vector3(PUNTO.x, .6, PUNTO.z)
	await get_tree().physics_frame
	await get_tree().physics_frame
	mopa.mostrar_la_mojada(inodoro, PUNTO, Basis.IDENTITY)
	var animacion: Tween = mopa.get("_bajada")
	animacion.pause()
	animacion.custom_step(ReglasDeLaLimpieza.DURACION_DE_LA_MOJADA * .3)
	mopa.malla.call("_physics_process", 1.0 / 60.0)
	var pinturas: Array = mopa.malla.get("_pinturas")
	assert_int(pinturas.size()).is_greater(0)
	for pintura: ShaderMaterial in pinturas:
		assert_float(float(pintura.get_shader_parameter("suelo_y"))).is_less(.44)
	animacion.custom_step(ReglasDeLaLimpieza.DURACION_DE_LA_MOJADA * .1 + .00001)
	mopa.malla.call("_physics_process", 1.0 / 60.0)
	for pintura: ShaderMaterial in pinturas:
		assert_float(float(pintura.get_shader_parameter("suelo_y"))).is_less(.44)
	# Al soltar vuelve el apoyo ordinario: la exclusión no sobrevive al gesto.
	(objetos.agarre as Agarre).soltar(true)
	mopa.freeze = true
	mopa.global_basis = Basis.IDENTITY
	# Soltar recupera la escala apoyada; ubicamos su punto de consulta debajo del asiento.
	mopa.global_position += PUNTO - mopa.malla.to_global(Vector3(0, -.83, 0))
	mopa.malla.call("_physics_process", 1.0 / 60.0)
	for pintura: ShaderMaterial in pinturas:
		assert_float(float(pintura.get_shader_parameter("suelo_y"))).is_greater(.59)
