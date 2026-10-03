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
	mopa.desgastar(1.0, 0.0)
	var carga := mopa.carga_restante()
	assert_int(mopa.mojar_en(Balde.new())).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_VACIO)
	assert_int(mopa.agua()).is_equal(AZUL)
	assert_float(mopa.carga_restante()).is_equal(carga)


func test_el_producto_se_agota_aunque_la_mopa_quede_apoyada() -> void:  # AC-CLN-026
	var mopa := Mopa.new()
	mopa.mojar_en(_balde(AMARILLO))
	mopa.desgastar(ReglasDeLaLimpieza.DURACION_DE_LA_CARGA, 0.0)
	assert_bool(mopa.esta_mojada()).is_false()
	assert_int(Mancha.new(ReglasDeLaLimpieza.TipoDeMancha.POLVO).borrar_con(mopa)).is_equal(
		ReglasDeLaLimpieza.Resultado.MOPA_SECA
	)


func test_caminar_agota_antes_la_carga_y_remojar_la_recupera() -> void:  # AC-CLN-027
	var mopa := Mopa.new()
	var balde := _balde(AMARILLO)
	mopa.mojar_en(balde)
	mopa.desgastar(1.0, ReglasDeLaLimpieza.RECORRIDO_DE_LA_CARGA)
	assert_bool(mopa.esta_mojada()).is_false()
	mopa.mojar_en(balde)
	assert_float(mopa.carga_restante()).is_equal(1.0)
	assert_int(Mancha.new(ReglasDeLaLimpieza.TipoDeMancha.POLVO).borrar_con(mopa)).is_equal(
		ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA
	)


func test_el_desgaste_es_independiente_de_los_cuadros_y_no_recarga() -> void:  # AC-CLN-026
	var entera := Mopa.new()
	var dividida := Mopa.new()
	entera.mojar_en(_balde(AZUL))
	dividida.mojar_en(_balde(AZUL))
	entera.desgastar(2.0, 3.0)
	for indice: int in 20:
		dividida.desgastar(0.1, 0.15)
	assert_float(dividida.carga_restante()).is_equal_approx(entera.carga_restante(), 0.00001)
	var anterior := entera.carga_restante()
	entera.desgastar(-2.0, -3.0)
	assert_float(entera.carga_restante()).is_equal(anterior)
