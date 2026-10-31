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


func test_el_giro_tarda_y_no_salta_al_tope() -> void:
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


func test_la_trabada_no_se_abre_por_mas_que_se_la_toque() -> void:  # AC-PLY-038
	var puerta := Puerta.new(true)
	for vez in 10:
		assert_bool(puerta.alternar()).override_failure_message("vez %d" % vez).is_false()
		assert_bool(puerta.abierta()).override_failure_message("vez %d" % vez).is_false()
	assert_bool(puerta.trabada()).is_true()
	assert_float(puerta.avanzar(10.0)).is_equal(0.0)


func test_la_que_no_esta_trabada_alterna_y_lo_contesta() -> void:  # AC-PLY-039
	var puerta := Puerta.new()
	assert_bool(puerta.trabada()).is_false()
	assert_bool(puerta.alternar()).is_true()
	assert_bool(puerta.abierta()).is_true()


func test_la_salida_abre_una_trabada_sin_habilitar_su_alternancia() -> void:  # AC-SHF-043
	var puerta := Puerta.new(true)
	assert_bool(puerta.abrir_para_salida()).is_true()
	assert_float(puerta.angulo()).is_zero()
	assert_bool(puerta.abrir_para_salida()).is_false()
	assert_bool(puerta.alternar()).is_false()
	assert_float(puerta.avanzar(0.1)).is_between(0.0, Puerta.ANGULO_ABIERTA)
	assert_float(puerta.avanzar(10.0)).is_equal(Puerta.ANGULO_ABIERTA)
	assert_bool(puerta.trabada()).is_true()


func test_un_factor_menor_a_uno_hace_el_giro_mas_lento() -> void:  # AC-PLY-142
	var libre := Puerta.new()
	var frenada := Puerta.new()
	libre.alternar()
	frenada.alternar()
	assert_float(frenada.avanzar(0.1, 0.5)).is_less(libre.avanzar(0.1))
	assert_float(frenada.avanzar(10.0, 0.5)).is_equal(Puerta.ANGULO_ABIERTA)


func test_un_factor_fuera_de_cero_a_uno_gira_como_con_uno() -> void:  # AC-PLY-148
	for factor: float in [0.0, -1.0, 1.5, NAN]:
		var puerta := Puerta.new()
		puerta.alternar()
		var libre := Puerta.new()
		libre.alternar()
		assert_float(puerta.avanzar(0.1, factor)).is_equal(libre.avanzar(0.1))


func test_el_tope_detiene_la_hoja_al_abrir_y_al_cerrar() -> void:  # AC-PLY-143 AC-PLY-144
	var puerta := Puerta.new()
	puerta.alternar()
	puerta.avanzar(0.3)
	var detenida := puerta.angulo()
	assert_float(puerta.avanzar(0.3, 1.0, detenida)).is_equal(detenida)
	assert_bool(puerta.quieta()).is_true()
	assert_float(puerta.avanzar(10.0)).is_equal(Puerta.ANGULO_ABIERTA)
	puerta.alternar()
	puerta.avanzar(0.3)
	detenida = puerta.angulo()
	assert_float(puerta.avanzar(0.3, 1.0, detenida)).is_equal(detenida)
	assert_float(puerta.avanzar(10.0)).is_equal(0.0)


func test_un_tope_detras_de_la_hoja_no_la_hace_retroceder() -> void:  # AC-PLY-148
	var puerta := Puerta.new()
	puerta.alternar()
	puerta.avanzar(0.3)
	var antes := puerta.angulo()
	assert_float(puerta.avanzar(0.1, 1.0, antes - 0.5)).is_equal(antes)


func test_el_angulo_siguiente_no_mueve_la_hoja() -> void:  # AC-PLY-140
	var puerta := Puerta.new()
	puerta.alternar()
	var siguiente := puerta.angulo_siguiente(0.1)
	assert_float(puerta.angulo()).is_zero()
	assert_float(puerta.avanzar(0.1)).is_equal(siguiente)
