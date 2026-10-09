func test_el_lector_es_copia_y_conserva_ranura_mundo_y_mano() -> void:  # AC-CLN-048
	var almacen := await _abrir()
	_emitir_papel(almacen)
	_emitir_papel(almacen)
	var papeles := _papeles(almacen)
	assert_array(papeles).has_size(2)
	var puesto := _puesto(almacen)
	var copia: Array[Node3D] = puesto.call("tickets_en_el_mundo")
	assert_array(copia).contains_exactly(papeles)
	copia.clear()
	assert_array(puesto.call("tickets_en_el_mundo")).contains_exactly(papeles)
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(papeles[0].datos, papeles[0])).is_true()
	assert_object(agarre.cuerpo_sostenido()).is_same(papeles[0])
	assert_array(puesto.call("tickets_en_el_mundo")).contains_exactly(papeles)
	assert_bool((almacen.get_node("Jugador").get("examen") as Examen).iniciar()).is_true()
	assert_array(puesto.call("tickets_en_el_mundo")).contains_exactly(papeles)
	(almacen.get_node("Jugador").get("examen") as Examen).terminar()


func test_el_lector_omite_referencias_liberadas_y_en_cola() -> void:  # AC-CLN-048
	var almacen := await _abrir()
	_emitir_papel(almacen)
	_emitir_papel(almacen)
	var papeles := _papeles(almacen)
	assert_array(papeles).has_size(2)
	var liberado := papeles[0]
	var pendiente := papeles[1]
	liberado.free()
	assert_bool(is_instance_valid(liberado)).is_false()
	pendiente.queue_free()
	assert_bool(is_instance_valid(pendiente)).is_true()
	assert_bool(pendiente.is_queued_for_deletion()).is_true()
	assert_array(_puesto(almacen).call("tickets_en_el_mundo")).is_empty()
	await get_tree().process_frame
	assert_bool(is_instance_valid(pendiente)).is_false()
	assert_array(_puesto(almacen).call("tickets_en_el_mundo")).is_empty()


func test_limpiar_vacia_el_lector_antes_y_despues_del_free() -> void:  # AC-CLN-048
	var almacen := await _abrir()
	_emitir_papel(almacen)
	var papeles := _papeles(almacen)
	assert_array(papeles).has_size(1)
	assert_array(_puesto(almacen).call("tickets_en_el_mundo")).contains_exactly(papeles)
	_puesto(almacen).call("limpiar")
	assert_array(_puesto(almacen).call("tickets_en_el_mundo")).is_empty()
	assert_bool(papeles[0].is_queued_for_deletion()).is_true()
	await get_tree().process_frame
	assert_bool(is_instance_valid(papeles[0])).is_false()
	assert_array(_puesto(almacen).call("tickets_en_el_mundo")).is_empty()
