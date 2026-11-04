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


func test_el_reloj_lee_la_hora_del_juego_desde_las_20() -> void:  # AC-INV-085
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	assert_str(reloj.hora()).is_empty()
	var turno := Turno.new(Reglas.DURACION_DEL_TURNO, [])
	reloj.arrancar(turno, [])
	assert_str(reloj.hora()).is_equal("20:00")
	turno.consumir(3630.0)
	assert_str(reloj.hora()).is_equal("21:00")


func test_irse_antes_fija_la_hora_del_cierre_en_la_del_reloj() -> void:  # AC-INV-085
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var turno := Turno.new(Reglas.DURACION_DEL_TURNO, [])
	reloj.arrancar(turno, [])
	assert_str(reloj.hora_al_cierre()).is_empty()
	turno.consumir(3630.0)
	reloj.terminar()
	assert_str(reloj.hora_al_cierre()).is_equal("21:00")


func test_irse_antes_con_el_cierre_reservado_fija_la_hora_del_cierre() -> void:  # AC-INV-085
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	var turno := Turno.new(Reglas.DURACION_DEL_TURNO, [])
	reloj.arrancar(turno, [])
	turno.consumir(7230.0)
	reloj.reservar_cierre()
	reloj.terminar_cierre_reservado()
	assert_str(reloj.hora_al_cierre()).is_equal("22:00")


func test_cumplir_el_turno_entero_cierra_a_las_8() -> void:  # AC-INV-085
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(Turno.new(Reglas.DURACION_DEL_TURNO, []), [])
	reloj.avanzar(1000000.0)
	assert_str(reloj.hora_al_cierre()).is_equal("08:00")
	reloj.arrancar(Turno.new(Reglas.DURACION_DEL_TURNO, []), [])
	assert_str(reloj.hora_al_cierre()).is_empty()
