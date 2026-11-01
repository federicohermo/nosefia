## Cuánto frena un obstáculo a la hoja de una puerta, y dónde la detiene.
extends GdUnitTestSuite

const UN_GRADO := deg_to_rad(1.0)


func _hoja_en(angulo: float) -> Puerta:
	var puerta := Puerta.new()
	puerta.alternar()
	puerta.avanzar(angulo / Puerta.VELOCIDAD_DEL_GIRO)
	return puerta


func test_sin_obstaculo_o_con_uno_liviano_la_hoja_no_se_frena() -> void:  # AC-PLY-140 AC-PLY-141
	for obstaculo: FrenoDeLaPuerta.Obstaculo in [
		FrenoDeLaPuerta.Obstaculo.NADA, FrenoDeLaPuerta.Obstaculo.LIVIANO
	]:
		for puede_correrse: bool in [true, false]:
			var freno := FrenoDeLaPuerta.decidir(obstaculo, puede_correrse, 0.0)
			assert_float(freno.factor).is_equal(1.0)
			assert_bool(is_nan(freno.tope)).is_true()


func test_lo_pesado_que_se_puede_correr_frena_sin_detener() -> void:  # AC-PLY-142
	var freno := FrenoDeLaPuerta.decidir(FrenoDeLaPuerta.Obstaculo.PESADO, true, 1.2)
	assert_float(freno.factor).is_between(0.0, 1.0)
	assert_float(freno.factor).is_not_equal(0.0)
	assert_float(freno.factor).is_not_equal(1.0)
	assert_bool(is_nan(freno.tope)).is_true()


func test_lo_pesado_inmovil_detiene_la_hoja_donde_toca_a_cualquier_angulo() -> void:  # AC-PLY-143
	for angulo: float in [0.0, UN_GRADO, Puerta.ANGULO_ABIERTA / 2.0, Puerta.ANGULO_ABIERTA]:
		var freno := FrenoDeLaPuerta.decidir(FrenoDeLaPuerta.Obstaculo.PESADO, false, angulo)
		assert_float(freno.tope).is_equal(angulo)


func test_la_hoja_detenida_queda_en_su_angulo_a_cualquier_angulo() -> void:  # AC-PLY-148
	for fraccion: float in [0.1, 0.5, 0.9]:
		var puerta := _hoja_en(Puerta.ANGULO_ABIERTA * fraccion)
		var detenida := puerta.angulo()
		var freno := FrenoDeLaPuerta.decidir(FrenoDeLaPuerta.Obstaculo.PESADO, false, detenida)
		assert_float(puerta.avanzar(10.0, freno.factor, freno.tope)).is_equal(detenida)
