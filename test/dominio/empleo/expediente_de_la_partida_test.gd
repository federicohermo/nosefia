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


func _partida_de_la_5(semilla: int) -> Partida:
	var partida := Partida.desde({"jornada": 5, "semilla": semilla})
	partida.abrir_la_jornada()
	return partida


func _semilla_que_sortea_en_la_5(identidad: String) -> int:
	for semilla: int in range(1, 65):
		if _partida_de_la_5(semilla).expediente.sorteos().get(5, "") == identidad:
			return semilla
	return 0


func test_sin_pistas_en_la_4_la_5_abre_con_un_solo_camino_sorteado() -> void:  # AC-INV-081
	var caso := CasoDeInvestigacion.de_la_partida()
	var salidos: Array[String] = []
	for semilla: int in range(1, 33):
		var expediente := _partida_de_la_5(semilla).expediente
		var sorteada: String = expediente.sorteos().get(5, "")
		var opcion := caso.opcion(4, sorteada)
		assert_object(opcion).is_not_null()
		if opcion == null:
			return
		for pista: String in expediente.pistas_activas(5):
			assert_bool(opcion.camino.has(pista)).is_true()
		if not salidos.has(sorteada):
			salidos.append(sorteada)
	assert_array(salidos).contains_exactly_in_any_order(["2A", "2B"])


func test_la_misma_semilla_sortea_el_mismo_camino() -> void:  # AC-INV-076
	for semilla: int in range(1, 9):
		var una := _partida_de_la_5(semilla).expediente
		var otra := _partida_de_la_5(semilla).expediente
		assert_dict(una.sorteos()).is_equal(otra.sorteos())


func test_abrir_otra_vez_la_misma_jornada_no_cambia_el_sorteo() -> void:  # AC-INV-077
	var partida := _partida_de_la_5(1)
	var sorteados := partida.expediente.sorteos()
	partida.abrir_la_jornada()
	assert_dict(partida.expediente.sorteos()).is_equal(sorteados)


func test_un_sorteo_guardado_manda_sobre_la_semilla() -> void:  # AC-SAV-036
	var semilla_a := _semilla_que_sortea_en_la_5("2A")
	var semilla_b := _semilla_que_sortea_en_la_5("2B")
	assert_int(semilla_a).is_greater(0)
	assert_int(semilla_b).is_greater(0)
	var retomada := Partida.desde({"jornada": 5, "semilla": semilla_b, "sorteos": {5: "2A"}})
	retomada.abrir_la_jornada()
	assert_dict(retomada.expediente.sorteos()).is_equal({5: "2A"})


func test_con_una_pista_en_la_4_no_se_sortea() -> void:  # AC-INV-081
	for semilla: int in range(1, 9):
		var partida := Partida.desde({"jornada": 5, "semilla": semilla})
		assert_int(partida.expediente.registrar("2A")).is_equal(Expediente.Resultado.ANOTADA)
		partida.abrir_la_jornada()
		assert_dict(partida.expediente.sorteos()).is_empty()


func test_las_jornadas_sin_hipotesis_que_sortean_no_sortean() -> void:  # AC-INV-081
	var partida := Partida.nueva()
	for _noche: int in range(3):
		partida.abrir_la_jornada()
		assert_dict(partida.expediente.sorteos()).is_empty()
		partida.cerrar_la_jornada(partida.obligatorias().size())


func _sorteo_de_la_6(semilla: int) -> String:
	var partida := Partida.desde({"jornada": 5, "semilla": semilla})
	partida.expediente.registrar("2A")
	assert_int(partida.expediente.elegir(4, "2A")).is_equal(Expediente.Resultado.ANOTADA)
	partida.abrir_la_jornada()
	assert_dict(partida.expediente.sorteos()).is_empty()
	partida.cerrar_la_jornada(partida.obligatorias().size())
	partida.abrir_la_jornada()
	assert_int(partida.jornada()).is_equal(6)
	return partida.expediente.sorteos().get(6, "")


func test_sin_pistas_en_la_5_la_6_sortea_el_camino_de_la_rama() -> void:  # AC-INV-076
	var salidos: Array[String] = []
	for semilla: int in range(1, 33):
		var sorteada := _sorteo_de_la_6(semilla)
		assert_str(_sorteo_de_la_6(semilla)).is_equal(sorteada)
		if not salidos.has(sorteada):
			salidos.append(sorteada)
	assert_array(salidos).contains_exactly_in_any_order(["5A", "5B"])


func test_dos_jornadas_seguidas_sin_pistas_no_sortean_la_segunda() -> void:  # AC-INV-077
	var partida := _partida_de_la_5(_semilla_que_sortea_en_la_5("2A"))
	var sorteados := partida.expediente.sorteos()
	assert_array(Array(partida.expediente.pistas_activas(5))).is_not_empty()
	partida.cerrar_la_jornada(partida.obligatorias().size())
	partida.abrir_la_jornada()
	assert_int(partida.jornada()).is_equal(6)
	assert_dict(partida.expediente.sorteos()).is_equal(sorteados)
