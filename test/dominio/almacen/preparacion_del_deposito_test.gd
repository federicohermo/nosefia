extends GdUnitTestSuite


func test_la_carga_de_la_primera_noche_no_prepara_las_cajas() -> void:
	assert_bool(PreparacionDelDeposito.se_prepara(ReglasDeLaPartida.PRIMERA_JORNADA)).is_false()


func test_desde_la_segunda_noche_se_preparan_hasta_el_final() -> void:
	for jornada: int in range(
		ReglasDeLaPartida.PRIMERA_JORNADA + 1, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
	):
		(
			assert_bool(PreparacionDelDeposito.se_prepara(jornada))
			. override_failure_message(str(jornada))
			. is_true()
		)


func test_la_transicion_de_la_primera_a_la_segunda_las_prepara() -> void:
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	assert_bool(PreparacionDelDeposito.por_preparar(primera, primera + 1)).is_true()


func test_una_noche_retomada_en_la_segunda_las_trae_preparadas_de_la_carga() -> void:
	var segunda := ReglasDeLaPartida.PRIMERA_JORNADA + 1
	assert_bool(PreparacionDelDeposito.se_prepara(segunda)).is_true()
	assert_bool(PreparacionDelDeposito.por_preparar(segunda, segunda + 1)).is_false()


func test_las_cajas_no_se_preparan_dos_veces_en_la_misma_partida() -> void:
	for carga: int in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
	):
		var veces := 1 if PreparacionDelDeposito.se_prepara(carga) else 0
		for siguiente: int in range(carga + 1, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1):
			if PreparacionDelDeposito.por_preparar(siguiente - 1, siguiente):
				veces += 1
		assert_int(veces).is_less_equal(1)
