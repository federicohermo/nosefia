extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	jugador.set_process(false)
	almacen.get("_limpieza").set_physics_process(false)
	return almacen


func test_examinar_el_balde_con_gotas_lo_mantiene_delante_de_la_camara() -> void:
	var almacen := await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	var balde: Node3D = almacen.get_node("Objetos/Balde")
	var examen: Examen = jugador.get("examen")
	jugador.set("_enfocado", balde)
	var tecla := InputEventAction.new()
	tecla.action = ReglasDeLosObjetos.ACCION_EXAMINAR
	tecla.pressed = true
	assert_bool(examen.esta_examinando()).is_false()
	jugador.call("_unhandled_input", tecla)
	assert_bool(examen.esta_examinando()).is_true()
	assert_float(examen.punto_de_examen.position.length()).is_less(1.5)
	assert_bool((balde.get("malla") as MeshInstance3D).is_visible_in_tree()).is_true()
	var antes := balde.global_basis
	examen.arrastrar(Vector2(80.0, 50.0), true)
	balde.call("_process", 0.016)
	assert_bool(balde.global_basis.is_equal_approx(antes)).is_false()
	assert_float(balde.global_basis.y.dot(Vector3.UP)).is_less(0.99)
	jugador.call("_unhandled_input", tecla)
	assert_bool(examen.esta_examinando()).is_false()
	assert_object(balde.get_parent()).is_same(almacen.get_node("Objetos"))


func test_el_viaje_seca_la_mopa_y_el_balde_cercano_permite_limpiar() -> void:  # AC-CLN-027
	var almacen := await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	var mopa: Node3D = almacen.get_node("Objetos/Mopa")
	var limpiador: Limpiador = almacen.get("_limpiador")
	var limpieza: Node = almacen.get("_limpieza")
	var agarre: Agarre = almacen.get("_agarre")
	limpiador.usar(&"balde", &"lavatorio")
	limpiador.usar(&"jabon_amarillo", &"balde")
	assert_bool(agarre.pedir_agarrar(mopa.get("datos"), mopa)).is_true()
	limpiador.usar(&"mopa", &"balde")
	limpieza.call("_physics_process", 0.0)
	jugador.global_position += Vector3.RIGHT * ReglasDeLaLimpieza.RECORRIDO_DE_LA_CARGA
	limpieza.call("_physics_process", 1.0)
	assert_bool(limpiador.piso().mopa().esta_mojada()).is_false()
	assert_int(limpiador.pasar(&"mopa", PisoDelLocal.Lugar.ENTRADA)).is_equal(
		ReglasDeLaLimpieza.Resultado.MOPA_SECA
	)
	jugador.global_position += Vector3.LEFT * ReglasDeLaLimpieza.RECORRIDO_DE_LA_CARGA
	limpiador.usar(&"mopa", &"balde")
	limpieza.call("_physics_process", 0.15)
	assert_float(limpiador.piso().mopa().carga_restante()).is_greater(0.9)
	assert_int(limpiador.pasar(&"mopa", PisoDelLocal.Lugar.ENTRADA)).is_equal(
		ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA
	)
	var gotas: Node3D = mopa.get("_gotas")
	var dibujo: MultiMeshInstance3D = gotas.get("_malla")
	assert_bool(dibujo.visible).is_true()
	assert_int(dibujo.multimesh.visible_instance_count).is_less_equal(24)
	agarre.soltar(true)


func test_dejar_la_mopa_en_el_piso_no_conserva_la_carga() -> void:  # AC-CLN-026
	var almacen := await _almacen()
	var limpiador: Limpiador = almacen.get("_limpiador")
	limpiador.usar(&"balde", &"lavatorio")
	limpiador.usar(&"jabon_amarillo", &"balde")
	limpiador.usar(&"mopa", &"balde")
	almacen.get("_limpieza").call("_physics_process", ReglasDeLaLimpieza.DURACION_DE_LA_CARGA)
	assert_bool(limpiador.piso().mopa().esta_mojada()).is_false()


func test_la_pausa_suspende_el_proceso_que_desgasta_la_mopa() -> void:  # AC-CLN-026
	var almacen := await _almacen()
	var limpieza: Node = almacen.get("_limpieza")
	limpieza.set_physics_process(true)
	assert_bool(limpieza.can_process()).is_true()
	get_tree().paused = true
	var procesaba := limpieza.can_process()
	get_tree().paused = false
	assert_bool(procesaba).is_false()
