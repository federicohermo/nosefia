## Cuándo toca un paso: por la distancia recorrida, no por el tiempo.
extends GdUnitTestSuite

const PASO := CadenciaDePasos.DISTANCIA_ENTRE_PASOS


func test_quieto_no_suena_ningun_paso() -> void:  # AC-AMB-019
	var cadencia := CadenciaDePasos.new()
	for _cuadro in range(100):
		assert_bool(cadencia.avanzar(0.0)).is_false()


func test_justo_antes_del_corte_no_suena_y_al_pasarlo_si() -> void:  # AC-AMB-019
	var cadencia := CadenciaDePasos.new()
	assert_bool(cadencia.avanzar(PASO - 0.01)).is_false()
	assert_bool(cadencia.avanzar(0.02)).is_true()
	# Sobró 0,01: el siguiente paso llega 0,01 antes.
	assert_bool(cadencia.avanzar(PASO - 0.005)).is_true()


func test_un_cuadro_largo_suena_un_solo_paso() -> void:  # AC-AMB-019
	var cadencia := CadenciaDePasos.new()
	assert_bool(cadencia.avanzar(PASO * 2.5)).is_true()
	assert_bool(cadencia.avanzar(0.0)).is_false()
	assert_bool(cadencia.avanzar(PASO * 0.49)).is_false()


func test_el_mismo_tramo_a_otra_velocidad_da_los_mismos_pasos() -> void:  # AC-AMB-019
	assert_int(_pasos_en(PASO * 6.5, 0.05)).is_equal(6)
	assert_int(_pasos_en(PASO * 6.5, 0.02)).is_equal(6)


func _pasos_en(tramo: float, por_cuadro: float) -> int:
	var cadencia := CadenciaDePasos.new()
	var pasos := 0
	var recorrido := 0.0
	while recorrido + por_cuadro <= tramo + 0.0001:
		recorrido += por_cuadro
		if cadencia.avanzar(por_cuadro):
			pasos += 1
	return pasos
