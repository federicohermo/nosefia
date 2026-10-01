## Una mancha: de qué tipo es, qué mopa la borra y qué contesta la pasada que no la borra.
extends GdUnitTestSuite

const POLVO := ReglasDeLaLimpieza.TipoDeMancha.POLVO


## Una mopa mojada de esa agua, como sale de mojarla en un balde que la tiene.
func _mopa(agua: ReglasDeLaLimpieza.Agua) -> Mopa:
	var mopa := Mopa.new()
	if agua == ReglasDeLaLimpieza.Agua.NINGUNA:
		return mopa
	var balde := Balde.new()
	balde.llenar()
	if agua != ReglasDeLaLimpieza.Agua.LIMPIA:
		balde.tenir(agua)
	mopa.mojar_en(balde)
	return mopa


func test_una_mancha_nueva_esta_sucia_y_se_ve_de_su_tipo() -> void:
	var mancha := Mancha.new(POLVO)
	assert_int(mancha.tipo()).is_equal(POLVO)
	assert_bool(mancha.esta_limpia()).is_false()
	assert_that(mancha.color()).is_equal(ReglasDeLaLimpieza.COLOR_DE_LA_MANCHA[POLVO])


func test_la_mopa_que_no_sirve_contesta_por_que_y_no_borra() -> void:  # AC-CLN-023
	var esperados := {
		ReglasDeLaLimpieza.Agua.NINGUNA: ReglasDeLaLimpieza.Resultado.MOPA_SECA,
		ReglasDeLaLimpieza.Agua.LIMPIA: ReglasDeLaLimpieza.Resultado.SIN_JABON,
		ReglasDeLaLimpieza.Agua.AZUL: ReglasDeLaLimpieza.Resultado.JABON_EQUIVOCADO,
		ReglasDeLaLimpieza.Agua.ROSA: ReglasDeLaLimpieza.Resultado.JABON_EQUIVOCADO,
	}
	for agua: ReglasDeLaLimpieza.Agua in esperados:
		var mancha := Mancha.new(POLVO)
		(
			assert_int(mancha.borrar_con(_mopa(agua)))
			. override_failure_message("la mopa de agua %d contestó otra cosa" % agua)
			. is_equal(esperados[agua])
		)
		assert_bool(mancha.esta_limpia()).is_false()


func test_el_jabon_que_corresponde_borra_y_la_mopa_sigue_mojada() -> void:  # AC-CLN-023
	# Con una mojada se borran las dos de polvo: si borrar secara la mopa, la segunda pediría
	# volver al balde, y la ficha no lo pide.
	var mopa := _mopa(ReglasDeLaLimpieza.Agua.AMARILLO)
	var una := Mancha.new(POLVO)
	var otra := Mancha.new(POLVO)
	assert_int(una.borrar_con(mopa)).is_equal(ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA)
	assert_bool(una.esta_limpia()).is_true()
	assert_int(mopa.agua()).is_equal(ReglasDeLaLimpieza.Agua.AMARILLO)
	assert_int(otra.borrar_con(mopa)).is_equal(ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA)


func test_una_mancha_borrada_contesta_ya_limpia_antes_que_mirar_la_mopa() -> void:  # AC-CLN-023
	var mancha := Mancha.new(POLVO)
	mancha.borrar_con(_mopa(ReglasDeLaLimpieza.Agua.AMARILLO))
	for agua: ReglasDeLaLimpieza.Agua in [
		ReglasDeLaLimpieza.Agua.NINGUNA, ReglasDeLaLimpieza.Agua.AMARILLO
	]:
		assert_int(mancha.borrar_con(_mopa(agua))).is_equal(
			ReglasDeLaLimpieza.Resultado.YA_ESTABA_LIMPIA
		)
		assert_bool(mancha.esta_limpia()).is_true()


func test_de_los_nueve_pares_de_mancha_y_jabon_se_borran_tres() -> void:  # AC-CLN-014
	var borradas: Array[Array] = []
	for tipo: ReglasDeLaLimpieza.TipoDeMancha in ReglasDeLaLimpieza.TipoDeMancha.values():
		for agua: ReglasDeLaLimpieza.Agua in [
			ReglasDeLaLimpieza.Agua.AZUL,
			ReglasDeLaLimpieza.Agua.ROSA,
			ReglasDeLaLimpieza.Agua.AMARILLO,
		]:
			var mancha := Mancha.new(tipo)
			if mancha.borrar_con(_mopa(agua)) == ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA:
				borradas.append([tipo, agua])
	(
		assert_array(borradas)
		. contains_exactly_in_any_order(
			[
				[ReglasDeLaLimpieza.TipoDeMancha.MOHO, ReglasDeLaLimpieza.Agua.AZUL],
				[ReglasDeLaLimpieza.TipoDeMancha.CACA, ReglasDeLaLimpieza.Agua.ROSA],
				[ReglasDeLaLimpieza.TipoDeMancha.POLVO, ReglasDeLaLimpieza.Agua.AMARILLO],
			]
		)
	)


func test_dos_manchas_no_comparten_el_estado() -> void:
	# Con el estado compartido, borrar una borraría las cuatro y la tarea se cumpliría sin
	# recorrer nada.
	var una := Mancha.new(POLVO)
	var otra := Mancha.new(POLVO)
	una.borrar_con(_mopa(ReglasDeLaLimpieza.Agua.AMARILLO))
	assert_bool(otra.esta_limpia()).is_false()
