extends GdUnitTestSuite

const JORNADA_5 := GeneradorDeTickets.JORNADA_SIN_LECTOR
const JORNADA_6 := JORNADA_5 + 1
const CUARTA := JORNADA_5 - 1
const E := ReflexionDeCierre.Etapa


func _caso() -> CasoDeInvestigacion:
	return CasoDeInvestigacion.de_la_partida()


func _por_la_5a() -> Dictionary:
	return {CUARTA: "2A", JORNADA_5: "5A"}


func _el_documento_esta(jornada: int, elecciones: Dictionary, sorteos: Dictionary = {}) -> bool:
	var origen := _caso().pista_de("6B").origen
	return _caso().esta_en_el_local(origen, jornada, elecciones, sorteos)


func _la_nota_esta(jornada: int, elecciones: Dictionary) -> bool:
	return _caso().esta_en_el_local(_caso().pista_de("6C").origen, jornada, elecciones, {})


func _identidades(opciones: Array[Hipotesis]) -> Array[String]:
	var identidades: Array[String] = []
	for opcion: Hipotesis in opciones:
		identidades.append(opcion.identidad)
	return identidades


## La partida que llegó a la sexta por la 5A: la 4 y la 5 elegidas, con sus pistas.
func _por_el_camino_de_la_5a() -> Expediente:
	var expediente := Expediente.new(_caso())
	expediente.registrar("2A")
	expediente.elegir(CUARTA, "2A")
	expediente.registrar("5A")
	expediente.elegir(JORNADA_5, "5A")
	return expediente


func _empezada(expediente: Expediente) -> ReflexionDeCierre:
	var reflexion := ReflexionDeCierre.para(JORNADA_6, expediente)
	reflexion.empezar()
	return reflexion


func test_el_documento_esta_solo_en_la_jornada_6_y_con_6b_activa() -> void:  # AC-INV-170
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
	):
		assert_bool(_el_documento_esta(jornada, _por_la_5a())).is_equal(jornada == JORNADA_6)
	assert_bool(_el_documento_esta(JORNADA_6, {CUARTA: "2A"}, {JORNADA_6: "5A"})).is_true()


func test_sin_la_5a_el_documento_no_esta() -> void:  # AC-INV-170
	var sin_documento: Array[Array] = [
		[{CUARTA: "2A", JORNADA_5: "5B"}, {}],
		[{CUARTA: "2B"}, {}],
		[{CUARTA: "2A", JORNADA_5: "5P"}, {}],
		[{CUARTA: "2A"}, {}],
		[{}, {}],
		[{CUARTA: "2P"}, {}],
		[{CUARTA: "2A"}, {JORNADA_6: "5B"}],
	]
	for caso: Array in sin_documento:
		(
			assert_bool(_el_documento_esta(JORNADA_6, caso[0], caso[1]))
			. override_failure_message("elecciones %s, sorteos %s" % [caso[0], caso[1]])
			. is_false()
		)


func test_el_documento_y_la_nota_son_de_caminos_distintos() -> void:  # AC-INV-170
	assert_bool(_la_nota_esta(JORNADA_6, {CUARTA: "2A", JORNADA_5: "5B"})).is_true()
	assert_bool(_el_documento_esta(JORNADA_6, {CUARTA: "2A", JORNADA_5: "5B"})).is_false()
	assert_bool(_la_nota_esta(JORNADA_6, _por_la_5a())).is_false()
	assert_bool(_el_documento_esta(JORNADA_6, _por_la_5a())).is_true()
	assert_bool(_caso().esta_en_el_local(&"balde", JORNADA_6, {}, {})).is_true()


func test_levantar_el_documento_registra_6b_una_vez_con_su_foto_y_su_texto() -> void:  # AC-INV-172
	var expediente := _por_el_camino_de_la_5a()
	var antes := expediente.mensajes_de_notas().size()
	var nuevas: Array[Pista] = []
	expediente.pista_nueva.connect(func(pista: Pista) -> void: nuevas.append(pista))
	var origen := _caso().pista_de("6B").origen
	var ajenos: Array[Array] = [
		[origen, Pista.Canal.LEVANTAR, JORNADA_5], [origen, Pista.Canal.CHAT, JORNADA_6]
	]
	for ajeno: Array in ajenos:
		assert_int(expediente.registrar_por_canal(ajeno[0], ajeno[1], ajeno[2])).is_equal(
			Expediente.Resultado.DESCONOCIDA
		)
	assert_array(Array(expediente.identidades())).not_contains(["6B"])
	assert_int(expediente.registrar_por_canal(origen, Pista.Canal.LEVANTAR, JORNADA_6)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	assert_int(expediente.registrar_por_canal(origen, Pista.Canal.LEVANTAR, JORNADA_6)).is_equal(
		Expediente.Resultado.REPETIDA
	)
	assert_int(nuevas.size()).is_equal(1)
	var notas := expediente.mensajes_de_notas()
	assert_int(notas.size()).is_equal(antes + 2)
	if notas.size() == antes + 2:
		assert_object(notas[antes].foto).is_not_null()
		assert_str(notas[antes].texto).is_empty()
		assert_str(notas[antes + 1].texto).is_equal(_caso().pista_de("6B").texto)
		assert_int(notas[antes + 1].jornada).is_equal(JORNADA_6)


func test_6b_no_se_anota_por_el_camino_de_la_5b() -> void:  # AC-INV-172
	var expediente := Expediente.new(_caso())
	expediente.registrar("2A")
	expediente.elegir(CUARTA, "2A")
	expediente.registrar("5B")
	expediente.elegir(JORNADA_5, "5B")
	assert_int(expediente.registrar("6B")).is_equal(Expediente.Resultado.DESCONOCIDA)
	assert_int(expediente.registrar("6C")).is_equal(Expediente.Resultado.ANOTADA)


func test_6b_es_una_pista_levantable_de_la_jornada_6_con_su_foto() -> void:  # AC-INV-173
	var caso := _caso()
	var pista := caso.pista_de("6B")
	assert_object(pista).is_not_null()
	if pista == null:
		return
	assert_int(pista.jornada).is_equal(JORNADA_6)
	assert_int(pista.canal).is_equal(Pista.Canal.LEVANTAR)
	assert_str(pista.texto).is_not_empty()
	assert_object(pista.foto).is_not_null()
	for otra: String in ["2A", "2B", "5A", "5B", "6C"]:
		assert_bool(pista.foto != caso.pista_de(otra).foto).is_true()
		assert_bool(pista.origen != caso.pista_de(otra).origen).is_true()


func test_la_hipotesis_6b_trae_su_titulo_y_la_5a_abre_su_camino() -> void:  # AC-INV-173
	var caso := _caso()
	var opciones := caso.hipotesis_para(JORNADA_6, PackedStringArray(["6B"]))
	assert_array(_identidades(opciones)).is_equal(["6B"])
	if not opciones.is_empty():
		assert_str(opciones[0].titulo).is_equal("DOCUMENTO PECULIAR")
		assert_str(opciones[0].texto).is_not_empty()
		assert_array(Array(opciones[0].exigencias)).is_equal(["6B"])
	assert_array(Array(caso.opcion(JORNADA_5, "5A").camino)).is_equal(["6A", "6B"])
	assert_array(Array(caso.opcion(JORNADA_5, "5B").camino)).is_equal(["6C", "6D"])
	assert_array(Array(caso.opcion(CUARTA, "2A").camino)).is_equal(["5A", "5B"])
	assert_array(Array(caso.opcion(JORNADA_6, "6C").camino)).is_equal(["7C"])


func test_con_la_6b_la_sexta_ofrece_solo_la_6b() -> void:  # AC-INV-174
	var expediente := _por_el_camino_de_la_5a()
	assert_int(expediente.registrar("6B")).is_equal(Expediente.Resultado.ANOTADA)
	var reflexion := _empezada(expediente)
	assert_str(reflexion.encabezado()).is_equal(ReflexionDeCierre.ENCABEZADOS[JORNADA_6])
	assert_array(_identidades(reflexion.opciones())).is_equal(["6B"])
	for ajena: String in ["6P", "6L", "6C"]:
		assert_int(reflexion.elegir(ajena)).is_equal(ReflexionDeCierre.Eleccion.NO_DISPONIBLE)
	assert_str(expediente.eleccion(JORNADA_6)).is_empty()


func test_sin_la_6b_ni_la_6c_la_sexta_ofrece_la_6l_y_no_deja_elegir_la_6b() -> void:  # AC-INV-174
	var reflexion := _empezada(_por_el_camino_de_la_5a())
	assert_array(_identidades(reflexion.opciones())).is_equal(["6L"])
	assert_int(reflexion.elegir("6B")).is_equal(ReflexionDeCierre.Eleccion.NO_DISPONIBLE)


func test_elegir_la_6b_anota_una_vez_y_pide_la_septima() -> void:  # AC-INV-174
	var expediente := _por_el_camino_de_la_5a()
	expediente.registrar("6B")
	var reflexion := _empezada(expediente)
	var notas := expediente.mensajes_de_notas().size()
	assert_int(reflexion.elegir("6B")).is_equal(ReflexionDeCierre.Eleccion.ACEPTADA)
	assert_str(expediente.eleccion(JORNADA_6)).is_equal("6B")
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas + 1)
	assert_int(reflexion.elegir("6B")).is_equal(ReflexionDeCierre.Eleccion.REPETIDA)
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas + 1)
	assert_bool(reflexion.avanzar(ReflexionDeCierre.ESPERA_ANTES_DE_LA_NOCHE)).is_true()
	assert_int(reflexion.etapa()).is_equal(E.TERMINADA)
