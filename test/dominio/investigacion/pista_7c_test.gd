## La pista 7C es una acción: abrir la puerta del jefe con la llave, por el camino de la 6C.
extends GdUnitTestSuite

const JORNADA_7 := ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
const JORNADA_6 := JORNADA_7 - 1
const JORNADA_5 := JORNADA_6 - 1
const CUARTA := JORNADA_5 - 1
const LLAVE := Partida.LLAVE


func _caso() -> CasoDeInvestigacion:
	return CasoDeInvestigacion.de_la_partida()


func _por_la_6c() -> Dictionary:
	return {CUARTA: "2A", JORNADA_5: "5B", JORNADA_6: "6C"}


## La partida que llegó a la séptima eligiendo lo que se le pide, con las pistas que lo habilitan.
func _expediente(hasta_la_6: bool = true) -> Expediente:
	var expediente := Expediente.new(_caso())
	expediente.registrar("2A")
	expediente.elegir(CUARTA, "2A")
	expediente.registrar("5B")
	expediente.elegir(JORNADA_5, "5B")
	if hasta_la_6:
		expediente.registrar("6C")
		expediente.elegir(JORNADA_6, "6C")
	return expediente


func test_7c_es_de_la_jornada_7_y_del_canal_de_accion() -> void:  # AC-INV-184
	var pista := _caso().pista_de("7C")
	assert_object(pista).is_not_null()
	if pista == null:
		return
	assert_int(pista.jornada).is_equal(JORNADA_7)
	assert_int(pista.canal).is_equal(Pista.Canal.ACCION)
	assert_object(pista.foto).is_null()
	assert_str(pista.texto).is_empty()
	assert_bool(pista.deja_nota()).is_false()
	assert_object(_caso().opcion(JORNADA_7, "7C")).is_null()


func test_la_hipotesis_6c_abre_el_camino_de_7c() -> void:  # AC-INV-184
	var camino := _caso().opcion(JORNADA_6, "6C").camino
	assert_array(Array(camino)).contains_exactly(["7C"])


func test_7c_esta_activa_solo_con_la_6c_elegida() -> void:  # AC-INV-184
	assert_array(Array(_expediente().pistas_activas(JORNADA_7))).contains_exactly(["7C"])
	var por_la_6b := Expediente.new(_caso())
	por_la_6b.registrar("2A")
	por_la_6b.elegir(CUARTA, "2A")
	por_la_6b.registrar("5A")
	por_la_6b.elegir(JORNADA_5, "5A")
	por_la_6b.registrar("6B")
	por_la_6b.elegir(JORNADA_6, "6B")
	assert_array(Array(por_la_6b.pistas_activas(JORNADA_7))).not_contains(["7C"])
	var sin_pista_en_la_6 := _expediente(false)
	var predeterminada := sin_pista_en_la_6.hipotesis_para(JORNADA_6)[0].identidad
	sin_pista_en_la_6.elegir(JORNADA_6, predeterminada)
	assert_array(Array(sin_pista_en_la_6.pistas_activas(JORNADA_7))).is_empty()
	assert_array(Array(_expediente(false).pistas_activas(JORNADA_7))).is_empty()


func test_registrar_7c_suma_al_expediente_una_vez_y_no_deja_notas() -> void:  # AC-INV-187
	var expediente := _expediente()
	var notas := expediente.mensajes_de_notas().size()
	var registrar := func() -> Expediente.Resultado:
		return expediente.registrar_por_canal(LLAVE, Pista.Canal.ACCION, JORNADA_7)
	assert_int(registrar.call()).is_equal(Expediente.Resultado.ANOTADA)
	assert_array(Array(expediente.identidades())).contains(["7C"])
	assert_int(registrar.call()).is_equal(Expediente.Resultado.REPETIDA)
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas)


func test_7c_no_se_registra_fuera_de_su_canal_jornada_o_camino() -> void:  # AC-INV-187
	var expediente := _expediente()
	var antes := expediente.identidades()
	for canal: Pista.Canal in [Pista.Canal.LEVANTAR, Pista.Canal.CHAT, Pista.Canal.COMPRADOR]:
		assert_int(expediente.registrar_por_canal(LLAVE, canal, JORNADA_7)).is_equal(
			Expediente.Resultado.DESCONOCIDA
		)
	assert_int(expediente.registrar_por_canal(LLAVE, Pista.Canal.ACCION, JORNADA_6)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	var sin_la_6c := _expediente(false)
	assert_int(sin_la_6c.registrar_por_canal(LLAVE, Pista.Canal.ACCION, JORNADA_7)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_array(Array(expediente.identidades())).is_equal(Array(antes))
	assert_array(Array(sin_la_6c.identidades())).not_contains(["7C"])


func test_la_llave_esta_en_el_local_solo_la_jornada_7_con_la_6c_elegida() -> void:  # AC-INV-185
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
	):
		assert_bool(_caso().esta_en_el_local(LLAVE, jornada, _por_la_6c(), {})).is_equal(
			jornada == JORNADA_7
		)
	var otras: Array[Dictionary] = [
		{CUARTA: "2A", JORNADA_5: "5A", JORNADA_6: "6B"},
		{CUARTA: "2A", JORNADA_5: "5B"},
		{CUARTA: "2A"},
		{},
	]
	for elecciones: Dictionary in otras:
		assert_bool(_caso().esta_en_el_local(LLAVE, JORNADA_7, elecciones, {})).is_false()


func test_llave_y_palanca_no_estan_nunca_en_la_misma_partida() -> void:  # AC-INV-185
	var por_la_6b := {CUARTA: "2A", JORNADA_5: "5A", JORNADA_6: "6B"}
	assert_bool(_caso().esta_en_el_local(Partida.PALANCA, JORNADA_7, por_la_6b, {})).is_true()
	assert_bool(_caso().esta_en_el_local(LLAVE, JORNADA_7, por_la_6b, {})).is_false()
	assert_bool(_caso().esta_en_el_local(Partida.PALANCA, JORNADA_7, _por_la_6c(), {})).is_false()
	assert_bool(_caso().esta_en_el_local(LLAVE, JORNADA_7, _por_la_6c(), {})).is_true()


func test_el_expediente_dice_lo_mismo_que_el_caso_de_la_llave() -> void:  # AC-INV-185
	assert_bool(_expediente().esta_en_el_local(LLAVE, JORNADA_7)).is_true()
	assert_bool(_expediente().esta_en_el_local(LLAVE, JORNADA_6)).is_false()
	assert_bool(_expediente(false).esta_en_el_local(LLAVE, JORNADA_7)).is_false()
	assert_bool(Expediente.new(_caso()).esta_en_el_local(LLAVE, JORNADA_7)).is_false()


func test_levantar_la_llave_no_registra_7c() -> void:  # AC-INV-186
	var expediente := _expediente()
	assert_bool(expediente.levanta_una_pista(LLAVE, JORNADA_7)).is_false()
	assert_int(expediente.registrar_por_canal(LLAVE, Pista.Canal.LEVANTAR, JORNADA_7)).is_equal(
		Expediente.Resultado.DESCONOCIDA
	)
	assert_array(Array(expediente.identidades())).not_contains(["7C"])
