extends GdUnitTestSuite


func test_el_aviso_no_vence_y_el_cierre_permite_otro() -> void:  # AC-NTF-026, AC-NTF-044
	var estado := Notificaciones.new()
	estado.pista_anotada()
	estado.actualizar_salida(true)
	assert_array(estado.visibles()).is_equal(
		[Notificaciones.Tipo.TAREAS_TERMINADAS, Notificaciones.Tipo.PISTA]
	)
	estado.avanzar(Notificaciones.DURACION - 0.1)
	estado.actualizar_salida(true)
	assert_array(estado.visibles()).has_size(2)
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])
	estado.avanzar(Notificaciones.DURACION * 10.0)
	estado.actualizar_salida(true)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])
	estado.vaciar()
	assert_array(estado.visibles()).is_empty()
	estado.actualizar_salida(true)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])


func test_cambiar_la_salida_conserva_el_orden_y_resto_de_otros_avisos() -> void:  # AC-NTF-045
	var estado := Notificaciones.new()
	estado.pista_anotada()
	estado.lectura_rechazada(GeneradorDeTickets.Resultado.LLENO)
	estado.avanzar(Notificaciones.DURACION - 1.0)
	estado.actualizar_salida(true)
	estado.actualizar_salida(false)
	assert_array(estado.visibles()).is_equal(
		[Notificaciones.Tipo.LECTURA_FALLIDA, Notificaciones.Tipo.PISTA]
	)
	estado.actualizar_salida(true)
	(
		assert_array(estado.visibles())
		. is_equal(
			[
				Notificaciones.Tipo.TAREAS_TERMINADAS,
				Notificaciones.Tipo.LECTURA_FALLIDA,
				Notificaciones.Tipo.PISTA,
			]
		)
	)
	estado.actualizar_salida(false)
	estado.avanzar(0.9)
	assert_array(estado.visibles()).has_size(2)
	estado.avanzar(0.1)
	assert_array(estado.visibles()).is_empty()
	estado.vaciar()
	assert_array(estado.visibles()).is_empty()


func test_perder_el_permiso_retira_y_recuperarlo_vuelve_a_avisar() -> void:  # AC-NTF-045
	var estado := Notificaciones.new()
	estado.actualizar_salida(false)
	assert_array(estado.visibles()).is_empty()
	estado.actualizar_salida(true)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])
	for _ciclo in 2:
		estado.actualizar_salida(false)
		assert_array(estado.visibles()).is_empty()
		estado.actualizar_salida(true)
		assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])
		estado.actualizar_salida(true)
		estado.avanzar(Notificaciones.DURACION * 3.0)
		assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])


# AC-NTF-045
func test_recuperar_vuelve_a_avisar_y_vaciar_reinicia_los_avisos() -> void:
	var estado := Notificaciones.new()
	estado.pista_anotada()
	estado.actualizar_salida(true)
	estado.actualizar_salida(false)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.PISTA])
	estado.actualizar_salida(true)
	assert_array(estado.visibles()).is_equal(
		[Notificaciones.Tipo.TAREAS_TERMINADAS, Notificaciones.Tipo.PISTA]
	)
	estado.actualizar_salida(false)
	estado.vaciar()
	assert_array(estado.visibles()).is_empty()
	estado.actualizar_salida(false)
	assert_array(estado.visibles()).is_empty()
	estado.actualizar_salida(true)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])


func test_la_computadora_demora_el_aviso_hasta_salir() -> void:  # AC-NTF-032
	var estado := Notificaciones.new()
	estado.pista_anotada()
	estado.actualizar_computadora(true)
	estado.actualizar_salida(true)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.PISTA])
	estado.avanzar(1.0)
	estado.actualizar_computadora(false)
	assert_array(estado.visibles()).is_equal(
		[Notificaciones.Tipo.TAREAS_TERMINADAS, Notificaciones.Tipo.PISTA]
	)
	estado.avanzar(Notificaciones.DURACION - 1.0)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])
	estado.avanzar(Notificaciones.DURACION * 10.0)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])
	estado.actualizar_computadora(true)
	estado.actualizar_salida(false)
	assert_array(estado.visibles()).is_empty()
	estado.actualizar_computadora(false)
	assert_array(estado.visibles()).is_empty()
	estado.actualizar_computadora(true)
	estado.actualizar_salida(true)
	assert_array(estado.visibles()).is_empty()
	estado.actualizar_computadora(false)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])


func test_salir_en_el_mismo_permiso_no_avisa() -> void:  # AC-NTF-032
	var estado := Notificaciones.new()
	estado.actualizar_computadora(true)
	estado.actualizar_salida(true)
	estado.actualizar_salida(false)
	estado.actualizar_computadora(false)
	assert_array(estado.visibles()).is_empty()
	estado.actualizar_salida(true)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])
	estado.avanzar(Notificaciones.DURACION)
	estado.actualizar_computadora(true)
	estado.actualizar_salida(true)
	estado.actualizar_computadora(false)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])
	estado.actualizar_salida(false)
	assert_array(estado.visibles()).is_empty()


func test_el_cierre_descarta_el_aviso_pendiente() -> void:  # AC-NTF-032
	for permiso: bool in [true, false]:
		var estado := Notificaciones.new()
		estado.actualizar_salida(not permiso)
		estado.avanzar(Notificaciones.DURACION)
		estado.actualizar_computadora(true)
		estado.actualizar_salida(permiso)
		estado.vaciar()
		estado.actualizar_computadora(false)
		assert_array(estado.visibles()).is_empty()
		estado.actualizar_salida(true)
		assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])


func test_rehacer_con_la_computadora_abierta_avisa_al_salir() -> void:  # AC-NTF-045
	var estado := Notificaciones.new()
	estado.actualizar_salida(true)
	estado.actualizar_computadora(true)
	estado.actualizar_salida(false)
	assert_array(estado.visibles()).is_empty()
	estado.actualizar_salida(true)
	assert_array(estado.visibles()).is_empty()
	estado.actualizar_computadora(false)
	assert_array(estado.visibles()).is_equal([Notificaciones.Tipo.TAREAS_TERMINADAS])
