extends GdUnitTestSuite


func test_el_aviso_no_se_renueva_y_el_cierre_permite_otro() -> void:  # AC-NTF-026
	var estado := Notificaciones.new()
	estado.pista_anotada()
	estado.tareas_terminadas()
	assert_array(estado.visibles()).is_equal(
		[Notificaciones.Tipo.TAREAS_TERMINADAS, Notificaciones.Tipo.PISTA]
	)
	estado.avanzar(2.9)
	estado.tareas_terminadas()
	assert_array(estado.visibles()).has_size(2)
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_empty()
	estado.tareas_terminadas()
	assert_array(estado.visibles()).is_empty()
	estado.vaciar()
	estado.tareas_terminadas()
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])
	estado.vaciar()
	assert_array(estado.visibles()).is_empty()
