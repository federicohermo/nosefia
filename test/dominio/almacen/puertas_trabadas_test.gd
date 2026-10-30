extends GdUnitTestSuite


func test_el_cuartito_sigue_a_la_limpieza() -> void:  # AC-PLY-040
	for jornada: int in range(1, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1):
		(
			assert_bool(PuertasTrabadas.cuartito_trabado(jornada))
			. override_failure_message("jornada %d" % jornada)
			. is_equal(not Apertura.pide(jornada, Tarea.Tipo.LIMPIAR))
		)


func test_la_primera_jornada_traba_el_cuartito_y_la_primera_que_limpia_no() -> void:  # AC-PLY-040
	assert_bool(PuertasTrabadas.cuartito_trabado(ReglasDeLaPartida.PRIMERA_JORNADA)).is_true()
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	while not Apertura.pide(jornada, Tarea.Tipo.LIMPIAR):
		jornada += 1
	assert_bool(PuertasTrabadas.cuartito_trabado(jornada)).is_false()
