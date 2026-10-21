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


func test_perder_y_recuperar_cualquier_tarea_cambia_el_permiso() -> void:  # AC-SHF-041
	for jornada: int in [1, 2, 3]:
		var tareas := _cumplidas_salvo(jornada)
		for tarea in tareas:
			assert_bool(CierreAnticipado.corresponde(jornada, tareas)).is_true()
			assert_bool(tarea.descompletar()).is_true()
			assert_bool(CierreAnticipado.corresponde(jornada, tareas)).is_false()
			assert_bool(tarea.completar()).is_true()
			assert_bool(CierreAnticipado.corresponde(jornada, tareas)).is_true()
