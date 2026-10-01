## La mopa: se moja de lo que tiene el balde, y sin gastarle el agua.
extends GdUnitTestSuite

const AZUL := ReglasDeLaLimpieza.Agua.AZUL
const AMARILLO := ReglasDeLaLimpieza.Agua.AMARILLO


func _balde(agua: ReglasDeLaLimpieza.Agua) -> Balde:
	var balde := Balde.new()
	if agua == ReglasDeLaLimpieza.Agua.NINGUNA:
		return balde
	balde.llenar()
	if agua != ReglasDeLaLimpieza.Agua.LIMPIA:
		balde.tenir(agua)
	return balde


func test_una_mopa_nueva_esta_seca() -> void:
	var mopa := Mopa.new()
	assert_int(mopa.agua()).is_equal(ReglasDeLaLimpieza.Agua.NINGUNA)
	assert_bool(mopa.esta_mojada()).is_false()


func test_mojada_en_agua_sin_jabon_queda_mojada_de_agua() -> void:  # AC-CLN-022
	var mopa := Mopa.new()
	var balde := _balde(ReglasDeLaLimpieza.Agua.LIMPIA)
	assert_int(mopa.mojar_en(balde)).is_equal(ReglasDeLaLimpieza.Resultado.MOPA_MOJADA)
	assert_int(mopa.agua()).is_equal(ReglasDeLaLimpieza.Agua.LIMPIA)
	assert_bool(mopa.esta_mojada()).is_true()
	assert_that(mopa.color()).is_equal(balde.color())


func test_se_moja_de_lo_que_tiene_el_balde_aunque_estuviera_de_otro() -> void:  # AC-CLN-022
	var mopa := Mopa.new()
	mopa.mojar_en(_balde(AZUL))
	assert_int(mopa.agua()).is_equal(AZUL)
	var amarillo := _balde(AMARILLO)
	assert_int(mopa.mojar_en(amarillo)).is_equal(ReglasDeLaLimpieza.Resultado.MOPA_MOJADA)
	assert_int(mopa.agua()).is_equal(AMARILLO)
	assert_that(mopa.color()).is_equal(amarillo.color())


func test_mojar_no_gasta_el_agua_del_balde() -> void:  # AC-CLN-022
	# Si mojar vaciara el balde, cada mancha pediría un viaje a la canilla y otro al inodoro.
	var balde := _balde(AMARILLO)
	Mopa.new().mojar_en(balde)
	Mopa.new().mojar_en(balde)
	assert_int(balde.agua()).is_equal(AMARILLO)


func test_en_un_balde_vacio_no_se_moja() -> void:  # AC-CLN-022
	var mopa := Mopa.new()
	assert_int(mopa.mojar_en(Balde.new())).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_VACIO)
	assert_bool(mopa.esta_mojada()).is_false()
	# Y la mojada sigue como estaba: un balde vacío no la seca.
	mopa.mojar_en(_balde(AZUL))
	assert_int(mopa.mojar_en(Balde.new())).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_VACIO)
	assert_int(mopa.agua()).is_equal(AZUL)
