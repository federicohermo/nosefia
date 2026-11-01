extends GdUnitTestSuite


func _pista(identidad: String, exigencias: PackedStringArray = PackedStringArray()) -> Pista:
	var pista := Pista.new()
	pista.identidad = identidad
	pista.jornada = 2
	pista.exigencias = exigencias
	return pista


func _caso(pistas: Array[Pista], desenlaces: Array[Desenlace] = []) -> CasoDeInvestigacion:
	var caso := CasoDeInvestigacion.new()
	caso.pistas = pistas
	caso.desenlaces = desenlaces
	return caso


func test_caso_valido_y_repetida_tienen_diagnosticos_distintos() -> void:  # AC-INV-046
	var a := _pista("A")
	var b := _pista("B", PackedStringArray(["A"]))
	assert_int(_caso([a, b]).consistencia()).is_equal(CasoDeInvestigacion.Consistencia.VALIDO)
	assert_int(_caso([a, a]).consistencia()).is_equal(CasoDeInvestigacion.Consistencia.ID_REPETIDA)


func test_exigencia_inexistente_y_ciclo_se_rechazan() -> void:  # AC-INV-046
	var a := _pista("A", PackedStringArray(["B"]))
	var b := _pista("B", PackedStringArray(["A"]))
	assert_int(_caso([a]).consistencia()).is_equal(CasoDeInvestigacion.Consistencia.EXIGENCIA_AJENA)
	assert_int(_caso([a, b]).consistencia()).is_equal(CasoDeInvestigacion.Consistencia.CICLO)
	a.exigencias = PackedStringArray(["A"])
	assert_int(_caso([a]).consistencia()).is_equal(CasoDeInvestigacion.Consistencia.CICLO)


func test_desenlace_inalcanzable_por_umbral_o_por_exigencia() -> void:  # AC-INV-046
	var final := Desenlace.new()
	final.identidad = "prueba"
	final.umbral = 3
	var caso := _caso([_pista("A"), _pista("B")], [final])
	assert_int(caso.consistencia()).is_equal(
		CasoDeInvestigacion.Consistencia.DESENLACE_INALCANZABLE
	)
	final.umbral = 2
	final.exigencias = PackedStringArray(["ajena"])
	assert_int(caso.consistencia()).is_equal(
		CasoDeInvestigacion.Consistencia.DESENLACE_INALCANZABLE
	)
	final.exigencias = PackedStringArray(["B"])
	assert_int(caso.consistencia()).is_equal(CasoDeInvestigacion.Consistencia.VALIDO)


func test_ciclo_largo_no_depende_del_orden_de_los_recursos() -> void:  # AC-INV-046
	var caso := _caso(
		[
			_pista("C", PackedStringArray(["A"])),
			_pista("A", PackedStringArray(["B"])),
			_pista("B", PackedStringArray(["C"])),
		]
	)
	assert_int(caso.consistencia()).is_equal(CasoDeInvestigacion.Consistencia.CICLO)


func _identidades(opciones: Array[Hipotesis]) -> Array[String]:
	var ids: Array[String] = []
	for opcion: Hipotesis in opciones:
		ids.append(opcion.identidad)
	return ids


func test_caso_real_entrega_las_cuatro_combinaciones_sin_mutar() -> void:  # AC-INV-050
	var caso := CasoDeInvestigacion.de_la_partida()
	assert_int(caso.consistencia()).is_equal(CasoDeInvestigacion.Consistencia.VALIDO)
	var combinaciones: Array[PackedStringArray] = [
		PackedStringArray(),
		PackedStringArray(["2A"]),
		PackedStringArray(["2B"]),
		PackedStringArray(["2B", "2A"]),
	]
	var esperadas: Array[Array] = [["2P"], ["2A"], ["2B"], ["2A", "2B"]]
	for indice: int in combinaciones.size():
		var expediente := Expediente.new(caso)
		expediente.reconstruir(combinaciones[indice])
		for _consulta: int in range(2):
			assert_array(_identidades(expediente.hipotesis_para(4))).is_equal(esperadas[indice])
		assert_array(Array(expediente.identidades())).is_equal(Array(combinaciones[indice]))
		assert_array(expediente.mensajes_de_notas()).is_empty()
		assert_array(expediente.hipotesis_para(1)).is_empty()
	assert_object(caso.pista_de("2P")).is_null()
	assert_object(caso.pista_de("2L")).is_null()
	assert_array(caso.desenlaces).is_empty()


func test_las_pistas_traen_su_foto_y_su_texto() -> void:  # AC-INV-053
	var caso := CasoDeInvestigacion.de_la_partida()
	var a := caso.pista_de("2A")
	var b := caso.pista_de("2B")
	assert_object(a).is_not_null()
	assert_object(b).is_not_null()
	if a == null or b == null:
		return
	assert_str(a.texto).is_equal(
		"Hoy Yasmín se quejó de que en el local “siempre falta algo o anda todo a medias”."
	)
	assert_str(b.texto).is_equal(
		(
			"Encontré una colilla de cigarrilo en el depósito. "
			+ "Pero, por lo que me dijeron, ni Enrique ni Yasmín fuman. Raro…"
		)
	)
	assert_object(a.foto).is_not_null()
	assert_object(b.foto).is_not_null()
	var titulos: Dictionary[String, String] = {
		"2A": "SIEMPRE FALTAN COSAS",
		"2B": "CIGARRILLO EN EL DEPÓSITO",
		"2P": "NO PASA NADA",
	}
	var textos: Dictionary[String, String] = {
		"2A":
		(
			"No me sorprendería tener un jefe inútil. Pero también, "
			+ "¿no es responsabilidad de Yasmín avisar si faltan cosas esenciales? "
			+ "Si esto va a ser frecuente, tengo que empezar a prestar más atención "
			+ "a las dinámicas internas del local."
		),
		"2B":
		(
			"¿Puede ser que alguien se esté metiendo sin que nos demos cuenta? "
			+ "Debería examinar bien las formas de ingreso al local…"
		),
		"2P":
		"Solo se acabó un jabón. No me tengo que hacer la cabeza con algo tan poco trascendental.",
	}
	var opciones := caso.hipotesis_para(4, PackedStringArray(["2A", "2B"]))
	opciones.append_array(caso.hipotesis_para(4, PackedStringArray()))
	assert_array(_identidades(opciones)).is_equal(["2A", "2B", "2P"])
	for opcion: Hipotesis in opciones:
		assert_str(opcion.titulo).is_equal(titulos[opcion.identidad])
		assert_str(opcion.texto).is_equal(textos[opcion.identidad])


func test_lo_que_se_levanta_para_una_pista_esta_solo_su_noche() -> void:  # AC-INV-049
	var levantar := _pista("L")
	levantar.canal = Pista.Canal.LEVANTAR
	levantar.origen = &"cosa"
	var mirar := _pista("M")
	mirar.canal = Pista.Canal.EXAMINAR_NO_LEVANTABLE
	mirar.origen = &"otra"
	var sin_origen := _pista("S")
	sin_origen.canal = Pista.Canal.LEVANTAR
	var caso := _caso([levantar, mirar, sin_origen])
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
	):
		assert_bool(caso.esta_en_el_local(&"cosa", jornada)).is_equal(jornada == levantar.jornada)
		assert_bool(caso.esta_en_el_local(&"otra", jornada)).is_true()
		assert_bool(caso.esta_en_el_local(&"ninguna", jornada)).is_true()
		assert_bool(caso.esta_en_el_local(&"", jornada)).is_true()


func test_la_colilla_del_caso_esta_la_noche_de_2b() -> void:  # AC-INV-049
	var caso := CasoDeInvestigacion.de_la_partida()
	var pista := caso.pista_de("2B")
	assert_object(pista).is_not_null()
	if pista == null:
		return
	assert_int(pista.canal).is_equal(Pista.Canal.LEVANTAR)
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
	):
		assert_bool(caso.esta_en_el_local(pista.origen, jornada)).is_equal(jornada == pista.jornada)
