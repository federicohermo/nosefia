## Qué hace Esc y qué hace perder el cursor, contestado sin levantar una escena.
extends GdUnitTestSuite


func test_esc_en_la_jornada_pausa() -> void:  # AC-SAV-018
	assert_int(Pausa.ante_esc(false)).is_equal(Pausa.Accion.PAUSAR)


func test_esc_en_pausa_reanuda() -> void:  # AC-SAV-018
	assert_int(Pausa.ante_esc(true)).is_equal(Pausa.Accion.REANUDAR)


## La devolución del cierre no es una excepción: Esc no pregunta por ella, y pausa igual.
func test_esc_no_depende_de_la_placa() -> void:  # AC-SAV-018
	assert_int(Pausa.ante_esc(false, false)).is_equal(Pausa.Accion.PAUSAR)
	assert_int(Pausa.ante_esc(true, false)).is_equal(Pausa.Accion.REANUDAR)


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


func test_perder_el_cursor_con_la_ventana_inactiva_no_pausa() -> void:  # AC-SAV-018
	assert_int(Pausa.ante_el_cursor(false, false, true, false, false)).is_equal(Pausa.Accion.NADA)


func test_esc_con_configuraciones_abierta_la_cierra_sin_reanudar() -> void:  # AC-SAV-018
	assert_int(Pausa.ante_esc(true, true)).is_equal(Pausa.Accion.CERRAR_CONFIGURACIONES)


func test_esc_con_configuraciones_cerrada_sigue_reanudando() -> void:  # AC-SAV-018
	assert_int(Pausa.ante_esc(true, false)).is_equal(Pausa.Accion.REANUDAR)
