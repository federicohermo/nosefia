## El balde: se llena en el lavatorio, lo tiñe un jabón y se vacía en el inodoro. Cada gesto que no
## hace nada contesta por qué, y ninguno cambia el balde.
extends GdUnitTestSuite

const AZUL := ReglasDeLaLimpieza.Agua.AZUL
const ROSA := ReglasDeLaLimpieza.Agua.ROSA
const AMARILLO := ReglasDeLaLimpieza.Agua.AMARILLO


func _con_agua() -> Balde:
	var balde := Balde.new()
	balde.llenar()
	return balde


func _tenido(agua: ReglasDeLaLimpieza.Agua) -> Balde:
	var balde := _con_agua()
	balde.tenir(agua)
	return balde


func test_un_balde_nuevo_esta_vacio() -> void:
	var balde := Balde.new()
	assert_int(balde.agua()).is_equal(ReglasDeLaLimpieza.Agua.NINGUNA)
	assert_bool(balde.tiene_agua()).is_false()


func test_llenar_un_balde_vacio_le_pone_agua_sin_jabon() -> void:  # AC-CLN-019
	var balde := Balde.new()
	assert_int(balde.llenar()).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_LLENADO)
	assert_int(balde.agua()).is_equal(ReglasDeLaLimpieza.Agua.LIMPIA)
	assert_bool(balde.tiene_agua()).is_true()
	assert_that(balde.color()).is_equal(
		ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.LIMPIA]
	)


func test_llenar_lo_que_ya_tiene_agua_no_lava_el_jabon() -> void:  # AC-CLN-019
	# Si llenar un balde teñido lo devolviera a celeste, cambiar de jabón no costaría el viaje al
	# inodoro: bastaría con volver a la canilla.
	var con_agua := _con_agua()
	assert_int(con_agua.llenar()).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_YA_LLENO)
	assert_int(con_agua.agua()).is_equal(ReglasDeLaLimpieza.Agua.LIMPIA)
	var azul := _tenido(AZUL)
	assert_int(azul.llenar()).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_YA_LLENO)
	assert_int(azul.agua()).is_equal(AZUL)


func test_el_jabon_tine_el_agua_sin_jabon() -> void:  # AC-CLN-020
	var balde := _con_agua()
	assert_int(balde.tenir(ROSA)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_TENIDO)
	assert_int(balde.agua()).is_equal(ROSA)
	assert_that(balde.color()).is_equal(ReglasDeLaLimpieza.COLOR_DEL_AGUA[ROSA])


func test_tenir_un_balde_vacio_no_hace_nada() -> void:  # AC-CLN-020
	var balde := Balde.new()
	assert_int(balde.tenir(ROSA)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_VACIO)
	assert_int(balde.agua()).is_equal(ReglasDeLaLimpieza.Agua.NINGUNA)


func test_un_segundo_jabon_no_cambia_el_color() -> void:  # AC-CLN-020
	# Ni otro jabón ni el mismo: el balde teñido se vacía para cambiar, y echar el mismo jabón dos
	# veces no es un gesto que haga algo.
	var balde := _tenido(ROSA)
	for otro: ReglasDeLaLimpieza.Agua in [AMARILLO, ROSA]:
		assert_int(balde.tenir(otro)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_YA_TENIDO)
		assert_int(balde.agua()).is_equal(ROSA)


func test_tenir_con_algo_que_no_es_un_jabon_no_hace_nada() -> void:
	# No es un gesto del juego: es el borde de la firma. Teñir de «ninguna» vaciaría el balde por
	# la puerta de atrás, y teñir de agua limpia lo dejaría como estaba contestando que cambió.
	var balde := _con_agua()
	for agua: ReglasDeLaLimpieza.Agua in [
		ReglasDeLaLimpieza.Agua.NINGUNA, ReglasDeLaLimpieza.Agua.LIMPIA
	]:
		assert_int(balde.tenir(agua)).is_equal(ReglasDeLaLimpieza.Resultado.SIN_EFECTO)
		assert_int(balde.agua()).is_equal(ReglasDeLaLimpieza.Agua.LIMPIA)


func test_vaciar_un_balde_tenido_lo_deja_listo_para_otro_jabon() -> void:  # AC-CLN-021
	var balde := _tenido(ROSA)
	assert_int(balde.vaciar()).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_VACIADO)
	assert_int(balde.agua()).is_equal(ReglasDeLaLimpieza.Agua.NINGUNA)
	assert_bool(balde.tiene_agua()).is_false()
	assert_int(balde.llenar()).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_LLENADO)
	assert_int(balde.tenir(AMARILLO)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_TENIDO)
	assert_int(balde.agua()).is_equal(AMARILLO)


func test_vaciar_el_agua_sin_jabon_tambien_vacia() -> void:  # AC-CLN-021
	var balde := _con_agua()
	assert_int(balde.vaciar()).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_VACIADO)
	assert_bool(balde.tiene_agua()).is_false()


func test_vaciar_un_balde_vacio_no_hace_nada() -> void:  # AC-CLN-021
	var balde := Balde.new()
	assert_int(balde.vaciar()).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_VACIO)
	assert_int(balde.agua()).is_equal(ReglasDeLaLimpieza.Agua.NINGUNA)


func test_dos_baldes_no_comparten_el_agua() -> void:
	# Con el agua declarada como estática, el balde de la noche siguiente arrancaría teñido.
	var uno := _tenido(AZUL)
	var otro := Balde.new()
	assert_int(uno.agua()).is_equal(AZUL)
	assert_int(otro.agua()).is_equal(ReglasDeLaLimpieza.Agua.NINGUNA)
