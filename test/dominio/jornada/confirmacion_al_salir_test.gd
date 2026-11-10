## Cuándo la página pide confirmación antes de cerrarse o recargarse: sólo mientras corre una noche.
extends GdUnitTestSuite


func test_al_empezar_la_noche_se_pide_la_confirmacion() -> void:  # AC-SHF-143
	var confirmacion := ConfirmacionAlSalir.new()
	assert_int(confirmacion.orden(true)).is_equal(ConfirmacionAlSalir.Orden.PEDIR)


func test_mientras_sigue_la_noche_no_se_repite_la_orden() -> void:  # AC-SHF-143
	var confirmacion := ConfirmacionAlSalir.new()
	confirmacion.orden(true)
	for cuadro in 5:
		assert_int(confirmacion.orden(true)).is_equal(ConfirmacionAlSalir.Orden.NADA)


func test_al_terminar_la_noche_se_retira_una_sola_vez() -> void:  # AC-SHF-144
	var confirmacion := ConfirmacionAlSalir.new()
	confirmacion.orden(true)
	assert_int(confirmacion.orden(false)).is_equal(ConfirmacionAlSalir.Orden.DEJAR_DE_PEDIR)
	assert_int(confirmacion.orden(false)).is_equal(ConfirmacionAlSalir.Orden.NADA)


func test_sin_noche_no_se_pide_nada() -> void:  # AC-SHF-144
	var confirmacion := ConfirmacionAlSalir.new()
	assert_int(confirmacion.orden(false)).is_equal(ConfirmacionAlSalir.Orden.NADA)


func test_cada_noche_nueva_vuelve_a_pedirla() -> void:  # AC-SHF-143
	var confirmacion := ConfirmacionAlSalir.new()
	confirmacion.orden(true)
	confirmacion.orden(false)
	assert_int(confirmacion.orden(true)).is_equal(ConfirmacionAlSalir.Orden.PEDIR)
