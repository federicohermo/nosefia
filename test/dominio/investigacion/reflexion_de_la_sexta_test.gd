extends GdUnitTestSuite

const E := ReflexionDeCierre.Etapa


func _expediente() -> Expediente:
	return Expediente.new(CasoDeInvestigacion.de_la_partida())


func _empezada(jornada: int, expediente: Expediente) -> ReflexionDeCierre:
	var reflexion := ReflexionDeCierre.para(jornada, expediente)
	reflexion.empezar()
	return reflexion


func _con_la_cuarta_elegida(elegida: String) -> Expediente:
	var expediente := _expediente()
	expediente.registrar(elegida)
	expediente.elegir(4, elegida)
	return expediente


func _identidades(opciones: Array[Hipotesis]) -> Array[String]:
	var identidades: Array[String] = []
	for opcion: Hipotesis in opciones:
		identidades.append(opcion.identidad)
	return identidades


func _con_la_quinta_elegida(elegida: String) -> Expediente:
	var expediente := _con_la_cuarta_elegida("2A")
	if elegida == "5B":
		expediente.registrar("5B")
	expediente.elegir(5, elegida)
	return expediente


func _con_la_nota(expediente: Expediente) -> Expediente:
	assert_int(expediente.registrar("6C")).is_equal(Expediente.Resultado.ANOTADA)
	return expediente


func test_con_la_6c_la_sexta_ofrece_solo_la_6c() -> void:  # AC-INV-150
	var expediente := _con_la_nota(_con_la_quinta_elegida("5B"))
	var reflexion := _empezada(6, expediente)
	assert_str(reflexion.encabezado()).is_equal(ReflexionDeCierre.ENCABEZADOS[6])
	assert_int(reflexion.etapa()).is_equal(E.ELEGIR)
	assert_array(_identidades(reflexion.opciones())).is_equal(["6C"])
	assert_bool(reflexion.siguiente()).is_false()
	assert_bool(reflexion.anterior()).is_false()
	for ajena: String in ["6P", "6L"]:
		assert_int(reflexion.elegir(ajena)).is_equal(ReflexionDeCierre.Eleccion.NO_DISPONIBLE)
	assert_str(expediente.eleccion(6)).is_empty()
	var sin_la_6c := _empezada(6, _con_la_quinta_elegida("5B"))
	assert_int(sin_la_6c.elegir("6C")).is_equal(ReflexionDeCierre.Eleccion.NO_DISPONIBLE)


func test_la_sexta_tiene_su_encabezado_propio() -> void:  # AC-INV-150, AC-INV-153
	var encabezado := _empezada(6, _expediente()).encabezado()
	assert_str(encabezado).is_not_empty()
	for otra: int in [3, 4, 5]:
		assert_str(encabezado).is_not_equal(ReflexionDeCierre.ENCABEZADOS[otra])


func test_sin_la_6c_la_sexta_ofrece_la_6p_o_la_6l() -> void:  # AC-INV-151
	var sin_antecedentes := _empezada(6, _expediente())
	assert_array(_identidades(sin_antecedentes.opciones())).is_equal(["6P"])
	assert_bool(sin_antecedentes.siguiente()).is_false()
	assert_int(sin_antecedentes.elegir("6L")).is_equal(ReflexionDeCierre.Eleccion.NO_DISPONIBLE)
	var con_la_5b := _con_la_quinta_elegida("5B")
	var con_antecedentes := _empezada(6, con_la_5b)
	assert_array(_identidades(con_antecedentes.opciones())).is_equal(["6L"])
	assert_bool(con_antecedentes.siguiente()).is_false()
	assert_int(con_antecedentes.elegir("6P")).is_equal(ReflexionDeCierre.Eleccion.NO_DISPONIBLE)
	assert_str(con_la_5b.eleccion(6)).is_empty()
	var con_la_5p := _empezada(6, _con_la_quinta_elegida("5P"))
	assert_array(_identidades(con_la_5p.opciones())).is_equal(["6L"])
	var con_la_6b := _con_la_cuarta_elegida("2A")
	con_la_6b.registrar("5A")
	con_la_6b.elegir(5, "5A")
	con_la_6b.registrar("6B")
	var reflexion_de_la_6b := _empezada(6, con_la_6b)
	assert_array(_identidades(reflexion_de_la_6b.opciones())).is_equal(["6B"])
	for ajena: String in ["6P", "6L"]:
		assert_int(reflexion_de_la_6b.elegir(ajena)).is_equal(
			ReflexionDeCierre.Eleccion.NO_DISPONIBLE
		)


func test_la_6p_y_la_6l_son_hipotesis_sin_pista_ni_camino() -> void:  # AC-INV-151
	var caso := CasoDeInvestigacion.de_la_partida()
	var vacia := _empezada(6, _expediente()).mostrada()
	var con_antecedentes := _empezada(6, _con_la_quinta_elegida("5P")).mostrada()
	for hipotesis: Hipotesis in [vacia, con_antecedentes]:
		assert_str(hipotesis.titulo).is_not_empty()
		assert_str(hipotesis.texto).is_not_empty()
		assert_array(Array(hipotesis.exigencias)).is_empty()
		assert_array(Array(hipotesis.camino)).is_empty()
		assert_object(caso.pista_de(hipotesis.identidad)).is_null()
	assert_str(vacia.titulo).is_not_equal(con_antecedentes.titulo)
	assert_str(vacia.texto).is_not_equal(con_antecedentes.texto)


func test_elegir_en_la_sexta_anota_una_vez_y_la_espera_retiene_la_septima() -> void:  # AC-INV-152
	for expediente: Expediente in [
		_expediente(), _con_la_quinta_elegida("5B"), _con_la_nota(_con_la_quinta_elegida("5B"))
	]:
		var reflexion := _empezada(6, expediente)
		var elegida := reflexion.mostrada()
		var notas := expediente.mensajes_de_notas().size()
		assert_bool(reflexion.avanzar(600.0)).is_false()
		assert_int(reflexion.etapa()).is_equal(E.ELEGIR)
		assert_int(reflexion.elegir(elegida.identidad)).is_equal(
			ReflexionDeCierre.Eleccion.ACEPTADA
		)
		assert_str(expediente.eleccion(6)).is_equal(elegida.identidad)
		assert_int(expediente.mensajes_de_notas().size()).is_equal(notas + 1)
		assert_str(expediente.mensajes_de_notas().back().texto).is_equal(elegida.texto)
		assert_int(reflexion.elegir(elegida.identidad)).is_equal(
			ReflexionDeCierre.Eleccion.REPETIDA
		)
		assert_int(expediente.mensajes_de_notas().size()).is_equal(notas + 1)
		var cuadro := 1.0 / 60.0
		(
			assert_bool(reflexion.avanzar(ReflexionDeCierre.ESPERA_ANTES_DE_LA_NOCHE - cuadro))
			. is_false()
		)
		assert_bool(reflexion.avanzar(cuadro)).is_true()
		assert_int(reflexion.etapa()).is_equal(E.TERMINADA)
		assert_bool(reflexion.avanzar(10.0)).is_false()


func test_la_sexta_retomada_sin_elegir_vuelve_a_la_eleccion() -> void:  # AC-INV-152
	var expediente := _con_la_nota(_con_la_quinta_elegida("5B"))
	assert_bool(_empezada(6, expediente).pendiente()).is_true()
	var retomada := _empezada(6, expediente)
	assert_int(retomada.etapa()).is_equal(E.ELEGIR)
	retomada.elegir("6C")
	assert_object(ReflexionDeCierre.para(6, expediente)).is_null()


func test_las_reflexiones_de_la_tercera_a_la_quinta_no_cambian_con_la_sexta() -> void:  # AC-INV-153
	assert_str(_empezada(3, _expediente()).encabezado()).is_equal(ReflexionDeCierre.ENCABEZADOS[3])
	assert_str(_empezada(4, _expediente()).encabezado()).is_equal(ReflexionDeCierre.ENCABEZADOS[4])
	assert_array(_identidades(_empezada(4, _expediente()).opciones())).is_equal(["2P"])
	assert_array(_identidades(_empezada(5, _expediente()).opciones())).is_equal(["5P"])
	assert_object(ReflexionDeCierre.para(7, _expediente())).is_null()
