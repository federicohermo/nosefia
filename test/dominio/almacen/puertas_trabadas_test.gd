extends GdUnitTestSuite


func _trabadas(jornada: int) -> Array[PuertasTrabadas.Cuarto]:
	var trabadas: Array[PuertasTrabadas.Cuarto] = []
	for cuarto: PuertasTrabadas.Cuarto in PuertasTrabadas.Cuarto.values():
		if PuertasTrabadas.trabada(cuarto, jornada):
			trabadas.append(cuarto)
	return trabadas


func test_el_deposito_esta_trabado_solo_en_la_primera_jornada() -> void:  # AC-PLY-040
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	assert_bool(PuertasTrabadas.trabada(PuertasTrabadas.Cuarto.DEPOSITO, primera)).is_true()
	for jornada: int in range(primera + 1, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1):
		(
			assert_bool(PuertasTrabadas.trabada(PuertasTrabadas.Cuarto.DEPOSITO, jornada))
			. override_failure_message("jornada %d" % jornada)
			. is_false()
		)


func test_el_cuartito_y_el_bano_siguen_a_la_limpieza() -> void:  # AC-PLY-040
	for jornada: int in range(1, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1):
		var cerradas := not Apertura.pide(jornada, Tarea.Tipo.LIMPIAR)
		for cuarto: PuertasTrabadas.Cuarto in [
			PuertasTrabadas.Cuarto.CUARTITO, PuertasTrabadas.Cuarto.BANO
		]:
			(
				assert_bool(PuertasTrabadas.trabada(cuarto, jornada))
				. override_failure_message("%s en la jornada %d" % [cuarto, jornada])
				. is_equal(cerradas)
			)


func test_la_primera_jornada_traba_las_tres_y_la_primera_que_limpia_ninguna() -> void:  # AC-PLY-040
	assert_array(_trabadas(ReglasDeLaPartida.PRIMERA_JORNADA)).has_size(
		PuertasTrabadas.Cuarto.size()
	)
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	while not Apertura.pide(jornada, Tarea.Tipo.LIMPIAR):
		jornada += 1
	assert_array(_trabadas(jornada)).is_empty()
