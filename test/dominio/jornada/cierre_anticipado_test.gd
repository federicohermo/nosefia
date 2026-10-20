extends GdUnitTestSuite


func _cumplidas_salvo(jornada: int, pendientes: Array[Tarea.Tipo]) -> Array[Tarea]:
	var obligatorias := Apertura.obligatorias(jornada)
	for tarea in obligatorias:
		if tarea.tipo() not in pendientes:
			tarea.completar()
	return obligatorias


func test_cerradas_las_compras_con_lo_demas_cumplido_corresponde() -> void:  # AC-SHF-031
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var sin_cobrar := _cumplidas_salvo(jornada, [Tarea.Tipo.CAJA])
	assert_bool(CierreAnticipado.corresponde(jornada, false, false, sin_cobrar)).is_false()
	assert_bool(CierreAnticipado.corresponde(jornada, true, false, sin_cobrar)).is_true()
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, true, false, _cumplidas_salvo(jornada, []))
		)
		. is_true()
	)


func test_el_que_espera_o_no_llego_no_deja_acelerar() -> void:  # AC-SHF-032
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var compradores := Compradores.de_la_jornada(jornada)
	assert_array(compradores).is_not_empty()
	var tarea := TareaDeAtender.new(compradores, Apertura.inventario_con_faltantes({}, {}))
	var cumplidas := _cumplidas_salvo(jornada, [Tarea.Tipo.CAJA])
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, tarea.compras_cerradas(), false, cumplidas)
		)
		. is_false()
	)
	tarea.avanzar(compradores[-1].horario.x)
	assert_object(tarea.en_ventanilla()).is_same(compradores[-1])
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, tarea.compras_cerradas(), false, cumplidas)
		)
		. is_false()
	)
	tarea.avanzar(compradores[-1].horario.y)
	assert_bool(tarea.compras_cerradas()).is_true()
	assert_bool(tarea.completada()).is_false()
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, tarea.compras_cerradas(), false, cumplidas)
		)
		. is_true()
	)


func test_una_obligatoria_pendiente_que_no_es_cobrar_no_deja_acelerar() -> void:  # AC-SHF-032
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var probadas := 0
	for tarea in Apertura.obligatorias(jornada):
		if tarea.tipo() == Tarea.Tipo.CAJA:
			continue
		var pendientes: Array[Tarea.Tipo] = [tarea.tipo()]
		var obligatorias := _cumplidas_salvo(jornada, pendientes)
		(
			assert_bool(CierreAnticipado.corresponde(jornada, true, false, obligatorias))
			. override_failure_message(str(tarea.tipo()))
			. is_false()
		)
		probadas += 1
	assert_int(probadas).is_greater(0)


func test_sin_compradores_las_compras_estan_cerradas() -> void:  # AC-SHF-032
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var nadie := TareaDeAtender.new([], Inventario.new([]))
	var cumplidas := _cumplidas_salvo(jornada, [Tarea.Tipo.CAJA])
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, nadie.compras_cerradas(), false, cumplidas)
		)
		. is_true()
	)


func test_solo_la_primera_noche_acelera() -> void:  # AC-SHF-035
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
	):
		var todas := _cumplidas_salvo(jornada, [])
		(
			assert_bool(CierreAnticipado.corresponde(jornada, true, false, todas))
			. override_failure_message("jornada %d" % jornada)
			. is_equal(jornada == ReglasDeLaPartida.PRIMERA_JORNADA)
		)


func test_sin_ventas_el_registro_que_coincide_deja_acelerar() -> void:  # AC-SHF-032
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var compradores := Compradores.de_la_jornada(jornada)
	var tarea := TareaDeAtender.new(compradores, Apertura.inventario_con_faltantes({}, {}))
	tarea.avanzar(compradores[-1].horario.y)
	assert_bool(tarea.compras_cerradas()).is_true()
	var registro := RegistroDeVentas.new(Catalogo.todos(), tarea)
	assert_bool(registro.completada()).is_false()
	var obligatorias := _cumplidas_salvo(jornada, [Tarea.Tipo.CAJA, Tarea.Tipo.REGISTRAR])
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, true, registro.completada(true), obligatorias)
		)
		. is_true()
	)
	registro.sumar(Catalogo.todos()[0])
	(
		assert_bool(
			CierreAnticipado.corresponde(jornada, true, registro.completada(true), obligatorias)
		)
		. is_false()
	)
	var sin_reponer := _cumplidas_salvo(jornada, [Tarea.Tipo.CAJA, Tarea.Tipo.REPONER])
	assert_bool(CierreAnticipado.corresponde(jornada, true, true, sin_reponer)).is_false()
