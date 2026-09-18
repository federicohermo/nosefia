## Una mancha del piso: cuántas pasadas le faltan y qué pasa cuando ya no le falta ninguna.
extends GdUnitTestSuite


func test_una_mancha_nueva_arranca_con_todas_las_pasadas() -> void:  # 014-AC2
	# Se compara contra la constante y nunca contra un número escrito acá: rebalancear las
	# pasadas no puede poner en rojo un caso que no habla del balance.
	var mancha := Mancha.new()
	assert_int(mancha.pasadas_restantes()).is_equal(ReglasDeLaLimpieza.PASADAS_POR_MANCHA)
	assert_bool(mancha.esta_limpia()).is_false()


func test_cada_pasada_baja_exactamente_una() -> void:  # 014-AC2
	var mancha := Mancha.new()
	var antes := mancha.pasadas_restantes()
	assert_bool(mancha.pasar()).is_true()
	assert_int(mancha.pasadas_restantes()).is_equal(antes - 1)


func test_la_ultima_pasada_la_deja_limpia() -> void:  # 014-AC2
	var mancha := Mancha.new()
	for _pasada in range(ReglasDeLaLimpieza.PASADAS_POR_MANCHA):
		assert_bool(mancha.pasar()).is_true()
	assert_int(mancha.pasadas_restantes()).is_equal(0)
	assert_bool(mancha.esta_limpia()).is_true()


func test_machacar_sobre_una_mancha_limpia_no_baja_de_cero() -> void:  # 014-AC2
	# Sin el corte el contador se iría a negativo y `esta_limpia()` seguiría diciendo que sí: un
	# estado imposible que ningún número delata.
	var mancha := Mancha.new()
	for _pasada in range(ReglasDeLaLimpieza.PASADAS_POR_MANCHA):
		mancha.pasar()
	assert_bool(mancha.pasar()).is_false()
	assert_int(mancha.pasadas_restantes()).is_equal(0)


func test_dos_manchas_no_comparten_el_contador() -> void:  # 014-AC2
	# Con el contador declarado como estático o compartido, limpiar una zona limpiaría las
	# cuatro y la tarea se cumpliría sin recorrer nada.
	var una := Mancha.new()
	var otra := Mancha.new()
	una.pasar()
	assert_int(otra.pasadas_restantes()).is_equal(ReglasDeLaLimpieza.PASADAS_POR_MANCHA)
