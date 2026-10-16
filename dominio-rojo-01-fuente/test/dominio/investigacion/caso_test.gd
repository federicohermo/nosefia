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
