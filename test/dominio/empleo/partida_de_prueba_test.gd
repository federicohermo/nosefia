## La partida de prueba que pide la URL: qué lee de la búsqueda y qué guardado arma, sin escena.
extends GdUnitTestSuite

var _caso: CasoDeInvestigacion


func before_test() -> void:
	_caso = CasoDeInvestigacion.de_la_partida()


func _identidades(cadena: Array[Hipotesis]) -> Array:
	var identidades: Array = []
	for hipotesis: Hipotesis in cadena:
		identidades.append(hipotesis.identidad)
	return identidades


func _todas_las_hipotesis() -> Array[Hipotesis]:
	var todas: Array[Hipotesis] = []
	for jornada: HipotesisDeLaJornada in _caso.hipotesis:
		todas.append_array(jornada.opciones)
		for aparte: Hipotesis in [jornada.predeterminada, jornada.con_antecedentes]:
			if aparte != null and not todas.has(aparte):
				todas.append(aparte)
	return todas


# --- La lectura de la búsqueda ---


func test_sin_parametros_no_hay_partida_de_prueba() -> void:
	for busqueda: String in ["", "?", "?otra=1", "?a=1&b=2"]:
		assert_object(PartidaDePrueba.desde_busqueda(busqueda)).is_null()


func test_la_jornada_se_lee_con_o_sin_el_signo_de_pregunta() -> void:
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA + 2
	for busqueda: String in ["?jornada=%d" % jornada, "jornada=%d" % jornada]:
		var prueba := PartidaDePrueba.desde_busqueda(busqueda)
		assert_object(prueba).is_not_null()
		assert_int(prueba.jornada).is_equal(jornada)


func test_lo_que_no_vino_queda_en_su_valor_ausente() -> void:
	var prueba := PartidaDePrueba.desde_busqueda("?jornada=%d" % ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_float(prueba.segundos_al_cierre).is_equal(-1.0)
	assert_bool(prueba.completas).is_false()
	assert_str(prueba.camino).is_empty()


func test_lee_los_cuatro_parametros() -> void:
	var prueba := PartidaDePrueba.desde_busqueda("?jornada=6&cierre=60&camino=6C&completas=1")
	assert_int(prueba.jornada).is_equal(6)
	assert_float(prueba.segundos_al_cierre).is_equal(60.0)
	assert_str(prueba.camino).is_equal("6C")
	assert_bool(prueba.completas).is_true()


func test_una_jornada_que_no_es_entera_ignora_todos_los_parametros() -> void:
	for jornada: String in ["abc", "6.5", "", "6x"]:
		var busqueda := "?jornada=%s&cierre=60&camino=6C&completas=1" % jornada
		assert_object(PartidaDePrueba.desde_busqueda(busqueda)).is_null()


func test_una_jornada_fuera_del_rango_ignora_todos_los_parametros() -> void:
	var ultima := ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
	for jornada: int in [ReglasDeLaPartida.PRIMERA_JORNADA - 1, ultima + 1]:
		var busqueda := "?jornada=%d&cierre=60&completas=1" % jornada
		assert_object(PartidaDePrueba.desde_busqueda(busqueda)).is_null()


func test_las_jornadas_de_los_dos_extremos_valen() -> void:
	var ultima := ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
	for jornada: int in [ReglasDeLaPartida.PRIMERA_JORNADA, ultima]:
		var prueba := PartidaDePrueba.desde_busqueda("?jornada=%d" % jornada)
		assert_object(prueba).is_not_null()
		assert_int(prueba.jornada).is_equal(jornada)


func test_un_cierre_que_no_es_un_numero_no_negativo_se_ignora() -> void:
	for cierre: String in ["abc", "-5", "", "1x"]:
		var prueba := PartidaDePrueba.desde_busqueda("?jornada=6&cierre=%s" % cierre)
		assert_float(prueba.segundos_al_cierre).is_equal(-1.0)


func test_cierre_cero_se_lee() -> void:
	var prueba := PartidaDePrueba.desde_busqueda("?jornada=6&cierre=0")
	assert_float(prueba.segundos_al_cierre).is_equal(0.0)


func test_completas_con_otro_valor_que_uno_o_cero_se_ignora() -> void:
	for completas: String in ["2", "si", "true", ""]:
		var prueba := PartidaDePrueba.desde_busqueda("?jornada=6&completas=%s" % completas)
		assert_bool(prueba.completas).is_false()
	assert_bool(PartidaDePrueba.desde_busqueda("?jornada=6&completas=0").completas).is_false()


func test_un_camino_sin_jornada_se_ignora() -> void:
	assert_object(PartidaDePrueba.desde_busqueda("?camino=6C")).is_null()


# --- La cadena de un camino ---


func test_la_cadena_de_un_camino_sale_de_las_pistas_que_cada_hipotesis_exige() -> void:
	assert_array(_identidades(PartidaDePrueba.cadena(_caso, "6C"))).is_equal(["2A", "5B", "6C"])
	assert_array(_identidades(PartidaDePrueba.cadena(_caso, "6B"))).is_equal(["2A", "5A", "6B"])


func test_una_hipotesis_sin_pistas_exigidas_es_su_propio_camino() -> void:
	for identidad: String in ["2P", "5P", "6P", "6L"]:
		assert_array(_identidades(PartidaDePrueba.cadena(_caso, identidad))).is_equal([identidad])


func test_una_identidad_que_no_es_del_caso_no_tiene_cadena() -> void:
	for identidad: String in ["", "9Z", "2a"]:
		assert_array(PartidaDePrueba.cadena(_caso, identidad)).is_empty()


func test_cada_hipotesis_con_pistas_encadena_con_la_que_abre_sus_pistas() -> void:
	var con_pistas := 0
	for hipotesis: Hipotesis in _todas_las_hipotesis():
		if hipotesis.exigencias.is_empty():
			continue
		con_pistas += 1
		var cadena := PartidaDePrueba.cadena(_caso, hipotesis.identidad)
		assert_object(cadena.back()).is_same(hipotesis)
		for lugar in range(1, cadena.size()):
			var anterior: Hipotesis = cadena[lugar - 1]
			var siguiente: Hipotesis = cadena[lugar]
			assert_int(anterior.jornada).is_equal(siguiente.jornada - 1)
			for exigida: String in siguiente.exigencias:
				assert_bool(anterior.camino.has(exigida)).is_true()
	assert_int(con_pistas).is_greater(0)


func test_una_hipotesis_con_pistas_solo_queda_sin_anterior_si_ninguna_la_abre() -> void:
	for hipotesis: Hipotesis in _todas_las_hipotesis():
		var cadena := PartidaDePrueba.cadena(_caso, hipotesis.identidad)
		var primera: Hipotesis = cadena.front()
		if primera.exigencias.is_empty():
			continue
		for jornada: HipotesisDeLaJornada in _caso.hipotesis:
			if jornada.jornada != primera.jornada - 1:
				continue
			for candidata: Hipotesis in jornada.opciones:
				for exigida: String in primera.exigencias:
					assert_bool(candidata.camino.has(exigida)).is_false()


func test_si_dos_hipotesis_abren_la_misma_pista_vale_la_primera_del_caso() -> void:
	var primera := _hipotesis("1A", 1, [], ["2A"])
	var segunda := _hipotesis("1B", 1, [], ["2A"])
	var final := _hipotesis("2A", 2, ["2A"], [])
	var caso := CasoDeInvestigacion.new()
	caso.hipotesis = [_jornada(1, [primera, segunda]), _jornada(2, [final])]
	assert_array(_identidades(PartidaDePrueba.cadena(caso, "2A"))).is_equal(["1A", "2A"])


func test_una_hipotesis_nueva_entra_como_camino_sin_tocar_el_codigo() -> void:
	var primera := _hipotesis("1A", 1, ["1A"], ["2A"])
	var final := _hipotesis("2A", 2, ["2A"], [])
	var caso := CasoDeInvestigacion.new()
	caso.hipotesis = [_jornada(1, [primera]), _jornada(2, [final])]
	assert_array(_identidades(PartidaDePrueba.cadena(caso, "2A"))).is_equal(["1A", "2A"])


func _hipotesis(identidad: String, jornada: int, exigencias: Array, camino: Array) -> Hipotesis:
	var hipotesis := Hipotesis.new()
	hipotesis.identidad = identidad
	hipotesis.jornada = jornada
	hipotesis.exigencias = PackedStringArray(exigencias)
	hipotesis.camino = PackedStringArray(camino)
	return hipotesis


func _jornada(numero: int, opciones: Array[Hipotesis]) -> HipotesisDeLaJornada:
	var jornada := HipotesisDeLaJornada.new()
	jornada.jornada = numero
	jornada.opciones = opciones
	return jornada
