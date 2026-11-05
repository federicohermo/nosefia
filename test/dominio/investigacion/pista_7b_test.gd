## La pista 7B es una acción: abrir la puerta del jefe con la palanca, por el camino de la 6B.
extends GdUnitTestSuite

const JORNADA_7 := ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
const JORNADA_6 := JORNADA_7 - 1
const JORNADA_5 := JORNADA_6 - 1
const CUARTA := JORNADA_5 - 1
const PALANCA := Partida.PALANCA


func _caso() -> CasoDeInvestigacion:
	return CasoDeInvestigacion.de_la_partida()


func _por_la_6b() -> Dictionary:
	return {CUARTA: "2A", JORNADA_5: "5A", JORNADA_6: "6B"}


## La partida que llegó a la séptima eligiendo lo que se le pide, con las pistas que lo habilitan.
func _expediente(hasta_la_6: bool = true, eleccion_de_la_6: String = "6B") -> Expediente:
	var expediente := Expediente.new(_caso())
	expediente.registrar("2A")
	expediente.elegir(CUARTA, "2A")
	expediente.registrar("5A")
	expediente.elegir(JORNADA_5, "5A")
	if hasta_la_6:
		expediente.registrar(eleccion_de_la_6)
		expediente.elegir(JORNADA_6, eleccion_de_la_6)
	return expediente


func test_7b_es_de_la_jornada_7_y_del_canal_de_accion() -> void:  # AC-INV-176
	var pista := _caso().pista_de("7B")
	assert_object(pista).is_not_null()
	if pista == null:
		return
	assert_int(pista.jornada).is_equal(JORNADA_7)
	assert_int(pista.canal).is_equal(Pista.Canal.ACCION)
	assert_object(pista.foto).is_null()
	assert_str(pista.texto).is_empty()
	assert_bool(pista.deja_nota()).is_false()
	assert_object(_caso().opcion(JORNADA_7, "7B")).is_null()


func test_la_hipotesis_6b_abre_el_camino_de_7b() -> void:  # AC-INV-176
	var camino := _caso().opcion(JORNADA_6, "6B").camino
	assert_array(Array(camino)).contains_exactly(["7B"])


func test_7b_esta_activa_solo_con_la_6b_elegida() -> void:  # AC-INV-176
	assert_array(Array(_expediente().pistas_activas(JORNADA_7))).contains_exactly(["7B"])
	var por_la_6c := Expediente.new(_caso())
	por_la_6c.registrar("2A")
	por_la_6c.elegir(CUARTA, "2A")
	por_la_6c.registrar("5B")
	por_la_6c.elegir(JORNADA_5, "5B")
	por_la_6c.registrar("6C")
	por_la_6c.elegir(JORNADA_6, "6C")
	assert_array(Array(por_la_6c.pistas_activas(JORNADA_7))).is_empty()
	var sin_pista_en_la_6 := _expediente(false)
	var predeterminada := sin_pista_en_la_6.hipotesis_para(JORNADA_6)[0].identidad
	sin_pista_en_la_6.elegir(JORNADA_6, predeterminada)
	assert_array(Array(sin_pista_en_la_6.pistas_activas(JORNADA_7))).is_empty()
	assert_array(Array(_expediente(false).pistas_activas(JORNADA_7))).is_empty()


func test_registrar_7b_suma_al_expediente_una_vez_y_no_deja_notas() -> void:  # AC-INV-179
	var expediente := _expediente()
	var notas := expediente.mensajes_de_notas().size()
	var registrar := func() -> Expediente.Resultado:
		return expediente.registrar_por_canal(PALANCA, Pista.Canal.ACCION, JORNADA_7)
	assert_int(registrar.call()).is_equal(Expediente.Resultado.ANOTADA)
	assert_array(Array(expediente.identidades())).contains(["7B"])
	assert_int(registrar.call()).is_equal(Expediente.Resultado.REPETIDA)
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas)


func test_7b_no_se_registra_fuera_de_su_canal_jornada_o_camino() -> void:  # AC-INV-179
	var expediente := _expediente()
	var antes := expediente.identidades()
	for canal: Pista.Canal in [Pista.Canal.LEVANTAR, Pista.Canal.CHAT, Pista.Canal.COMPRADOR]:
		assert_int(expediente.registrar_por_canal(PALANCA, canal, JORNADA_7)).is_equal(
			Expediente.Resultado.DESCONOCIDA
		)
	assert_int(expediente.registrar_por_canal(PALANCA, Pista.Canal.ACCION, JORNADA_6)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	var sin_la_6b := _expediente(false)
	assert_int(sin_la_6b.registrar_por_canal(PALANCA, Pista.Canal.ACCION, JORNADA_7)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_array(Array(expediente.identidades())).is_equal(Array(antes))
	assert_array(Array(sin_la_6b.identidades())).not_contains(["7B"])


func test_la_palanca_esta_en_el_local_solo_la_jornada_7_con_la_6b_elegida() -> void:  # AC-INV-177
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
	):
		assert_bool(_caso().esta_en_el_local(PALANCA, jornada, _por_la_6b(), {})).is_equal(
			jornada == JORNADA_7
		)
	var otras: Array[Dictionary] = [
		{CUARTA: "2A", JORNADA_5: "5B", JORNADA_6: "6C"},
		{CUARTA: "2A", JORNADA_5: "5A"},
		{CUARTA: "2A"},
		{},
	]
	for elecciones: Dictionary in otras:
		assert_bool(_caso().esta_en_el_local(PALANCA, JORNADA_7, elecciones, {})).is_false()
	assert_bool(_caso().esta_en_el_local(&"balde", JORNADA_7, {}, {})).is_true()


func test_el_expediente_dice_lo_mismo_que_el_caso_de_la_palanca() -> void:  # AC-INV-177
	assert_bool(_expediente().esta_en_el_local(PALANCA, JORNADA_7)).is_true()
	assert_bool(_expediente().esta_en_el_local(PALANCA, JORNADA_6)).is_false()
	assert_bool(_expediente(false).esta_en_el_local(PALANCA, JORNADA_7)).is_false()
	assert_bool(Expediente.new(_caso()).esta_en_el_local(PALANCA, JORNADA_7)).is_false()


func test_levantar_la_palanca_no_registra_7b() -> void:  # AC-INV-178
	var expediente := _expediente()
	assert_bool(expediente.levanta_una_pista(PALANCA, JORNADA_7)).is_false()
	assert_int(expediente.registrar_por_canal(PALANCA, Pista.Canal.LEVANTAR, JORNADA_7)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_array(Array(expediente.identidades())).not_contains(["7B"])
