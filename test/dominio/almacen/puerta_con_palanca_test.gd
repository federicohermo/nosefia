## La puerta trabada que cede a un solo objeto en la mano: la traba sigue siendo suya.
extends GdUnitTestSuite


func _objeto(id: StringName) -> ObjetoDelAlmacen:
	var objeto := ObjetoDelAlmacen.new()
	objeto.id = id
	return objeto


func _puerta_que_cede_a_la_palanca() -> Puerta:
	var puerta := Puerta.new(true)
	puerta.ceder_a(Partida.PALANCA)
	return puerta


func test_con_la_palanca_en_la_mano_la_trabada_abre_y_sigue_trabada() -> void:  # AC-PLY-190
	var puerta := _puerta_que_cede_a_la_palanca()
	assert_bool(puerta.forzar(_objeto(Partida.PALANCA))).is_true()
	assert_bool(puerta.abierta()).is_true()
	assert_bool(puerta.trabada()).is_true()


func test_sin_la_palanca_la_trabada_no_cede() -> void:  # AC-PLY-190
	var puerta := _puerta_que_cede_a_la_palanca()
	assert_bool(puerta.forzar(null)).is_false()
	assert_bool(puerta.forzar(_objeto(&"mopa"))).is_false()
	assert_bool(puerta.forzar(_objeto(ObjetoDelAlmacen.SIN_ID))).is_false()
	assert_bool(puerta.abierta()).is_false()
	assert_bool(puerta.alternar()).is_false()


func test_una_puerta_que_no_declaro_la_palanca_no_cede_a_ella() -> void:  # AC-PLY-190
	var porton := Puerta.new(true)
	assert_bool(porton.forzar(_objeto(Partida.PALANCA))).is_false()
	assert_bool(porton.abierta()).is_false()


func test_forzar_una_puerta_ya_abierta_o_sin_traba_no_hace_nada() -> void:  # AC-PLY-190
	var abierta := _puerta_que_cede_a_la_palanca()
	abierta.forzar(_objeto(Partida.PALANCA))
	assert_bool(abierta.forzar(_objeto(Partida.PALANCA))).is_false()
	var libre := Puerta.new()
	libre.ceder_a(Partida.PALANCA)
	assert_bool(libre.forzar(_objeto(Partida.PALANCA))).is_false()
	assert_bool(libre.abierta()).is_false()
