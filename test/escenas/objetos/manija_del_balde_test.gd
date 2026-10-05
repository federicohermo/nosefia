extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const Util := preload("res://src/escenas/objetos/util_de_limpieza.gd")


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_process(false)
	jugador.set_physics_process(false)
	almacen.get("_limpieza").set_physics_process(false)
	return almacen


func _angulo(malla: MeshInstance3D) -> float:
	var pinturas: Array = malla.get("_pinturas")
	assert_int(pinturas.size()).is_greater(0)
	if pinturas.is_empty():
		return -1.0
	return (pinturas[0] as ShaderMaterial).get_shader_parameter("angulo")


func _avanzar(malla: MeshInstance3D, segundos: float) -> void:
	malla.call("_process", segundos)


func _contorno(malla: MeshInstance3D, angulo: float) -> void:
	var pinturas: Array = malla.get("_pinturas")
	for pintura: ShaderMaterial in pinturas:
		assert_float(pintura.get_shader_parameter("angulo")).is_equal_approx(angulo, 0.00001)
		assert_object(pintura.next_pass).is_not_null()
		if pintura.next_pass != null:
			var borde := pintura.next_pass as ShaderMaterial
			assert_object(borde).is_not_null()
			if borde != null:
				assert_float(borde.get_shader_parameter("angulo")).is_equal_approx(angulo, 0.00001)


func test_agarrar_y_soltar_anima_el_asa_sin_mover_el_cuerpo_ni_su_carga() -> void:
	var almacen := await _almacen()
	var balde := almacen.get_node("Objetos/Balde") as Util
	var malla := balde.malla
	assert_bool(malla.has_method("mostrar_contorno")).is_true()
	if not malla.has_method("mostrar_contorno"):
		return
	malla.set_process(false)
	_avanzar(malla, 0.5)
	var reposo := _angulo(malla)
	assert_float(absf(reposo)).is_greater(1.5)
	var cuerpo := malla.transform
	var carga := balde.carga.transform
	var forma := balde.get_node("Forma") as CollisionShape3D
	var posicion_de_forma := forma.transform
	var solido := forma.shape
	var capa := balde.collision_layer
	var mascara := balde.collision_mask
	var marco: MarcoDelObjetivo = auto_free(MarcoDelObjetivo.new())
	add_child(marco)
	marco.enfocar(balde)
	_contorno(malla, reposo)
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(balde.datos, balde)).is_true()
	assert_bool(balde.freeze).is_true()
	assert_bool(balde.top_level).is_false()
	_avanzar(malla, 0.0625)
	var intermedio := _angulo(malla)
	assert_float(absf(intermedio)).is_between(0.001, absf(reposo) - 0.001)
	_contorno(malla, intermedio)
	_avanzar(malla, 0.5)
	assert_float(_angulo(malla)).is_equal_approx(0.0, 0.00001)
	_contorno(malla, 0.0)
	assert_bool(malla.transform.is_equal_approx(cuerpo)).is_true()
	assert_bool(balde.carga.transform.is_equal_approx(carga)).is_true()
	assert_bool(forma.transform.is_equal_approx(posicion_de_forma)).is_true()
	assert_object(forma.shape).is_same(solido)
	assert_object(agarre.soltar(true)).is_same(balde)
	assert_bool(balde.freeze).is_false()
	assert_bool(balde.top_level).is_true()
	assert_int(balde.collision_layer).is_equal(capa)
	assert_int(balde.collision_mask).is_equal(mascara)
	_avanzar(malla, 0.0625)
	assert_float(absf(_angulo(malla))).is_between(0.001, absf(reposo) - 0.001)
	_avanzar(malla, 0.5)
	assert_float(absf(_angulo(malla))).is_equal_approx(absf(reposo), 0.00001)
	_contorno(malla, _angulo(malla))
	marco.apagar()


func test_examinar_levanta_el_asa_y_devuelve_el_balde_a_su_estado_real() -> void:
	var almacen := await _almacen()
	var balde := almacen.get_node("Objetos/Balde") as Util
	var malla := balde.malla
	assert_bool(malla.has_method("mostrar_contorno")).is_true()
	if not malla.has_method("mostrar_contorno"):
		return
	malla.set_process(false)
	_avanzar(malla, 0.5)
	var reposo := _angulo(malla)
	var padre := balde.get_parent()
	var lugar := balde.transform
	var congelado := balde.freeze
	var suelto := balde.top_level
	var capa := balde.collision_layer
	var mascara := balde.collision_mask
	var agarre: Agarre = almacen.get("_agarre")
	var jugador: Node3D = almacen.get("_jugador")
	var examen: Examen = jugador.get("examen")
	_examinar(jugador, balde)
	assert_bool(examen.esta_examinando()).is_true()
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(balde.freeze).is_true()
	assert_bool(balde.top_level).is_false()
	_avanzar(malla, 0.5)
	assert_float(_angulo(malla)).is_equal_approx(0.0, 0.00001)
	var antes := balde.global_basis
	examen.arrastrar(Vector2(80, 50), true)
	balde.call("_process", 0.016)
	_avanzar(malla, 0.016)
	assert_bool(balde.global_basis.is_equal_approx(antes)).is_false()
	_examinar(jugador, balde)
	assert_bool(examen.esta_examinando()).is_false()
	assert_object(balde.get_parent()).is_same(padre)
	assert_bool(balde.transform.is_equal_approx(lugar)).is_true()
	assert_bool(balde.freeze).is_equal(congelado)
	assert_bool(balde.top_level).is_equal(suelto)
	assert_int(balde.collision_layer).is_equal(capa)
	assert_int(balde.collision_mask).is_equal(mascara)
	_avanzar(malla, 0.5)
	assert_float(absf(_angulo(malla))).is_equal_approx(absf(reposo), 0.00001)
	assert_bool(agarre.pedir_agarrar(balde.datos, balde)).is_true()
	_avanzar(malla, 0.5)
	_examinar(jugador, balde)
	assert_bool(examen.esta_examinando()).is_true()
	_avanzar(malla, 0.5)
	assert_float(_angulo(malla)).is_equal_approx(0.0, 0.00001)
	_examinar(jugador, balde)
	assert_bool(examen.esta_examinando()).is_false()
	assert_object(agarre.manos().sostenido()).is_same(balde.datos)
	assert_bool(balde.freeze).is_true()
	assert_bool(balde.top_level).is_false()
	_avanzar(malla, 0.5)
	assert_float(_angulo(malla)).is_equal_approx(0.0, 0.00001)
	agarre.soltar(true)


func test_soltar_el_asa_elige_el_lado_opuesto_y_lo_conserva_al_caminar() -> void:
	var almacen := await _almacen()
	var balde := almacen.get_node("Objetos/Balde") as Util
	var malla := balde.malla
	malla.set_process(false)
	var jugador: Node3D = almacen.get("_jugador")
	assert_object(malla.get("observador")).is_same(jugador)
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(balde.datos, balde)).is_true()
	_avanzar(malla, 0.5)
	assert_object(agarre.soltar(true)).is_same(balde)
	jugador.global_position = malla.to_global(Vector3(0, 0.5, 1))
	assert_float(malla.to_local(jugador.global_position).z).is_greater(0.9)
	_avanzar(malla, 0.5)
	var negativa := _angulo(malla)
	assert_float(negativa).is_less(-1.5)
	jugador.global_position = malla.to_global(Vector3(0, 0.5, -1))
	_avanzar(malla, 0.5)
	assert_float(_angulo(malla)).is_equal_approx(negativa, 0.00001)
	assert_bool(agarre.pedir_agarrar(balde.datos, balde)).is_true()
	_avanzar(malla, 0.5)
	assert_object(agarre.soltar(true)).is_same(balde)
	jugador.global_position = malla.to_global(Vector3(0, 0.5, -1))
	assert_float(malla.to_local(jugador.global_position).z).is_less(-0.9)
	_avanzar(malla, 0.5)
	assert_float(_angulo(malla)).is_greater(1.5)
	assert_bool(agarre.pedir_agarrar(balde.datos, balde)).is_true()
	_avanzar(malla, 0.5)
	assert_object(agarre.soltar(true)).is_same(balde)
	balde.global_basis = Basis(Vector3.UP, PI / 2.0)
	jugador.global_position = malla.to_global(Vector3(0, 0.5, 1))
	assert_float(malla.to_local(jugador.global_position).z).is_greater(0.9)
	_avanzar(malla, 0.5)
	assert_float(_angulo(malla)).is_less(-1.5)


func test_interrumpir_agarre_o_bajada_conserva_el_angulo_actual_sin_salto() -> void:
	var almacen := await _almacen()
	var balde := almacen.get_node("Objetos/Balde") as Util
	var malla := balde.malla
	malla.set_process(false)
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(balde.datos, balde)).is_true()
	_avanzar(malla, 0.5)
	agarre.soltar(true)
	jugador.global_position = malla.to_global(Vector3(0, 0.5, 1))
	_avanzar(malla, 0.5)
	var suelo := _angulo(malla)
	assert_float(suelo).is_less(-1.5)
	assert_bool(agarre.pedir_agarrar(balde.datos, balde)).is_true()
	_avanzar(malla, 0.0)
	assert_float(_angulo(malla)).is_equal_approx(suelo, 0.00001)
	_avanzar(malla, 0.0625)
	var subiendo := _angulo(malla)
	assert_float(subiendo).is_between(suelo + 0.001, -0.001)
	agarre.soltar(true)
	jugador.global_position = malla.to_global(Vector3(0, 0.5, -1))
	_avanzar(malla, 0.0)
	assert_float(_angulo(malla)).is_equal_approx(subiendo, 0.00001)
	_avanzar(malla, 0.0625)
	var bajando := _angulo(malla)
	assert_float(bajando).is_between(subiendo + 0.001, 1.5)
	assert_bool(agarre.pedir_agarrar(balde.datos, balde)).is_true()
	_avanzar(malla, 0.0)
	assert_float(_angulo(malla)).is_equal_approx(bajando, 0.00001)
	_avanzar(malla, 0.5)
	assert_float(_angulo(malla)).is_equal_approx(0.0, 0.00001)
	agarre.soltar(true)


func _examinar(jugador: Node3D, objetivo: Node3D) -> void:
	jugador.set("_enfocado", objetivo)
	var tecla := InputEventAction.new()
	tecla.action = ReglasDeLosObjetos.ACCION_EXAMINAR
	tecla.pressed = true
	jugador.call("_unhandled_input", tecla)
