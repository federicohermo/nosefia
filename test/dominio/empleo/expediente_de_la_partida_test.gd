extends GdUnitTestSuite


func test_misma_partida_conserva_el_expediente_entre_aperturas() -> void:  # AC-EMP-069
	var partida := Partida.desde({"jornada": 3})
	var expediente := partida.expediente
	assert_object(expediente).is_not_null()
	if expediente == null:
		return
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias():
		tarea.completar()
	partida.cerrar_la_jornada(partida.obligatorias().size())
	partida.abrir_la_jornada()
	assert_object(partida.expediente).is_same(expediente)
	assert_int(expediente.registrar_por_canal(&"colilla", Pista.Canal.LEVANTAR, 4)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	assert_int(expediente.registrar_por_canal(&"2A", Pista.Canal.CHAT, 4)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	for tarea: Tarea in partida.obligatorias():
		tarea.completar()
	partida.cerrar_la_jornada(partida.obligatorias().size())
	partida.abrir_la_jornada()
	assert_object(partida.expediente).is_same(expediente)
	assert_array(Array(partida.expediente.identidades())).is_equal(["2B", "2A"])
	var notas := partida.expediente.mensajes_de_notas()
	assert_int(notas.size()).is_equal(4)
	if notas.size() != 4:
		return
	assert_object(notas[0].foto).is_not_null()
	assert_str(notas[1].texto).is_equal(CasoDeInvestigacion.de_la_partida().pista_de("2B").texto)
	assert_object(notas[2].foto).is_not_null()
	assert_str(notas[3].texto).is_equal(CasoDeInvestigacion.de_la_partida().pista_de("2A").texto)
	var primero: Investigador = auto_free(Investigador.new())
	var segundo: Investigador = auto_free(Investigador.new())
	primero.usar(partida.expediente)
	segundo.usar(partida.expediente)
	assert_object(primero.get("_expediente")).is_same(expediente)
	assert_object(segundo.get("_expediente")).is_same(expediente)
	assert_array(Array(expediente.identidades())).is_equal(["2B", "2A"])
	assert_int(expediente.mensajes_de_notas().size()).is_equal(4)


func test_otra_partida_empieza_con_otro_expediente_limpio() -> void:  # AC-EMP-069
	var partida := Partida.nueva()
	var otra := Partida.nueva()
	assert_object(partida.expediente).is_not_same(otra.expediente)
	partida.expediente.registrar("2A")
	assert_array(Array(partida.expediente.identidades())).is_equal(["2A"])
	assert_array(Array(otra.expediente.identidades())).is_empty()
	assert_array(otra.expediente.mensajes_de_notas()).is_empty()
	var restaurada := Partida.desde({})
	assert_object(restaurada.expediente).is_not_same(partida.expediente)
	assert_array(Array(restaurada.expediente.identidades())).is_empty()


func test_rechazar_sustitucion_conserva_la_instancia_poseida() -> void:  # AC-EMP-069
	var partida := Partida.nueva()
	var poseido := partida.expediente
	var ajeno := Expediente.new(CasoDeInvestigacion.new())
	await (
		assert_error(func() -> void: partida.expediente = ajeno)
		. is_push_error("El expediente pertenece a la partida y no se sustituye")
	)
	assert_object(partida.expediente).is_same(poseido)
	assert_object(partida.expediente).is_not_same(ajeno)


func test_consumidores_reciben_la_misma_identidad_sin_crear_duenos() -> void:  # AC-EMP-069
	var partida := Partida.nueva()
	var a: Investigador = auto_free(Investigador.new())
	var b: Investigador = auto_free(Investigador.new())
	a.usar(partida.expediente)
	b.usar(partida.expediente)
	assert_object(a.get("_expediente")).is_same(partida.expediente)
	assert_object(b.get("_expediente")).is_same(partida.expediente)
	assert_int(a.pedir_pista(&"2A", Pista.Canal.CHAT, 4, true)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	assert_int(b.pedir_pista(&"2A", Pista.Canal.CHAT, 4, true)).is_equal(
		Expediente.Resultado.REPETIDA
	)
	assert_array(Array(partida.expediente.identidades())).is_equal(["2A"])
