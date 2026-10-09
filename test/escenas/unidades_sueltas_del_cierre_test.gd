## El lector conserva las unidades físicas agrupadas y el examen de la que está en mano.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const CIERRE := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const Habitaciones := preload("res://src/escenas/puestos/habitaciones_del_almacen.gd")
var _almacen: Node3D


func after_test() -> void:
	if is_instance_valid(_almacen):
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in _almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		_almacen.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_almacen = null


func _abrir() -> void:
	_almacen = ALMACEN.instantiate()
	add_child(_almacen)
	_almacen.get("_jugador").set_process(false)
	_almacen.get("_jugador").set_physics_process(false)


func _unidad() -> ObjetoAgarrable:
	_almacen.get("_reposicion_manual").call("retirar", Producto.Id.ACTRONCITO)
	return _almacen.get("_agarre").cuerpo_sostenido()


func _desorden() -> bool:
	return CIERRE.hay_desorden(_almacen.call("_estados_del_cierre"))


func test_suelta_en_cada_habitacion_cuenta_aunque_el_grupo_oculte_su_malla() -> void:  # AC-CLN-041
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var unidad := _unidad()
	_almacen.get("_agarre").soltar(true)
	assert_bool(unidad.get_node("Malla").visible).is_false()
	for partes: Array[AABB] in [lector.local, lector.deposito, lector.bano]:
		unidad.global_position = lector.to_global(partes[0].get_center())
		assert_bool(_desorden()).is_true()
	var copia: Array[Node3D] = _almacen.get("_reposicion_manual").call("unidades_sueltas")
	assert_array(copia).contains_exactly([unidad])
	copia.clear()
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).has_size(1)


func test_devolver_o_colocar_retira_suelta_y_no_cuenta_el_repuesto() -> void:  # AC-CLN-041
	_abrir()
	var agarre: Agarre = _almacen.get("_agarre")
	var puesto: Node3D = _almacen.get("_reposicion_manual")
	var unidad := _unidad()
	agarre.soltar(true)
	assert_bool(_desorden()).is_true()
	agarre.pedir_agarrar(unidad.datos, unidad)
	puesto.call("devolver", Producto.Id.ACTRONCITO)
	assert_bool(_desorden()).is_false()
	assert_array(puesto.call("unidades_sueltas")).is_empty()
	unidad = _unidad()
	puesto.call("pedir_colocar", Producto.Id.ACTRONCITO)
	assert_object(agarre.cuerpo_sostenido()).is_null()
	assert_bool(_desorden()).is_false()
	assert_array(puesto.call("unidades_sueltas")).is_empty()


func test_apoyada_sobre_una_caja_del_deposito_sigue_siendo_suelta() -> void:  # AC-CLN-041
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var caja: RigidBody3D = _almacen.get("_cajas_de_productos")[0]
	var forma_de_caja: CollisionShape3D = caja.get_node("Cuerpo")
	var caja_local := forma_de_caja.transform * forma_de_caja.shape.get_debug_mesh().get_aabb()
	caja.global_basis = Basis.IDENTITY
	caja.global_position = lector.to_global(lector.deposito[0].get_center())
	caja.global_position.y = lector.to_global(lector.deposito[0].position).y - caja_local.position.y
	assert_bool(caja.freeze).is_true()
	var unidad := _unidad()
	_almacen.get("_agarre").soltar(true)
	unidad.global_basis = Basis.IDENTITY
	var forma: CollisionShape3D = unidad.get_node("Forma")
	var unidad_local := forma.transform * forma.shape.get_debug_mesh().get_aabb()
	unidad.global_position = caja.global_position
	unidad.global_position.y += caja_local.end.y - unidad_local.position.y + 0.1
	for cuadro in 120:
		await get_tree().physics_frame
	assert_int(lector.de(unidad.global_position)).is_equal(CIERRE.Habitacion.DEPOSITO)
	assert_float(unidad.global_position.y + unidad_local.position.y).is_equal_approx(
		caja.global_position.y + caja_local.end.y, 0.03
	)
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).contains_exactly(
		[unidad]
	)
	assert_bool(_desorden()).is_true()


func test_la_unidad_en_examen_vuelve_a_la_foto_sin_reingresar_al_grupo() -> void:  # AC-CLN-043
	_abrir()
	var unidad := _unidad()
	var examen: Examen = _almacen.get("_jugador").examen
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).is_empty()
	assert_bool(_desorden()).is_false()
	assert_bool(examen.iniciar()).is_true()
	assert_bool(_desorden()).is_true()
	assert_array(_almacen.get("_reposicion_manual").call("unidades_sueltas")).is_empty()
	assert_object(_almacen.get("_agarre").cuerpo_sostenido()).is_same(unidad)
	examen.terminar()
	assert_bool(_desorden()).is_false()


func test_recuperar_la_unidad_de_afuera_y_soltar_adentro_cambia_el_motivo() -> void:  # AC-CLN-044
	_abrir()
	var lector: Habitaciones = _almacen.get("_habitaciones")
	var agarre: Agarre = _almacen.get("_agarre")
	var unidad := _unidad()
	agarre.soltar(true)
	unidad.global_position = lector.to_global(
		lector.local[0].get_center() + Vector3.UP * lector.local[0].size.y
	)
	assert_bool(CIERRE.hay_objetos_afuera(_almacen.call("_estados_del_cierre"))).is_true()
	agarre.pedir_agarrar(unidad.datos, unidad)
	assert_bool(CIERRE.hay_objetos_afuera(_almacen.call("_estados_del_cierre"))).is_false()
	agarre.soltar(true)
	unidad.global_position = lector.to_global(lector.local[0].get_center())
	assert_bool(CIERRE.hay_objetos_afuera(_almacen.call("_estados_del_cierre"))).is_false()
	assert_bool(_desorden()).is_true()
