## Una puerta del local: si está abierta y cuánto le falta al giro.
extends GdUnitTestSuite


func test_una_puerta_nueva_arranca_cerrada_y_sin_giro() -> void:  # 043-AC1
	var puerta := Puerta.new()
	assert_bool(puerta.abierta()).is_false()
	assert_float(puerta.angulo()).is_equal(0.0)


func test_alternar_abre_y_la_segunda_llamada_cierra() -> void:  # 043-AC2
	var puerta := Puerta.new()
	puerta.alternar()
	assert_bool(puerta.abierta()).is_true()
	puerta.alternar()
	assert_bool(puerta.abierta()).is_false()


func test_el_giro_no_se_pasa_de_ninguno_de_los_dos_topes() -> void:  # 043-AC3
	# Sin el tope el ángulo seguiría creciendo cuadro a cuadro y la hoja daría vueltas enteras,
	# con la escena cargando sin un solo error.
	var puerta := Puerta.new()
	puerta.alternar()
	puerta.avanzar(10.0)
	assert_float(puerta.angulo()).is_equal(Puerta.ANGULO_ABIERTA)
	puerta.alternar()
	puerta.avanzar(10.0)
	assert_float(puerta.angulo()).is_equal(0.0)


func test_el_giro_tarda_y_no_salta_al_tope() -> void:  # 043-AC4
	# El borde que importa es el primer paso: con el ángulo puesto de una, la hoja se
	# teletransportaría y la colisión atravesaría al jugador que tenga delante.
	var puerta := Puerta.new()
	puerta.alternar()
	puerta.avanzar(0.05)
	assert_float(puerta.angulo()).is_greater(0.0)
	assert_float(puerta.angulo()).is_less(Puerta.ANGULO_ABIERTA)


func test_dos_puertas_no_comparten_el_estado() -> void:  # 043-AC2
	var una := Puerta.new()
	var otra := Puerta.new()
	una.alternar()
	assert_bool(otra.abierta()).is_false()
	assert_float(otra.angulo()).is_equal(0.0)
