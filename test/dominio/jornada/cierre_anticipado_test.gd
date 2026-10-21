extends GdUnitTestSuite


func _cumplidas_salvo(jornada: int, pendiente: Tarea = null) -> Array[Tarea]:
	var obligatorias := Apertura.obligatorias(jornada)
	for tarea in obligatorias:
		if pendiente == null or tarea.tipo() != pendiente.tipo():
			tarea.completar()
	return obligatorias


func test_cada_obligatoria_es_necesaria_y_solo_salen_las_noches_de_prueba() -> void:  # AC-SHF-036
	for jornada: int in range(1, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1):
		var de_prueba := jornada < ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
		assert_bool(CierreAnticipado.corresponde(jornada, _cumplidas_salvo(jornada))).is_equal(
			de_prueba
		)
		for pendiente in Apertura.obligatorias(jornada):
			(
				assert_bool(
					CierreAnticipado.corresponde(jornada, _cumplidas_salvo(jornada, pendiente))
				)
				. is_false()
			)
	assert_bool(CierreAnticipado.corresponde(0, _cumplidas_salvo(0))).is_false()


func test_consolidar_solo_si_todas_estan_hechas_y_la_jornada_lo_permite() -> void:  # AC-SHF-037
	for jornada: int in [1, 2, 3, 4]:
		var todas := _cumplidas_salvo(jornada)
		CierreAnticipado.consolidar(jornada, todas)
		for tarea in todas:
			assert_bool(tarea.descompletar()).is_equal(jornada == 4)
	var pendiente := Tarea.new(Tarea.Tipo.REGISTRAR)
	var incompletas := _cumplidas_salvo(1, pendiente)
	CierreAnticipado.consolidar(1, incompletas)
	for tarea in incompletas:
		if tarea.tipo() == Tarea.Tipo.REGISTRAR:
			assert_bool(tarea.completada()).is_false()
		else:
			assert_bool(tarea.descompletar()).is_true()
