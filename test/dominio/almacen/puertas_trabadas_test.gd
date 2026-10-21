extends GdUnitTestSuite


func _trabadas(jornada: int) -> Array[PuertasTrabadas.Puerta]:
	var trabadas: Array[PuertasTrabadas.Puerta] = []
	for puerta: PuertasTrabadas.Puerta in PuertasTrabadas.Puerta.values():
		if PuertasTrabadas.trabada(puerta, jornada):
			trabadas.append(puerta)
	return trabadas


func test_el_deposito_esta_trabado_solo_en_la_primera_jornada() -> void:  # AC-PLY-040
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	assert_bool(PuertasTrabadas.trabada(PuertasTrabadas.Puerta.DEPOSITO, primera)).is_true()
	for jornada: int in range(primera + 1, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1):
		(
			assert_bool(PuertasTrabadas.trabada(PuertasTrabadas.Puerta.DEPOSITO, jornada))
			. override_failure_message("jornada %d" % jornada)
			. is_false()
		)


func test_el_cuartito_y_el_bano_siguen_a_la_limpieza() -> void:  # AC-PLY-040
	for jornada: int in range(1, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1):
		var cerradas := not Apertura.pide(jornada, Tarea.Tipo.LIMPIAR)
		for puerta: PuertasTrabadas.Puerta in [
			PuertasTrabadas.Puerta.CUARTITO, PuertasTrabadas.Puerta.BANO
		]:
			(
				assert_bool(PuertasTrabadas.trabada(puerta, jornada))
				. override_failure_message("%s en la jornada %d" % [puerta, jornada])
				. is_equal(cerradas)
			)


func test_la_primera_jornada_traba_las_tres_y_la_primera_que_limpia_ninguna() -> void:  # AC-PLY-040
	assert_array(_trabadas(ReglasDeLaPartida.PRIMERA_JORNADA)).has_size(
		PuertasTrabadas.Puerta.size()
	)
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	while not Apertura.pide(jornada, Tarea.Tipo.LIMPIAR):
		jornada += 1
	assert_array(_trabadas(jornada)).is_empty()
