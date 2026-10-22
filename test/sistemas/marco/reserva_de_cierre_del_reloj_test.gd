extends GdUnitTestSuite


func test_reservar_conserva_turno_y_tareas_hasta_el_cierre_una_vez() -> void:  # AC-SHF-046
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var hecha := Tarea.new(Tarea.Tipo.CAJA)
	var pendiente := Tarea.new(Tarea.Tipo.LIMPIAR)
	var turno := Turno.new(100.0, [hecha, pendiente])
	reloj.arrancar(turno, [hecha, pendiente])
	reloj.completar(hecha)
	var cierres: Array[int] = []
	reloj.turno_cerrado.connect(cierres.append)
	assert_bool(reloj.reservar_cierre()).is_true()
	assert_bool(reloj.reservar_cierre()).is_false()
	reloj.terminar()
	reloj.avanzar(1000.0)
	assert_bool(reloj.descumplir(hecha)).is_false()
	assert_bool(reloj.completar(pendiente)).is_false()
	assert_float(turno.tiempo_restante()).is_equal(100.0)
	assert_array(cierres).is_empty()
	reloj.cierre_iniciado.connect(func() -> void: reloj.completar(pendiente))
	reloj.terminar_cierre_reservado()
	reloj.terminar_cierre_reservado()
	assert_array(cierres).is_equal([1])
	assert_float(turno.tiempo_restante()).is_zero()


func test_arrancar_descarta_la_reserva_anterior_sin_cambiar_retener() -> void:
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	assert_bool(reloj.reservar_cierre()).is_false()
	reloj.terminar_cierre_reservado()
	reloj.arrancar(Turno.new(100.0, []), [])
	reloj.reservar_cierre()
	var nuevo := Turno.new(200.0, [])
	reloj.arrancar(nuevo, [])
	reloj.retener()
	reloj.avanzar(1.0)
	assert_float(nuevo.tiempo_restante()).is_equal(200.0 - Ritmo.escalar(1.0))
	reloj.terminar()
	assert_bool(nuevo.cerrado()).is_true()
