## Una puerta del local: si está abierta y cuánto le falta al giro.
extends GdUnitTestSuite


func test_una_puerta_nueva_arranca_cerrada_y_sin_giro() -> void:
	var puerta := Puerta.new()
	assert_bool(puerta.abierta()).is_false()
	assert_float(puerta.angulo()).is_equal(0.0)


func test_alternar_abre_y_la_segunda_llamada_cierra() -> void:  # AC-PLY-012
	var puerta := Puerta.new()
	puerta.alternar()
	assert_bool(puerta.abierta()).is_true()
	assert_float(puerta.angulo()).is_equal(0.0)
	puerta.alternar()
	assert_bool(puerta.abierta()).is_false()


func test_el_giro_no_se_pasa_de_ninguno_de_los_dos_topes() -> void:  # AC-PLY-012 AC-PLY-013
	# Sin el tope el ángulo seguiría creciendo cuadro a cuadro y la hoja daría vueltas enteras,
	# con la escena cargando sin un solo error.
	var puerta := Puerta.new()
	puerta.alternar()
	puerta.avanzar(10.0)
	assert_float(puerta.angulo()).is_equal(Puerta.ANGULO_ABIERTA)
	puerta.alternar()
	puerta.avanzar(10.0)
	assert_float(puerta.angulo()).is_equal(0.0)


func test_el_giro_tarda_y_no_salta_al_tope() -> void:  # AC-PLY-012
	# El borde que importa es el primer paso: con el ángulo puesto de una, la hoja se
	# teletransportaría y la colisión atravesaría al jugador que tenga delante.
	var puerta := Puerta.new()
	puerta.alternar()
	puerta.avanzar(0.05)
	assert_float(puerta.angulo()).is_greater(0.0)
	assert_float(puerta.angulo()).is_less(Puerta.ANGULO_ABIERTA)


func test_dos_puertas_no_comparten_el_estado() -> void:
	var una := Puerta.new()
	var otra := Puerta.new()
	una.alternar()
	assert_bool(otra.abierta()).is_false()
	assert_float(otra.angulo()).is_equal(0.0)


func test_cerrar_de_golpe_deja_la_puerta_cerrada_y_sin_giro_sin_avanzar() -> void:
	var puerta := Puerta.new()
	puerta.alternar()
	puerta.avanzar(0.2)
	puerta.cerrar_de_golpe()
	assert_bool(puerta.abierta()).is_false()
	assert_float(puerta.angulo()).is_equal(0.0)


func test_cerrar_de_golpe_una_puerta_cerrada_no_cambia_nada() -> void:
	var puerta := Puerta.new()
	puerta.cerrar_de_golpe()
	assert_bool(puerta.abierta()).is_false()
	assert_float(puerta.angulo()).is_equal(0.0)


func test_despues_de_cerrar_de_golpe_se_porta_como_nueva() -> void:
	var puerta := Puerta.new()
	puerta.alternar()
	puerta.avanzar(10.0)
	puerta.cerrar_de_golpe()
	puerta.alternar()
	assert_float(puerta.avanzar(10.0)).is_equal(Puerta.ANGULO_ABIERTA)


func test_una_puerta_nueva_esta_quieta() -> void:
	assert_bool(Puerta.new().quieta()).is_true()


func test_girando_no_esta_quieta_y_en_el_tope_si() -> void:
	var puerta := Puerta.new()
	puerta.alternar()
	puerta.avanzar(0.1)
	assert_bool(puerta.quieta()).is_false()
	puerta.avanzar(10.0)
	assert_bool(puerta.quieta()).is_false()
	puerta.avanzar(0.1)
	assert_bool(puerta.quieta()).is_true()


func test_cerrar_de_golpe_a_medio_giro_la_deja_quieta() -> void:
	var puerta := Puerta.new()
	puerta.alternar()
	puerta.avanzar(0.1)
	puerta.cerrar_de_golpe()
	assert_bool(puerta.quieta()).is_true()
