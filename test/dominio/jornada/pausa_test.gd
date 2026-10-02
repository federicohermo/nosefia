## Qué hace Esc y qué hace perder el cursor, contestado sin levantar una escena.
extends GdUnitTestSuite


func test_esc_en_la_jornada_pausa() -> void:  # AC-SAV-018
	assert_int(Pausa.ante_esc(false, false)).is_equal(Pausa.Accion.PAUSAR)


func test_esc_en_pausa_reanuda() -> void:  # AC-SAV-018
	assert_int(Pausa.ante_esc(true, false)).is_equal(Pausa.Accion.REANUDAR)


func test_esc_con_la_placa_no_hace_nada() -> void:  # AC-SAV-018
	assert_int(Pausa.ante_esc(false, true)).is_equal(Pausa.Accion.NADA)


func test_perder_el_cursor_tomado_pausa() -> void:  # AC-SAV-018
	assert_int(Pausa.ante_el_cursor(false, false, true, false)).is_equal(Pausa.Accion.PAUSAR)


func test_el_cursor_que_sigue_igual_no_pausa() -> void:  # AC-SAV-018
	assert_int(Pausa.ante_el_cursor(false, false, true, true)).is_equal(Pausa.Accion.NADA)
	assert_int(Pausa.ante_el_cursor(false, false, false, false)).is_equal(Pausa.Accion.NADA)
	# Tomarlo no es perderlo.
	assert_int(Pausa.ante_el_cursor(false, false, false, true)).is_equal(Pausa.Accion.NADA)


func test_perder_el_cursor_en_pausa_o_con_la_placa_no_hace_nada() -> void:  # AC-SAV-018
	assert_int(Pausa.ante_el_cursor(true, false, true, false)).is_equal(Pausa.Accion.NADA)
	assert_int(Pausa.ante_el_cursor(false, true, true, false)).is_equal(Pausa.Accion.NADA)
