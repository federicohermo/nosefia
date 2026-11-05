extends GdUnitTestSuite

const JORNADA_4 := GeneradorDeTickets.JORNADA_SIN_LECTOR - 1
const JORNADA_5 := GeneradorDeTickets.JORNADA_SIN_LECTOR
const E := ReflexionDeCierre.Etapa


func _con_la_cuarta_elegida(elegida: String) -> Expediente:
	var expediente := Expediente.new(CasoDeInvestigacion.de_la_partida())
	expediente.registrar(elegida)
	expediente.elegir(JORNADA_4, elegida)
	return expediente


func _identidades(opciones: Array[Hipotesis]) -> Array[String]:
	var identidades: Array[String] = []
	for opcion: Hipotesis in opciones:
		identidades.append(opcion.identidad)
	return identidades


func _empezada(expediente: Expediente) -> ReflexionDeCierre:
	var reflexion := ReflexionDeCierre.para(JORNADA_5, expediente)
	reflexion.empezar()
	return reflexion


func test_5a_se_registra_una_vez_con_su_foto_y_su_texto() -> void:  # AC-INV-166
	var caso := CasoDeInvestigacion.de_la_partida()
	var expediente := _con_la_cuarta_elegida("2A")
	var antes := expediente.mensajes_de_notas().size()
	var nuevas: Array[Pista] = []
	expediente.pista_nueva.connect(func(pista: Pista) -> void: nuevas.append(pista))
	var ajenos: Array[Array] = [
		[&"5A", Pista.Canal.COMPRADOR, JORNADA_4], [&"5A", Pista.Canal.CHAT, JORNADA_5]
	]
	for ajeno: Array in ajenos:
		assert_int(expediente.registrar_por_canal(ajeno[0], ajeno[1], ajeno[2])).is_equal(
			Expediente.Resultado.DESCONOCIDA
		)
	assert_array(Array(expediente.identidades())).is_equal(["2A"])
	assert_int(expediente.registrar_por_canal(&"5A", Pista.Canal.COMPRADOR, JORNADA_5)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	assert_int(expediente.registrar_por_canal(&"5A", Pista.Canal.COMPRADOR, JORNADA_5)).is_equal(
		Expediente.Resultado.REPETIDA
	)
	assert_array(Array(expediente.identidades())).is_equal(["2A", "5A"])
	assert_int(nuevas.size()).is_equal(1)
	var notas := expediente.mensajes_de_notas()
	assert_int(notas.size()).is_equal(antes + 2)
	if notas.size() == antes + 2:
		assert_object(notas[antes].foto).is_not_null()
		assert_str(notas[antes].texto).is_empty()
		assert_object(notas[antes + 1].foto).is_null()
		assert_str(notas[antes + 1].texto).is_equal(caso.pista_de("5A").texto)
		assert_int(notas[antes + 1].jornada).is_equal(JORNADA_5)


func test_5a_solo_se_anota_por_el_camino_de_2a() -> void:  # AC-INV-166
	var caso := CasoDeInvestigacion.de_la_partida()
	assert_bool(Array(caso.opcion(JORNADA_4, "2A").camino).has("5A")).is_true()
	assert_bool(Array(caso.opcion(JORNADA_4, "2B").camino).has("5A")).is_false()
	var con_2b := _con_la_cuarta_elegida("2B")
	assert_int(con_2b.registrar_por_canal(&"5A", Pista.Canal.COMPRADOR, JORNADA_5)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_array(Array(con_2b.identidades())).is_equal(["2B"])
	var sin_elegir := Expediente.new(caso)
	assert_int(sin_elegir.registrar("5A")).is_equal(Expediente.Resultado.DESCONOCIDA)


func test_registrar_5a_no_cambia_lo_que_hace_la_5b() -> void:  # AC-INV-166
	var expediente := _con_la_cuarta_elegida("2A")
	assert_int(expediente.registrar("5A")).is_equal(Expediente.Resultado.ANOTADA)
	assert_int(expediente.registrar_por_canal(&"5B", Pista.Canal.CHAT, JORNADA_5)).is_equal(
		Expediente.Resultado.ANOTADA
	)
	assert_array(Array(expediente.identidades())).is_equal(["2A", "5A", "5B"])


func test_5a_es_una_pista_de_comprador_de_la_jornada_del_lector_con_su_foto() -> void:  # AC-INV-167
	var caso := CasoDeInvestigacion.de_la_partida()
	var pista := caso.pista_de("5A")
	assert_object(pista).is_not_null()
	if pista == null:
		return
	assert_int(pista.jornada).is_equal(JORNADA_5)
	assert_int(pista.canal).is_equal(Pista.Canal.COMPRADOR)
	assert_str(pista.texto).is_not_empty()
	assert_object(pista.foto).is_not_null()
	for otra: String in ["2A", "2B", "5B", "6C"]:
		assert_bool(pista.foto != caso.pista_de(otra).foto).is_true()


func test_la_hipotesis_5a_trae_el_titulo_y_el_texto_de_su_ficha() -> void:  # AC-INV-167
	var caso := CasoDeInvestigacion.de_la_partida()
	var opciones := caso.hipotesis_para(JORNADA_5, PackedStringArray(["5A"]))
	assert_array(_identidades(opciones)).is_equal(["5A"])
	if opciones.is_empty():
		return
	assert_str(opciones[0].titulo).is_equal("ACTITUDES EXTRAÑAS")
	assert_str(opciones[0].texto).is_not_empty()
	assert_array(Array(opciones[0].exigencias)).is_equal(["5A"])


func test_la_quinta_ofrece_la_5a_con_la_5a_y_las_dos_con_las_dos() -> void:  # AC-INV-168
	var sola := _con_la_cuarta_elegida("2A")
	sola.registrar("5A")
	assert_array(_identidades(_empezada(sola).opciones())).is_equal(["5A"])
	var las_dos := _con_la_cuarta_elegida("2A")
	las_dos.registrar("5B")
	las_dos.registrar("5A")
	assert_array(_identidades(_empezada(las_dos).opciones())).is_equal(["5A", "5B"])
	var solo_5b := _con_la_cuarta_elegida("2A")
	solo_5b.registrar("5B")
	assert_array(_identidades(_empezada(solo_5b).opciones())).is_equal(["5B"])


func test_sin_la_5a_no_se_puede_elegir_y_con_ella_se_pide_la_sexta() -> void:  # AC-INV-168
	var sin_la_5a := _empezada(_con_la_cuarta_elegida("2A"))
	assert_int(sin_la_5a.elegir("5A")).is_equal(ReflexionDeCierre.Eleccion.NO_DISPONIBLE)
	var expediente := _con_la_cuarta_elegida("2A")
	expediente.registrar("5A")
	var reflexion := _empezada(expediente)
	var notas := expediente.mensajes_de_notas().size()
	assert_int(reflexion.elegir("5A")).is_equal(ReflexionDeCierre.Eleccion.ACEPTADA)
	assert_str(expediente.eleccion(JORNADA_5)).is_equal("5A")
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas + 1)
	assert_int(reflexion.elegir("5A")).is_equal(ReflexionDeCierre.Eleccion.REPETIDA)
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas + 1)
	assert_bool(reflexion.avanzar(ReflexionDeCierre.ESPERA_ANTES_DE_LA_NOCHE)).is_true()
	assert_int(reflexion.etapa()).is_equal(E.TERMINADA)
