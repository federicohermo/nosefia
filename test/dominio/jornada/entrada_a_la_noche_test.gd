extends GdUnitTestSuite

const Entrada := preload("res://src/dominio/jornada/entrada_a_la_noche.gd")


func test_la_placa_desaparece_antes_de_que_suba_la_persiana() -> void:  # AC-SHF-022
	var entrada := Entrada.new(3)
	entrada.avanzar(1.0)
	assert_str(entrada.texto()).is_equal("NOCHE 3")
	assert_float(entrada.opacidad_de_la_placa()).is_equal(1.0)
	assert_float(entrada.apertura_de_la_persiana()).is_zero()
	assert_bool(entrada.terminada()).is_false()
	entrada.avanzar(0.25)
	assert_float(entrada.opacidad_de_la_placa()).is_equal(0.5)
	assert_float(entrada.apertura_de_la_persiana()).is_zero()
	entrada.avanzar(0.25)
	assert_float(entrada.opacidad_de_la_placa()).is_zero()
	assert_float(entrada.apertura_de_la_persiana()).is_zero()
	entrada.avanzar(0.5)
	assert_float(entrada.apertura_de_la_persiana()).is_equal(0.5)
	assert_bool(entrada.terminada()).is_false()
	entrada.avanzar(0.5)
	assert_float(entrada.apertura_de_la_persiana()).is_equal(1.0)
	assert_bool(entrada.terminada()).is_true()


func test_los_avances_son_monotonos_acotados_y_ignoran_tiempo_no_positivo() -> void:  # AC-SHF-022
	var entrada := Entrada.new(1)
	var opacidad := 1.0
	var apertura := 0.0
	for _paso in 40:
		for tiempo: float in [0.0, -1.0]:
			entrada.avanzar(tiempo)
			assert_float(entrada.opacidad_de_la_placa()).is_equal(opacidad)
			assert_float(entrada.apertura_de_la_persiana()).is_equal(apertura)
		entrada.avanzar(0.1)
		assert_float(entrada.opacidad_de_la_placa()).is_between(0.0, opacidad)
		assert_float(entrada.apertura_de_la_persiana()).is_between(apertura, 1.0)
		opacidad = entrada.opacidad_de_la_placa()
		apertura = entrada.apertura_de_la_persiana()
	assert_bool(entrada.terminada()).is_true()
	entrada.avanzar(100.0)
	assert_float(entrada.opacidad_de_la_placa()).is_zero()
	assert_float(entrada.apertura_de_la_persiana()).is_equal(1.0)
