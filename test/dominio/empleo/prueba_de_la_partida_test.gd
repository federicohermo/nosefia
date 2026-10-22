extends GdUnitTestSuite

const M := Reglas.MEDIOS_POR_APERCIBIMIENTO
const T := Tarea.Tipo
const UMBRAL := Reglas.APERCIBIMIENTOS_QUE_PIERDEN_LA_PRUEBA
const TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA - 1
const CUARTA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
const CAMPO := PartidaSerializada.Campo


func _con(jornada: int, apercibimientos: int) -> Partida:
	return Partida.desde({"jornada": jornada, "medios": apercibimientos * M})


func _noche(
	partida: Partida,
	sin_cumplir: Array[Tarea.Tipo],
	mal_atendidos: int = 0,
	llamados: Array[Partida.Llamado] = []
) -> void:
	partida.abrir_la_jornada()
	var cumplidas := 0
	for tarea: Tarea in partida.obligatorias():
		if not sin_cumplir.has(tarea.tipo()):
			tarea.completar()
			cumplidas += 1
	for llamado: Partida.Llamado in llamados:
		partida.anotar_llamado(llamado)
	partida.cerrar_la_jornada(cumplidas, mal_atendidos)


func test_cada_cliente_y_cada_registro_o_reposicion_mal_hechos_suman_uno() -> void:  # AC-EMP-078
	var partida := _con(ReglasDeLaPartida.PRIMERA_JORNADA + 1, 0)
	_noche(partida, [T.CAJA, T.REGISTRAR, T.REPONER], 2)
	var descuidos := 2 + 2
	assert_int(partida.apercibimientos()).is_equal(
		descuidos * Reglas.APERCIBIMIENTOS_POR_FALLA_DE_LA_PRUEBA
	)


func test_la_limpieza_mal_hecha_suma_uno_en_la_tercera() -> void:  # AC-EMP-078
	var partida := _con(TERCERA, 0)
	_noche(partida, [T.LIMPIAR])
	assert_int(partida.legajo().apercibimientos_de_la_prueba()).is_equal(
		Reglas.APERCIBIMIENTOS_POR_FALLA_DE_LA_PRUEBA
	)


func test_atender_suma_por_cliente_y_no_por_la_tarea() -> void:  # AC-EMP-078
	var partida := _con(ReglasDeLaPartida.PRIMERA_JORNADA + 1, 0)
	_noche(partida, [T.CAJA], 1)
	assert_int(partida.apercibimientos()).is_equal(Reglas.APERCIBIMIENTOS_POR_FALLA_DE_LA_PRUEBA)


func test_en_la_prueba_los_llamados_no_suman_y_las_bandas_no_pesan() -> void:  # AC-EMP-078
	var todos: Array[Partida.Llamado] = []
	todos.assign(Partida.Llamado.values())
	var partida := Partida.nueva()
	_noche(partida, [], 0, todos)
	assert_bool(partida.antecedentes().hubo_llamados()).is_false()
	assert_int(partida.medios()).is_zero()
	var sin_tareas := _con(ReglasDeLaPartida.PRIMERA_JORNADA + 1, 0)
	_noche(sin_tareas, [T.CAJA, T.REGISTRAR, T.REPONER])
	assert_int(sin_tareas.apercibimientos()).is_equal(
		2 * Reglas.APERCIBIMIENTOS_POR_FALLA_DE_LA_PRUEBA
	)


func test_las_dos_primeras_no_despiden_con_lo_que_sea() -> void:  # AC-EMP-079
	var partida := Partida.nueva()
	for _noche_de_prueba in TERCERA - 1:
		_noche(partida, [T.CAJA, T.REGISTRAR, T.REPONER], 2)
	assert_bool(partida.terminada()).is_false()
	assert_int(partida.jornada()).is_equal(TERCERA)
	assert_int(partida.apercibimientos()).is_greater(Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO)
	assert_object(partida.abrir_la_jornada()).is_not_null()


func test_la_tercera_con_el_umbral_y_alguna_tarea_sin_cumplir_despide() -> void:  # AC-EMP-080
	for total: int in [UMBRAL, UMBRAL + 1]:
		var partida := _con(TERCERA, total - 1)
		_noche(partida, [T.LIMPIAR])
		assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)
		assert_int(partida.jornada()).is_equal(TERCERA)
		assert_object(partida.abrir_la_jornada()).is_null()


func test_la_tercera_un_apercibimiento_antes_del_umbral_sigue() -> void:  # AC-EMP-080
	var partida := _con(TERCERA, UMBRAL - 2)
	_noche(partida, [T.LIMPIAR])
	assert_bool(partida.terminada()).is_false()
	assert_int(partida.jornada()).is_equal(CUARTA)
	assert_object(partida.abrir_la_jornada()).is_not_null()


func test_la_tercera_completa_sigue_debajo_en_y_sobre_el_umbral() -> void:  # AC-EMP-080
	for total: int in [UMBRAL - 1, UMBRAL, UMBRAL + 1]:
		var partida := _con(TERCERA, total)
		_noche(partida, [])
		assert_bool(partida.terminada()).is_false()
		assert_int(partida.jornada()).is_equal(CUARTA)
		assert_int(partida.legajo().apercibimientos_de_la_prueba()).is_equal(total)


func test_la_cuarta_arranca_en_cero_si_la_prueba_no_llego_al_umbral() -> void:  # AC-EMP-081
	var partida := _con(TERCERA, UMBRAL - 2)
	_noche(partida, [T.LIMPIAR])
	assert_int(partida.medios()).is_zero()
	assert_int(partida.legajo().apercibimientos_de_la_prueba()).is_equal(UMBRAL - 1)
	assert_bool(partida.legajo().ultima_de_la_prueba_completa()).is_false()


func test_la_cuarta_arranca_con_uno_si_la_prueba_llego_al_umbral() -> void:  # AC-EMP-081
	var partida := _con(TERCERA, UMBRAL)
	_noche(partida, [])
	assert_int(partida.medios()).is_equal(Reglas.APERCIBIMIENTOS_TRAS_UNA_PRUEBA_EXCEDIDA * M)
	assert_int(partida.legajo().apercibimientos_de_la_prueba()).is_equal(UMBRAL)
	assert_bool(partida.legajo().ultima_de_la_prueba_completa()).is_true()


func test_la_despedida_en_la_tercera_recuerda_su_resultado_sin_reiniciar() -> void:  # AC-EMP-081
	var partida := _con(TERCERA, UMBRAL - 1)
	_noche(partida, [T.LIMPIAR])
	assert_int(partida.legajo().apercibimientos_de_la_prueba()).is_equal(UMBRAL)
	assert_bool(partida.legajo().ultima_de_la_prueba_completa()).is_false()
	assert_int(partida.apercibimientos()).is_equal(UMBRAL)


func test_desde_la_cuarta_suman_las_bandas_y_los_llamados() -> void:  # AC-EMP-082
	var partida := _con(TERCERA, UMBRAL - 2)
	_noche(partida, [T.LIMPIAR])
	var grave: Array[Tarea.Tipo] = [T.CAJA, T.REGISTRAR, T.LIMPIAR]
	_noche(partida, grave, 0, [Partida.Llamado.OBJETO_AFUERA])
	assert_int(partida.medios()).is_equal(
		Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE * M + Reglas.MEDIOS_POR_LLAMADO
	)
	assert_bool(partida.terminada()).is_false()
	_noche(partida, grave)
	assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)


func test_los_apercibimientos_de_la_prueba_cruzan_el_guardado() -> void:  # AC-EMP-083
	var partida := Partida.nueva()
	_noche(partida, [])
	_noche(partida, [T.CAJA, T.REGISTRAR, T.REPONER], 1)
	var retomada := Partida.desde(PoliticaDeGuardado.datos(partida))
	assert_int(retomada.jornada()).is_equal(TERCERA)
	assert_int(retomada.apercibimientos()).is_equal(partida.apercibimientos())
	assert_int(retomada.apercibimientos()).is_equal(3)


func test_el_resultado_de_la_prueba_cruza_el_guardado() -> void:  # AC-EMP-083
	var partida := _con(TERCERA, UMBRAL)
	_noche(partida, [])
	var retomada := Partida.desde(PoliticaDeGuardado.datos(partida))
	assert_int(retomada.jornada()).is_equal(CUARTA)
	assert_int(retomada.medios()).is_equal(partida.medios())
	assert_int(retomada.legajo().apercibimientos_de_la_prueba()).is_equal(UMBRAL)
	assert_bool(retomada.legajo().ultima_de_la_prueba_completa()).is_true()


func test_un_guardado_sin_el_resultado_o_con_otro_tipo_lo_restaura_en_cero() -> void:  # AC-EMP-083
	var apercibimientos := PartidaSerializada.clave(CAMPO.APERCIBIMIENTOS_DE_LA_PRUEBA)
	var completa := PartidaSerializada.clave(CAMPO.ULTIMA_DE_LA_PRUEBA_COMPLETA)
	var ajenos := {"jornada": CUARTA, apercibimientos: "5", completa: 1}
	for crudo: Dictionary in [{"jornada": CUARTA}, ajenos]:
		var partida := Partida.desde(crudo)
		assert_int(partida.jornada()).is_equal(CUARTA)
		assert_int(partida.legajo().apercibimientos_de_la_prueba()).is_zero()
		assert_bool(partida.legajo().ultima_de_la_prueba_completa()).is_false()
