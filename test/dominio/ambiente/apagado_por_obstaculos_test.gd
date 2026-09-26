## Cuánto se apaga un sonido según los obstáculos entre él y el oído.
extends GdUnitTestSuite

const MAXIMO := ApagadoPorObstaculos.MAXIMO


func test_mas_obstaculos_apagan_mas_hasta_el_maximo() -> void:  # AC-AMB-020
	assert_float(ApagadoPorObstaculos.volumen_db(0.0)).is_equal(0.0)
	assert_float(ApagadoPorObstaculos.corte_hz(0.0)).is_equal(ApagadoPorObstaculos.SIN_CORTE_HZ)
	var uno := ApagadoPorObstaculos.volumen_db(1.0)
	var dos := ApagadoPorObstaculos.volumen_db(2.0)
	assert_float(uno).is_less(0.0)
	assert_float(dos).is_less(uno)
	var corte_uno := ApagadoPorObstaculos.corte_hz(1.0)
	assert_float(corte_uno).is_less(ApagadoPorObstaculos.SIN_CORTE_HZ)
	assert_float(ApagadoPorObstaculos.corte_hz(2.0)).is_less(corte_uno)
	assert_float(ApagadoPorObstaculos.volumen_db(MAXIMO + 1)).is_equal(
		ApagadoPorObstaculos.volumen_db(MAXIMO)
	)
	assert_float(ApagadoPorObstaculos.corte_hz(MAXIMO + 1)).is_equal(
		ApagadoPorObstaculos.corte_hz(MAXIMO)
	)


func test_el_cambio_dura_mas_de_un_cuadro_y_llega() -> void:  # AC-AMB-022
	var nivel := ApagadoPorObstaculos.acercar(0.0, 1, 1.0 / 60.0)
	assert_float(nivel).is_greater(0.0)
	assert_float(nivel).is_less(1.0)
	assert_float(ApagadoPorObstaculos.acercar(nivel, 1, 1.0)).is_equal(1.0)


func test_acercar_no_pasa_del_maximo() -> void:
	assert_float(ApagadoPorObstaculos.acercar(0.0, MAXIMO + 5, 60.0)).is_equal(float(MAXIMO))
