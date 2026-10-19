## El factor que convierte un segundo real en segundos de turno.
extends GdUnitTestSuite


func test_cada_jornada_dura_su_sesion_y_cubre_el_turno_entero() -> void:  # AC-SHF-002
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	for jornada: int in range(primera, primera + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA):
		var ritmo := Ritmo.de_la_jornada(jornada)
		assert_float(ritmo).is_greater(0.0)
		assert_float(Ritmo.escalar(1.0, ritmo)).is_equal(ritmo)
		var sesion := Reglas.DURACION_DEL_TURNO / ritmo
		assert_float(Ritmo.escalar(sesion, ritmo)).is_equal_approx(Reglas.DURACION_DEL_TURNO, 0.001)


func test_una_jornada_sin_fila_corre_a_un_minuto_por_segundo() -> void:  # AC-SHF-002
	var minuto := Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL
	assert_float(Ritmo.escalar(1.0, Ritmo.de_la_jornada(0))).is_equal(minuto)
	assert_float(Ritmo.escalar(1.0)).is_equal(minuto)


func test_sin_tiempo_real_no_se_consume_nada_del_turno() -> void:
	assert_float(Ritmo.escalar(0.0)).is_equal(0.0)


func test_es_lineal_y_medio_segundo_vale_la_mitad() -> void:
	assert_float(Ritmo.escalar(0.5)).is_equal(Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL / 2)
