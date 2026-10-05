extends GdUnitTestSuite

const Charcos := preload("res://src/escenas/objetos/charcos_temporales.gd")


func _charcos() -> Charcos:
	var charcos: Charcos = auto_free(Charcos.new())
	add_child(charcos)
	charcos.set_process(false)
	return charcos


func _mallas(charcos: Charcos) -> Array[MeshInstance3D]:
	var mallas: Array[MeshInstance3D] = []
	for hijo in charcos.get_children():
		if hijo is MeshInstance3D:
			mallas.append(hijo)
	return mallas


func _opacidad(malla: MeshInstance3D) -> float:
	return (malla.material_override as ShaderMaterial).get_shader_parameter("opacidad")


func test_el_charco_solo_dibuja_agua_sobre_la_superficie() -> void:  # AC-CLN-030
	var charcos := _charcos()
	var punto := Vector3(2, 0.1, 3)
	var normal := Vector3(0.02, 1.0, 0.01).normalized()
	charcos.dejar_en(punto, normal)
	var mallas := _mallas(charcos)
	assert_int(mallas.size()).is_equal(1)
	if mallas.is_empty():
		return
	var malla := mallas[0]
	assert_bool(malla.is_visible_in_tree()).is_true()
	assert_float(malla.global_position.distance_to(punto + normal * 0.003)).is_less(0.00001)
	assert_float(malla.global_basis.y.normalized().dot(normal)).is_greater(0.9999)
	assert_int(malla.gi_mode).is_equal(GeometryInstance3D.GI_MODE_DISABLED)
	assert_int(malla.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_array(charcos.find_children("*", "CollisionObject3D", true, false)).is_empty()
	assert_array(charcos.find_children("*", "CollisionShape3D", true, false)).is_empty()
	for hijo: Node in charcos.get_children():
		assert_bool(hijo.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_false()
		assert_object((hijo as MeshInstance3D).material_overlay).is_null()
	var limites := malla.get_aabb()
	assert_float(limites.size.x).is_less_equal(0.5)
	assert_float(limites.size.z).is_less_equal(0.5)
	assert_float(_opacidad(malla)).is_greater(0.0)


func test_evapora_al_cumplir_cuatro_segundos_sin_depender_de_los_cuadros() -> void:  # AC-CLN-032
	var charcos := _charcos()
	charcos.dejar_en(Vector3.ZERO)
	assert_int(charcos.cantidad()).is_equal(1)
	var mallas := _mallas(charcos)
	if mallas.is_empty():
		return
	var opacidad := _opacidad(mallas[0])
	charcos.call("_process", 3.9)
	assert_int(charcos.cantidad()).is_equal(1)
	assert_float(_opacidad(mallas[0])).is_between(0.0, opacidad - 0.001)
	assert_float(_opacidad(mallas[0])).is_greater(0.0)
	assert_bool(mallas[0].visible).is_true()
	charcos.call("_process", -0.5)
	charcos.call("_process", 0.09999)
	assert_int(charcos.cantidad()).is_equal(1)
	charcos.call("_process", 0.00002)
	assert_int(charcos.cantidad()).is_equal(0)
	await get_tree().process_frame
	assert_array(_mallas(charcos)).is_empty()
	for paso in 40:
		if paso == 0:
			charcos.dejar_en(Vector3.ONE)
		charcos.call("_process", 0.1)
	assert_int(charcos.cantidad()).is_equal(0)


func test_la_pausa_conserva_el_charco_y_su_opacidad() -> void:  # AC-CLN-032
	var charcos := _charcos()
	charcos.dejar_en(Vector3.ZERO)
	var mallas := _mallas(charcos)
	assert_int(mallas.size()).is_equal(1)
	if mallas.is_empty():
		return
	charcos.call("_process", 3.99)
	var opacidad := _opacidad(mallas[0])
	charcos.set_process(true)
	get_tree().paused = true
	var procesaba := charcos.can_process()
	await get_tree().create_timer(0.06, true).timeout
	var cantidad := charcos.cantidad()
	var despues := _opacidad(mallas[0])
	get_tree().paused = false
	charcos.set_process(false)
	assert_bool(procesaba).is_false()
	assert_int(cantidad).is_equal(1)
	assert_float(despues).is_equal(opacidad)
	charcos.call("_process", 0.02)
	assert_int(charcos.cantidad()).is_equal(0)


func test_reutiliza_el_mas_viejo_y_limpiar_retira_todos() -> void:  # AC-CLN-032
	var charcos := _charcos()
	for indice in 8:
		charcos.dejar_en(Vector3(indice, 0.1, 0))
	assert_int(charcos.cantidad()).is_equal(8)
	var mallas := _mallas(charcos)
	assert_int(mallas.size()).is_equal(8)
	if mallas.is_empty():
		return
	var primero := mallas[0]
	charcos.call("_process", 3.5)
	var nuevo := Vector3(12, 0.1, 4)
	charcos.dejar_en(nuevo)
	assert_int(charcos.cantidad()).is_equal(8)
	assert_int(_mallas(charcos).size()).is_equal(8)
	assert_float(primero.global_position.distance_to(nuevo + Vector3.UP * 0.003)).is_less(0.00001)
	charcos.call("_process", 0.6)
	assert_int(charcos.cantidad()).is_equal(1)
	assert_float(_opacidad(primero)).is_greater(0.0)
	await get_tree().process_frame
	for indice in 30:
		charcos.dejar_en(Vector3(indice, 0.1, 8))
	assert_int(charcos.cantidad()).is_equal(8)
	assert_int(_mallas(charcos).size()).is_equal(8)
	charcos.limpiar()
	assert_int(charcos.cantidad()).is_equal(0)
	await get_tree().process_frame
	assert_array(_mallas(charcos)).is_empty()
	charcos.limpiar()
	charcos.dejar_en(Vector3.ZERO)
	assert_int(charcos.cantidad()).is_equal(1)
