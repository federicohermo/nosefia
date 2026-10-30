extends GdUnitTestSuite


func test_registra_solo_un_tenido_aceptado_y_no_escribe_deuda_ni_mensajes() -> void:  # AC-EMP-067
	var partida := Partida.desde({"jornada": AnomaliasDeLaJornada.JORNADA_SIN_AZUL})
	var id := UnidadDeProducto.new(Catalogo.de(Producto.Id.POETICO)).id
	partida.abrir_la_jornada()
	for rechazo: ReglasDeLaLimpieza.Resultado in [
		ReglasDeLaLimpieza.Resultado.BALDE_VACIO, ReglasDeLaLimpieza.Resultado.BALDE_YA_TENIDO
	]:
		assert_int(partida.anotar_uso_de_poetico(id, rechazo, true)).is_equal(
			Partida.RegistroDePoetico.RECHAZADO
		)
		assert_bool(partida.uso_de_poetico_en(AnomaliasDeLaJornada.JORNADA_SIN_AZUL)).is_false()
	(
		assert_int(
			partida.anotar_uso_de_poetico(id, ReglasDeLaLimpieza.Resultado.BALDE_TENIDO, true)
		)
		. is_equal(Partida.RegistroDePoetico.ANOTADO)
	)
	(
		assert_int(
			partida.anotar_uso_de_poetico(id, ReglasDeLaLimpieza.Resultado.BALDE_TENIDO, true)
		)
		. is_equal(Partida.RegistroDePoetico.REPETIDO)
	)
	assert_bool(partida.uso_de_poetico_en(AnomaliasDeLaJornada.JORNADA_SIN_AZUL)).is_true()
	assert_int(partida.medios()).is_zero()
	assert_array(partida.devoluciones_del_jefe()).is_empty()


func test_el_hecho_pertenece_a_la_jornada_abierta_y_se_consulta_tras_cerrar() -> void:  # AC-EMP-068
	var id := UnidadDeProducto.new(Catalogo.de(Producto.Id.POETICO)).id
	for jornada in range(1, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1):
		var partida := Partida.desde({"jornada": jornada})
		(
			assert_int(
				partida.anotar_uso_de_poetico(id, ReglasDeLaLimpieza.Resultado.BALDE_TENIDO, true)
			)
			. is_equal(Partida.RegistroDePoetico.RECHAZADO)
		)
		partida.abrir_la_jornada()
		(
			assert_int(
				partida.anotar_uso_de_poetico(id, ReglasDeLaLimpieza.Resultado.BALDE_TENIDO, false)
			)
			. is_equal(Partida.RegistroDePoetico.RECHAZADO)
		)
		assert_bool(partida.uso_de_poetico_en(jornada)).is_false()
		(
			assert_int(
				partida.anotar_uso_de_poetico(
					&"jabon_azul", ReglasDeLaLimpieza.Resultado.BALDE_TENIDO, true
				)
			)
			. is_equal(Partida.RegistroDePoetico.RECHAZADO)
		)
		partida.anotar_uso_de_poetico(id, ReglasDeLaLimpieza.Resultado.BALDE_TENIDO, true)
		partida.cerrar_la_jornada(partida.obligatorias().size())
		assert_bool(partida.uso_de_poetico_en(jornada)).is_equal(
			jornada == AnomaliasDeLaJornada.JORNADA_SIN_AZUL
		)
		(
			assert_int(
				partida.anotar_uso_de_poetico(id, ReglasDeLaLimpieza.Resultado.BALDE_TENIDO, true)
			)
			. is_equal(Partida.RegistroDePoetico.RECHAZADO)
		)
		if jornada == AnomaliasDeLaJornada.JORNADA_SIN_AZUL:
			partida.abrir_la_jornada()
			assert_bool(partida.uso_de_poetico_en(AnomaliasDeLaJornada.JORNADA_SIN_AZUL)).is_true()
			(
				assert_bool(partida.uso_de_poetico_en(AnomaliasDeLaJornada.JORNADA_SIN_AZUL + 1))
				. is_false()
			)
			(
				assert_bool(
					Partida.nueva().uso_de_poetico_en(AnomaliasDeLaJornada.JORNADA_SIN_AZUL)
				)
				. is_false()
			)
