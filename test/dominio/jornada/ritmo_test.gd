## El factor que convierte un segundo real en segundos de turno.
extends GdUnitTestSuite


func test_toda_jornada_dura_lo_mismo_y_cubre_el_turno_entero() -> void:  # AC-SHF-002
	var ritmo := Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL
	assert_float(ritmo).is_greater(0.0)
	var sesion := Reglas.DURACION_DEL_TURNO / ritmo
	assert_float(Ritmo.escalar(sesion)).is_equal_approx(Reglas.DURACION_DEL_TURNO, 0.001)


func test_un_segundo_real_escala_igual_en_cualquier_jornada() -> void:  # AC-SHF-002
	var minuto := Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL
	assert_float(Ritmo.escalar(1.0)).is_equal(minuto)


func test_sin_tiempo_real_no_se_consume_nada_del_turno() -> void:
	assert_float(Ritmo.escalar(0.0)).is_equal(0.0)


func test_es_lineal_y_medio_segundo_vale_la_mitad() -> void:
	assert_float(Ritmo.escalar(0.5)).is_equal(Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL / 2)
