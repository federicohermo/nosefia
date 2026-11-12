## Los parámetros `logros` y `joystick` de la URL: qué significa cada valor, sin escena.
extends GdUnitTestSuite


func test_logros_uno_pide_ver_todos_los_logros_y_otro_valor_se_ignora() -> void:
	assert_bool(PartidaDePrueba.desde_busqueda("?logros=1").logros_completos).is_true()
	for valor: String in ["0", "", "si", "2"]:
		assert_object(PartidaDePrueba.desde_busqueda("?logros=" + valor)).is_null()
	assert_bool(PartidaDePrueba.desde_busqueda("?completas=1").logros_completos).is_false()


func test_joystick_uno_lo_simula_sin_fijar_la_familia() -> void:
	var prueba := PartidaDePrueba.desde_busqueda("?joystick=1")
	assert_bool(prueba.joystick).is_true()
	assert_int(prueba.familia_del_joystick).is_equal(PartidaDePrueba.SIN_FAMILIA)


func test_cada_nombre_de_familia_simula_el_joystick_y_fija_su_familia() -> void:
	var esperadas := {
		"xbox": FamiliaDeJoystick.Familia.XBOX,
		"ps": FamiliaDeJoystick.Familia.PLAYSTATION,
		"nintendo": FamiliaDeJoystick.Familia.NINTENDO,
	}
	for nombre: String in esperadas:
		var prueba := PartidaDePrueba.desde_busqueda("?joystick=" + nombre)
		assert_bool(prueba.joystick).is_true()
		assert_int(prueba.familia_del_joystick).is_equal(esperadas[nombre])


func test_un_joystick_desconocido_se_ignora() -> void:
	for valor: String in ["0", "", "sega", "XBOX"]:
		assert_object(PartidaDePrueba.desde_busqueda("?joystick=" + valor)).is_null()
	var prueba := PartidaDePrueba.desde_busqueda("?logros=1&joystick=sega")
	assert_bool(prueba.joystick).is_false()
	assert_int(prueba.familia_del_joystick).is_equal(PartidaDePrueba.SIN_FAMILIA)


func test_los_logros_y_el_joystick_conviven_con_los_demas_parametros() -> void:
	var prueba := PartidaDePrueba.desde_busqueda("?jornada=6&logros=1&joystick=ps&completas=1")
	assert_int(prueba.jornada).is_equal(6)
	assert_bool(prueba.logros_completos).is_true()
	assert_bool(prueba.joystick).is_true()
	assert_bool(prueba.completas).is_true()


func test_una_jornada_invalida_anula_tambien_los_logros_y_el_joystick() -> void:
	assert_object(PartidaDePrueba.desde_busqueda("?jornada=abc&logros=1&joystick=1")).is_null()


func test_sin_jornada_los_logros_y_el_joystick_no_arman_un_guardado() -> void:
	var prueba := PartidaDePrueba.desde_busqueda("?logros=1&joystick=1")
	assert_int(prueba.jornada).is_less(0)
